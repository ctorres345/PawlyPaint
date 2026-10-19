import 'package:flutter/material.dart';

import '../data/courses.dart' show unlockAfter;
import '../models/puzzle.dart';
import '../state/progress_store.dart';
import 'game_screen.dart';
import 'gem_style.dart';

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: CustomScrollView(
        slivers: [
          for (var l = 0; l < course.levels.length; l++) ...[
            SliverToBoxAdapter(
              child: _LevelHeader(
                course: course,
                level: course.levels[l],
                completed: store.completedIn(course.levels[l].puzzles),
                unlocked: store.isLevelUnlocked(course, l),
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
                  final levelOpen = store.isLevelUnlocked(course, l);
                  return _PuzzleTile(
                    index: i,
                    puzzle: puzzle,
                    unlocked: levelOpen && store.isPuzzleUnlocked(level, i),
                    lockedHint: levelOpen
                        ? 'Finish the picture before this one to unlock it.'
                        : 'Finish $unlockAfter ${course.levels[l - 1].difficulty.label} pictures to unlock '
                            '${level.difficulty.label}.',
                    record: store.record(puzzle.id),
                    saved: store.savedFor(puzzle),
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GameScreen(puzzle: puzzle, store: store)),
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
    required this.onOpen,
  });

  final int index;
  final Puzzle puzzle;
  final bool unlocked;
  final String lockedHint;
  final PuzzleRecord? record;
  final SavedGame? saved;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final done = record != null;
    final progress = saved == null ? 0.0 : saved!.placedCount / puzzle.cellCount;
    final label = done
        ? '${puzzle.title}, ${record!.bestStars} of 3 stars, best score ${record!.bestScore}'
        : !unlocked
            ? 'Picture ${index + 1}, locked'
            : saved != null
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
                    saved != null
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
