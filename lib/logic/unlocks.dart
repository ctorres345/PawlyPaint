/// What is unlocked: 3-star rewards and the step-by-step gates. Pure rules, no
/// Flutter. Everything is derived from her records, never stored, so a save
/// already qualifies for what it earned the first time it loads.
///
/// Numbers come from the approved tables in PAP-14.
library;

import 'boosters.dart';

/// One reward earned with 3-star pictures. [threshold] is for [UnlockTables.basePictureCount].
class Reward {
  const Reward(this.id, this.threshold);

  /// Stable id, like `reward.bg.sakura`. Content tickets look these up.
  final String id;
  final int threshold;
}

/// The PAP-14 tables, in one place.
abstract final class UnlockTables {
  /// Rewards are written for this many pictures and scale down for smaller builds.
  static const basePictureCount = 160;

  static const rewards = [
    Reward('reward.bg.sakura', 5),
    Reward('reward.palette.matcha', 10),
    Reward('reward.frame.polaroid', 15),
    Reward('reward.drill.heart', 20),
    Reward('reward.drill.glitter', 25),
    Reward('reward.bg.ocean', 30),
    Reward('reward.palette.midnight', 40),
    Reward('reward.frame.lace', 45),
    Reward('reward.secret.song', 50),
    Reward('reward.drill.pastel', 55),
    Reward('reward.bg.starry', 65),
    Reward('reward.frame.paw', 75),
    Reward('reward.mochi.outfit', 80),
    Reward('reward.drill.holographic', 90),
    Reward('reward.palette.strawberry', 100),
    Reward('reward.drill.golden', 120),
  ];

  /// Total stars (best of Paint and Sort per picture) a course needs. Courses
  /// not listed here are open from the start, including the sideload-only
  /// ones and For You. These are not scaled.
  static const courseStars = {'garden': 15, 'sweets': 35, 'catcafe': 60, 'sea_world': 90, 'jungle': 125, 'retro': 165};

  /// Gated courses that don't exist yet. A test checks every other gated id is a real course.
  static const futureCourseIds = {'sea_world', 'jungle', 'retro'};

  /// The UI follows the gates (PAP-41). Builds before it showed everything, so
  /// every save they wrote keeps the legacy gates in `keptOpen` and stays fully open.
  static const gatesEnforced = true;

  static const sortAfterPaint = 1;
  static const timeAttackAfterSort = 3;
  static const dailyAfterFinished = 1;

  /// Finished Paint pictures each booster needs.
  static const boosterAfterPaint = {Booster.bomb: 1, Booster.wand: 3, Booster.brush: 6};

  static const modeSort = 'mode.sort';
  static const modeTimeAttack = 'mode.timeAttack';
  static const modeDaily = 'mode.daily';

  static String courseId(String id) => 'course.$id';
  static String boosterId(Booster b) => 'booster.${b.name}';

  /// Every course, mode and booster gate a version-1 save had open. Courses
  /// that don't exist yet are left out, so they still unlock with stars.
  static Set<String> get legacyIds => {
        for (final id in courseStars.keys)
          if (!futureCourseIds.contains(id)) courseId(id),
        modeSort,
        modeTimeAttack,
        modeDaily,
        for (final b in Booster.values) boosterId(b),
      };

  /// Every id [UnlockState.unlocked] can hold.
  static Set<String> get gatedIds => {
        for (final id in courseStars.keys) courseId(id),
        modeSort,
        modeTimeAttack,
        modeDaily,
        for (final b in Booster.values) boosterId(b),
        for (final r in rewards) r.id,
      };

  /// [threshold] scaled down for a build with [pictureCount] pictures.
  /// It stops growing at 160 pictures. Below that it grows with the build, so
  /// the store keeps every earned reward in `keptOpen` when a picture is finished.
  /// It is never above [pictureCount], so every reward stays reachable.
  static int scaled(int threshold, int pictureCount) {
    if (pictureCount <= 0) return 1;
    final n = pictureCount < basePictureCount ? pictureCount : basePictureCount;
    final s = (threshold * n / basePictureCount).round();
    return s.clamp(1, pictureCount);
  }
}

/// What the rules read. Built from every record, hidden courses included.
class UnlockInput {
  const UnlockInput({
    this.threeStarPictures = const {},
    this.finishedPaint = 0,
    this.finishedSort = 0,
    this.finishedAny = 0,
    this.gateStars = 0,
    this.pictureCount = 0,
    this.keptOpen = const {},
    this.celebrated = const {},
  });

