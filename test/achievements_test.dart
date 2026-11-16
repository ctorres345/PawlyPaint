import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/achievements.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Puzzle _puzzle(String id) => Puzzle(
      id: id,
      title: id,
      width: 1,
      height: 1,
      cells: Uint8List.fromList([0]),
      palette: const [Color(0xFF000000)],
    );

/// A course with [perLevel] pictures in each of Easy..Extreme.
Course _course(String id, int perLevel, {bool special = false}) => Course(
      id: id,
      title: 'Course $id',
      subtitle: '',
      accent: const Color(0xFF000000),
      special: special,
      levels: [
        for (final d in Difficulty.values)
          Level(difficulty: d, puzzles: [for (var i = 0; i < perLevel; i++) _puzzle('$id-${d.name}-$i')]),
      ],
    );

/// Courses holding about [n] pictures in total (4 levels each, [n] / 4 rounded to whole levels).
List<Course> _build(int n, {int courses = 4}) => [for (var i = 0; i < courses; i++) _course('c$i', n ~/ courses ~/ 4)];

Future<void> _finishAll(ProgressStore store, List<Course> courses, {int stars = 3, bool sort = true}) async {
  for (final p in [for (final c in courses) ...c.puzzles]) {
    await store.recordCompletion(p.id, score: 1, stars: stars, seconds: 1);
    if (sort) await store.recordCompletion(PlayMode.sort.key(p.id), score: 1, stars: stars, seconds: 1);
  }
}

Future<void> _everythingElse(ProgressStore store) async {
  await store.noteCombo(30);
  for (final d in Difficulty.values.take(3)) {
    for (var i = 0; i < 7; i++) {
      await store.recordTimeAttack(d, won: true, score: 1, combo: 1, secondsLeft: 1);
    }
  }
  var day = 0;
  ProgressStore.clock = () => DateTime(2026, 1, 1 + day);
  for (; day < 31; day++) {
    await store.recordCompletion('extra$day', score: 1, stars: 1, seconds: 1);
  }
}

