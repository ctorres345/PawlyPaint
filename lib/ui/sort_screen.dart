import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/courses.dart' show allCourses;
import '../logic/scoring.dart';
import '../logic/time_attack.dart';
import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/music.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import '../state/sort_controller.dart';
import 'board.dart' show BoardView, kCell;
import 'coach.dart';
import 'completion_sheet.dart';
import 'desk.dart';
import 'gem_style.dart';
import 'idle_shimmer.dart';
import 'layer_raster.dart';
import 'mini_map.dart';
import 'music_sheet.dart';

/// Sort mode: the picture starts scrambled. Tap misplaced beads to pick them
/// up, then tap the tray or an empty spot that wants their color.
class SortScreen extends StatefulWidget {
  const SortScreen({
    super.key,
    required this.puzzle,
    required this.store,
    this.daily = false,
    this.tutorial = false,
    this.timeAttack,
    this.seed = 0,
    this.dailyChallenge = false,
  });

  final Puzzle puzzle;
  final ProgressStore store;

  /// Opened from today's daily picture, so finishing it counts for the streak.
  final bool daily;

  /// The guided first picture: nothing is saved or scored.
  final bool tutorial;

  /// Set for a Time Attack run at this difficulty: a fresh board scrambled
  /// by [seed], against the clock, never saved.
  final Difficulty? timeAttack;

  /// Today's Time Attack challenge: the same board on every try, with its
  /// own best score.
  final bool dailyChallenge;
  final int seed;

  @override
  State<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends State<SortScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  AppSettings get _settings => SettingsScope.read(context);

  late final SortController game;
  late final List<GemPaints> paints;
  final view = BoardView();
  late final IdleShimmer _shimmer;
  bool _animate = true;
  Animation<double> get shimmer => _shimmer.animation;
  late final Ticker _ticker;
  int _lastFrameUs = 0;
  final clock = ValueNotifier<int>(0);

  /// Ticks every frame while something animates (flights, hint, pulses).
  final frame = ValueNotifier<int>(0);
  Timer? _clockTick;
  final _boardKey = GlobalKey();
  final _trayKey = GlobalKey();
  final _stackKey = GlobalKey();
  late bool showWrong = widget.tutorial;

  /// True while the player holds the preview, showing the finished picture.
  bool peeking = false;
  bool _finished = false;
  int _savedVersion = 0;

  /// The zoom-out after finishing; kept so leaving mid-way can stop it.
  AnimationController? _glide;
  bool _celebrate = false;
  DateTime? _sweepAt;
  int _unsaved = 0;
  MusicController? _music;
  late bool _showTips = !widget.store.seenSortTutorial && !widget.tutorial;

  /// Drains while the combo is alive; restarted on every good drop.
  late final AnimationController _comboBar;
  bool get _timed => widget.timeAttack != null;

  static const _coachSteps = [
    CoachStep(Icons.touch_app_rounded,
        'Beads with a dot are in the wrong spot. Tap one to pick it up, along with any misplaced beads of its color touching it.'),
    CoachStep(Icons.inventory_2_outlined, 'Now tap the tray to put them there. That leaves empty spots behind.'),
    CoachStep(Icons.auto_awesome_rounded,
        'Empty spots show the color they need. Pick up that color (from the tray or the canvas), then tap a glowing spot.'),
    CoachStep(Icons.bolt_rounded,
        'Good drops in a row build a combo for bonus points. Hold the little picture in the corner to peek.'),
    CoachStep(Icons.vibration_rounded,
        'The eye button turns the dots on or off, and the hint shows a good move. Finish the heart!'),
  ];
  int _coach = 0;

  void _endTutorial() {
    widget.store.markSortTutorialSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _coachEvent(SortTapResult result) {
    if (!widget.tutorial) return;
    final next = switch ((_coach, result)) {
      (0, SortTapResult.selected) => 1,
      (0 || 1, SortTapResult.moved) => 2,
      (< 3, SortTapResult.sorted) => 3,
      _ => _coach,
    };
    if (next != _coach) setState(() => _coach = next);
  }

  @override
  void initState() {
    super.initState();
    game = _timed
        ? SortController.timed(widget.puzzle, seed: widget.seed)
        : SortController(widget.puzzle, resume: widget.tutorial ? null : widget.store.sortSaved(widget.puzzle.id));
    _comboBar = AnimationController(vsync: this, duration: Scoring.comboWindow);
    paints = GemPaints.forPuzzle(widget.puzzle);
    _shimmer = IdleShimmer(this)..poke();
    _ticker = createTicker((_) {
      game.tick();
      final hintAt = game.hintAt, missAt = game.mistakeAt;
      final now = DateTime.now();
      if (game.animating ||
          // Picked-up beads and the spots that want them gently pulse.
          (game.selection != null && !_finished) ||
          (hintAt != null && now.difference(hintAt).inMilliseconds < 4000) ||
          (missAt != null && now.difference(missAt).inMilliseconds < 700)) {
        // Flying beads get every frame; the gentle pulses are fine at about
        // 30 a second, which matters on 120 Hz screens.
        final us = now.microsecondsSinceEpoch;
        if (game.animating || us - _lastFrameUs >= 30000) {
          _lastFrameUs = us;
          frame.value++;
        }
      } else {
        // Nothing moving: stop ticking until the next tap, shake or hint.
        frame.value++;
        _ticker.stop();
      }
    });
    clock.value = game.seconds;
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) {
      clock.value = game.seconds;
      if (game.timeUp && !_finished) _timeUp();
    });
    // The clock starts with the run, not with the first tap.
    if (_timed) game.resume();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game.relaxed = SettingsScope.of(context).relaxed;
    if (_music == null) {
      _music = MusicScope.read(context);
      _music!.enterGame();
    }
    // Respect the system "remove animations" setting: the drills stay still.
    final animate = !MediaQuery.of(context).disableAnimations;
    if (animate != _animate) {
      _animate = animate;
      _shimmer.allowed = animate;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      game.pause();
      _save();
    } else if (state == AppLifecycleState.resumed && _timed && !_finished) {
      game.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pause();
    if (!_finished &&
        !widget.tutorial &&
        !_timed &&
        game.game.placed + game.game.shakes > 0 &&
        game.saveVersion != _savedVersion) {
      final state = game.toJson();
      final store = widget.store, id = widget.puzzle.id;
      Future.microtask(() => store.saveSort(id, state));
    }
    if (!widget.tutorial && !_timed && game.bestCombo > widget.store.bestCombo) {
      final store = widget.store, combo = game.bestCombo;
      Future.microtask(() => store.noteCombo(combo));
    }
    final music = _music;
    if (music != null) Future.microtask(music.leaveGame);
    _music = null;
    _glide?.dispose();
    _comboBar.dispose();
    _clockTick?.cancel();
    _ticker.dispose();
    clock.dispose();
    frame.dispose();
    _shimmer.dispose();
    game.dispose();
    view.dispose();
    super.dispose();
  }

