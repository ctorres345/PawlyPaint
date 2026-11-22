import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/ui/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PAP-78: the one-time Fresh paint card on Home after the save v3 reset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final courses = buildCourses();

  late MusicController music;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    music = await MusicController.load();
  });
  tearDown(() => music.dispose());

  /// A launch: Home on whatever the store loads from the current preferences.
  Future<ProgressStore> launch(WidgetTester tester) async {
    final store = await ProgressStore.load(pictureCount: courses.fold<int>(0, (n, c) => n + c.puzzles.length));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MusicScope(
        music: music,
        child: ProgressScope(store: store, child: MaterialApp(home: HomeScreen(courses: courses))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    return store;
  }

  final card = find.text('New pictures, fresh start');

  testWidgets('shows once after the reset and stays gone after closing and a restart', (tester) async {
    SharedPreferences.setMockInitialValues({
      'progress_v1': jsonEncode({'version': 2, 'seenTutorial': true, 'seenSortTutorial2': true, 'bestCombo': 9}),
    });
    final semantics = tester.ensureSemantics();
    await launch(tester);
    expect(card, findsOneWidget);
    expect(find.text('Fresh paint!'), findsOneWidget);
    expect(find.bySemanticsLabel('Fresh paint! New pictures, fresh start'), findsOneWidget);
    expect(tester.getSemantics(find.byTooltip('Dismiss')).label, 'Dismiss', reason: 'its own button');

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(card, findsNothing);

    await tester.pumpWidget(const SizedBox());
    final restarted = await launch(tester);
    expect(restarted.freshPaintPending, isFalse, reason: 'the stored flag is gone too');
    expect(card, findsNothing);
    semantics.dispose();
  });

  testWidgets('a fresh install shows no card', (tester) async {
    await launch(tester);
    expect(card, findsNothing);
  });
}
