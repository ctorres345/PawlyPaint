import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/courses.dart' show allCourses;
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
import 'music_sheet.dart';

/// Sort mode: the picture starts scrambled; tap wrong beads to send them to
/// the tray, and the right beads fly back into place.
class SortScreen extends StatefulWidget {
  const SortScreen({super.key, required this.puzzle, required this.store, this.tutorial = false});

  final Puzzle puzzle;
  final ProgressStore store;

  /// The guided first picture: nothing is saved or scored.
  final bool tutorial;

  @override
  State<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends State<SortScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  AppSettings get _settings => SettingsScope.read(context);

  late final SortController game;
  late final List<GemPaints> paints;
  final view = BoardView();
  late final AnimationController shimmer;
  late final Ticker _ticker;
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
  bool _celebrate = false;
  int _unsaved = 0;
  MusicController? _music;
  late bool _showTips = !widget.store.seenSortTutorial && !widget.tutorial;

  static const _coachSteps = [
    CoachStep(Icons.touch_app_rounded,
        'Some beads are in the wrong spot (marked with a dot for now). Tap one to send it to the tray.'),
    CoachStep(Icons.auto_awesome_rounded,
        'Beads in the tray fly back to any spot that needs their color. Keep tapping marked beads!'),
    CoachStep(Icons.visibility_rounded, 'Hold the little picture in the corner to peek at the finished heart.'),
    CoachStep(Icons.vibration_rounded,
        "If the tray fills up, press Shake. The eye button turns the dots on or off. Finish the heart!"),
  ];
  int _coach = 0;