  void _save() {
    // Only write when the board changed since the last save.
    if (_finished || widget.tutorial || _timed || game.saveVersion == _savedVersion) return;
    _savedVersion = game.saveVersion;
    _unsaved = 0;
    widget.store.saveSort(widget.puzzle.id, game.toJson());
  }

  /// Runs the per-frame ticker while beads fly or a hint pulses.
  void _wakeTicker() {
    if (!_ticker.isActive) _ticker.start();
  }

  /// On-screen bead size a canvas opens at, and that a hint zooms to.
  static const _comfyCell = 22.0;

  /// Below this bead size a tap zooms in instead of picking a bead.
  static const _minTapCell = 14.0;

  /// How far from the touch a bead still counts as under the fingertip.
  static const _fingerRadius = 18.0;

  void _tap(Offset local) {
    _wakeTicker();
    if (view.cellAt(local) == null) return;
    if (view.cellSize < _minTapCell) {
      view.zoomAt(local, _comfyCell / view.cellSize);
      return;
    }
    // A fingertip covers more than one bead, so aim among those under it.
    final w = widget.puzzle.width;
    _react(game.tapNear([for (final (x, y) in view.cellsNear(local, _fingerRadius)) y * w + x]));
  }

  void _tapTray(Offset local, Size size) {
    _wakeTicker();
    _react(game.tapTray(SortTrayPainter.slotAt(size, game.game.capacity, local)));
  }

