import '../models/puzzle.dart';
import 'progress_store.dart';

/// A badge earned by playing.
class Achievement {
  const Achievement(this.id, this.title, this.description, this.isEarned);

  final String id;
  final String title;
  final String description;
  final bool Function(ProgressFacts f) isEarned;
}

/// What the achievements look at, gathered once from the saved progress.
class ProgressFacts {
  ProgressFacts(List<Course> courses, ProgressStore store) : bestStreak = store.bestStreak {
    for (final c in courses) {
      var courseDone = 0;
      for (final level in c.levels) {
        for (final p in level.puzzles) {
          final paint = store.record(PlayMode.paint.key(p.id));
          final sort = store.record(PlayMode.sort.key(p.id));
          if (paint != null || sort != null) {
            finished++;
            courseDone++;
            if (level.difficulty == Difficulty.hard) hardFinished++;
            if (c.special) specialCoursesTouched.add(c.id);
          }
          if (paint != null && sort != null) bothModes++;
          if (sort != null) sortFinished++;
          if ((sort?.bestStars ?? 0) == 3) cleanSorts++;
          if ((paint?.bestStars ?? 0) == 3 || (sort?.bestStars ?? 0) == 3) threeStars++;
          total++;
        }
      }
      if (courseDone == c.puzzles.length) coursesDone++;
      if (c.special) specialCourses++;
    }
  }

  int total = 0;
  int finished = 0;
  int hardFinished = 0;
  int coursesDone = 0;
  int threeStars = 0;
  int sortFinished = 0;
  int cleanSorts = 0;
  int bothModes = 0;
  int specialCourses = 0;
  final Set<String> specialCoursesTouched = {};
  final int bestStreak;
}

final achievements = <Achievement>[
  Achievement('first', 'First sparkle', 'Finish your first picture', (f) => f.finished >= 1),
  Achievement('hard', 'Big canvas', 'Finish a Hard picture', (f) => f.hardFinished >= 1),
  Achievement('both', 'Two ways', 'Finish the same picture in Paint and Sort', (f) => f.bothModes >= 1),
  Achievement('sort5', 'Tidy hands', 'Finish 5 pictures in Sort', (f) => f.sortFinished >= 5),
  Achievement('cleansort', 'Steady tray', 'Earn 3 stars in Sort (no shaking)', (f) => f.cleanSorts >= 1),
  Achievement('stars10', 'Perfectionist', 'Earn 3 stars on 10 pictures', (f) => f.threeStars >= 10),
  Achievement('streak3', 'Little habit', 'Keep a 3-day daily streak', (f) => f.bestStreak >= 3),
  Achievement('streak7', 'Week of sparkle', 'Keep a 7-day daily streak', (f) => f.bestStreak >= 7),
  Achievement('course', 'Collector', 'Finish every picture in a course', (f) => f.coursesDone >= 1),
  Achievement('fan', 'Fan favorite', 'Finish a picture in each special collection',
      (f) => f.specialCourses > 0 && f.specialCoursesTouched.length == f.specialCourses),
  Achievement('half', 'Halfway there', 'Finish half of all pictures', (f) => f.finished * 2 >= f.total),
  Achievement('all', 'Full gallery', 'Finish every picture', (f) => f.finished == f.total),
];

/// IDs of every badge earned so far.
Set<String> earnedAchievements(List<Course> courses, ProgressStore store) {
  final facts = ProgressFacts(courses, store);
  return {
    for (final a in achievements)
      if (a.isEarned(facts)) a.id
  };
}

/// Badges earned but not yet celebrated; marks them as celebrated.
List<Achievement> takeNewAchievements(List<Course> courses, ProgressStore store) {
  final earned = earnedAchievements(courses, store);
  final fresh = [
    for (final a in achievements)
      if (earned.contains(a.id) && !store.hasSeenBadge(a.id)) a
  ];
  if (fresh.isNotEmpty) store.markBadgesSeen(fresh.map((a) => a.id));
  return fresh;
}