  void _endTutorial() {
    widget.store.markSortTutorialSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _coachEvent(SortTapResult result) {
    if (!widget.tutorial) return;
    if (_coach == 0 && (result == SortTapResult.moved || result == SortTapResult.sorted)) {
      setState(() => _coach = result == SortTapResult.sorted ? 2 : 1);
    } else if (_coach == 1 && result == SortTapResult.sorted) {
      setState(() => _coach = 2);
    }
  }

  @override
  void initState() {
    super.initState();
    game = SortController(widget.puzzle, resume: widget.store.sortSaved(widget.puzzle.id));
    paints = GemPaints.forPuzzle(widget.puzzle);
    shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
    _ticker = createTicker((_) {
      game.tick();
      final hintAt = game.hintAt, missAt = game.mistakeAt;
      final now = DateTime.now();
      if (game.animating ||
          (hintAt != null && now.difference(hintAt).inMilliseconds < 2600) ||
          (missAt != null && now.difference(missAt).inMilliseconds < 700)) {
        frame.value++;
      }
    })
      ..start();
    clock.value = game.seconds;
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) => clock.value = game.seconds);
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
    if (!_finished && !widget.tutorial && game.game.placed + game.game.shakes > 0) {
      final state = game.toJson();
      final store = widget.store, id = widget.puzzle.id;
      Future.microtask(() => store.saveSort(id, state));
    }
    final music = _music;
    if (music != null) Future.microtask(music.leaveGame);
    _clockTick?.cancel();
    _ticker.dispose();
    clock.dispose();
    frame.dispose();
    shimmer.dispose();
    game.dispose();
    view.dispose();
    super.dispose();
  }

  void _save() {
    if (_finished || widget.tutorial) return;
    _unsaved = 0;
    widget.store.saveSort(widget.puzzle.id, game.toJson());
  }

  void _tap(Offset local) {
    final cell = view.cellAt(local);
    if (cell == null) return;
    if (view.cellSize < 10) {
      view.zoomAt(local, 30 / view.cellSize);
      return;
    }
    final (x, y) = cell;
    final result = game.tap(y * widget.puzzle.width + x);
    _coachEvent(result);
    switch (result) {
      case SortTapResult.moved:
        _settings.selection();
        _music?.play(Sfx.place);
        if (++_unsaved >= 10) _save();
      case SortTapResult.sorted:
        _settings.light();
        _music?.play(Sfx.place);
        // The chime lands with the bead flying back into place.
        Future.delayed(const Duration(milliseconds: 650), () => _music?.play(Sfx.land));
        if (++_unsaved >= 10) _save();
      case SortTapResult.wrong:
        _settings.medium();
        _music?.play(Sfx.wrong);
      case SortTapResult.trayFull:
        _settings.heavy();
        _music?.play(Sfx.wrong);
        _toast('The tray is full. Shake it to free some space.');
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
    final cell = game.hint();
    if (cell == null) return;
    // On big canvases, zoom in a little so the hinted bead is easy to tap.
    if (view.cellSize < 14) {
      final w = widget.puzzle.width;
      final center = view.offset + Offset((cell % w + 0.5) * view.cellSize, (cell ~/ w + 0.5) * view.cellSize);
      view.zoomAt(center, 22 / view.cellSize);
    }
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
          content: const Text('Every Sort picture works just like this one. Watch the tray space and have fun!'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Let's go"))],
        ),
      );
      _endTutorial();
      return;
    }
    final relaxed = game.relaxed;
    final stars = relaxed ? 0 : game.stars;
    final best = widget.store.recordCompletion(
      PlayMode.sort.key(widget.puzzle.id),
      score: relaxed ? 0 : game.score,
      stars: stars,
      seconds: game.seconds,
    );
    // Let the last beads land, then glide out to the whole picture.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _celebrate = true);
    final (toScale, toOffset) = view.fitTransform();
    final fromScale = view.scale, fromOffset = view.offset;
    final glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
      mistakes: game.game.mistakes + game.game.shakes,
      isBest: isBest,
      relaxed: relaxed,
      badges: badges,
    );
    if (mounted) Navigator.of(context).pop();
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
    await widget.store.resetPuzzle(PlayMode.sort.key(widget.puzzle.id));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SortScreen(puzzle: widget.puzzle, store: widget.store)),
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
        if (didPop) return;
        _save();
        if (widget.tutorial) widget.store.markSortTutorialSeen();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: SettingsScope.of(context).theme.desk,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          title: Text(_finished || widget.store.isCompleted(PlayMode.sort.key(widget.puzzle.id))
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
                ListenableBuilder(
                  listenable: Listenable.merge([game, clock]),
                  builder: (context, _) => _SortStats(
                    relaxed: game.relaxed,
                    progress: game.progress,
                    seconds: clock.value,
                    left: game.game.wrongCount,
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: DeskPainter(SettingsScope.of(context).theme))),
                        Positioned.fill(
                          child: Semantics(
                            label: 'Scrambled picture',
                            hint: 'Tap a bead that is in the wrong place to send it to the tray.',
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
                              onTap: _tap,
                            ),
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
                                if (on && widget.tutorial && _coach == 2) setState(() => _coach = 3);
                              },
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
                    onShake: () {
                      if (game.shake()) {
                        _settings.medium();
                        _music?.play(Sfx.shake);
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
  const _SortStats({required this.relaxed, required this.progress, required this.seconds, required this.left});

  final bool relaxed;

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
                    const Icon(Icons.timer_outlined, size: 18, semanticLabel: 'Time'),
                    const SizedBox(width: 4),
                    Text(time, style: text.labelLarge),
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
            tip(Icons.touch_app_outlined, 'Some beads are in the wrong place. Tap one to send it to the tray.'),
            tip(Icons.auto_awesome_rounded, 'Beads in the tray fly back to any spot that needs their color.'),
            tip(Icons.inventory_2_outlined, "Mind the tray's space. If it fills up, shake it to free some room."),
            tip(Icons.tips_and_updates_outlined, 'Stuck? The hint button shows a good next bead.'),
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
  final ValueChanged<Offset> onTap;

  @override
  State<_SortBoard> createState() => _SortBoardState();
}

class _SortBoardState extends State<_SortBoard> {
  Size? _fittedFor;
  double _lastScale = 1;
  int _pointers = 0;
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
          if (mounted) view.fit(size, p.width, p.height);
        });
      }
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) view.zoomAt(e.localPosition, e.scrollDelta.dy > 0 ? 0.9 : 1.1);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onTap(d.localPosition),
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
              cache: _cache,
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

  void dispose() {
    picture?.dispose();
    picture = null;
    key = null;
  }
}

final _socket = Paint()..color = const Color(0xFFE2D6CF);
final _socketRim = Paint()
  ..color = const Color(0x22000000)
  ..style = PaintingStyle.stroke;

