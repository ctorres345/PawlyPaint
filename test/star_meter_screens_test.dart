import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/data/tutorial.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/settings.dart';
import 'package:pawlypaint/ui/game_screen.dart';
import 'package:pawlypaint/ui/sort_screen.dart';
import 'package:pawlypaint/ui/star_meter.dart';
import 'package:pawlypaint/ui/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PAP-8: the star meter shows in Paint and Sort, and stays hidden wherever
/// the finish gives no stars: Relaxed mode, tutorials and Time Attack.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final courses = buildCourses();
  final Puzzle puzzle = courses.first.puzzles.first;

  late MusicController music;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    music = await MusicController.load();
  });
  tearDown(() => music.dispose());

  Future<void> pumpScreen(WidgetTester tester, Widget Function(ProgressStore store) screen,
      {bool relaxed = false, ThemeData? theme}) async {
    SharedPreferences.setMockInitialValues({
      'relaxed_mode': relaxed,
      'progress_v1': jsonEncode({'version': 3, 'seenTutorial': true, 'seenSortTutorial2': true}),
    });
    final (settings, store) = (await tester.runAsync(() async => (
          await AppSettings.load(),
          await ProgressStore.load(pictureCount: courses.fold<int>(0, (n, c) => n + c.puzzles.length)),
        )))!;
    // Wide enough that the test font (wider than Quicksand) fits the coach card.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // GameScreen and SortScreen start the game music in didChangeDependencies,
    // which notifies MusicScope mid-build: a known debug-only assertion that
    // predates PAP-8. Only that one error is tolerated here.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.context.toString().contains('MusicController')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    // Pushed onto a built app, as the app does: the screen starts the game
    // music while its dependencies settle, which must not be the first frame.
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MusicScope(
      music: music,
      child: SettingsScope(
          settings: settings, child: MaterialApp(navigatorKey: nav, theme: theme, home: const SizedBox())),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen(store)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  testWidgets('Paint shows the meter with the 3-star limit before the first move', (tester) async {
    await pumpScreen(tester, (store) => GameScreen(puzzle: puzzle, store: store));
    expect(find.byType(StarMeterBar), findsOneWidget);
    expect(find.textContaining('3 stars: up to'), findsOneWidget);
  });

  testWidgets('Paint hides the meter in Relaxed mode', (tester) async {
    await pumpScreen(tester, (store) => GameScreen(puzzle: puzzle, store: store), relaxed: true);
    expect(find.byType(StarMeterBar), findsNothing);
  });

  testWidgets('Paint hides the meter in the tutorial', (tester) async {
    await pumpScreen(tester, (store) => GameScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true));
    expect(find.byType(StarMeterBar), findsNothing);
  });

  testWidgets('Sort shows the meter with the 3-star limit before the first move', (tester) async {
    await pumpScreen(tester, (store) => SortScreen(puzzle: puzzle, store: store));
    expect(find.byType(StarMeterBar), findsOneWidget);
    expect(find.text('3 stars: up to 3 wrong taps, no shakes'), findsOneWidget);
  });

  testWidgets('Sort hides the meter in Relaxed mode', (tester) async {
    await pumpScreen(tester, (store) => SortScreen(puzzle: puzzle, store: store), relaxed: true);
    expect(find.byType(StarMeterBar), findsNothing);
  });

  testWidgets('Sort hides the meter in the tutorial', (tester) async {
    await pumpScreen(tester, (store) => SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true));
    expect(find.byType(StarMeterBar), findsNothing);
  });

  testWidgets('Time Attack has no meter, even with Relaxed off', (tester) async {
    await pumpScreen(tester, (store) => SortScreen(puzzle: puzzle, store: store, timeAttack: Difficulty.easy));
    expect(find.byType(StarMeterBar), findsNothing);
  });

  // PAP-20: until PAP-22 the play pages stay light, and so does the context
  // their dialogs and sheets open from.
  for (final (name, page) in [
    ('_GamePage', (ProgressStore store) => GameScreen(puzzle: puzzle, store: store)),
    ('_SortPage', (ProgressStore store) => SortScreen(puzzle: puzzle, store: store)),
  ]) {
    testWidgets('$name and its dialogs stay light under a dark app theme', (tester) async {
      await pumpScreen(tester, page, theme: pawTheme(PawTokens.espresso, Brightness.dark));
      final state = tester.element(find.byWidgetPredicate((w) => w.runtimeType.toString() == name));
      expect(Theme.of(state).brightness, Brightness.light);
    });
  }
}
