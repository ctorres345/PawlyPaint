import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/ui/course_screen.dart';
import 'package:pawlypaint/ui/home_screen.dart';
import 'package:pawlypaint/ui/unlock_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _save(List<Course> courses, {int version = 2, int paint = 0, int sort = 0, int stars = 3}) {
  final ids = [for (final c in courses) ...c.puzzles.map((p) => p.id)];
  return {
    'version': version,
    'seenTutorial': true,
    'seenSortTutorial2': true,
    'records': {
      for (final id in ids.take(paint)) id: {'score': 900, 'stars': stars, 'seconds': 80},
      for (final id in ids.take(sort)) 'sort:$id': {'score': 700, 'stars': stars, 'seconds': 90},
    },
  };
}

Future<ProgressStore> _load(List<Course> courses, Map<String, dynamic>? save) async {
  SharedPreferences.setMockInitialValues({if (save != null) 'progress_v1': jsonEncode(save)});
  return ProgressStore.load(pictureCount: courses.fold<int>(0, (n, c) => n + c.puzzles.length));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MusicController music;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    music = await MusicController.load();
  });
  tearDown(() => music.dispose());

  Future<void> pumpHome(WidgetTester tester, ProgressStore store, List<Course> courses) async {
    tester.view.physicalSize = const Size(900, 7000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MusicScope(
        music: music,
        child: ProgressScope(store: store, child: MaterialApp(home: HomeScreen(courses: courses))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  final builds = {'sideload': buildCourses(), 'store': buildCourses(store: true)};

  for (final MapEntry(key: name, value: courses) in builds.entries) {
    group('$name build', () {
      testWidgets('a fresh install opens only the starting content, with no dialog', (tester) async {
        final store = await _load(courses, null);
        await pumpHome(tester, store, courses);
        final s = store.unlockState(courses);
        expect(s.isCourseOpen('classics'), isTrue);
        expect(s.isCourseOpen('garden'), isFalse);
        expect(find.byType(AlertDialog), findsNothing);
        // Locked cards show their star progress, and Time Attack shows a lock.
        expect(find.text('★ 0 / 15'), findsOneWidget);
        expect(find.text('★ 0 / 35'), findsOneWidget);
        expect(find.text('Time Attack'), findsOneWidget);
        expect(find.byIcon(Icons.lock_rounded), findsWidgets);
        // The teaser names the nearest course.
        expect(find.textContaining('15 more stars to open Garden!'), findsOneWidget);
      });

      testWidgets('a new player can always start a picture', (tester) async {
        final store = await _load(courses, null);
        final first = courses.first;
        expect(store.unlockState(courses).isCourseOpen(first.id), isTrue);
        expect(store.isLevelUnlocked(first, 0), isTrue);
        expect(store.isPuzzleUnlocked(first.levels.first, 0), isTrue);
        // And the first course card is really there to tap, and opens.
        await pumpHome(tester, store, courses);
        await tester.tap(find.text(first.title));
        await tester.pumpAndSettle();
        expect(find.byType(CourseScreen), findsOneWidget);
      });

      testWidgets('every gate opens at its condition and not before', (tester) async {
        // [id, finished Paint, finished Sort, stars per picture]
        final gates = <(String, int, int, int)>[
          (UnlockTables.modeSort, 1, 0, 0),
          (UnlockTables.modeDaily, 1, 0, 0),
          (UnlockTables.modeTimeAttack, 3, 3, 0),
          ('booster.bomb', 1, 0, 0),
          ('booster.wand', 3, 0, 0),
          ('booster.brush', 6, 0, 0),
        ];
        for (final (id, paint, sort, _) in gates) {
          final below =
              await _load(courses, _save(courses, paint: paint > 0 ? paint - 1 : 0, sort: sort > 0 ? sort - 1 : 0));
          expect(below.unlockState(courses).isUnlocked(id), isFalse, reason: '$id below its condition');
          final at = await _load(courses, _save(courses, paint: paint, sort: sort));
          expect(at.unlockState(courses).isUnlocked(id), isTrue, reason: '$id at its condition');
        }
        // Courses open with stars (3 per picture): Garden 15, Sweets 35, Cat Cafe 60.
        for (final (id, stars) in [('garden', 15), ('sweets', 35), ('catcafe', 60)]) {
          final below = await _load(courses, _save(courses, paint: (stars ~/ 3) - 1));
          expect(below.unlockState(courses).isCourseOpen(id), isFalse, reason: '$id below its stars');
          final at = await _load(courses, _save(courses, paint: (stars + 2) ~/ 3));
          expect(at.unlockState(courses).isCourseOpen(id), isTrue, reason: '$id at its stars');
        }
      });

      testWidgets('locked cards turn into open cards as stars arrive', (tester) async {
        var store = await _load(courses, _save(courses, paint: 1));
        await pumpHome(tester, store, courses);
        expect(find.text('★ 3 / 15'), findsOneWidget);
        expect(find.text('★ 3 / 35'), findsOneWidget);
        store = await _load(courses, _save(courses, paint: 5));
        await tester.pumpWidget(const SizedBox());
        await pumpHome(tester, store, courses);
        // Garden (15 stars) is open now: its locked card is gone, Sweets still shows progress.
        expect(find.text('★ 15 / 15'), findsNothing);
        expect(find.text('★ 15 / 35'), findsOneWidget);
      });

      testWidgets('gates open at their conditions', (tester) async {
        var store = await _load(courses, _save(courses, paint: 1, stars: 3));
        var s = store.unlockState(courses);
        expect(s.isModeOpen(UnlockTables.modeSort), isTrue);
        expect(s.isModeOpen(UnlockTables.modeTimeAttack), isFalse);
        expect(s.isCourseOpen('garden'), isFalse);

        store = await _load(courses, _save(courses, paint: 5, sort: 3, stars: 3));
        s = store.unlockState(courses);
        expect(s.isCourseOpen('garden'), isTrue); // 5 pictures x 3 stars = 15
        expect(s.isModeOpen(UnlockTables.modeTimeAttack), isTrue);
      });

      testWidgets('a save with progress and nothing celebrated shows exactly one summary', (tester) async {
        final store = await _load(courses, _save(courses, paint: 20, sort: 3));
        await pumpHome(tester, store, courses);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining("You've unlocked"), findsOneWidget);
        await tester.tap(find.text("Let's paint"));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(store.unlockState(courses).summary, isEmpty);

        // Coming back later, from the saved file, shows nothing more.
        final reloaded = await ProgressStore.load(pictureCount: courses.fold<int>(0, (n, c) => n + c.puzzles.length));
        await tester.pumpWidget(const SizedBox());
        await pumpHome(tester, reloaded, courses);
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('a save from the build before the gates keeps everything open', (tester) async {
        final store = await _load(courses, {
          ..._save(courses, paint: 1),
          'keptOpen': UnlockTables.legacyIds.toList(),
        });
        await pumpHome(tester, store, courses);
        expect(store.unlockState(courses).isCourseOpen('catcafe'), isTrue);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(LockedSurface), findsNothing);
        expect(find.textContaining('more stars to open'), findsNothing);
      });

      testWidgets('a version 1 save with progress opens everything and shows one summary', (tester) async {
        final store = await _load(courses, _save(courses, version: 1, paint: 20, sort: 3));
        final s = store.unlockState(courses);
        for (final id in UnlockTables.legacyIds) {
          expect(s.isUnlocked(id), isTrue, reason: '$id stays open');
        }
        await pumpHome(tester, store, courses);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(LockedSurface), findsNothing);
      });

      testWidgets('courses that are not in the game yet are never announced', (tester) async {
        final store = await _load(courses, _save(courses, paint: 60, stars: 3)); // 180 stars
        final s = store.unlockState(courses);
        expect(s.isUnlocked('course.retro'), isTrue);
        expect(
            s.summary.any((id) => id == 'course.retro' || id == 'course.sea_world' || id == 'course.jungle'), isFalse);
      });

      testWidgets('a save from a newer build shows the notice', (tester) async {
        final store = await _load(courses, _save(courses, version: 9, paint: 1));
        await pumpHome(tester, store, courses);
        expect(find.textContaining('comes from a newer PawlyPaint'), findsOneWidget);
      });
    });
  }
}
