import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/settings.dart';
import 'package:pawlypaint/ui/board.dart';
import 'package:pawlypaint/ui/effect_clock.dart';
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

  late GlobalKey<NavigatorState> nav;
  final original = EffectClock.newElapsed;

  Future<void> pumpScreen(WidgetTester tester, Widget Function(ProgressStore store) screen) async {
    SharedPreferences.setMockInitialValues({
      'progress_v1': jsonEncode({'version': 2, 'seenTutorial': true, 'seenSortTutorial2': true}),
    });
    final (settings, store) = (await tester.runAsync(() async => (
          await AppSettings.load(),
          await ProgressStore.load(pictureCount: courses.fold<int>(0, (n, c) => n + c.puzzles.length)),
        )))!;
    // The effect clocks follow the test's fake time.
    EffectClock.newElapsed = () {
      final start = tester.binding.clock.now();
      return () => tester.binding.clock.now().difference(start);
    };
    EffectClock.wallNow = tester.binding.clock.now;
    addTearDown(() {
      EffectClock.newElapsed = original;
      EffectClock.wallNow = DateTime.now;
    });
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // The known debug-only MusicScope assertion (see star_meter_screens_test).
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.context.toString().contains('MusicController')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MusicScope(
      music: music,
      child: SettingsScope(settings: settings, child: MaterialApp(navigatorKey: nav, home: const SizedBox())),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen(store)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  /// Pumps [d] in 100 ms steps and counts the vsync frames something asked
  /// for. Timer-driven frames draw inside a pump, so the tests check the
  /// timers through [PlayTimers] as well.
  Future<int> framesOver(WidgetTester tester, Duration d) async {
    var frames = 0;
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
      if (tester.binding.hasScheduledFrame) frames++;
      await tester.pump(const Duration(milliseconds: 100));
    }
    return frames;
  }

  Finder screenType(String name) => _page(name == 'Paint' ? '_GamePage' : '_SortPage');

  final screens = <String, Widget Function(ProgressStore)>{
    'Paint': (store) => GameScreen(puzzle: puzzle, store: store),
    'Sort': (store) => SortScreen(puzzle: puzzle, store: store),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name: effects run at first, then the idle screen asks for no frames', (tester) async {
      await pumpScreen(tester, screen);
      final timers = tester.state(screenType(name)) as PlayTimers;
      expect(timers.effects.isRunning, isTrue, reason: 'shimmer after opening');
      await tester.pump(const Duration(seconds: 16));
      expect(timers.effects.isRunning, isFalse, reason: 'effects rest once idle');
      expect(tester.binding.transientCallbackCount, 0, reason: 'no running ticker');
      expect(timers.lapsePending, isFalse, reason: 'no effect timer waits');
      expect(await framesOver(tester, const Duration(seconds: 3)), 0);
      expect(timers.effects.isRunning, isFalse, reason: 'nothing woke the effects');
    });

    for (final state in [AppLifecycleState.inactive, AppLifecycleState.paused]) {
      testWidgets('$name: $state stops every timer and ticker, resumed starts the clock again', (tester) async {
        await pumpScreen(tester, screen);
        final timers = tester.state(screenType(name)) as PlayTimers;
        expect(timers.clockTicking, isTrue);
        expect(timers.effects.isRunning, isTrue, reason: 'shimmer after opening');

        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump(const Duration(seconds: 1));
        expect(music.inForeground, isFalse, reason: 'music paused');
        expect(timers.clockTicking, isFalse, reason: 'clock timer cancelled');
        expect(timers.effects.isRunning, isFalse, reason: 'no effect timer');
        expect(tester.binding.transientCallbackCount, 0, reason: 'no running ticker');

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 100));
        expect(music.inForeground, isTrue, reason: 'music back');
        expect(timers.clockTicking, isTrue);
        expect(timers.effects.isRunning, isTrue, reason: 'still inside the idle time');
      });
    }

    testWidgets('$name: covered by another screen, the effects and the clock stop, and start again on return',
        (tester) async {
      await pumpScreen(tester, screen);
      final timers = tester.state(screenType(name)) as PlayTimers;
      expect(timers.effects.isRunning, isTrue);
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(timers.effects.isRunning, isFalse);
      expect(timers.clockTicking, isFalse, reason: 'the clock text rests too');
      expect(tester.binding.transientCallbackCount, 0, reason: 'no running ticker');
      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(timers.effects.isRunning, isTrue);
      expect(timers.clockTicking, isTrue);
    });
  }

  group('Sort hint', () {
    Future<PlayTimers> openSort(WidgetTester tester) async {
      await pumpScreen(tester, (store) => SortScreen(puzzle: puzzle, store: store));
      return tester.state(_page('_SortPage')) as PlayTimers;
    }

    testWidgets('keeps the effects running past the idle time while it shows', (tester) async {
      final timers = await openSort(tester);
      await tester.pump(const Duration(seconds: 13));
      await tester.tap(find.byTooltip('Hint'));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(timers.effects.isRunning, isTrue, reason: '15.5 s since opening, the hint still pulses');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timers.effects.isRunning, isFalse, reason: 'hint gone, idle');
    });

    testWidgets('with "remove animations", a timer clears it, and stops in the background', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final timers = await openSort(tester);
      expect(timers.effects.isRunning, isFalse, reason: 'no effects at all');
      await tester.tap(find.byTooltip('Hint'));
      await tester.pump();
      expect(timers.lapsePending, isTrue, reason: 'waiting to clear the hint');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(timers.lapsePending, isFalse, reason: 'nothing waits in the background');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(timers.lapsePending, isTrue, reason: 'armed again for the rest of the hint');

      await tester.pump(const Duration(seconds: 4));
      expect(timers.lapsePending, isFalse, reason: 'cleared when the hint ended');
    });

    testWidgets('with "remove animations", no timer waits under a covering screen, even after a resume',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final timers = await openSort(tester);
      await tester.tap(find.byTooltip('Hint'));
      await tester.pump();
      expect(timers.lapsePending, isTrue);

      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(timers.lapsePending, isFalse, reason: 'covered');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(timers.lapsePending, isFalse, reason: 'resumed but still covered');

      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(timers.lapsePending, isTrue, reason: 'armed again for the rest of the hint');
    });
  });

  group('Paint effects clear on time (PAP-60)', () {
    Future<(PlayTimers, Board)> openPaint(WidgetTester tester) async {
      // Taps play sounds, and the audio plugin is missing in tests.
      await tester.runAsync(() => music.setSfx(false));
      await pumpScreen(tester, (store) => GameScreen(puzzle: puzzle, store: store));
      return (tester.state(_page('_GamePage')) as PlayTimers, tester.widget<Board>(find.byType(Board)));
    }

    /// Where cell [i] sits on screen.
    Offset cellCenter(WidgetTester tester, Board board, int i) {
      final w = board.game.puzzle.width, view = board.view;
      final local = view.offset + Offset((i % w + 0.5) * kCell, (i ~/ w + 0.5) * kCell) * view.scale;
      return tester.getTopLeft(find.byType(Board)) + local;
    }

    /// A cell of another color than the selected one, and one of the selected color.
    (int wrong, int right) pickCells(Board board) {
      final g = board.game;
      final cells = g.puzzle.cells;
      final wrong = cells.indexWhere((c) => c != g.selected), right = cells.indexWhere((c) => c == g.selected);
      expect([wrong, right], everyElement(isNonNegative), reason: 'the picture has two colors');
      return (wrong, right);
    }

    /// Pumps up to just before [window] ends, then just past it, and checks
    /// the canvas painted only after it ended.
    Future<void> expectRedrawAtEnd(WidgetTester tester, PlayTimers timers, Duration window, String what) async {
      expect(timers.lapsePending, isTrue, reason: 'waiting to clear the $what');
      await tester.pump(window - const Duration(milliseconds: 20));
      // Counts the canvas paints through the debug paint hook, which must be
      // off again before the test ends.
      var boardPaints = 0;
      debugProfilePaintsEnabled = true;
      debugOnProfilePaint = (object) {
        if (object is RenderCustomPaint && object.painter is BoardPainter) boardPaints++;
      };
      try {
        await tester.pump(const Duration(milliseconds: 20));
      } finally {
        debugProfilePaintsEnabled = false;
        debugOnProfilePaint = null;
      }
      expect(boardPaints, greaterThan(0), reason: 'the canvas redraws when the $what ends');
    }

    void removeAnimations(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    testWidgets('with "remove animations", a miss cross clears when its window ends', (tester) async {
      removeAnimations(tester);
      final (timers, board) = await openPaint(tester);
      expect(timers.effects.isRunning, isFalse, reason: 'no effects at all');
      expect(board.view.cellSize, greaterThanOrEqualTo(kMinTapCell), reason: 'a tap places, not zooms');
      final (wrong, _) = pickCells(board);
      await tester.tapAt(cellCenter(tester, board, wrong));
      await tester.pump();
      expect(board.game.lastMistakeCell, wrong);
      await expectRedrawAtEnd(tester, timers, BoardPainter.missShows, 'miss cross');
      expect(timers.lapsePending, isFalse, reason: 'nothing left to clear');
    });

    testWidgets('with "remove animations", a pop settles when its window ends', (tester) async {
      removeAnimations(tester);
      final (timers, board) = await openPaint(tester);
      final (_, right) = pickCells(board);
      await tester.tapAt(cellCenter(tester, board, right));
      await tester.pump();
      expect(board.game.placed[right], 1);
      await expectRedrawAtEnd(tester, timers, BoardPainter.popShows, 'pop');
    });

    testWidgets('in a drag held past the effects idle time, a pop settles when its window ends', (tester) async {
      final (timers, board) = await openPaint(tester);
      final (_, right) = pickCells(board);
      final gesture = await tester.startGesture(cellCenter(tester, board, right) + const Offset(-40, 0));
      await tester.pump(const Duration(seconds: 16));
      expect(timers.effects.isRunning, isFalse, reason: 'the effects rest during the long hold');
      await gesture.moveTo(cellCenter(tester, board, right));
      await tester.pump();
      expect(board.game.placed[right], 1);
      await expectRedrawAtEnd(tester, timers, BoardPainter.popShows, 'pop');
      await gesture.up();
    });

    testWidgets('with "remove animations", no timer waits in the background or under another screen', (tester) async {
      removeAnimations(tester);
      final (timers, board) = await openPaint(tester);
      final (wrong, _) = pickCells(board);
      await tester.tapAt(cellCenter(tester, board, wrong));
      await tester.pump();
      expect(timers.lapsePending, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(timers.lapsePending, isFalse, reason: 'nothing waits in the background');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(timers.lapsePending, isTrue, reason: 'armed again for the rest of the cross');

      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(timers.lapsePending, isFalse, reason: 'covered');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(timers.lapsePending, isFalse, reason: 'resumed but still covered');
    });
  });
}

/// The play screen's stateful page (it sits under the screen's light theme).
Finder _page(String name) => find.byWidgetPredicate((w) => w.runtimeType.toString() == name);