  void _react(SortTapResult result) {
    _coachEvent(result);
    switch (result) {
      case SortTapResult.selected:
        _settings.selection();
        _music?.play(Sfx.place);
      case SortTapResult.deselected:
        _settings.selection();
      case SortTapResult.moved:
        _settings.light();
        _music?.play(Sfx.place);
        if (++_unsaved >= 10) _save();
      case SortTapResult.sorted:
        // The chime and the thump brighten as the combo grows.
        final level = Scoring.sortStreakLevel(game.combo);
        _settings.light();
        _music?.play(Sfx.place);
        // The chime lands with the beads flying into place.
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          if (level == 1) _settings.medium();
          if (level == 2) _settings.heavy();
          _music?.play(Sfx.landAt(level));
        });
        if (game.combo >= 2) _comboBar.forward(from: 0);
        if (++_unsaved >= 10) _save();
      case SortTapResult.wrong:
        _settings.medium();
        _music?.play(Sfx.wrong);
        _comboBar.value = 1;
      case SortTapResult.noBeads:
        _settings.light();
        _toast('No beads of that color in the tray yet. Pick up a misplaced one first.');
      case SortTapResult.trayFull:
        _settings.heavy();
        _music?.play(Sfx.wrong);
        _toast('The tray is full. Drop beads into empty spots, or shake the tray.');
      case SortTapResult.complete:
        _settings.heavy();
        Future.delayed(const Duration(milliseconds: 650), () => _music?.play(Sfx.complete));
        _finish();
      case SortTapResult.ignored:
        break;
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ));
  }

  void _hint() {
    _wakeTicker();
    final step = game.hint();
    if (step == null) return;
    if (_timed) _toast('Hint: −${TimeAttack.helpCost} seconds');
    // On big canvases, zoom in a little so the hinted spot is easy to tap.
    final cell = step.fromCell ?? step.toCell;
    if (cell != null && view.cellSize < _comfyCell) {
      final w = widget.puzzle.width;
      final center = view.offset + Offset((cell % w + 0.5) * view.cellSize, (cell ~/ w + 0.5) * view.cellSize);
      view.zoomAt(center, _comfyCell / view.cellSize);
    }
  }

  /// A wide shine sweeps once across the finished picture.
  void _startSweep() {
    if (MediaQuery.of(context).disableAnimations) return;
    _shimmer.poke();
    setState(() => _sweepAt = DateTime.now());
  }

  Future<void> _finish() async {
    _finished = true;
    if (widget.tutorial) {
      setState(() => _coach = _coachSteps.length);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _celebrate = true);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC107), size: 40),
          title: const Text("You're ready!"),
          content: const Text('Every Sort picture works just like this one. Keep your combo going and have fun!'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Let's go"))],
        ),
      );
      _endTutorial();
      return;
    }
    final difficulty = widget.timeAttack;
    final relaxed = difficulty == null && (game.relaxed || game.excusedMistakes);
    final stars = relaxed ? 0 : game.stars;
    if (widget.daily) recordDailyIfToday(widget.store, widget.puzzle);
    final secondsLeft = game.timeLeft;
    final Future<bool> best;
    if (difficulty != null) {
      final overall = widget.store
          .recordTimeAttack(difficulty, won: true, score: game.score, combo: game.bestCombo, secondsLeft: secondsLeft);
      best = widget.dailyChallenge
          ? widget.store.recordDailyTimeAttack(DateTime.now(),
              won: true, score: game.score, combo: game.bestCombo, secondsLeft: secondsLeft)
          : overall;
    } else {
      widget.store.noteCombo(game.bestCombo);
      best = widget.store.recordCompletion(
        PlayMode.sort.key(widget.puzzle.id),
        score: relaxed ? 0 : game.score,
        stars: stars,
        seconds: game.seconds,
      );
    }
    // Let the last beads land, then glide out to the whole picture.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _celebrate = true);
    final (toScale, toOffset) = view.fitTransform();
    final fromScale = view.scale, fromOffset = view.offset;
    final glide = _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    final curve = CurvedAnimation(parent: glide, curve: Curves.easeInOutCubic);
    glide.addListener(() => view.setTransform(
          lerpDouble(fromScale, toScale, curve.value)!,
          Offset.lerp(fromOffset, toOffset, curve.value)!,
        ));
    await glide.forward();
    if (!mounted) return;
    _startSweep();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    final isBest = await best;
    if (!mounted) return;
    final badges = takeNewAchievements(allCourses, widget.store);
    await showCompletionSheet(
      context,
      puzzle: widget.puzzle,
      score: game.score,
      stars: stars,
      seconds: game.seconds,
      mistakes: game.game.mistakes + game.game.shakes,
      isBest: isBest,
      relaxed: relaxed,
      badges: badges,
      bestCombo: game.bestCombo,
      secondsLeft: difficulty == null ? null : secondsLeft,
      title: difficulty == null ? 'Masterpiece complete!' : 'You beat the clock!',
      done: difficulty == null ? 'Back to the course' : 'Back to Time Attack',
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Time Attack ran out: count the round and offer another go.
  /// The board for another try: a fresh scramble, except today's challenge
  /// which stays the same.
  int get _nextSeed => widget.dailyChallenge ? widget.seed : widget.seed + 1;

  Future<void> _timeUp() async {
    _finished = true;
    _settings.heavy();
    _music?.play(Sfx.wrong);
    setState(() {});
    await widget.store
        .recordTimeAttack(widget.timeAttack!, won: false, score: game.score, combo: game.bestCombo, secondsLeft: 0);
    if (widget.dailyChallenge) {
      await widget.store
          .recordDailyTimeAttack(DateTime.now(), won: false, score: game.score, combo: game.bestCombo, secondsLeft: 0);
    }
    if (!mounted) return;
    final badges = takeNewAchievements(allCourses, widget.store);
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.timer_off_rounded, size: 40),
        title: const Text("Time's up!"),
        content: Text([
          'You sorted ${(game.progress * 100).floor()}% of ${widget.puzzle.title}.',
          if (game.bestCombo > 1) 'Best combo: ×${game.bestCombo}.',
          for (final b in badges) 'New badge: ${b.title}!',
        ].join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Try again')),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SortScreen(
          puzzle: widget.puzzle,
          store: widget.store,
          timeAttack: widget.timeAttack,
          seed: _nextSeed,
          dailyChallenge: widget.dailyChallenge,
        ),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text('The picture gets scrambled again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start over')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _finished = true;
    if (!_timed) await widget.store.resetPuzzle(PlayMode.sort.key(widget.puzzle.id));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => SortScreen(
                puzzle: widget.puzzle,
                store: widget.store,
                daily: widget.daily,
                tutorial: widget.tutorial,
                timeAttack: widget.timeAttack,
                seed: _nextSeed,
                dailyChallenge: widget.dailyChallenge,
              )),
    );
  }

  /// Centre of a board cell, in the coordinates of the screen's stack.
  Offset? _cellCenter(int cell) {
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null || stack == null) return null;
    final w = widget.puzzle.width;
    final local = view.offset + Offset((cell % w + 0.5) * view.cellSize, (cell ~/ w + 0.5) * view.cellSize);
    return stack.globalToLocal(board.localToGlobal(local));
  }

  Rect? _slotRect(int slot) {
    final tray = _trayKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (tray == null || stack == null) return null;
    final r = SortTrayPainter.slotRect(tray.size, game.game.capacity, slot);
    return Rect.fromCenter(
      center: stack.globalToLocal(tray.localToGlobal(r.center)),
      width: r.width,
      height: r.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _finished) return;
        _save();
        if (widget.tutorial) widget.store.markSortTutorialSeen();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: SettingsScope.of(context).theme.desk,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          title: Text(_timed
              ? (widget.dailyChallenge ? 'Daily · ${widget.timeAttack!.label}' : '${widget.timeAttack!.label} run')
              : _finished || widget.store.isDone(widget.puzzle.id)
                  ? widget.puzzle.title
                  : 'Sort the beads'),
          actions: [
            IconButton(
              tooltip: 'Hint',
              icon: const Icon(Icons.tips_and_updates_outlined),
              onPressed: _finished ? null : _hint,
            ),
            IconButton(
              tooltip: showWrong ? 'Hide misplaced beads' : 'Mark misplaced beads',
              icon: Icon(showWrong ? Icons.visibility_rounded : Icons.visibility_outlined),
              onPressed: () => setState(() => showWrong = !showWrong),
            ),
            const MusicButton(),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'restart') _confirmRestart();
                if (v == 'fit') view.fit(view.viewport, widget.puzzle.width, widget.puzzle.height);
                if (v == 'tips') setState(() => _showTips = true);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'fit', child: Text('Show whole canvas')),
                PopupMenuItem(value: 'tips', child: Text('How to play')),
                PopupMenuItem(value: 'restart', child: Text('Start over')),
              ],
            ),
          ],
        ),
        body: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                RepaintBoundary(
                    child: ListenableBuilder(
                  listenable: SettingsScope.of(context).relaxed && !_timed ? game : Listenable.merge([game, clock]),
                  builder: (context, _) => _SortStats(
                    relaxed: game.relaxed && !_timed,
                    progress: game.progress,
                    seconds: _timed ? game.timeLeft : clock.value,
                    countdown: _timed,
                    left: game.game.wrongCount,
                  ),
                )),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                              child: CustomPaint(painter: DeskPainter(SettingsScope.of(context).theme))),
                        ),
                        Positioned.fill(
                          child: Semantics(
                            label: 'Scrambled picture',
                            hint: 'Tap a misplaced bead to pick it up, then tap the tray or an empty spot.',
                            child: Listener(
                                onPointerDown: (_) => _shimmer.poke(),
                                child: RepaintBoundary(
                                    child: _SortBoard(
                                  key: _boardKey,
                                  game: game,
                                  view: view,
                                  shimmer: shimmer,
                                  frame: frame,
                                  paints: paints,
                                  showWrong: showWrong,
                                  peek: peeking,
                                  celebrate: _celebrate,
                                  sweepAt: _sweepAt,
                                  onTap: _tap,
                                ))),
                          ),
                        ),
                        if (!_showTips && !_finished)
                          Positioned(
                            left: 10,
                            top: 10,
                            child: _PeekThumb(
                              puzzle: widget.puzzle,
                              onPeek: (on) {
                                setState(() => peeking = on);
                                if (on && widget.tutorial && _coach == 3) setState(() => _coach = 4);
                              },
                            ),
                          ),
                        if (!_showTips && !_finished)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: _ComboMeter(game: game, bar: _comboBar),
                          ),
                        if (!_showTips && !_finished && !widget.tutorial)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: MiniMap(
                              width: widget.puzzle.width,
                              height: widget.puzzle.height,
                              board: game,
                              version: () => game.boardVersion,
                              cellPaint: (i) {
                                final c = game.game.current[i];
                                return c < 0 ? null : paints[c].base;
                              },
                              view: view,
                            ),
                          ),
                        if (widget.tutorial && _coach < _coachSteps.length)
                          Positioned(
                            left: 112,
                            right: 12,
                            top: 10,
                            child: CoachCard(
                              steps: _coachSteps,
                              step: _coach,
                              onNext: () => setState(() => _coach++),
                              onSkip: _endTutorial,
                            ),
                          ),
                        if (_showTips)
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 12,
                            child: _SortTips(onDone: () {
                              setState(() => _showTips = false);
                              widget.store.markSortTutorialSeen();
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: _TrayPanel(
                    trayKey: _trayKey,
                    game: game,
                    paints: paints,
                    frame: frame,
                    onTap: _tapTray,
                    onShake: () {
                      if (game.shake()) {
                        _wakeTicker();
                        _settings.medium();
                        _music?.play(Sfx.shake);
                        if (_timed) _toast('Shake: −${TimeAttack.helpCost} seconds');
                      }
                    },
                    onUndo: () {
                      if (game.undo()) {
                        _settings.selection();
                        _music?.play(Sfx.place);
                      }
                    },
                  ),
                ),
              ],
            ),
            // Beads flying between the board and the tray.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FlightPainter(
                    game: game,
                    frame: frame,
                    paints: paints,
                    view: view,
                    cellCenter: _cellCenter,
                    slotRect: _slotRect,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortStats extends StatelessWidget {
  const _SortStats({
    required this.relaxed,
    required this.progress,
    required this.seconds,
    required this.left,
    this.countdown = false,
  });

  final bool relaxed;

  /// Time Attack: [seconds] counts down and turns red near the end.
  final bool countdown;

  final double progress;
  final int seconds;
  final int left;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final time = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Text('$left to sort', style: text.labelLarge),
                  if (!relaxed) ...[
                    const SizedBox(width: 16),
                    Icon(
                      countdown ? Icons.hourglass_bottom_rounded : Icons.timer_outlined,
                      size: 18,
                      semanticLabel: countdown ? 'Time left' : 'Time',
                      color: countdown && seconds <= 10 ? scheme.error : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: text.labelLarge?.copyWith(
                        color: countdown && seconds <= 10 ? scheme.error : null,
                        fontWeight: countdown ? FontWeight.w800 : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortTips extends StatelessWidget {
  const _SortTips({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget tip(IconData icon, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: text.bodyMedium)),
            ],
          ),
        );
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort the beads', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            tip(Icons.touch_app_outlined,
                'Tap a misplaced bead to pick it up, together with the misplaced beads of its color touching it.'),
            tip(Icons.inventory_2_outlined, 'Tap the tray to put them there. That leaves empty spots behind.'),
            tip(Icons.auto_awesome_rounded, 'Pick up the color an empty spot needs, then tap the glowing spot.'),
            tip(Icons.bolt_rounded, 'Good drops in a row build a combo for bonus points.'),
            tip(Icons.tips_and_updates_outlined, 'Stuck? The hint button shows a good next move.'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onDone, child: const Text('Got it')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The canvas for Sort mode: tap to send beads down, drag or pinch to move.
class _SortBoard extends StatefulWidget {
  const _SortBoard({
    super.key,
    required this.game,
    required this.view,
    required this.shimmer,
    required this.frame,
    required this.paints,
    required this.showWrong,
    required this.peek,
    required this.celebrate,
    this.sweepAt,
    required this.onTap,
  });

  final SortController game;
  final BoardView view;
  final Animation<double> shimmer;
  final Listenable frame;
  final List<GemPaints> paints;
  final bool showWrong;
  final bool peek;
  final bool celebrate;
  final DateTime? sweepAt;
  final ValueChanged<Offset> onTap;

  @override
  State<_SortBoard> createState() => _SortBoardState();
}

class _SortBoardState extends State<_SortBoard> {
  Size? _fittedFor;
  double _lastScale = 1;
  int _pointers = 0;
  Offset? _downAt;
  final _cache = _SortCache();

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final p = widget.game.puzzle;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (_fittedFor != size) {
        _fittedFor = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) view.fit(size, p.width, p.height, minCell: _SortScreenState._comfyCell);
        });
      }
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) view.zoomAt(e.localPosition, e.scrollDelta.dy > 0 ? 0.9 : 1.1);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Where the finger lands is what it aimed at; it can roll a few
          // pixels before lifting.
          onTapDown: (d) => _downAt = d.localPosition,
          onTapUp: (d) => widget.onTap(_downAt ?? d.localPosition),
          onScaleStart: (d) {
            _lastScale = 1;
            _pointers = d.pointerCount;
          },
          onScaleUpdate: (d) {
            if (d.pointerCount != _pointers) {
              _pointers = d.pointerCount;
              _lastScale = d.scale;
              return;
            }
            if (d.pointerCount > 1) view.zoomAt(d.localFocalPoint, d.scale / _lastScale);
            view.panBy(d.focalPointDelta);
            _lastScale = d.scale;
          },
          child: CustomPaint(
            size: size,
            painter: _SortBoardPainter(
              game: widget.game,
              view: view,
              shimmer: widget.shimmer,
              frame: widget.frame,
              paints: widget.paints,
              showWrong: widget.showWrong,
              peek: widget.peek,
              celebrate: widget.celebrate,
              sweepAt: widget.sweepAt,
              cache: _cache,
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        ),
      );
    });
  }
}

