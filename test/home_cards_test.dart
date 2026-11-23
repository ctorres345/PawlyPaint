import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/ui/home_screen.dart';
import 'package:pawlypaint/ui/theme/tokens.dart';
import 'package:pawlypaint/ui/unlock_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PAP-88: the hero cards on Home at large text, and closing the Fresh paint card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final courses = buildCourses();
  final dailyHint = unlockCondition(UnlockTables.modeDaily);
  final raceHint = unlockCondition(UnlockTables.modeTimeAttack);

  late MusicController music;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    music = await MusicController.load();
  });
  tearDown(() => music.dispose());

  Future<ProgressStore> launch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1.0,
    Brightness brightness = Brightness.light,
    bool reduceMotion = false,
    int painted = 0,
  }) async {
    final store = await ProgressStore.load(pictureCount: courses.fold<int>(0, (n, c) => n + c.puzzles.length));
    await tester.runAsync(() async {
      for (final p in courses.first.puzzles.take(painted)) {
        await store.recordCompletion(PlayMode.paint.key(p.id), score: 100, stars: 3, seconds: 60);
      }
    });
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final tokens = brightness == Brightness.dark ? PawTokens.espresso : PawTokens.latte;
    await tester.pumpWidget(
      MusicScope(
        music: music,
        child: ProgressScope(
          store: store,
          child: MaterialApp(theme: pawTheme(tokens, brightness), home: HomeScreen(courses: courses)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    return store;
  }

  Finder shown(String text) => _shown(text);

  for (final brightness in Brightness.values) {
    for (final (size, scale) in [
      (const Size(320, 640), 2.0),
      (const Size(360, 740), 2.0),
      (const Size(412, 915), 2.0),
      (const Size(360, 740), 1.3),
    ]) {
      testWidgets('locked hero hints show in full at ${size.width.round()} pt, text ${scale}x ($brightness)',
          (tester) async {
        await launch(tester, size: size, scale: scale, brightness: brightness);
        expect(tester.takeException(), isNull);
        for (final hint in [dailyHint, raceHint]) {
          expect(shown(hint), findsOneWidget, reason: 'a fresh install has both hero cards locked');
          final p = tester.renderObject<RenderParagraph>(shown(hint));
          expect(p.didExceedMaxLines, isFalse, reason: '$hint is cut off');
          final text = tester.getRect(shown(hint));
          final card = tester.getRect(_cardAround(hint));
          expect(text.bottom, lessThanOrEqualTo(card.bottom - 14 + 0.5), reason: '$hint runs out of its card');
        }
        final daily = tester.getRect(_cardAround(dailyHint));
        final race = tester.getRect(_cardAround(raceHint));
        expect(daily.height, closeTo(race.height, 0.5), reason: 'both hero cards share the row height');
        expect(daily.height, greaterThanOrEqualTo(176 - 0.5));
      });
    }
  }

  testWidgets('an open Today\'s picture beside a locked Time Attack grows with it at text 2.0x', (tester) async {
    await launch(tester, size: const Size(360, 740), scale: 2.0, painted: 1);
    expect(tester.takeException(), isNull);
    expect(_shown(dailyHint), findsNothing, reason: "one finished picture opens Today's picture");
    final p = tester.renderObject<RenderParagraph>(_shown(raceHint));
    expect(p.didExceedMaxLines, isFalse);
    final race = tester.getRect(_cardAround(raceHint));
    final row = tester.getRect(find.ancestor(of: _shown(raceHint), matching: find.byType(IntrinsicHeight)).first);
    expect(race.height, closeTo(row.height, 0.5), reason: 'the open card stretches to the same height');
    expect(race.height, greaterThan(176));
  });

  testWidgets('at normal text the hero row stays 176 pt tall', (tester) async {
    await launch(tester);
    expect(tester.getRect(_cardAround(dailyHint)).height, closeTo(176, 0.5));
    expect(tester.getRect(_cardAround(raceHint)).height, closeTo(176, 0.5));
  });

  final card = find.text('New pictures, fresh start');
  final resetSave = {
    'progress_v1': jsonEncode({'version': 2, 'seenTutorial': true, 'seenSortTutorial2': true}),
  };

  testWidgets('closing the Fresh paint card slides the cards below up over several frames', (tester) async {
    SharedPreferences.setMockInitialValues(resetSave);
    await launch(tester);
    expect(card, findsOneWidget);
    final before = tester.getRect(_cardAround(dailyHint)).top;

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getRect(_cardAround(dailyHint)).top;
    expect(midway, lessThan(before), reason: 'the cards below start moving up');

    await tester.pumpAndSettle();
    expect(card, findsNothing);
    final after = tester.getRect(_cardAround(dailyHint)).top;
    expect(midway, greaterThan(after), reason: 'the move is spread over frames, not one jump');
    expect(after, lessThan(before - 26), reason: 'the card and its gap are both gone');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduce motion the Fresh paint card closes at once', (tester) async {
    SharedPreferences.setMockInitialValues(resetSave);
    await launch(tester, reduceMotion: true);
    expect(card, findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    await tester.pump();
    expect(card, findsNothing);
  });
}

/// The visible locked hero card that holds [hint].
Finder _cardAround(String hint) => find.ancestor(of: _shown(hint), matching: find.byType(LockedSurface)).first;

Finder _shown(String text) => find.text(text);
