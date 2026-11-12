import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/boosters.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/state/progress_store.dart';

UnlockState eval({
  Set<String> threeStar = const {},
  int paint = 0,
  int sort = 0,
  int any = 0,
  int stars = 0,
  int pictures = 160,
  Set<String> legacy = const {},
  Set<String> celebrated = const {},
}) =>
    Unlocks.evaluate(UnlockInput(
      threeStarPictures: threeStar,
      finishedPaint: paint,
      finishedSort: sort,
      finishedAny: any,
      gateStars: stars,
      pictureCount: pictures,
      keptOpen: legacy,
      celebrated: celebrated,
    ));

Set<String> ids(int n) => {for (var i = 0; i < n; i++) 'p$i'};

void main() {
  final sideload = buildCourses();
  final store = buildCourses(store: true);

  group('rewards', () {
    test('crossing a threshold unlocks exactly once', () {
      expect(eval(threeStar: ids(4)).unlocked, isNot(contains('reward.bg.sakura')));
      expect(eval(threeStar: ids(5)).unlocked, contains('reward.bg.sakura'));
      expect(eval(threeStar: ids(6)).unlocked.where((i) => i == 'reward.bg.sakura'), hasLength(1));
      // Catch-up lists it once, and not again after it was celebrated.
      final first = eval(threeStar: ids(5));
      expect(first.catchUp, contains('reward.bg.sakura'));
      expect(eval(threeStar: ids(5), celebrated: first.unlocked).catchUp, isEmpty);
    });

    test('next reward and how many more', () {
      final s = eval(threeStar: ids(3));
      expect(s.nextReward?.id, 'reward.bg.sakura');
      expect(s.nextReward?.remaining, 2);
      expect(eval(threeStar: ids(200)).nextReward, isNull);
    });

    test('Paint and Sort 3 stars on one picture count once; relaxed (0 stars) does not', () async {
      final course = sideload.first;
      final p = course.puzzles.first;
      final store = ProgressStore.memory();
      await store.recordCompletion(PlayMode.paint.key(p.id), score: 1, stars: 3, seconds: 1);
      await store.recordCompletion(PlayMode.sort.key(p.id), score: 1, stars: 3, seconds: 1);
      // Relaxed play saves 0 stars (game_screen.dart), so the picture is finished but not 3-star.
      await store.recordCompletion(course.puzzles[1].id, score: 1, stars: 0, seconds: 1);
      final input = store.unlockState(sideload);
      expect(input.nextReward?.remaining, 4, reason: '1 of 5 pictures counted once');
    });
  });

  group('scaling', () {
    test('never scales up and never passes the picture count', () {
      for (final r in UnlockTables.rewards) {
        expect(UnlockTables.scaled(r.threshold, 220), r.threshold, reason: r.id);
        for (final n in [100, 160]) {
          final s = UnlockTables.scaled(r.threshold, n);
          expect(s, inInclusiveRange(1, n), reason: '${r.id} at $n');
        }
      }
      expect(UnlockTables.scaled(120, 100), 75);
    });

    test('every reward is reachable at 100, 160 and 220 pictures', () {
      for (final n in [100, 160, 220]) {
        final all = eval(threeStar: ids(n), pictures: n);
        expect(all.unlocked.containsAll(UnlockTables.rewards.map((r) => r.id)), isTrue, reason: '$n pictures');
      }
    });

    test('a reward earned in a 100-picture build stays earned when the build grows', () async {
      final progress = ProgressStore.memory(pictureCount: 100);
      for (final p in sideload.first.puzzles.take(3)) {
        await progress.recordCompletion(p.id, score: 1, stars: 3, seconds: 1);
      }
      // 5 * 100 / 160 rounds to 3, so Sakura is earned; at 160 pictures it would need 5.
      expect(progress.unlockState(store).unlocked, contains('reward.bg.sakura'));
      expect(progress.unlockState(sideload).unlocked, contains('reward.bg.sakura'));
      expect(progress.unlockState(sideload).catchUp, contains('reward.bg.sakura'));
    });

    test('a reward unlocked at 160 pictures stays unlocked at 220', () {
      final at160 = eval(threeStar: ids(5), pictures: 160);
      final at220 = eval(threeStar: ids(5), pictures: 220, celebrated: at160.unlocked);
      expect(at220.unlocked, containsAll(at160.unlocked));
    });
  });

  group('gates', () {
    test('a fresh save in either build has only the free things open', () {
      for (final courses in [sideload, store]) {
        final s = eval(pictures: courses.fold(0, (n, c) => n + c.puzzles.length));
        expect(s.unlocked, isEmpty);
        expect(s.catchUp, isEmpty);
        expect(s.isModeOpen(UnlockTables.modeSort), isFalse);
        expect(s.isModeOpen(UnlockTables.modeTimeAttack), isFalse);
        expect(s.isModeOpen(UnlockTables.modeDaily), isFalse);
        for (final b in Booster.values) {
          expect(s.isBoosterOpen(b), isFalse);
        }
        for (final c in courses) {
          final gated = UnlockTables.courseStars.containsKey(c.id);
          expect(s.isCourseOpen(c.id), !gated, reason: c.id);
        }
      }
    });

    test('a fresh install of either build has a playable picture', () {
      for (final courses in [sideload, store]) {
        final progress = ProgressStore.memory();
        final state = progress.unlockState(courses);
        final open = courses.where((c) => state.isCourseOpen(c.id));
        expect(open, isNotEmpty);
        final first = open.first;
        expect(progress.isLevelUnlocked(first, 0), isTrue);
        expect(progress.isPuzzleUnlocked(first.levels.first, 0), isTrue);
      }
    });

    test('courses open at their star total', () {
      for (final e in UnlockTables.courseStars.entries) {
        expect(eval(stars: e.value - 1).isCourseOpen(e.key), isFalse, reason: e.key);
        expect(eval(stars: e.value).isCourseOpen(e.key), isTrue, reason: e.key);
      }
      expect(eval(stars: 20).nextCourse?.id, 'course.sweets');
      expect(eval(stars: 20).nextCourse?.remaining, 15);
    });

    test('every gated course id is a real course or a known future one', () {
      final real = {for (final c in sideload) c.id};
      for (final id in UnlockTables.courseStars.keys) {
        expect(real.contains(id) || UnlockTables.futureCourseIds.contains(id), isTrue, reason: id);
      }
      expect(real.intersection(UnlockTables.futureCourseIds), isEmpty);
    });

    test('the course gates are a chain that stays reachable', () {
      // Gate stars are the best of Paint and Sort per picture, so at most 3 per picture.
      for (final courses in [sideload, store]) {
        final gated = UnlockTables.courseStars.entries.where((e) => courses.any((c) => c.id == e.key)).toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        final open = courses.where((c) => !UnlockTables.courseStars.containsKey(c.id)).toList();
        var best = open.fold(0, (n, c) => n + c.puzzles.length * 3);
        for (final g in gated) {
          expect(best, greaterThanOrEqualTo(g.value), reason: '${g.key} unreachable');
          best += courses.firstWhere((c) => c.id == g.key).puzzles.length * 3;
        }
      }
    });

    test('Sort, Time Attack and the daily picture open after finished pictures', () {
      expect(eval(paint: 0).isModeOpen(UnlockTables.modeSort), isFalse);
      expect(eval(paint: 1).isModeOpen(UnlockTables.modeSort), isTrue);
      expect(eval(sort: 2).isModeOpen(UnlockTables.modeTimeAttack), isFalse);
      expect(eval(sort: 3).isModeOpen(UnlockTables.modeTimeAttack), isTrue);
      expect(eval(any: 0).isModeOpen(UnlockTables.modeDaily), isFalse);
      expect(eval(any: 1).isModeOpen(UnlockTables.modeDaily), isTrue);
    });

    test('boosters are introduced one at a time', () {
      expect(eval(paint: 1).isBoosterOpen(Booster.bomb), isTrue);
      expect(eval(paint: 1).isBoosterOpen(Booster.wand), isFalse);
      expect(eval(paint: 3).isBoosterOpen(Booster.wand), isTrue);
      expect(eval(paint: 5).isBoosterOpen(Booster.brush), isFalse);
      expect(eval(paint: 6).isBoosterOpen(Booster.brush), isTrue);
    });

    test('records of hidden courses count in both builds', () async {
      final hidden = sideload.firstWhere((c) => sideloadOnlyCourseIds.contains(c.id));
      for (final courses in [sideload, store]) {
        final progress = ProgressStore.memory();
        for (final p in hidden.puzzles.take(15)) {
          await progress.recordCompletion(p.id, score: 1, stars: 3, seconds: 1);
        }
        final s = progress.unlockState(courses);
        expect(s.isCourseOpen('garden'), isTrue, reason: '45 stars from hidden pictures');
        expect(s.isCourseOpen('sweets'), isTrue);
        expect(s.isCourseOpen('catcafe'), isFalse);
        expect(s.unlocked, contains('reward.palette.matcha'));
        expect(s.isModeOpen(UnlockTables.modeSort), isTrue);
      }
    });

    test('stars use the best of Paint and Sort per picture', () async {
      final p = sideload.first.puzzles.first;
      final progress = ProgressStore.memory();
      await progress.recordCompletion(PlayMode.paint.key(p.id), score: 1, stars: 3, seconds: 1);
      await progress.recordCompletion(PlayMode.sort.key(p.id), score: 1, stars: 2, seconds: 1);
      expect(progress.unlockState(sideload).nextCourse?.remaining, 15 - 3);
    });

    test('sideload-only courses are open from the start', () {
      final s = eval();
      for (final id in sideloadOnlyCourseIds) {
        expect(s.isCourseOpen(id), isTrue);
      }
    });
  });

  group('legacy and celebrated', () {
    test('keptOpen keeps the old gates open and lists them for catch-up', () {
      final s = eval(legacy: UnlockTables.legacyIds);
      expect(s.unlocked, UnlockTables.legacyIds);
      expect(s.catchUp, UnlockTables.legacyIds);
      expect(s.isCourseOpen('catcafe'), isTrue);
      expect(s.isModeOpen(UnlockTables.modeTimeAttack), isTrue);
    });

    test('courses that do not exist yet are not in keptOpen', () {
      final s = eval(legacy: UnlockTables.legacyIds);
      for (final id in UnlockTables.futureCourseIds) {
        expect(s.isCourseOpen(id), isFalse, reason: id);
      }
    });

    test('"next course" never points at a course that is not in the game', () {
      expect(eval(stars: 100, legacy: UnlockTables.legacyIds).nextCourse, isNull);
      expect(eval(stars: 100).nextCourse, isNull, reason: 'every real course is open at 100 stars');
      expect(eval(stars: 20).nextCourse?.id, 'course.sweets');
    });

    test('a celebrated unlock never locks again', () {
      expect(eval(celebrated: {'course.garden'}).isCourseOpen('garden'), isTrue);
    });
  });
}