class _SortCache {
  ui.Picture? picture;
  Object? key;

  /// The recorded board as one bitmap at screen resolution.
  final raster = LayerRaster();

  void dispose() {
    picture?.dispose();
    picture = null;
    key = null;
    raster.dispose();
  }
}

final _socket = Paint()..color = const Color(0xFFE2D6CF);
final _socketRim = Paint()
  ..color = const Color(0x22000000)
  ..style = PaintingStyle.stroke;

/// An empty spot where a bead will go, tinted with [fill] when given.
void drawSocket(Canvas canvas, Rect cell, [Paint? fill]) {
  final r = cell.deflate(cell.width * 0.16);
  canvas.drawOval(r, fill ?? _socket);
  _socketRim.strokeWidth = math.max(0.6, cell.width * 0.05);
  canvas.drawOval(r, _socketRim);
}

class _SortBoardPainter extends CustomPainter {
  _SortBoardPainter({
    required this.game,
    required this.view,
    required this.shimmer,
    required this.frame,
    required this.paints,
    required this.showWrong,
    required this.peek,
    required this.celebrate,
    this.sweepAt,
    required this.cache,
    required this.pixelRatio,
  }) : super(repaint: Listenable.merge([game, view, shimmer, frame]));

  final SortController game;
  final BoardView view;
  final Animation<double> shimmer;
  final Listenable frame;
  final List<GemPaints> paints;
  final bool showWrong;
  final bool peek;
  final bool celebrate;
  final DateTime? sweepAt;
  final _SortCache cache;

