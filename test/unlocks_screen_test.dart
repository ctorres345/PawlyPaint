import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/data/rewards.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/ui/home_screen.dart';
import 'package:pawlypaint/ui/unlock_ui.dart';
import 'package:pawlypaint/ui/unlocks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store for a 160-picture build (rewards at their table thresholds) with
/// [threeStar] pictures finished with 3 stars.
Future<ProgressStore> _store(int threeStar) async {
  final store = ProgressStore.memory(pictureCount: 160);
  for (var i = 0; i < threeStar; i++) {
    await store.recordCompletion('p$i', score: 900, stars: 3, seconds: 60);
  }
  return store;
}

Future<void> _pump(WidgetTester tester, ProgressStore store, Widget home) async {
  tester.view.physicalSize = const Size(780, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProgressScope(store: store, child: MaterialApp(home: home)));
  await tester.pump();
}

/// A screen with one button that runs the end-of-picture celebration.
class _Finish extends StatelessWidget {
  const _Finish(this.store, this.result);

  final ProgressStore store;
  final List<bool> result;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result.add(await celebrateNewRewards(context, store)),
              child: const Text('finish'),
            ),
          ),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reward catalog', () {
    test('every reward has words and art that exists', () {
      expect(describedRewardIds.toSet(), {for (final r in UnlockTables.rewards) r.id});
      for (final r in UnlockTables.rewards) {
        final info = rewardInfo(r);
        expect(File('assets/art/${info.art}').existsSync(), isTrue, reason: '${r.id}: ${info.art}');
        expect(info.name.length, lessThanOrEqualTo(24), reason: '${r.id} fits a row');
      }
    });

    test('frames are ready, rewards without content are not yet', () {
      expect(rewardReady(rewardById('reward.frame.polaroid')!), isTrue);
      expect(rewardReady(rewardById('reward.bg.sakura')!), isFalse);
    });
  });

  group('newRewards', () {
    test('lists earned, uncelebrated rewards in table order', () async {
      final store = await _store(10);
      final s = store.currentUnlocks;
      expect(s.threeStars, 10);
      expect([for (final r in s.newRewards) r.id], ['reward.bg.sakura', 'reward.palette.matcha']);
      await store.markCelebrated(['reward.bg.sakura']);
      expect([for (final r in store.currentUnlocks.newRewards) r.id], ['reward.palette.matcha']);
    });

    test('thresholds scale with the build', () async {
      final store = ProgressStore.memory(pictureCount: 80);
      final sakura = rewardById('reward.bg.sakura')!;
      expect(store.currentUnlocks.threshold(sakura), 3);
    });
  });

  group('Unlocks screen', () {
    testWidgets('a fresh save shows the first reward as next and the rest hidden', (tester) async {
      final store = await _store(0);
      await _pump(tester, store, const UnlocksScreen());
      expect(find.text('Sakura canvas'), findsOneWidget);
      expect(find.text('5 more three-star pictures'), findsOneWidget);
      expect(find.text('0 / 5'), findsOneWidget);
      expect(find.textContaining('Nothing yet'), findsOneWidget);
      expect(find.text('Mystery reward'), findsNWidgets(UnlockTables.rewards.length - 1));
      expect(find.text('At 10 three-star pictures'), findsOneWidget);
    });

    testWidgets('earned, next and locked states follow the engine', (tester) async {
      final store = await _store(7);
      await _pump(tester, store, const UnlocksScreen());
      expect(find.text('7 three-star'), findsOneWidget);
      // Earned: Sakura, whose content has not shipped yet.
      expect(find.text('Sakura canvas'), findsOneWidget);
      expect(find.text('Background · at 5 three-star'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      // Next: Matcha, 3 to go.
      expect(find.text('Matcha palette'), findsOneWidget);
      expect(find.text('3 more three-star pictures'), findsOneWidget);
      expect(find.text('7 / 10'), findsOneWidget);
      // The rest stay mysteries.
      expect(find.text('Mystery reward'), findsNWidgets(UnlockTables.rewards.length - 2));
      expect(find.text('Polaroid frame'), findsNothing);
    });

    testWidgets('every reward earned says so', (tester) async {
      final store = await _store(120);
      await _pump(tester, store, const UnlocksScreen());
      expect(find.textContaining('You found them all'), findsOneWidget);
      expect(find.text('Mystery reward'), findsNothing);
      expect(find.text('Still hidden'), findsNothing);
    });
  });

  group('celebration', () {
    testWidgets('shows once per unlock', (tester) async {
      final store = await _store(4);
      final results = <bool>[];
      await _pump(tester, store, _Finish(store, results));

      // Nothing new: no card.
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(find.byType(UnlockCelebration), findsNothing);
      expect(results, [false]);

      // The fifth 3-star picture crosses the first threshold.
      await store.recordCompletion('p4', score: 900, stars: 3, seconds: 60);
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(find.byType(UnlockCelebration), findsOneWidget);
      expect(find.text('New unlock'), findsOneWidget);
      expect(find.text('Sakura canvas'), findsOneWidget);
      expect(find.textContaining('You earned it with 5 three-star pictures.'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(results.last, isFalse);

      // The next finish does not show it again.
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(find.byType(UnlockCelebration), findsNothing);
    });

    testWidgets('two thresholds at once make one card', (tester) async {
      final store = await _store(10);
      final results = <bool>[];
      await _pump(tester, store, _Finish(store, results));
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(find.byType(UnlockCelebration), findsOneWidget);
      expect(find.text('2 new unlocks'), findsOneWidget);
      expect(find.text('Sakura canvas and Matcha palette'), findsOneWidget);
      await tester.tap(find.text('See my unlocks'));
      await tester.pumpAndSettle();
      expect(results.last, isTrue);
      expect(store.currentUnlocks.newRewards, isEmpty);
    });

    testWidgets('with reduced motion the card just appears', (tester) async {
      final store = await _store(5);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pump(tester, store, _Finish(store, []));
      await tester.tap(find.text('finish'));
      await tester.pump();
      await tester.pump();
      final scale = tester.widget<ScaleTransition>(
        find.descendant(of: find.byType(UnlockCelebration), matching: find.byType(ScaleTransition)).first,
      );
      expect(scale.scale.value, 1);
    });
  });

  group('first-launch catch-up', () {
    late MusicController music;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      music = await MusicController.load();
    });
    tearDown(() => music.dispose());

    testWidgets('rewards a save already earns join the one summary', (tester) async {
      final courses = buildCourses();
      final ids = [for (final c in courses) ...c.puzzles.map((p) => p.id)];
      SharedPreferences.setMockInitialValues({
        'progress_v1': jsonEncode({
          'version': 2,
          'seenTutorial': true,
          'seenSortTutorial2': true,
          'records': {
            for (final id in ids.take(20)) id: {'score': 900, 'stars': 3, 'seconds': 80},
          },
        }),
      });
      final store = await ProgressStore.load(pictureCount: ids.length);
      expect(store.currentUnlocks.newRewards, isNotEmpty);
      tester.view.physicalSize = const Size(900, 7000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MusicScope(
        music: music,
        child: ProgressScope(store: store, child: MaterialApp(home: HomeScreen(courses: courses))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(UnlockCelebration), findsNothing);
      expect(find.textContaining('rewards'), findsOneWidget);
      await tester.tap(find.text("Let's paint"));
      await tester.pumpAndSettle();
      expect(store.currentUnlocks.newRewards, isEmpty);
      expect(catchUpIds(store.currentUnlocks), isEmpty);
    });

    testWidgets('the Home strip names the next reward and opens Unlocks', (tester) async {
      final courses = buildCourses();
      final store = await ProgressStore.load(pictureCount: 160);
      tester.view.physicalSize = const Size(900, 7000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MusicScope(
        music: music,
        child: ProgressScope(store: store, child: MaterialApp(home: HomeScreen(courses: courses))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.textContaining('Next: Sakura canvas'), findsOneWidget);
      await tester.tap(find.text('Unlocks'));
      await tester.pumpAndSettle();
      expect(find.byType(UnlocksScreen), findsOneWidget);
    });
  });
}
