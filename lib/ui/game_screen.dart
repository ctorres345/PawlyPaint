import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../data/courses.dart' show allCourses;
import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/game_controller.dart';
import '../state/music.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import 'board.dart';
import 'coach.dart';
import 'completion_sheet.dart';
import 'desk.dart';
import 'gem_style.dart';
import 'music_sheet.dart';
import 'tray.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.puzzle, required this.store, this.daily = false, this.tutorial = false});

  final Puzzle puzzle;
  final ProgressStore store;

  /// Opened from today's daily picture, so finishing it counts for the streak.
  final bool daily;

  /// The guided first picture: nothing is saved or scored.
  final bool tutorial;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  AppSettings get _settings => SettingsScope.read(context);

  late final GameController game;
  late final List<GemPaints> paints;
  final view = BoardView();
  late final AnimationController shimmer;
  final clock = ValueNotifier<int>(0);
  Timer? _clockTick;
  int _unsavedPlacements = 0;
  DateTime _lastHaptic = DateTime(0);
  bool highlight = true;
  TraySort sort = TraySort.number;
  bool _finished = false;
  bool _celebrate = false;
  late bool _showTips = !widget.store.seenTutorial && !widget.tutorial;

  static const _coachSteps = [
    CoachStep(Icons.touch_app_rounded,
        'Color 1 is picked in the tray below, and its spots glow on the canvas. Tap a glowing spot!'),
    CoachStep(Icons.swipe_rounded, 'Lovely! Now drag your finger across glowing spots to fill several at once.'),
    CoachStep(
        Icons.pinch_rounded, 'Pinch with two fingers to zoom. When a color is done, the next one is picked for you.',
        manual: true),
    CoachStep(Icons.favorite_rounded, 'You can pick any color in the tray anytime. Finish the heart!'),
  ];
  int _coach = 0;
  int _dragPlacements = 0;

  void _endTutorial() {
    widget.store.markTutorialSeen();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    game = GameController(widget.puzzle, resume: widget.store.savedFor(widget.puzzle));
    paints = GemPaints.forPuzzle(widget.puzzle);
    shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
    clock.value = game.seconds;
    // Only the clock text listens to this, so the canvas never rebuilds for it.
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) => clock.value = game.seconds);
    WidgetsBinding.instance.addObserver(this);
  }

  MusicController? _music;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game.relaxed = SettingsScope.of(context).relaxed;
    if (_music == null) {
      _music = MusicScope.read(context);
      _music!.enterGame();
    }
    // Respect the system "remove animations" setting: the drills stay still.
    if (MediaQuery.of(context).disableAnimations) {
      shimmer.stop();
    } else if (!shimmer.isAnimating) {
      shimmer.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      game.pause();
      _save();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pause();
    // The tree is locked during dispose, so the store notifies its listeners afterwards.
    if (!_finished && game.placedCount > 0 && !widget.tutorial) {
      final snapshot = game.snapshot();
      final store = widget.store, id = widget.puzzle.id;
      Future.microtask(() => store.saveGame(id, snapshot));
    }
    final music = _music;
    if (music != null) Future.microtask(music.leaveGame);
    _clockTick?.cancel();
    clock.dispose();
    shimmer.dispose();
    game.dispose();
    view.dispose();
    super.dispose();
  }

  void _save() {
    if (_finished || game.placedCount == 0 || widget.tutorial) return;
    _unsavedPlacements = 0;
    widget.store.saveGame(widget.puzzle.id, game.snapshot());
  }

  /// A light tick per drill, thinned out during fast drags.
  void _tick() {
    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds < 40) return;
    _lastHaptic = now;
    _settings.selection();
  }

  void _onResult(PlaceResult result, {required bool dragging}) {
    if (widget.tutorial && result != PlaceResult.wrong && result != PlaceResult.ignored) {
      if (_coach == 0) setState(() => _coach = 1);
      if (_coach == 1 && dragging && ++_dragPlacements >= 3) setState(() => _coach = 2);
    }
    switch (result) {
      case PlaceResult.wrong:
        _settings.medium();
        _music?.play(Sfx.wrong);
      case PlaceResult.placed:
        _tick();
        _music?.play(Sfx.place);
        if (++_unsavedPlacements >= 25) _save();
      case PlaceResult.colorComplete:
        _settings.light();
        _music?.play(Sfx.color);
        _save();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F)),
                SizedBox(width: 12),
                Expanded(child: Text('Color complete! On to the next one.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1400),
          ));
      case PlaceResult.puzzleComplete:
        _settings.heavy();
        _music?.play(Sfx.complete);
        _finish();
      case PlaceResult.ignored:
        break;
    }
  }

  /// Glides back to the whole picture, lets it sparkle, then shows the results.
  Future<void> _finish() async {
    _finished = true;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (widget.tutorial) {
      setState(() {
        _celebrate = true;
        _coach = _coachSteps.length;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC107), size: 40),
          title: const Text("You're ready!"),
          content: const Text('Every picture works just like this one. Have fun painting!'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Let's go"))],
        ),
      );
      _endTutorial();
      return;
    }
    final relaxed = game.relaxed;
    final stars = relaxed ? 0 : game.stars;
    if (widget.daily) widget.store.recordDaily(DateTime.now());
    final best = widget.store.recordCompletion(
      widget.puzzle.id,
      score: relaxed ? 0 : game.score,
      stars: stars,
      seconds: game.seconds,
    );
    setState(() => _celebrate = true);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final (toScale, toOffset) = view.fitTransform();
    final fromScale = view.scale, fromOffset = view.offset;
    final glide = AnimationController(vsync: this, duration: Duration(milliseconds: reduceMotion ? 1 : 900));
    final curve = CurvedAnimation(parent: glide, curve: Curves.easeInOutCubic);
    glide.addListener(() => view.setTransform(
          lerpDouble(fromScale, toScale, curve.value)!,
          Offset.lerp(fromOffset, toOffset, curve.value)!,
        ));
    await glide.forward();
    glide.dispose();
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
      mistakes: game.mistakes,
      isBest: isBest,
      relaxed: relaxed,
      badges: badges,
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Jumps to the remaining cell of the selected color closest to the view center.
  void _findNext() {
    final p = widget.puzzle;
    final center = view.centerCell;
    int? best;
    var bestDist = double.infinity;
    for (final i in p.cellsByColor[game.selected]) {
      if (game.placed[i] == 1) continue;
      final dx = i % p.width + 0.5 - center.dx, dy = i ~/ p.width + 0.5 - center.dy;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (best != null) view.focusCell(best % p.width, best ~/ p.width);
  }

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text('This clears every drill on this picture.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start over')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _finished = true; // stops dispose from saving the old board
    await widget.store.resetPuzzle(widget.puzzle.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(puzzle: widget.puzzle, store: widget.store, daily: widget.daily)),
    );
  }

  void _dismissTips() {
    setState(() => _showTips = false);
    widget.store.markTutorialSeen();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Back still works from the app bar and the system back button, but the
    // iOS edge swipe is off so painting near the edge never leaves the picture.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _save();
        if (widget.tutorial) widget.store.markTutorialSeen();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: SettingsScope.of(context).theme.desk,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          title:
              Text(widget.store.isCompleted(widget.puzzle.id) || _finished ? widget.puzzle.title : 'Mystery picture'),
          actions: [
            ListenableBuilder(
              listenable: game,
              builder: (context, _) => IconButton(
                tooltip: 'Find the next ${widget.puzzle.symbolFor(game.selected)}',
                icon: const Icon(Icons.center_focus_strong_rounded),
                onPressed: _finished ? null : _findNext,
              ),
            ),
            const MusicButton(),
            IconButton(
              tooltip: highlight ? 'Highlighting on' : 'Highlighting off',
              icon: Icon(highlight ? Icons.lightbulb : Icons.lightbulb_outline),
              onPressed: () => setState(() => highlight = !highlight),
            ),
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final canvas = ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: DeskPainter(SettingsScope.of(context).theme))),
                  Positioned.fill(
                    child: Semantics(
                      label: 'Painting canvas',
                      hint: 'Tap or drag over the cells with the selected number. Pinch to zoom.',
                      child: Board(
                        game: game,
                        view: view,
                        shimmer: shimmer,
                        paints: paints,
                        highlight: highlight,
                        celebrate: _celebrate,
                        onResult: _onResult,
                      ),
                    ),
                  ),
                  if (_showTips) Positioned(left: 12, right: 12, top: 12, child: _Tips(onDone: _dismissTips)),
                  if (widget.tutorial && _coach < _coachSteps.length)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: CoachCard(
                        steps: _coachSteps,
                        step: _coach,
                        onNext: () => setState(() => _coach++),
                        onSkip: _endTutorial,
                      ),
                    ),
                ],
              ),
            );
            final tray = Tray(
              game: game,
              paints: paints,
              sort: sort,
              axis: landscape ? Axis.vertical : Axis.horizontal,
              onSortChanged: (s) => setState(() => sort = s),
            );
            final stats = ListenableBuilder(
              listenable: Listenable.merge([game, clock]),
              builder: (context, _) => _StatsBar(
                relaxed: game.relaxed,
                progress: game.progress,
                seconds: clock.value,
                score: game.score,
                combo: game.combo,
              ),
            );
            if (landscape) {
              return Column(
                children: [
                  stats,
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: SafeArea(right: false, top: false, child: canvas)),
                        SafeArea(left: false, top: false, child: tray),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                stats,
                Expanded(child: canvas),
                SafeArea(top: false, child: tray),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.onDone});

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
            Text('How to play', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            tip(Icons.palette_outlined, 'Pick a color in the tray. Its cells light up on the canvas.'),
            tip(Icons.touch_app_outlined, 'Tap a glowing cell, or drag across them to fill a row.'),
            tip(Icons.pinch_outlined, 'Pinch or use two fingers to zoom and move around.'),
            tip(Icons.center_focus_strong_rounded, 'Lost a cell? The target button finds the next one.'),
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

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.relaxed,
    required this.progress,
    required this.seconds,
    required this.score,
    required this.combo,
  });

  final bool relaxed;

  final double progress;
  final int seconds;
  final int score;
  final int combo;

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
                  Text('${(progress * 100).floor()}%', style: text.labelLarge),
                  if (relaxed) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.spa_rounded, size: 18, color: scheme.primary, semanticLabel: 'Relaxed mode'),
                  ],
                  if (!relaxed) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.timer_outlined, size: 18, semanticLabel: 'Time'),
                    const SizedBox(width: 4),
                    Text(time, style: text.labelLarge),
                    const SizedBox(width: 16),
                    const Icon(Icons.diamond_outlined, size: 18, semanticLabel: 'Score'),
                    const SizedBox(width: 4),
                    Text('$score', style: text.labelLarge),
                    if (combo >= 10) ...[
                      const SizedBox(width: 8),
                      Text('×$combo',
                          style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
                    ],
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