  /// Device pixels per logical pixel, so the cached bitmap is crisp.
  final double pixelRatio;

  static final _sheet = Paint();
  static final _wrongDot = Paint()..color = const Color(0xCC3B2F36);
  // Two soft rings instead of a blur, which would cost an offscreen pass per
  // picked-up bead every frame.
  static final _glowOuter = Paint()..color = const Color(0x2EFFFFFF);
  static final _glowInner = Paint()..color = const Color(0x55FFFFFF);
  static final _spot = Paint();
  static final _ring = Paint()..style = PaintingStyle.stroke;
  static final _miss = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Rect _cell(int i) {
    final w = game.puzzle.width;
    return Rect.fromLTWH((i % w) * kCell, (i ~/ w) * kCell, kCell, kCell);
  }

  void _record() {
    final key = (game.boardVersion, showWrong, peek, currentLook());
    _sheet.color = canvasTheme.sheet;
    if (cache.key == key && cache.picture != null) return;
    cache.dispose();
    cache.key = key;
    final p = game.puzzle;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final board = Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell);
    final sheet = RRect.fromRectAndRadius(board.inflate(kCell * 0.6), const Radius.circular(kCell * 0.4));
    drawSheet(c, sheet, _sheet);
    // While peeking, show the finished picture instead of the board.
    final cur = peek ? game.game.target : game.game.current;
    for (var i = 0; i < cur.length; i++) {
      final rect = _cell(i);
      // Each spot shows the color that belongs there, like a printed canvas,
      // so a bead in the wrong place stands out against it.
      final spot = paints[game.game.target[i]];
      if (!peek) c.drawRect(rect, spot.pale);
      if (cur[i] < 0) {
        drawSocket(c, rect, spot.paleSelected);
        continue;
      }
      drawGem(c, peek ? rect : rect.deflate(kCell * 0.07), paints[cur[i]]);
      if (showWrong && !peek && game.game.isWrong(i)) {
        c.drawCircle(rect.center, kCell * 0.1, _wrongDot);
      }
    }
    cache.picture = rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _record();
    final p = game.puzzle;
    final now = DateTime.now();
    final t = shimmer.value;
    canvas.save();
    canvas.translate(view.offset.dx, view.offset.dy);
    canvas.scale(view.scale);
    cache.raster.draw(
      canvas,
      key: cache.key!,
      bounds: Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell).inflate(sheetMargin),
      pixelsPerUnit: view.scale * pixelRatio,
      paintLayer: (c) => c.drawPicture(cache.picture!),
    );

    // Spots whose bead is still on its way stay empty until it lands.
    for (final cell in peek ? const <int>[] : game.arriving.keys) {
      final rect = _cell(cell);
      final spot = paints[game.game.target[cell]];
      canvas.drawRect(rect, spot.pale);
      drawSocket(canvas, rect, spot.paleSelected);
    }

    // Shimmer band, brighter and with sparkles once the picture is done.
    final span = (p.width + p.height).toDouble();
    final band = t * 1.6 - 0.3;
    final width = celebrate ? 0.12 : 0.06;
    final sFrom = math.max(0, ((band - width) * span).floor());
    final sTo = math.min(p.width + p.height - 2, ((band + width) * span).ceil());
    for (var s = sFrom; s <= sTo; s++) {
      final shine = (1 - (s / span - band).abs() / width).clamp(0.0, 1.0);
      if (shine <= 0) continue;
      for (var x = math.max(0, s - p.height + 1); x <= math.min(p.width - 1, s); x++) {
        final i = (s - x) * p.width + x;
        final placed = game.game.current[i] >= 0 && !game.arriving.containsKey(i);
        if (placed) drawGemShine(canvas, _cell(i).deflate(kCell * 0.07), shine);
      }
    }
    drawSweep(canvas, sweepAt, Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell), now);
    if (celebrate) {
      for (var i = 0; i < p.cellCount; i++) {
        final hash = (i * 2654435761) & 0xFFFF;
        if (hash % 3 != 0) continue;
        final s = math.sin(2 * math.pi * (t * 6 + hash / 0xFFFF));
        if (s > 0.94) drawGemSparkle(canvas, _cell(i), (s - 0.94) / 0.06);
      }
    }

    final pulse = 0.5 + 0.5 * math.sin(now.millisecondsSinceEpoch / 140);
    final sel = peek ? null : game.selection;
    if (sel != null) {
      // Picked-up beads glow, and every empty spot that wants them breathes.
      // Picked-up beads get a dark-and-white ring that reads on any bead
      // color, white included; every empty spot that wants them breathes.
      final ringWidth = math.max(kCell * 0.09, 1.5 / view.scale);
      for (final c in sel.cells) {
        final r = _cell(c);
        canvas.drawCircle(r.center, kCell * 0.68, _glowOuter);
        canvas.drawCircle(r.center, kCell * 0.52, _glowInner);
        drawGem(canvas, r.deflate(kCell * 0.02), paints[sel.color], pop: 0.25);
        drawSelectRing(canvas, Rect.fromCircle(center: r.center, radius: kCell * 0.5), ringWidth,
            alpha: 0.8 + 0.2 * pulse);
      }
      _spot.color = paints[sel.color].color.withValues(alpha: 0.35 + 0.45 * pulse);
      final cur = game.game.current, target = game.game.target;
      for (var i = 0; i < cur.length; i++) {
        if (cur[i] >= 0 || target[i] != sel.color || game.arriving.containsKey(i)) continue;
        final r = _cell(i).deflate(kCell * (0.2 - 0.06 * pulse));
        canvas.drawOval(r, _spot);
        drawSelectRing(canvas, r, math.max(kCell * 0.07, 1.2 / view.scale), alpha: 0.6 + 0.4 * pulse);
      }
    }

    // Hint: pulsing rings on what to pick up and where it goes.
    final hint = game.hintStep, hintAt = game.hintAt;
    if (hint != null && hintAt != null && now.difference(hintAt).inMilliseconds < 3800) {
      _ring
        ..color = const Color(0xFFFFC107).withValues(alpha: 0.5 + 0.5 * pulse)
        ..strokeWidth = math.max(kCell * 0.12, 2 / view.scale);
      for (final c in [hint.fromCell, hint.toCell]) {
        if (c != null) canvas.drawCircle(_cell(c).center, kCell * (0.62 + 0.12 * pulse), _ring);
      }
    }

    // A tap on a bead that was already right shows a fading cross.
    final miss = game.mistakeCell, missAt = game.mistakeAt;
    if (miss != null && missAt != null) {
      final age = now.difference(missAt).inMilliseconds;
      if (age < 600) {
        final rect = _cell(miss).deflate(kCell * 0.22);
        _miss
          ..color = const Color(0xFFE53935).withValues(alpha: 1 - age / 600)
          ..strokeWidth = kCell * 0.12;
        canvas.drawLine(rect.topLeft, rect.bottomRight, _miss);
        canvas.drawLine(rect.topRight, rect.bottomLeft, _miss);
      }
    }
    canvas.restore();
  }

  final Object look = currentLook();

  @override
  bool shouldRepaint(_SortBoardPainter old) =>
      old.look != look ||
      old.game != game ||
      old.showWrong != showWrong ||
      old.peek != peek ||
      old.celebrate != celebrate ||
      old.sweepAt != sweepAt ||
      old.paints != paints;
}

