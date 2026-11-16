import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/settings.dart';
import 'package:pawlypaint/ui/game_screen.dart';
import 'package:pawlypaint/ui/sort_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PAP-18: a play screen left alone, or sent to the background, asks the
/// engine for no frames. A vsync ticker would keep the GPU busy at 120 Hz.
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

  Future<void> pumpScreen(WidgetTester tester, Widget Function(ProgressStore store) screen) async {
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
    // The known debug-only MusicScope assertion (see star_meter_screens_test).
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
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  /// Pumps [d] in 100 ms steps and counts the frames something asked for.
  Future<int> framesOver(WidgetTester tester, Duration d) async {
    var frames = 0;
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
      if (tester.binding.hasScheduledFrame) frames++;
      await tester.pump(const Duration(milliseconds: 100));
    }
    return frames;
  }

  final screens = <String, Widget Function(ProgressStore)>{
    'Paint': (store) => GameScreen(puzzle: puzzle, store: store),
    'Sort': (store) => SortScreen(puzzle: puzzle, store: store),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name: effects run at first, then the idle screen asks for no frames', (tester) async {
      await pumpScreen(tester, screen);
      expect(await framesOver(tester, const Duration(seconds: 1)), greaterThan(0), reason: 'shimmer after opening');
      await framesOver(tester, const Duration(seconds: 16));
      expect(tester.binding.transientCallbackCount, 0, reason: 'no running ticker');
      expect(await framesOver(tester, const Duration(seconds: 3)), 0);
    });

    testWidgets('$name: in the background, no ticker runs and no effect ticks', (tester) async {
      await pumpScreen(tester, screen);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0, reason: 'no running ticker');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Back in front, effects never woke while away, so nothing is pending.
      await framesOver(tester, const Duration(seconds: 16));
      expect(await framesOver(tester, const Duration(seconds: 3)), 0);
    });
  }
}
