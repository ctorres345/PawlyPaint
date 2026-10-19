import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/progress_store.dart';
import 'course_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final totalStars = courses.fold(0, (s, c) => s + store.starsIn(c.puzzles));
    final maxStars = courses.fold(0, (s, c) => s + c.puzzles.length * 3);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              children: [
                Icon(Icons.diamond_rounded, color: scheme.primary, size: 36),
                const SizedBox(width: 10),
                Text('PawlyPaint', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                const Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
                const SizedBox(width: 4),
                Text('$totalStars / $maxStars', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text('Pick a course and fill each mystery picture with sparkly drills.', style: text.bodyMedium),
            const SizedBox(height: 24),
            for (final course in courses) ...[
              _CourseCard(course: course, store: store),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.store});

  final Course course;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = course.puzzles.length;
    final completed = store.completedIn(course.puzzles);
    final stars = store.starsIn(course.puzzles);
    return Semantics(
      button: true,
      label: '${course.title}, $completed of $total pictures finished, $stars stars',
      excludeSemantics: true,
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [course.accent, Color.lerp(course.accent, Colors.white, 0.55)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseScreen(course: course))),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(course.title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      const Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
                      Text(' $stars / ${total * 3}', style: text.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(course.subtitle, style: text.bodyMedium),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: completed / total,
                      minHeight: 8,
                      backgroundColor: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < course.levels.length; i++)
                        _LevelPill(
                          level: course.levels[i],
                          completed: store.completedIn(course.levels[i].puzzles),
                          unlocked: store.isLevelUnlocked(course, i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level, required this.completed, required this.unlocked});

  final Level level;
  final int completed;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!unlocked) ...[const Icon(Icons.lock_rounded, size: 14), const SizedBox(width: 4)],
          Text('${level.difficulty.label}  $completed/${level.puzzles.length}', style: text.labelMedium),
        ],
      ),
    );
  }
}
