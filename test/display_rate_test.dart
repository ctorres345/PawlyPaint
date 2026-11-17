import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/display_rate.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/settings.dart';
import 'package:pawlypaint/ui/game_screen.dart';
import 'package:pawlypaint/ui/sort_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PAP-59: play screens ask Android for 60 Hz and give it back when they close.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];
  setUp(() {
    calls.clear();
    DisplayRate.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      DisplayRate.channel,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DisplayRate.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('DisplayRate', () {
    test('caps on the first hold and releases after the last', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      DisplayRate.hold();
      DisplayRate.hold();
      DisplayRate.release();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['cap60']);
      DisplayRate.release();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['cap60', 'release']);
      expect(DisplayRate.holds, 0);
    });

    test('an extra release never goes below zero or calls twice', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      DisplayRate.release();
      DisplayRate.hold();
      DisplayRate.release();
      DisplayRate.release();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['cap60', 'release']);
      expect(DisplayRate.holds, 0);
    });

    test('does nothing off Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      DisplayRate.hold();
      DisplayRate.release();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
    });

    test('a missing platform side is ignored', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DisplayRate.channel, null);
      DisplayRate.hold();
      DisplayRate.release();
      await Future<void>.delayed(Duration.zero);
      expect(DisplayRate.holds, 0);
    });
  });

  group('play screens', () {
    final courses = buildCourses();
    final Puzzle puzzle = courses.first.puzzles.first;

    late MusicController music;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      music = await MusicController.load();
    });
    tearDown(() => music.dispose());

    Future<NavigatorState> pumpScreen(WidgetTester tester, Widget Function(ProgressStore store) screen) async {
      SharedPreferences.setMockInitialValues({
        'progress_v1': jsonEncode({'version': 2, 'seenTutorial': true, 'seenSortTutorial2': true}),
      });
      final (settings, store) = (await tester.runAsync(() async => (
            await AppSettings.load(),
            await ProgressStore.load(pictureCount: courses.fold<int>(0, (n, c) => n + c.puzzles.length)),
          )))!;
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      // Known debug-only assertion when a play screen starts the game music
      // (see star_meter_screens_test.dart).
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.context.toString().contains('MusicController')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MusicScope(
        music: music,
        child: SettingsScope(settings: settings, child: MaterialApp(navigatorKey: nav, home: const SizedBox())),
      ));
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen(store)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return nav.currentState!;
    }

    Future<void> closeScreen(WidgetTester tester, NavigatorState nav) async {
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('Paint holds 60 Hz while open', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final nav = await pumpScreen(tester, (store) => GameScreen(puzzle: puzzle, store: store));
      expect(calls, ['cap60']);
      expect(DisplayRate.holds, 1);
      await closeScreen(tester, nav);
      expect(calls, ['cap60', 'release']);
      expect(DisplayRate.holds, 0);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Sort holds 60 Hz while open', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final nav = await pumpScreen(tester, (store) => SortScreen(puzzle: puzzle, store: store));
      expect(calls, ['cap60']);
      await closeScreen(tester, nav);
      expect(calls, ['cap60', 'release']);
      expect(DisplayRate.holds, 0);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
