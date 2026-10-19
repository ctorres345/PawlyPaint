import 'package:flutter/material.dart';

import '../data/courses.dart' show unlockAfter;
import '../data/tutorial.dart';
import '../models/puzzle.dart';
import '../state/progress_store.dart';
import 'game_screen.dart';
import 'coach.dart';
import 'gem_style.dart';
import 'sort_screen.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.course});

  final Course course;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  /// Remembered while the app is open, so going back keeps the same mode.
  static PlayMode _lastMode = PlayMode.paint;
  PlayMode mode = _lastMode;

  Course get course => widget.course;

  static double? _sortProgress(Map<String, dynamic>? save, Puzzle p) {
    final board = save?['board'];
    if (board is! String || board.length != p.cellCount) return null;
    var right = 0;
    for (var i = 0; i < p.cellCount; i++) {
      if (board.codeUnitAt(i) - 0x41 == p.cells[i]) right++;
    }
    return right / p.cellCount;
  }

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<PlayMode>(
                    segments: const [
                      ButtonSegment(value: PlayMode.paint, icon: Icon(Icons.brush_rounded), label: Text('Paint')),
                      ButtonSegment(value: PlayMode.sort, icon: Icon(Icons.swap_horiz_rounded), label: Text('Sort')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setState(() => mode = _lastMode = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mode == PlayMode.paint
                        ? 'Fill each numbered spot with its matching drill.'
                        : 'The picture starts scrambled. Send misplaced beads to the tray to sort it.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          for (var l = 0; l < course.levels.length; l++) ...[
            SliverToBoxAdapter(
              child: _LevelHeader(
                course: course,
                level: course.levels[l],
                completed: store.completedIn(course.levels[l].puzzles, mode),
                unlocked: store.isLevelUnlocked(course, l, mode),
                previous: l == 0 ? null : course.levels[l - 1],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: course.levels[l].puzzles.length,
                itemBuilder: (context, i) {
                  final level = course.levels[l];
                  final puzzle = level.puzzles[i];
                  final levelOpen = store.isLevelUnlocked(course, l, mode);
                  final sorting = mode == PlayMode.sort;
                  return _PuzzleTile(
                    index: i,
                    puzzle: puzzle,
                    unlocked: levelOpen && store.isPuzzleUnlocked(level, i, mode),
                    lockedHint: levelOpen
                        ? 'Finish the picture before this one to unlock it.'
                        : 'Finish $unlockAfter ${course.levels[l - 1].difficulty.label} pictures to unlock '
                            '${level.difficulty.label}.',
                    record: store.record(mode.key(puzzle.id)),
                    saved: sorting ? null : store.savedFor(puzzle),
                    sortProgress: sorting ? _sortProgress(store.sortSaved(puzzle.id), puzzle) : null,
                    onOpen: () => openWithTutorial(
                      context,
                      mode: mode,
                      store: store,
                      tutorial: () => sorting
                          ? SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true)
                          : GameScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true),
                      open: () =>
                          sorting ? SortScreen(puzzle: puzzle, store: store) : GameScreen(puzzle: puzzle, store: store),
                    ),
                  );
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({
    required this.course,
    required this.level,
    required this.completed,
    required this.unlocked,
    required this.previous,
  });

  final Course course;
  final Level level;
  final int completed;
  final bool unlocked;
  final Level? previous;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final size = level.puzzles.first;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(level.difficulty.label, style: text.titleLarge),
                  Text(
                    unlocked
                        ? '${level.difficulty.blurb} · ${size.width}×${size.height}'
                        : 'Finish $unlockAfter ${previous!.difficulty.label} pictures to unlock',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (unlocked)
              Text('$completed/${level.puzzles.length}', style: text.titleSmall)
            else
              Icon(Icons.lock_rounded, color: scheme.outline, semanticLabel: 'Locked'),
          ],
        ),
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.index,
    required this.puzzle,
    required this.unlocked,
    required this.lockedHint,
    required this.record,
    required this.saved,
    this.sortProgress,
    required this.onOpen,
  });

  final int index;
  final Puzzle puzzle;
  final bool unlocked;
  final String lockedHint;
  final PuzzleRecord? record;
  final SavedGame? saved;

  /// Share of beads already in place for a Sort game in progress.
  final double? sortProgress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final done = record != null;
    final progress = sortProgress ?? (saved == null ? 0.0 : saved!.placedCount / puzzle.cellCount);
    final started = saved != null || sortProgress != null;
    final label = done
        ? '${puzzle.title}, ${record!.bestStars} of 3 stars, best score ${record!.bestScore}'
        : !unlocked
            ? 'Picture ${index + 1}, locked'
            : started
                ? 'Picture ${index + 1}, ${(progress * 100).floor()} percent done'
                : 'Picture ${index + 1}, ${puzzle.width} by ${puzzle.height}, ${puzzle.colorCount} colors';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unlocked
              ? onOpen
              : () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(lockedHint),
                  behavior: SnackBarBehavior.floating,
                )),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: PuzzleThumbPainter(puzzle, placed: saved?.placed, complete: done)),
                        if (!done)
                          Center(
                            child: Icon(
                              unlocked ? Icons.question_mark_rounded : Icons.lock_rounded,
                              size: 40,
                              color: scheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  done ? puzzle.title : 'No. ${index + 1}',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (done)
                  Row(
                    children: [
                      for (var s = 0; s < 3; s++)
                        Icon(
                          s < record!.bestStars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 18,
                          color: s < record!.bestStars ? const Color(0xFFFFC107) : scheme.outlineVariant,
                        ),
                      const Spacer(),
                      Text('${record!.bestScore}', style: text.labelMedium),
                    ],
                  )
                else
                  Text(
                    started
                        ? '${(progress * 100).floor()}% done'
                        : '${puzzle.width}×${puzzle.height} · ${puzzle.colorCount} colors',
                    style: text.labelMedium,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
