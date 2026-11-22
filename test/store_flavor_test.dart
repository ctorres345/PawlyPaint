import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/time_attack.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/achievements.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _otherCoursesCountAndFnv1aOn946505c = {false: (140, 1787030827), true: (80, 1236448668)};

(int, int) _fnv1aOfOtherCourses(List<Course> courses) {
  var h = 0x811c9dc5, n = 0;
  for (final c in courses) {
    if (c.id == 'classics') continue;
    for (final p in c.puzzles) {
      n++;
      final s = '${p.id}|${p.title}|${p.width}|${p.cells.join(',')}|'
          '${p.palette.map((c) => c.toARGB32()).join(',')};';
      for (final u in s.codeUnits) {
        h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
      }
    }
  }
  return (n, h);
}

void main() {
  final sideload = buildCourses();
  final store = buildCourses(store: true);
  final hiddenPuzzleIds = {
    for (final c in sideload)
      if (sideloadOnlyCourseIds.contains(c.id)) ...c.puzzles.map((p) => p.id),
  };

  test('every other course still builds from its shape art, picture for picture, in both builds', () {
    expect(_fnv1aOfOtherCourses(sideload), _otherCoursesCountAndFnv1aOn946505c[false]);
    expect(_fnv1aOfOtherCourses(store), _otherCoursesCountAndFnv1aOn946505c[true]);
  });

  test('the sideload build lists every course, in the same order as before', () {
    expect(sideload.map((c) => c.id), [
      'classics',
      'animals',
      'garden',
      'sweets',
      'catcafe',
      'minecraft',
      'vocaloid',
      'kpop',
    ]);
  });

  test('the store build lists no fan-art course and no special course', () {
    expect(store.map((c) => c.id), ['classics', 'animals', 'garden', 'sweets', 'catcafe']);
    expect(store.where((c) => c.special), isEmpty);
    expect(sideloadOnlyCourseIds, {'minecraft', 'vocaloid', 'kpop'});
  });

  test('the store build has no picture from a hidden course', () {
    final ids = {for (final c in store) ...c.puzzles.map((p) => p.id)};
    expect(hiddenPuzzleIds, isNotEmpty);
    expect(ids.intersection(hiddenPuzzleIds), isEmpty);
    for (final id in ids) {
      expect(sideloadOnlyCourseIds.any((c) => id.startsWith('$c-')), isFalse, reason: id);
    }
  });

  test('picture ids are unchanged, so saved progress keeps working', () {
    final ids = {for (final c in sideload) ...c.puzzles.map((p) => p.id)};
    expect(ids, containsAll(['classics-heart', 'minecraft-creeper', 'vocaloid-miku', 'kpop-lightstick']));
    expect(ids.length, sideload.fold(0, (n, c) => n + c.puzzles.length));
    final storeIds = {for (final c in store) ...c.puzzles.map((p) => p.id)};
    expect(ids.containsAll(storeIds), isTrue);
  });

  test('Time Attack never picks a hidden picture in the store build', () {
    for (var d = 0; d < 400; d++) {
      final day = DateTime(2026, 1, 1).add(Duration(days: d));
      final pick = TimeAttack.daily(day, store);
      expect(hiddenPuzzleIds, isNot(contains(pick.puzzle.id)), reason: '$day');
    }
  });

  test('the daily picture never picks a hidden picture in the store build', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressStore.load();
    final all = [for (final c in store) ...c.puzzles];
    for (var d = 0; d < 400; d++) {
      final day = DateTime(2026, 1, 1).add(Duration(days: d));
      expect(hiddenPuzzleIds, isNot(contains(progress.dailyPuzzleId(day, all))), reason: '$day');
    }
  });

  test('totals in the store build count only store pictures', () {
    int maxStars(List<Course> cs) => cs.fold(0, (s, c) => s + ProgressStore.maxStarsIn(c.puzzles));
    expect(maxStars(store), lessThan(maxStars(sideload)));
    expect(store.fold(0, (n, c) => n + c.puzzles.length),
        sideload.fold(0, (n, c) => n + c.puzzles.length) - hiddenPuzzleIds.length);
  });

  test('records of hidden pictures are kept and do not count in the store build', () async {
    final hidden = sideload.firstWhere((c) => c.id == 'minecraft').puzzles.first;
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressStore.load();
    await progress.recordCompletion(hidden.id, score: 100, stars: 3, seconds: 60);
    expect(progress.record(PlayMode.paint.key(hidden.id)), isNotNull);
    expect(ProgressFacts(store, progress).finished, 0);
    expect(ProgressFacts(sideload, progress).finished, 1);
  });

  test('the Fan favorite badge is only offered where a special course exists', () {
    final storeIds = achievementsFor(store: true, courses: store).map((a) => a.id).toSet();
    final sideIds = achievementsFor(store: false, courses: sideload).map((a) => a.id).toSet();
    expect(storeIds, isNot(contains('fan')));
    expect(sideIds, contains('fan'));
    // The sideload build differs by Fan favorite and the Course master badges of its extra courses.
    final extra = {
      for (final c in sideload)
        if (sideloadOnlyCourseIds.contains(c.id)) ...sideIds.where((id) => id.startsWith('course.${c.id}.')),
    };
    expect(sideIds.difference(storeIds), {'fan', ...extra});
    expect(storeIds.difference(sideIds).where((id) => !id.startsWith('course.')), isEmpty);
  });
}
