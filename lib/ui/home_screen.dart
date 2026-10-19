import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/progress_store.dart';
import '../data/tutorial.dart';
import 'coach.dart';
import 'course_screen.dart';
import 'gallery_screen.dart';
import 'game_screen.dart';
import 'gem_style.dart';
import 'sort_screen.dart';
import 'music_sheet.dart';
import 'settings_screen.dart';
import 'time_attack_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final totalStars = courses.fold(0, (s, c) => s + store.starsIn(c.puzzles));
    final maxStars = courses.fold(0, (s, c) => s + ProgressStore.maxStarsIn(c.puzzles));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              children: [
                Icon(Icons.diamond_rounded, color: scheme.primary, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('PawlyPaint', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
                const MusicButton(),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
                const SizedBox(width: 4),
                Text('$totalStars / $maxStars', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text('Pick a course and fill each mystery picture with sparkly drills.', style: text.bodyMedium),
            const SizedBox(height: 20),
            _DailyCard(courses: courses, store: store),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GalleryScreen(courses: courses)),
                    ),
                    icon: const Icon(Icons.collections_rounded),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showHowToPlay(context, store),
                    icon: const Icon(Icons.school_rounded),
                    label: const Text('How to play'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TimeAttackScreen(courses: courses)),
              ),
              icon: const Icon(Icons.timer_rounded),
              label: const Text('Time Attack'),
            ),
            const SizedBox(height: 24),
            for (final course in courses.where((c) => !c.special)) ...[
              _CourseCard(course: course, store: store),
              const SizedBox(height: 16),
            ],
            if (courses.any((c) => c.special)) ...[
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('Special collections', style: text.titleLarge),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final course in courses.where((c) => c.special)) ...[
                _CourseCard(course: course, store: store),
                const SizedBox(height: 16),
              ],
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
    final painted = store.completedIn(course.puzzles, PlayMode.paint);
    final sorted = store.completedIn(course.puzzles, PlayMode.sort);
    final stars = store.starsIn(course.puzzles);
    return Semantics(
      button: true,
      label: '${course.title}, $painted of $total painted, $sorted of $total sorted, $stars stars',
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
                      Text(' $stars / ${ProgressStore.maxStarsIn(course.puzzles)}', style: text.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(course.subtitle, style: text.bodyMedium),
                  const SizedBox(height: 14),
                  _ModeProgress(icon: Icons.brush_rounded, label: 'Paint', done: painted, total: total),
                  const SizedBox(height: 6),
                  _ModeProgress(icon: Icons.swap_horiz_rounded, label: 'Sort', done: sorted, total: total),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < course.levels.length; i++)
                        _LevelPill(
                          level: course.levels[i],
                          painted: store.completedIn(course.levels[i].puzzles, PlayMode.paint),
                          sorted: store.completedIn(course.levels[i].puzzles, PlayMode.sort),
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
  const _LevelPill({required this.level, required this.painted, required this.sorted, required this.unlocked});

  final Level level;
  final int painted;
  final int sorted;
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
          Text('${level.difficulty.label}  ', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Icon(Icons.brush_rounded, size: 13),
          Text(' $painted  ', style: text.labelMedium),
          const Icon(Icons.swap_horiz_rounded, size: 14),
          Text(' $sorted  /${level.puzzles.length}', style: text.labelMedium),
        ],
      ),
    );
  }
}

/// One labelled progress bar for a course in Paint or Sort.
class _ModeProgress extends StatelessWidget {
  const _ModeProgress({required this.icon, required this.label, required this.done, required this.total});

  final IconData icon;
  final String label;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        SizedBox(width: 38, child: Text(label, style: text.labelMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: done / total, minHeight: 8, backgroundColor: Colors.white54),
          ),
        ),
        SizedBox(width: 48, child: Text('$done/$total', textAlign: TextAlign.end, style: text.labelMedium)),
      ],
    );
  }
}

/// Today's surprise picture and the daily streak.
class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.courses, required this.store});

  final List<Course> courses;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final all = [for (final c in courses) ...c.puzzles];
    final id = store.dailyPuzzleId(today, all);
    final puzzle = all.firstWhere((p) => p.id == id);
    final done = store.dailyDoneToday(today);
    final streak = store.streak(today);
    return Semantics(
      button: true,
      label: done ? "Today's picture is done. Streak: $streak days" : "Today's surprise picture. Streak: $streak days",
      excludeSemantics: true,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pickDailyMode(context, store, puzzle),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: PuzzleThumbPainter(
                            puzzle,
                            complete: done,
                            placed: store.savedFor(puzzle)?.placed,
                          ),
                        ),
                        if (!done) Center(child: Icon(Icons.card_giftcard_rounded, color: scheme.primary, size: 32)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's picture", style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        done ? 'Done! Come back tomorrow for a new one.' : 'A surprise picture, just for today.',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 20,
                            color: streak > 0 ? const Color(0xFFFF7043) : scheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            streak == 1 ? '1 day streak' : '$streak day streak',
                            style: text.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks whether to play today's picture in Paint or Sort mode.
void _pickDailyMode(BuildContext context, ProgressStore store, Puzzle puzzle) {
  void play(PlayMode mode) => openWithTutorial(
        context,
        mode: mode,
        store: store,
        tutorial: () => mode == PlayMode.sort
            ? SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true)
            : GameScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true),
        open: () => mode == PlayMode.sort
            ? SortScreen(puzzle: puzzle, store: store, daily: true)
            : GameScreen(puzzle: puzzle, store: store, daily: true),
      );
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('How do you want to play today?', style: Theme.of(sheet).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.brush_rounded),
            title: const Text('Paint'),
            subtitle: const Text('Fill numbered spots with matching drills'),
            onTap: () {
              Navigator.pop(sheet);
              play(PlayMode.paint);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Sort'),
            subtitle: const Text('Unscramble the picture using the tray'),
            onTap: () {
              Navigator.pop(sheet);
              play(PlayMode.sort);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Lets the player replay either tutorial.
void _showHowToPlay(BuildContext context, ProgressStore store) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.brush_rounded),
            title: const Text('Paint tutorial'),
            subtitle: const Text('Fill numbered spots with matching drills'),
            onTap: () {
              Navigator.pop(sheet);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GameScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Sort tutorial'),
            subtitle: const Text('Unscramble a picture using the tray'),
            onTap: () {
              Navigator.pop(sheet);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true),
              ));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