/// An empty spot where a bead will go.
void drawSocket(Canvas canvas, Rect cell) {
  final r = cell.deflate(cell.width * 0.16);
  canvas.drawOval(r, _socket);
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
    required this.cache,
  }) : super(repaint: Listenable.merge([game, view, shimmer, frame]));

  final SortController game;
  final BoardView view;
  final Animation<double> shimmer;
  final Listenable frame;
  final List<GemPaints> paints;
  final bool showWrong;
  final bool peek;
  final bool celebrate;
  final _SortCache cache;

  static final _sheet = Paint();
  static final _sheetShadow = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  static final _wrongDot = Paint()..color = const Color(0xCC3B2F36);
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
    c.drawRRect(sheet.shift(const Offset(0, 4)), _sheetShadow);
    c.drawRRect(sheet, _sheet);
    // While peeking, show the finished picture instead of the board.
    final cur = peek ? game.game.target : game.game.current;
    for (var i = 0; i < cur.length; i++) {
      final rect = _cell(i);
      if (cur[i] < 0) {
        drawSocket(c, rect);
        continue;
      }
      drawGem(c, rect, paints[cur[i]]);
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
    canvas.drawPicture(cache.picture!);

    // Spots whose bead is still on its way stay empty until it lands.
    final sheetPaint = _sheet;
    for (final cell in peek ? const <int>[] : game.arriving.keys) {
      final rect = _cell(cell);
      canvas.drawRect(rect, sheetPaint);
      drawSocket(canvas, rect);
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
        if (game.game.current[i] >= 0 && !game.arriving.containsKey(i)) drawGemShine(canvas, _cell(i), shine);
      }
    }
    if (celebrate) {
      for (var i = 0; i < p.cellCount; i++) {
        final hash = (i * 2654435761) & 0xFFFF;
        if (hash % 3 != 0) continue;
        final s = math.sin(2 * math.pi * (t * 6 + hash / 0xFFFF));
        if (s > 0.94) drawGemSparkle(canvas, _cell(i), (s - 0.94) / 0.06);
      }
    }

    // Hint: a pulsing ring around a good bead to tap.
    final hint = game.hintCell, hintAt = game.hintAt;
    if (hint != null && hintAt != null && now.difference(hintAt).inMilliseconds < 2500) {
      final pulse = 0.5 + 0.5 * math.sin(now.millisecondsSinceEpoch / 120);
      _ring
        ..color = const Color(0xFFFFC107).withValues(alpha: 0.5 + 0.5 * pulse)
        ..strokeWidth = math.max(kCell * 0.12, 2 / view.scale);
      canvas.drawCircle(_cell(hint).center, kCell * (0.62 + 0.12 * pulse), _ring);
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
      old.paints != paints;
}

/// The tray of collected beads, with its shake button.
class _TrayPanel extends StatelessWidget {
  const _TrayPanel({required this.trayKey, required this.game, required this.paints, required this.onShake});

  final GlobalKey trayKey;
  final SortController game;
  final List<GemPaints> paints;
  final VoidCallback onShake;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final g = game.game;
        final full = g.freeSlots == 0 && !g.isComplete;
        final rows = (g.capacity / SortTrayPainter.columns).ceil();
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
                    label: 'Tray, ${g.tray.length} of ${g.capacity} slots used',
                    child: CustomPaint(
                      key: trayKey,
                      painter: SortTrayPainter(tray: g.tray, capacity: g.capacity, paints: paints, full: full),
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
                    const Spacer(),
                    full
                        ? FilledButton.icon(
                            onPressed: onShake,
                            icon: const Icon(Icons.vibration_rounded),
                            label: const Text('Shake tray'),
                          )
                        : OutlinedButton.icon(
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
  SortTrayPainter({required this.tray, required this.capacity, required this.paints, required this.full});

  static const columns = 12;

  final List<int> tray;
  final int capacity;
  final List<GemPaints> paints;
  final bool full;

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

  static final _fullTint = Paint()..color = const Color(0x22E53935);

  @override
  void paint(Canvas canvas, Size size) {
    if (full) {
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)), _fullTint);
    }
    for (var i = 0; i < capacity; i++) {
      final r = slotRect(size, capacity, i);
      if (i < tray.length) {
        drawGem(canvas, r.deflate(r.width * 0.04), paints[tray[i]]);
      } else {
        drawSocket(canvas, r);
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

  @override
  void paint(Canvas canvas, Size size) {
    if (game.flights.isEmpty) return;
    final now = DateTime.now();
    for (final f in game.flights) {
      final t = f.progress(now);
      if (t == null || t >= 1) continue;
      final cell = cellCenter(f.cell);
      final slot = slotRect(f.slot);
      if (cell == null || slot == null) continue;
      final from = f.toTray ? cell : slot.center;
      final to = f.toTray ? slot.center : cell;
      final e = Curves.easeInOut.transform(t);
      final arc = math.sin(math.pi * e) * 60;
      final pos = Offset.lerp(from, to, e)! - Offset(0, arc);
      final cellSize = view.cellSize;
      final s = f.toTray ? lerpDouble(cellSize, slot.width, e)! : lerpDouble(slot.width, cellSize, e)!;
      drawGem(canvas, Rect.fromCenter(center: pos, width: s * 1.1, height: s * 1.1), paints[f.color]);
    }
  }

  @override
  bool shouldRepaint(_FlightPainter old) => true;
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
