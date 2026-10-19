import 'package:flutter/material.dart';

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
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        itemCount: course.puzzles.length,
        itemBuilder: (context, i) {
          final puzzle = course.puzzles[i];
          return _PuzzleTile(
            index: i,
            puzzle: puzzle,
            unlocked: store.isPuzzleUnlocked(course, i),
            record: store.record(puzzle.id),
            saved: store.saved(puzzle.id),
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GameScreen(puzzle: puzzle, store: store)),
            ),
          );
        },
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.index,
    required this.puzzle,
    required this.unlocked,
    required this.record,
    required this.saved,
    required this.onOpen,
  });

  final int index;
  final Puzzle puzzle;
  final bool unlocked;
  final PuzzleRecord? record;
  final SavedGame? saved;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final done = record != null;
    final progress = saved == null ? 0.0 : saved!.placedCount / puzzle.cellCount;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: unlocked ? onOpen : null,
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
    );
  }
}