void main() {
  tearDown(() {
    resetRegisteredBadges();
    ProgressStore.clock = DateTime.now;
  });

  final builds = {'sideload': buildCourses(), 'store': buildCourses(store: true)};

  group('series and tiers', () {
    const series = {
      'Perfectionist': ['stars10', 'stars.silver', 'stars.gold'],
      'Gallery': ['gallery.bronze', 'half', 'all'],
      'Days played': ['streak3', 'days.silver', 'days.gold'],
      'Sort combo': ['combo10', 'combo.silver', 'combo.gold'],
      'Time Attack': ['clock', 'clock.silver', 'clock.gold'],
      'Extreme': ['extreme', 'extreme.silver', 'extreme.gold'],
    };

    final sizes = {...builds, '100': _build(100), '160': _build(160), '220': _build(220)};
    sizes.forEach((name, courses) {
      test('every series has bronze, silver and gold with reachable targets: $name', () {
        final n = courses.fold(0, (s, c) => s + c.puzzles.length);
        final list = achievementsFor(store: false, courses: courses);
        final byId = {for (final a in list) a.id: a};
        final facts = ProgressFacts(courses, ProgressStore.memory());
        series.forEach((s, ids) {
          var last = 0;
          for (var i = 0; i < 3; i++) {
            final a = byId[ids[i]]!;
            expect(a.series, s);
            expect(a.tier, BadgeTier.values[i], reason: a.id);
            final target = badgeProgress(a, facts)!.target;
            expect(target, greaterThanOrEqualTo(1), reason: a.id);
            expect(target, greaterThanOrEqualTo(last), reason: '${a.id} not below the tier before');
            last = target;
          }
        });
        for (final id in ['stars10', 'stars.silver', 'stars.gold', 'gallery.bronze', 'half', 'all']) {
          expect(badgeProgress(byId[id]!, facts)!.target, lessThanOrEqualTo(n), reason: id);
        }
        expect(badgeProgress(byId['all']!, facts)!.target, n);
        final extremeTotal = facts.extremeTotal;
        for (final id in ['extreme', 'extreme.silver', 'extreme.gold']) {
          expect(badgeProgress(byId[id]!, facts)!.target, lessThanOrEqualTo(extremeTotal), reason: id);
        }
        expect(badgeProgress(byId['extreme.gold']!, facts)!.target, extremeTotal);
      });
    });

    test('count rows scale down below 160 pictures and stop growing at 160', () {
      int target(List<Course> c, String id) => badgeProgress(
            achievementsFor(store: false, courses: c).firstWhere((a) => a.id == id),
            ProgressFacts(c, ProgressStore.memory()),
          )!
              .target;
      expect(target(_build(160), 'stars10'), 10);
      expect(target(_build(220), 'stars10'), 10);
      expect(target(_build(100), 'stars10'), lessThan(10));
      expect(target(_build(160), 'stars.silver'), 48);
      expect(target(_build(220), 'stars.silver'), 62, reason: '208 pictures: percent rows follow the build');
    });

    test('a series step is earned at its target and progress never passes it', () async {
      final courses = _build(160);
      final store = ProgressStore.memory();
      await store.noteCombo(25);
      final facts = ProgressFacts(courses, store);
      final earned = earnedAchievements(courses, store);
      expect(earned, containsAll(['combo10', 'combo.silver']));
      expect(earned, isNot(contains('combo.gold')));
      final gold = achievementsFor(store: false, courses: courses).firstWhere((a) => a.id == 'combo.gold');
      expect(badgeProgress(gold, facts)!.current, 25);
      await store.noteCombo(99);
      final p = badgeProgress(gold, ProgressFacts(courses, store))!;
      expect((p.current, p.target), (30, 30));
    });

    test('retired Week of sparkle is never offered, but stays earned once seen', () async {
      final courses = buildCourses();
      final store = ProgressStore.memory();
      expect(achievementsFor(store: false, courses: courses).map((a) => a.id), isNot(contains('streak7')));
      expect(achievementsShown(courses, store).map((a) => a.id), isNot(contains('streak7')));
      await store.markBadgesSeen(['streak7']);
      expect(earnedAchievements(courses, store), contains('streak7'));
      expect(achievementsShown(courses, store).map((a) => a.id), contains('streak7'));
      final unseen = ProgressStore.memory();
      expect(earnedAchievements(courses, unseen), isNot(contains('streak7')));
    });
  });

  group('Course master', () {
    test('each course adds bronze, silver and gold; a new course adds three', () {
      final three = _build(120, courses: 3);
      final four = [...three, _course('extra', 10)];
      int masters(List<Course> c) =>
          achievementsFor(store: false, courses: c).where((a) => a.id.startsWith('course.')).length;
      expect(masters(three), 9);
      expect(masters(four), 12);
    });

    test('gold is skipped when a course has no Extreme pictures', () {
      final noExtreme = Course(
        id: 'tiny',
        title: 'Tiny',
        subtitle: '',
        accent: const Color(0xFF000000),
        levels: [
          Level(difficulty: Difficulty.easy, puzzles: [_puzzle('t1')])
        ],
      );
      final ids = achievementsFor(store: false, courses: [noExtreme]).map((a) => a.id);
      expect(ids, containsAll(['course.tiny.bronze', 'course.tiny.silver']));
      expect(ids, isNot(contains('course.tiny.gold')));
    });

    test('the steps follow finished, all 3 stars and Extreme 3 stars', () async {
      final courses = [_course('a', 2)];
      final store = ProgressStore.memory();
      await _finishAll(store, courses, stars: 2, sort: false);
      var earned = earnedAchievements(courses, store);
      expect(earned, contains('course.a.bronze'));
      expect(earned, isNot(contains('course.a.silver')));
      await _finishAll(store, courses, stars: 3, sort: false);
      earned = earnedAchievements(courses, store);
      expect(earned, containsAll(['course.a.silver', 'course.a.gold']));
      final gold = achievementsFor(store: false, courses: courses).firstWhere((a) => a.id == 'course.a.gold');
      expect(gold.mochiTitle, 'Course Champion');
    });

    test('store build offers Course master for its own courses only', () {
      final storeIds = achievementsFor(store: true, courses: builds['store']!).map((a) => a.id);
      expect(storeIds.where((i) => i.startsWith('course.')), hasLength(builds['store']!.length * 3));
      expect(storeIds, isNot(contains('fan')));
    });
  });

  group('titles', () {
    builds.forEach((name, courses) {
      test('every badge has a Mochi title, description and sensible progress: $name', () async {
        final store = ProgressStore.memory();
        final list = achievementsFor(store: name == 'store', courses: courses);
        final facts = ProgressFacts(courses, store);
        for (final a in list) {
          expect(a.mochiTitle, isNotEmpty, reason: a.id);
          expect(a.title, isNotEmpty, reason: a.id);
          final p = badgeProgress(a, facts);
          if (p != null) expect(p.current, lessThanOrEqualTo(p.target), reason: a.id);
        }
        expect(list.map((a) => a.id).toSet(), hasLength(list.length), reason: 'ids are unique');
        final byId = {for (final a in list) a.id: a};
        expect(byId['first']!.mochiTitle, 'Sparkle Kitten');
        expect(byId['stars.gold']!.mochiTitle, 'Sparkle Chef');
        expect(byId['all']!.mochiTitle, 'Curator');
        expect(byId['days.gold']!.mochiTitle, 'Loyal Regular');
        expect(byId['combo.gold']!.mochiTitle, 'Combo Cat');
        expect(byId['clock.gold']!.mochiTitle, 'Speedy Paws');
        expect(byId['extreme.gold']!.mochiTitle, 'Fearless Painter');
        expect(byId['platinum']!.mochiTitle, 'Pawly Master');
      });
    });
  });

  group('platinum and completion', () {
    test('platinum needs every other badge, in both builds', () async {
      for (final entry in builds.entries) {
        final courses = entry.value;
        final store = ProgressStore.memory();
        expect(earnedAchievements(courses, store), isNot(contains('platinum')));
        await _finishAll(store, courses);
        await _everythingElse(store);
        // Time Attack, days, combo and pictures done; secrets-based and 'fan' need the sideload courses only.
        final earned = earnedAchievements(courses, store);
        final missing = achievementsFor(store: entry.key == 'store', courses: courses)
            .where((a) => a.tier != BadgeTier.platinum && !earned.contains(a.id))
            .map((a) => a.id);
        expect(missing, isEmpty, reason: entry.key);
        expect(earned, contains('platinum'), reason: entry.key);
        expect(completionPercent(courses, store), 100, reason: entry.key);
        ProgressStore.clock = DateTime.now;
      }
    });

    test('platinum is not earned while one badge is missing', () async {
      final courses = buildCourses(store: true);
      final store = ProgressStore.memory();
      await _finishAll(store, courses);
      await _everythingElse(store);
      registerBadge(Achievement('feature.test', 'Test', 'A feature badge', (f) => f.secrets.contains('test')));
      expect(earnedAchievements(courses, store), isNot(contains('platinum')));
      expect(completionPercent(courses, store), lessThan(100));
      await store.addSecret('test');
      expect(earnedAchievements(courses, store), contains('platinum'));
    });

    test('a rainbow badge never changes platinum or the percentage', () async {
      final courses = buildCourses(store: true);
      final store = ProgressStore.memory();
      await _finishAll(store, courses);
      await _everythingElse(store);
      final before = completionPercent(courses, store);
      registerBadge(Achievement('rainbow.test', 'Placeholder', 'Placeholder', (f) => false, tier: BadgeTier.rainbow));
      expect(completionPercent(courses, store), before);
      expect(earnedAchievements(courses, store), contains('platinum'));
      expect(earnedAchievements(courses, store), isNot(contains('rainbow.test')));
      expect(progressFacts(courses, store).platinumTarget,
          achievementsFor(store: true, courses: courses).where((a) => a.tier != BadgeTier.rainbow).length - 1);
    });

    test('completion counts earned over all badges, platinum included', () async {
      final courses = buildCourses();
      final store = ProgressStore.memory();
      expect(completionPercent(courses, store), 0);
      await _finishAll(store, courses.take(1).toList());
      final p = completionPercent(courses, store);
      expect(p, inInclusiveRange(1, 99));
    });

    test('a badge stays earned when the build grows', () async {
      final small = [_course('a', 2)];
      final store = ProgressStore.memory();
      await _finishAll(store, small);
      expect(takeNewAchievements(small, store).map((a) => a.id), contains('all'));
      final grown = [...small, _course('b', 2)];
      expect(earnedAchievements(grown, store), contains('all'));
    });
  });

  group('registry', () {
    test('a duplicate id throws', () {
      registerBadge(Achievement('feature.a', 'A', 'A', (f) => false));
      expect(() => registerBadge(Achievement('feature.a', 'B', 'B', (f) => false)), throwsStateError);
      expect(() => registerBadge(Achievement('first', 'B', 'B', (f) => false)), throwsStateError);
      expect(() => registerBadge(Achievement('fake.p', 'P', 'P', (f) => true, tier: BadgeTier.platinum)),
          throwsStateError);
      expect(() => registerBadge(Achievement('fake.r', 'R', 'R', (f) => true, retired: true)), throwsStateError);
    });

    test('registered badges join the list; sideload-only ones skip the store build', () {
      registerBadge(Achievement('feature.a', 'A', 'A', (f) => false));
      registerBadge(Achievement('feature.s', 'S', 'S', (f) => false), sideloadOnly: true);
      final store = achievementsFor(store: true, courses: builds['store']!).map((a) => a.id);
      final side = achievementsFor(store: false, courses: builds['sideload']!).map((a) => a.id);
      expect(store, contains('feature.a'));
      expect(store, isNot(contains('feature.s')));
      expect(side, containsAll(['feature.a', 'feature.s']));
      expect(side.last, 'platinum');
    });

    test('a feature badge reads the store secrets and is celebrated once', () async {
      registerBadge(Achievement('feature.owl', 'Owl', 'Owl', (f) => f.secrets.contains('owl'), tier: BadgeTier.silver));
      final courses = buildCourses();
      final store = ProgressStore.memory();
      expect(takeNewAchievements(courses, store), isEmpty);
      await store.addSecret('owl');
      expect(takeNewAchievements(courses, store).map((a) => a.id), ['feature.owl']);
      expect(takeNewAchievements(courses, store), isEmpty);
    });
  });

  group('baseline', () {
    test('marks what she already qualifies for, quietly, and only once', () async {
      final courses = buildCourses();
      final store = ProgressStore.memory();
      await store.recordCompletion(courses.first.puzzles.first.id, score: 1, stars: 3, seconds: 1);
      await baselineBadges(courses, store);
      expect(store.hasSeenBadge('first'), isTrue);
      expect(store.hasSeenBadge(engineSentinel), isTrue);
      expect(takeNewAchievements(courses, store), isEmpty);
      // Later progress is celebrated as normal, and a second baseline changes nothing.
      await store.noteCombo(10);
      await baselineBadges(courses, store);
      expect(store.hasSeenBadge('combo10'), isFalse);
      expect(takeNewAchievements(courses, store).map((a) => a.id), ['combo10']);
    });

    test('keeps an old retired badge she had reached', () async {
      final courses = buildCourses();
      final store = await _storeWithStreak(7);
      await baselineBadges(courses, store);
      expect(store.hasSeenBadge('streak7'), isTrue);
    });

    test('keeps Little habit for a past 3-day streak even when the run now is short', () async {
      final courses = buildCourses();
      final store = await _storeWithStreak(1, best: 3);
      expect(store.daysPlayed, 1);
      await baselineBadges(courses, store);
      expect(store.hasSeenBadge('streak3'), isTrue);
      expect(earnedAchievements(courses, store), contains('streak3'));
    });

    test('a damaged streak value does not stall loading', () async {
      final store = await _storeWithStreak(2000000000);
      expect(store.daysPlayed, lessThanOrEqualTo(3650));
    });
  });

  group('days played', () {
    test('two pictures on one day count once, Paint and Sort both count', () async {
      final store = ProgressStore.memory();
      ProgressStore.clock = () => DateTime(2026, 11, 1, 9);
      await store.recordCompletion('a', score: 1, stars: 1, seconds: 1);
      await store.recordCompletion('b', score: 1, stars: 1, seconds: 1);
      expect(store.daysPlayed, 1);
      ProgressStore.clock = () => DateTime(2026, 11, 2);
      await store.recordCompletion('sort:c', score: 1, stars: 1, seconds: 1);
      expect(store.daysPlayed, 2);
      expect(store.playedDays, {'2026-11-01', '2026-11-02'});
    });

    test('a missed day never lowers the count', () async {
      final store = ProgressStore.memory();
      for (final day in [1, 2, 5, 9]) {
        ProgressStore.clock = () => DateTime(2026, 11, day);
        await store.recordCompletion('p$day', score: 1, stars: 1, seconds: 1);
      }
      expect(store.daysPlayed, 4);
    });

    test('survives save and load, in order, and the key is a top-level list', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      for (final day in [9, 3]) {
        ProgressStore.clock = () => DateTime(2026, 11, day);
        await store.recordCompletion('p$day', score: 1, stars: 1, seconds: 1);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecodeSave(prefs)['daysPlayed'], ['2026-11-03', '2026-11-09']);
      expect(jsonDecodeSave(prefs)['version'], 2);
      final again = await ProgressStore.load();
      expect(again.daysPlayed, 2);
    });

    test('a save without the key is seeded from the daily streak run', () async {
      final store = await _storeWithStreak(3);
      expect(store.playedDays, {'2026-11-07', '2026-11-08', '2026-11-09'});
      expect(store.daysPlayed, 3);
    });

    test('a save with no daily history starts at zero, and a wrong-typed key is reseeded', () async {
      SharedPreferences.setMockInitialValues({'progress_v1': '{"version":2,"daysPlayed":"oops"}'});
      final store = await ProgressStore.load();
      expect(store.daysPlayed, 0);
    });

    test('a read-only save seeds in memory and is not written', () async {
      SharedPreferences.setMockInitialValues({
        'progress_v1': '{"version":3,"daily":{"date":"2026-11-09","id":null,"done":"2026-11-09","streak":2,"best":2}}',
      });
      final store = await ProgressStore.load();
      expect(store.isReadOnly, isTrue);
      expect(store.daysPlayed, 2);
      await store.noteCombo(5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('progress_v1'), contains('"version":3'));
    });
  });
}

Map<String, dynamic> jsonDecodeSave(SharedPreferences prefs) =>
    (jsonDecode(prefs.getString('progress_v1')!) as Map).cast<String, dynamic>();

Future<ProgressStore> _storeWithStreak(int streak, {int? best}) async {
  SharedPreferences.setMockInitialValues({
    'progress_v1':
        '{"version":2,"daily":{"date":"2026-11-09","id":null,"done":"2026-11-09","streak":$streak,"best":${best ?? streak}}}',
  });
  return ProgressStore.load();
}
