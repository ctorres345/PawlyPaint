import 'dart:async';

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

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameController game;
  late final List<GemPaints> paints;
  final view = BoardView();
  late final AnimationController shimmer;
  Timer? _clockTick;
  int _unsavedPlacements = 0;
  bool highlight = true;
  TraySort sort = TraySort.number;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    game = GameController(widget.puzzle, resume: widget.store.saved(widget.puzzle.id));
    paints = GemPaints.forPuzzle(widget.puzzle);
    shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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

  void _onResult(PlaceResult result) {
    switch (result) {
      case PlaceResult.wrong:
        HapticFeedback.mediumImpact();
      case PlaceResult.placed:
        HapticFeedback.selectionClick();
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

  Future<void> _finish() async {
    _finished = true;
    final stars = game.stars;
    final isBest = await widget.store.recordCompletion(
      widget.puzzle.id,
      score: game.score,
      stars: stars,
      seconds: game.seconds,
    );
    if (!mounted) return;
    view.fit(view.viewport, widget.puzzle.width, widget.puzzle.height);
    await Future<void>.delayed(const Duration(milliseconds: 900));
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
    for (var i = 0; i < p.cellCount; i++) {
      if (game.placed[i] == 1 || p.cells[i] != game.selected) continue;
      final dx = i % p.width - center.dx, dy = i ~/ p.width - center.dy;
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

  String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF1E7E1),
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(widget.store.isCompleted(widget.puzzle.id) || _finished ? widget.puzzle.title : 'Mystery picture'),
        actions: [
          IconButton(
            tooltip: 'Find the next ${widget.puzzle.symbolFor(game.selected)}',
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: _finished ? null : _findNext,
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
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'fit', child: Text('Show whole canvas')),
              PopupMenuItem(value: 'restart', child: Text('Start over')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: game,
            builder: (context, _) => _StatsBar(
              progress: game.progress,
              time: _clock(game.seconds),
              score: game.score,
              combo: game.combo,
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Board(
                game: game,
                view: view,
                shimmer: shimmer,
                paints: paints,
                highlight: highlight,
                onResult: _onResult,
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
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.progress, required this.time, required this.score, required this.combo});

  final double progress;
  final String time;
  final int score;
  final int combo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
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
            Text('$combo combo', style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}
