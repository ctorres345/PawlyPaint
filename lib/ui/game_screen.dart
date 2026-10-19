import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/puzzle.dart';
import '../state/game_controller.dart';
import '../state/progress_store.dart';
import 'board.dart';
import 'completion_sheet.dart';
import 'gem_style.dart';
import 'tray.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.puzzle, required this.store});

  final Puzzle puzzle;
  final ProgressStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
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
  late bool _showTips = !widget.store.seenTutorial;

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
    if (!_finished && game.placedCount > 0) {
      final snapshot = game.snapshot();
      final store = widget.store, id = widget.puzzle.id;
      Future.microtask(() => store.saveGame(id, snapshot));
    }
    _clockTick?.cancel();
    clock.dispose();
    shimmer.dispose();
    game.dispose();
    view.dispose();
    super.dispose();
  }

  void _save() {
    if (_finished || game.placedCount == 0) return;
    _unsavedPlacements = 0;
    widget.store.saveGame(widget.puzzle.id, game.snapshot());
  }

  /// A light tick per drill, thinned out during fast drags.
  void _tick() {
    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds < 40) return;
    _lastHaptic = now;
    HapticFeedback.selectionClick();
  }

  void _onResult(PlaceResult result, {required bool dragging}) {
    switch (result) {
      case PlaceResult.wrong:
        HapticFeedback.mediumImpact();
      case PlaceResult.placed:
        _tick();
        if (++_unsavedPlacements >= 25) _save();
      case PlaceResult.colorComplete:
        HapticFeedback.lightImpact();
        _save();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('✨ Color complete! On to the next one.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1400),
          ));
      case PlaceResult.puzzleComplete:
        HapticFeedback.heavyImpact();
        _finish();
      case PlaceResult.ignored:
        break;
    }
  }

  /// Glides back to the whole picture, lets it sparkle, then shows the results.
  Future<void> _finish() async {
    _finished = true;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final stars = game.stars;
    final best = widget.store.recordCompletion(
      widget.puzzle.id,
      score: game.score,
      stars: stars,
      seconds: game.seconds,
    );
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
    await showCompletionSheet(
      context,
      puzzle: widget.puzzle,
      score: game.score,
      stars: stars,
      seconds: game.seconds,
      mistakes: game.mistakes,
      isBest: isBest,
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
      MaterialPageRoute(builder: (_) => GameScreen(puzzle: widget.puzzle, store: widget.store)),
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
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1E7E1),
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
        body: Column(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([game, clock]),
              builder: (context, _) => _StatsBar(
                progress: game.progress,
                seconds: clock.value,
                score: game.score,
                combo: game.combo,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
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
                    if (_showTips) Positioned(left: 12, right: 12, top: 12, child: _Tips(onDone: _dismissTips)),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Tray(
                game: game,
                paints: paints,
                sort: sort,
                onSortChanged: (s) => setState(() => sort = s),
              ),
            ),
          ],
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
  const _StatsBar({required this.progress, required this.seconds, required this.score, required this.combo});

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
          Text('${(progress * 100).floor()}%', style: text.labelLarge),
          const SizedBox(width: 16),
          const Icon(Icons.timer_outlined, size: 18),
          const SizedBox(width: 4),
          Text(time, style: text.labelLarge),
          const SizedBox(width: 16),
          const Icon(Icons.diamond_outlined, size: 18),
          const SizedBox(width: 4),
          Text('$score', style: text.labelLarge),
          if (combo >= 10) ...[
            const SizedBox(width: 8),
            Text('×$combo', style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}
