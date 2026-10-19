import 'package:flutter/material.dart';

import '../data/courses.dart' show unlockAfter;
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
    final totalStars = courses.fold(0, (s, c) => s + store.starsIn(c));
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
            for (var i = 0; i < courses.length; i++) ...[
              _CourseCard(
                course: courses[i],
                unlocked: store.isCourseUnlocked(courses, i),
                lockedHint: i == 0 ? '' : 'Finish $unlockAfter ${courses[i - 1].title} pictures to unlock',
                completed: store.completedIn(courses[i]),
                stars: store.starsIn(courses[i]),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.unlocked,
    required this.lockedHint,
    required this.completed,
    required this.stars,
  });

  final Course course;
  final bool unlocked;
  final String lockedHint;
  final int completed;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = course.puzzles.length;
    final size = course.puzzles.first;
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
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
            onTap: unlocked
                ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseScreen(course: course)))
                : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(course.title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      if (!unlocked) const Icon(Icons.lock_rounded),
                      if (unlocked) ...[
                        const Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
                        Text(' $stars / ${total * 3}', style: text.titleSmall),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${course.subtitle} · ${size.width}×${size.height}', style: text.bodyMedium),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: completed / total,
                      minHeight: 8,
                      backgroundColor: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(unlocked ? '$completed of $total pictures finished' : lockedHint, style: text.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