  /// Pictures with 3 stars in Paint or Sort. A picture counts once.
  final Set<String> threeStarPictures;
  final int finishedPaint;
  final int finishedSort;

  /// Pictures finished in either mode.
  final int finishedAny;

  /// Best of Paint and Sort per picture, added up.
  final int gateStars;

  /// Pictures the running build ships, for scaling rewards.
  final int pictureCount;

  /// Gates a version-1 save already had open, and rewards earned so far.
  /// Both stay open, whatever the build grows to.
  final Set<String> keptOpen;

  /// Unlocks already celebrated; they never lock again.
  final Set<String> celebrated;
}

/// The next thing to earn and how far away it is.
class NextUnlock {
  const NextUnlock(this.id, this.remaining);

  final String id;

  /// 3-star pictures (rewards) or stars (courses) still needed.
  final int remaining;
}

class UnlockState {
  const UnlockState._(this.unlocked, this.nextReward, this.nextCourse, this.celebrated, this.gateStars);

  /// Gated items that are open. Items that are always open never appear here.
  final Set<String> unlocked;
  final NextUnlock? nextReward;
  final NextUnlock? nextCourse;
  final Set<String> celebrated;

  /// Stars toward the course gates (best of Paint and Sort per picture, added up).
  final int gateStars;

  bool isUnlocked(String id) => unlocked.contains(id);

  /// A course with no star gate is open from the start.
  bool isCourseOpen(String courseId) =>
      !UnlockTables.courseStars.containsKey(courseId) || unlocked.contains(UnlockTables.courseId(courseId));

  bool isModeOpen(String modeId) => unlocked.contains(modeId);
  bool isBoosterOpen(Booster b) => unlocked.contains(UnlockTables.boosterId(b));

  /// Unlocked but never celebrated: the end-of-picture screen and the one
  /// catch-up summary both read this, then mark the ids celebrated.
  Set<String> get catchUp => unlocked.difference(celebrated);

  /// What the catch-up summary and the "New!" lines name: [catchUp] without
  /// rewards, which the Unlocks screen owns (PAP-38), and without courses that
  /// are not in the game yet, so they are announced when they ship.
  Set<String> get summary => {
        for (final id in catchUp)
          if (!id.startsWith('reward.') && !_isFutureCourse(id)) id,
      };

  static bool _isFutureCourse(String id) => UnlockTables.futureCourseIds.any((c) => id == UnlockTables.courseId(c));
}

abstract final class Unlocks {
  static UnlockState evaluate(UnlockInput i) {
    final met = <String>{};

    final threeStars = i.threeStarPictures.length;
    int need(Reward r) => UnlockTables.scaled(r.threshold, i.pictureCount);
    for (final r in UnlockTables.rewards) {
      if (threeStars >= need(r)) met.add(r.id);
    }
    for (final e in UnlockTables.courseStars.entries) {
      if (i.gateStars >= e.value) met.add(UnlockTables.courseId(e.key));
    }
    if (i.finishedPaint >= UnlockTables.sortAfterPaint) met.add(UnlockTables.modeSort);
    if (i.finishedSort >= UnlockTables.timeAttackAfterSort) met.add(UnlockTables.modeTimeAttack);
    if (i.finishedAny >= UnlockTables.dailyAfterFinished) met.add(UnlockTables.modeDaily);
    for (final e in UnlockTables.boosterAfterPaint.entries) {
      if (i.finishedPaint >= e.value) met.add(UnlockTables.boosterId(e.key));
    }

    // What a version-1 save had open, and what was already celebrated, stays open.
    final unlocked = {...met, ...i.keptOpen, ...i.celebrated}.intersection(UnlockTables.gatedIds);

    NextUnlock? nextReward;
    for (final r in UnlockTables.rewards) {
      if (!unlocked.contains(r.id)) {
        nextReward = NextUnlock(r.id, need(r) - threeStars);
        break;
      }
    }
    NextUnlock? nextCourse;
    for (final e in UnlockTables.courseStars.entries) {
      // Courses that aren't in the game yet are not "next".
      if (UnlockTables.futureCourseIds.contains(e.key) || unlocked.contains(UnlockTables.courseId(e.key))) continue;
      final left = e.value - i.gateStars;
      if (nextCourse == null || left < nextCourse.remaining) {
        nextCourse = NextUnlock(UnlockTables.courseId(e.key), left);
      }
    }
    return UnlockState._(unlocked, nextReward, nextCourse, i.celebrated, i.gateStars);
  }
}