/// The tray of collected beads, with its shake button. Tap it to put
/// picked-up beads in, or tap a tray bead to pick up its color.
class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.trayKey,
    required this.game,
    required this.paints,
    required this.frame,
    required this.onTap,
    required this.onShake,
    required this.onUndo,
  });

  final GlobalKey trayKey;
  final SortController game;
  final List<GemPaints> paints;
  final Listenable frame;
  final void Function(Offset local, Size size) onTap;
  final VoidCallback onShake;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final g = game.game;
        final full = g.freeSlots <= 0 && !g.isComplete;
        final rows = (g.capacity / SortTrayPainter.columns).ceil();
        final sel = g.selection;
        final waiting = sel != null && !sel.fromTray;
        return Material(
          color: scheme.surface,
          elevation: 6,
          shadowColor: const Color(0x55000000),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: SortTrayPainter.columns / rows,
                  child: Semantics(
                    button: true,
                    label: 'Tray, ${g.tray.length} of ${g.capacity} slots used',
                    hint: waiting ? 'Tap to put the picked-up beads here' : 'Tap a bead to pick up its color',
                    child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => onTap(d.localPosition, box.biggest),
                        child: CustomPaint(
                          key: trayKey,
                          size: box.biggest,
                          painter: SortTrayPainter(
                            tray: g.tray,
                            capacity: g.capacity,
                            paints: paints,
                            full: full,
                            selectedColor: sel != null && sel.fromTray ? sel.color : null,
                            hintColor: game.hintStep?.trayColor,
                            invite: waiting || (game.hintStep != null && game.hintStep!.toCell == null),
                            frame: frame,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18, color: full ? scheme.error : null),
                    const SizedBox(width: 6),
                    Text(
                      full ? 'Tray full' : '${g.tray.length} / ${g.capacity}',
                      style: text.labelLarge?.copyWith(color: full ? scheme.error : null),
                    ),
                    if (waiting) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${sel.cells.length} in hand',
                          style: text.labelMedium?.copyWith(color: scheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else if (sel != null) ...[
                      // What's in hand, since the matching spots may be off-screen.
                      const SizedBox(width: 10),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: paints[sel.color].color,
                          shape: BoxShape.circle,
                          border: Border.all(color: ringInk, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${g.tray.where((c) => c == sel.color).length} held',
                          style: text.labelMedium?.copyWith(color: scheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton.outlined(
                      tooltip: 'Undo',
                      onPressed: game.canUndo ? onUndo : null,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: g.tray.isEmpty ? null : onShake,
                      icon: const Icon(Icons.vibration_rounded),
                      label: const Text('Shake'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SortTrayPainter extends CustomPainter {
  SortTrayPainter({
    required this.tray,
    required this.capacity,
    required this.paints,
    required this.full,
    this.selectedColor,
    this.hintColor,
    this.invite = false,
    Listenable? frame,
  }) : super(repaint: frame);

  static const columns = 12;

  final List<int> tray;
  final int capacity;
  final List<GemPaints> paints;
  final bool full;

  /// Tray beads of this color are picked up.
  final int? selectedColor;

  /// Tray beads of this color are the hint's suggestion.
  final int? hintColor;

  /// Canvas beads are picked up, so the tray glows to say "drop them here".
  final bool invite;

  /// Where tray slot [slot] sits inside a tray of [size].
  static Rect slotRect(Size size, int capacity, int slot) {
    final rows = (capacity / columns).ceil();
    final cw = size.width / columns, ch = size.height / rows;
    final s = math.min(cw, ch);
    return Rect.fromCenter(
      center: Offset((slot % columns + 0.5) * cw, (slot ~/ columns + 0.5) * ch),
      width: s,
      height: s,
    );
  }

  /// The slot under [local] in a tray of [size], or null outside it.
  static int? slotAt(Size size, int capacity, Offset local) {
    final rows = (capacity / columns).ceil();
    final col = (local.dx / (size.width / columns)).floor(), row = (local.dy / (size.height / rows)).floor();
    if (col < 0 || row < 0 || col >= columns || row >= rows) return null;
    final slot = row * columns + col;
    return slot < capacity ? slot : null;
  }

  static final _fullTint = Paint()..color = const Color(0x22E53935);
  static final _inviteTint = Paint();
  static final _ring = Paint()..style = PaintingStyle.stroke;
  static final _slotLine = Paint()
    ..color = const Color(0x55000000)
    ..style = PaintingStyle.stroke;

  /// An empty tray slot: a dashed outline, so the free space is easy to count.
  static void _drawSlot(Canvas canvas, Rect r) {
    final box = RRect.fromRectAndRadius(r.deflate(r.width * 0.1), Radius.circular(r.width * 0.25));
    _slotLine.strokeWidth = math.max(1, r.width * 0.05);
    final dash = r.width * 0.12;
    for (final metric in (Path()..addRRect(box)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        canvas.drawPath(metric.extractPath(d, d + dash), _slotLine);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 140);
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    if (full) canvas.drawRRect(box, _fullTint);
    if (invite && !full) {
      _inviteTint.color = const Color(0xFFFFC107).withValues(alpha: 0.12 + 0.14 * pulse);
      canvas.drawRRect(box, _inviteTint);
    }
    for (var i = 0; i < capacity; i++) {
      final r = slotRect(size, capacity, i);
      if (i >= tray.length) {
        _drawSlot(canvas, r);
        continue;
      }
      final color = tray[i];
      final lifted = color == selectedColor;
      drawCutGem(canvas, lifted ? r.shift(Offset(0, -r.height * 0.12)) : r, paints[color]);
      if (lifted) {
        final c = r.center.translate(0, -r.height * 0.12);
        drawSelectRing(canvas, Rect.fromCircle(center: c, radius: r.width * 0.5), math.max(1.5, r.width * 0.09));
      } else if (color == hintColor) {
        _ring
          ..color = const Color(0xFFFFC107).withValues(alpha: 0.5 + 0.5 * pulse)
          ..strokeWidth = math.max(1.5, r.width * 0.1);
        canvas.drawCircle(r.center, r.width * 0.5, _ring);
      }
    }
  }

  @override
  bool shouldRepaint(SortTrayPainter old) => true;
}

/// Draws beads in flight on top of everything.
class _FlightPainter extends CustomPainter {
  _FlightPainter({
    required this.game,
    required this.frame,
    required this.paints,
    required this.view,
    required this.cellCenter,
    required this.slotRect,
  }) : super(repaint: Listenable.merge([game, view, frame]));

  final SortController game;
  final Listenable frame;
  final List<GemPaints> paints;
  final BoardView view;
  final Offset? Function(int cell) cellCenter;
  final Rect? Function(int slot) slotRect;

  /// Where a flight end sits on screen, and how big a bead is there.
  (Offset, double)? _end(int? cell, int? slot) {
    if (cell != null) {
      final c = cellCenter(cell);
      return c == null ? null : (c, view.cellSize);
    }
    final r = slotRect(slot!);
    return r == null ? null : (r.center, r.width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (game.flights.isEmpty) return;
    final now = DateTime.now();
    for (final f in game.flights) {
      final t = f.progress(now);
      if (t == null || t >= 1) continue;
      final from = _end(f.fromCell, f.fromSlot), to = _end(f.toCell, f.toSlot);
      if (from == null || to == null) continue;
      final e = Curves.easeInOut.transform(t);
      final arc = math.sin(math.pi * e) * 60;
      final pos = Offset.lerp(from.$1, to.$1, e)! - Offset(0, arc);
      final s = lerpDouble(from.$2, to.$2, e)!;
      drawGem(canvas, Rect.fromCenter(center: pos, width: s * 1.1, height: s * 1.1), paints[f.color]);
    }
  }

  @override
  bool shouldRepaint(_FlightPainter old) => true;
}

/// The live combo: a badge that pops on each good drop, with a bar that
/// drains until the combo lapses.
class _ComboMeter extends StatelessWidget {
  const _ComboMeter({required this.game, required this.bar});

  final SortController game;
  final AnimationController bar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([game, bar]),
        builder: (context, _) {
          final combo = game.comboNow();
          final show = combo >= 2 && bar.isAnimating;
          return AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(combo),
              tween: Tween(begin: 1.35, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Semantics(
                liveRegion: true,
                label: show ? 'Combo $combo' : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFFFC107)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Combo ×$combo',
                        style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 84,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: 1 - bar.value,
                            minHeight: 5,
                            color: Colors.white,
                            backgroundColor: Colors.white30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small preview of the finished picture. Hold it to see the whole
/// finished picture on the canvas.
class _PeekThumb extends StatelessWidget {
  const _PeekThumb({required this.puzzle, required this.onPeek});

  final Puzzle puzzle;
  final ValueChanged<bool> onPeek;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Preview the finished picture',
      hint: 'Press and hold',
      child: Listener(
        onPointerDown: (_) => onPeek(true),
        onPointerUp: (_) => onPeek(false),
        onPointerCancel: (_) => onPeek(false),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox.square(
                    dimension: 56,
                    child: CustomPaint(painter: PuzzleThumbPainter(puzzle, complete: true)),
                  ),
                ),
                const SizedBox(height: 2),
                Text('Hold to peek', style: text.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
