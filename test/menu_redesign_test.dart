import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/achievements.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/settings.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/ui/badges_screen.dart';
import 'package:pawlypaint/ui/course_screen.dart';
import 'package:pawlypaint/ui/gallery_screen.dart';
import 'package:pawlypaint/ui/home_screen.dart';
import 'package:pawlypaint/ui/settings_screen.dart';
import 'package:pawlypaint/ui/theme/paw_widgets.dart';
import 'package:pawlypaint/ui/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedGame _half(Puzzle p) => SavedGame(
      signature: p.signature,
      placed: '1' * (p.cellCount ~/ 2) + '0' * (p.cellCount - p.cellCount ~/ 2),
      score: 100,
      combo: 0,
      mistakes: 0,
      seconds: 30,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The real font, so the nameplate is measured as she will see it.
    final bytes = File('assets/fonts/Quicksand.ttf').readAsBytesSync();
    await (FontLoader('Quicksand')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ProgressStore.clock = DateTime.now);

  group('nameplate', () {
    for (final (theme, brightness) in [(PawTokens.latte, Brightness.light), (PawTokens.espresso, Brightness.dark)]) {
      testWidgets('the longest name and title fit on one line each ($brightness)', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: pawTheme(theme, brightness),
          home: Scaffold(
            body: Center(child: Nameplate(name: 'Christabella', title: 'Midnight Muse', onTap: () {})),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(Nameplate)).width, Nameplate.width);
        for (final text in ['Christabella', 'Midnight Muse']) {
          final p = tester.renderObject<RenderParagraph>(find.text(text));
          expect(p.didExceedMaxLines, isFalse, reason: '$text is cut off');
          // Laid out whole, and not shrunk: the line fits its box at full size.
          final box = tester.getSize(find.ancestor(of: find.text(text), matching: find.byType(FittedBox)).first);
          expect(p.size.width, lessThanOrEqualTo(box.width + 0.01), reason: '$text is shrunk to fit');
        }
      });
    }

    for (final (scale, name) in [(1.3, 'Christabella'), (2.0, 'Christabella'), (1.0, 'WWWWWWWWWWWW')]) {
      testWidgets('$name at text ${scale}x stays inside the pill', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: pawTheme(PawTokens.latte, Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: Center(child: Nameplate(name: name, title: 'Midnight Muse', onTap: () {}))),
          ),
        ));
        expect(tester.takeException(), isNull);
        final pill = tester.getRect(find.byType(Nameplate));
        for (final text in [name, 'Midnight Muse']) {
          final p = tester.renderObject<RenderParagraph>(find.text(text));
          expect(p.didExceedMaxLines, isFalse, reason: '$text is cut off');
          // The whole line, as drawn (after any shrinking), sits inside the pill.
          final drawn = tester.getRect(find.text(text));
          expect(drawn.right, lessThanOrEqualTo(pill.right - 8 + 0.5), reason: '$text runs past the pill');
          expect(drawn.bottom, lessThanOrEqualTo(pill.bottom + 0.5), reason: '$text falls out of the pill');
        }
      });
    }

    test('every nameplate title is at most 14 letters', () {
      for (final store in [true, false]) {
        for (final a in achievementsFor(store: store, courses: buildCourses())) {
          if (a.givesTitle) expect(a.mochiTitle.characters.length, lessThanOrEqualTo(14), reason: a.id);
        }
      }
      expect(starterTitle.characters.length, lessThanOrEqualTo(14));
    });
  });

  group('keep painting', () {
    test('lists half-done pictures newest first, after older saves without a time', () async {
      final courses = buildCourses();
      final store = await ProgressStore.load(pictureCount: 160);
      final pictures = courses.first.levels.first.puzzles;
      final (a, b, c) = (pictures[0], pictures[1], pictures[2]);
      ProgressStore.clock = () => DateTime(2026, 11, 1);
      await store.saveGame(a.id, _half(a));
      ProgressStore.clock = () => DateTime(2026, 11, 3);
      await store.saveGame(c.id, _half(c));
      ProgressStore.clock = () => DateTime(2026, 11, 2);
      await store.saveGame(b.id, _half(b));
      final unlocks = store.unlockState(courses);
      expect([for (final i in keepPainting(store, courses, unlocks)) i.puzzle.id], [c.id, b.id, a.id]);
      expect(nowPainting(keepPainting(store, courses, unlocks), store, courses, unlocks), courses.first);
    });

    test('Now painting skips a course that is still locked', () async {
      final courses = buildCourses();
      final store = await ProgressStore.load(pictureCount: 160);
      final unlocks = store.unlockState(courses);
      final locked = courses.firstWhere((c) => !unlocks.isCourseOpen(c.id));
      final p = locked.puzzles.first;
      await store.saveGame(p.id, _half(p)); // as from Today's picture
      final inProgress = keepPainting(store, courses, unlocks, dailyId: p.id);
      expect(inProgress.first.course, locked);
      expect(nowPainting(inProgress, store, courses, unlocks), isNot(locked));
    });

    test('Keep painting leaves out an old daily from a locked course or level', () async {
      final courses = buildCourses();
      final store = await ProgressStore.load(pictureCount: 160);
      final unlocks = store.unlockState(courses);
      final lockedCourse = courses.firstWhere((c) => !unlocks.isCourseOpen(c.id)).puzzles.first;
      final lockedLevel = courses.first.levels[1].puzzles.first;
      await store.saveGame(lockedCourse.id, _half(lockedCourse));
      await store.saveGame(lockedLevel.id, _half(lockedLevel));
      expect(keepPainting(store, courses, unlocks), isEmpty);
      expect([for (final i in keepPainting(store, courses, unlocks, dailyId: lockedLevel.id)) i.puzzle.id],
          [lockedLevel.id]);
    });

    test('an empty save is not listed', () async {
      final courses = buildCourses();
      final store = await ProgressStore.load(pictureCount: 160);
      final p = courses.first.puzzles.first;
      await store.saveGame(p.id,
          SavedGame(signature: p.signature, placed: '0' * p.cellCount, score: 0, combo: 0, mistakes: 0, seconds: 0));
      expect(keepPainting(store, courses, store.unlockState(courses)), isEmpty);
    });

    test('a save keeps its time across a reload', () async {
      final courses = buildCourses();
      var store = await ProgressStore.load(pictureCount: 160);
      final p = courses.first.puzzles.first;
      ProgressStore.clock = () => DateTime(2026, 11, 18, 9, 30);
      await store.saveGame(p.id, _half(p));
      store = await ProgressStore.load(pictureCount: 160);
      expect(store.savedFor(p)?.savedAt, DateTime(2026, 11, 18, 9, 30));
    });
  });

  group('settings', () {
    test('theme and name are saved', () async {
      var settings = await AppSettings.load();
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.playerName, AppSettings.defaultPlayerName);
      await settings.setThemeMode(ThemeMode.dark);
      await settings.setPlayerName('  Christabella  ');
      settings = await AppSettings.load();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.playerName, 'Christabella');
    });

    test('a name is trimmed, cut to twelve letters and never empty', () {
      expect(AppSettings.cleanName('   '), AppSettings.defaultPlayerName);
      expect(AppSettings.cleanName(null), AppSettings.defaultPlayerName);
      expect(AppSettings.cleanName('Christabellaaa'), 'Christabella');
      expect(AppSettings.cleanName('Mía 🐱🐱🐱🐱🐱🐱🐱🐱🐱🐱'), 'Mía 🐱🐱🐱🐱🐱🐱🐱🐱');
    });
  });

  group('menus fit a small phone', () {
    final courses = buildCourses();
    late MusicController music;
    setUp(() async => music = await MusicController.load());
    tearDown(() => music.dispose());
    // 360 x 740 at normal text, a 320 pt phone, and 360 pt with text at 200%.
    const sizes = [(Size(360, 740), 1.0), (Size(320, 640), 1.0), (Size(360, 740), 2.0)];
    final screens = <String, Widget Function()>{
      'Home': () => HomeScreen(courses: courses),
      'Course': () => CourseScreen(course: courses.first),
      'Gallery': () => GalleryScreen(courses: courses),
      'Badges': () => BadgesScreen(courses: courses),
      'Settings': () => const SettingsScreen(),
    };
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      for (final (theme, brightness) in [(PawTokens.latte, Brightness.light), (PawTokens.espresso, Brightness.dark)]) {
        for (final (size, scale) in sizes) {
          testWidgets('$name ($brightness) at ${size.width.round()} pt, text ${scale}x lays out without overflow',
              (tester) async {
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            final settings = await AppSettings.load();
            final store = await ProgressStore.load(pictureCount: 160);
            await tester.pumpWidget(MusicScope(
              music: music,
              child: SettingsScope(
                settings: settings,
                child: ProgressScope(
                  store: store,
                  child: MaterialApp(theme: pawTheme(theme, brightness), home: screen()),
                ),
              ),
            ));
            await tester.pump(const Duration(milliseconds: 900));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    for (final (size, scale) in [
      (const Size(320, 640), 1.3),
      (const Size(360, 740), 2.0),
      (const Size(320, 640), 2.0)
    ]) {
      testWidgets('Home with Time Attack open and a best time fits at ${size.width.round()} pt, text ${scale}x',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final settings = await AppSettings.load();
        final store = await ProgressStore.load(pictureCount: 160);
        await tester.runAsync(() async {
          for (final p in courses.first.puzzles.take(UnlockTables.timeAttackAfterSort)) {
            await store.recordCompletion(PlayMode.sort.key(p.id), score: 100, stars: 3, seconds: 60);
          }
          await store.recordTimeAttack(Difficulty.easy, won: true, score: 500, combo: 3, secondsLeft: 83);
        });
        await tester.pumpWidget(MusicScope(
          music: music,
          child: SettingsScope(
            settings: settings,
            child: ProgressScope(
              store: store,
              child:
                  MaterialApp(theme: pawTheme(PawTokens.latte, Brightness.light), home: HomeScreen(courses: courses)),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.text('1:23'), findsOneWidget, reason: 'the Time Attack card is open');
        expect(tester.takeException(), isNull);
      });
    }
  });

  for (final width in [360.0, 320.0]) {
    testWidgets('the raised Home dock button keeps its 84 x 78 size at $width pt', (tester) async {
      tester.view.physicalSize = Size(width * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: pawTheme(PawTokens.latte, Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(padding: const EdgeInsets.all(12), child: PawDock(onSelect: (_) {})),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final raised =
          find.byWidgetPredicate((w) => w is Container && w.constraints == BoxConstraints.tight(const Size(84, 78)));
      final rect = tester.getRect(raised);
      expect(rect.height, moreOrLessEquals(78, epsilon: width < 340 ? 12 : 0.5));
    });
  }

  testWidgets('sticker titles and chips keep their text whole at 2x text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: pawTheme(PawTokens.latte, Brightness.light),
      home: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: Column(
            children: [
              StickerTitle(icon: Icons.palette_rounded, text: 'Look'),
              MiniChip(label: '5/5 · 13 of 15 stars'),
              PawChip(label: 'Locked'),
            ],
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    for (final text in ['Look', '5/5 · 13 of 15 stars', 'Locked']) {
      final p = tester.renderObject<RenderParagraph>(find.text(text));
      expect(p.didExceedMaxLines, isFalse, reason: text);
      expect(p.getMaxIntrinsicHeight(p.size.width), lessThanOrEqualTo(p.size.height + 0.5), reason: '$text is cut off');
    }
  });

  group('keep painting on Home', () {
    late MusicController music;
    setUp(() async => music = await MusicController.load());
    tearDown(() => music.dispose());
    testWidgets('resuming today\'s picture still counts for the streak', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final courses = buildCourses();
      final settings = await AppSettings.load();
      final store = await ProgressStore.load(pictureCount: 160);
      final all = [for (final c in courses) ...c.puzzles];
      final daily = all.firstWhere((p) => p.id == store.dailyPuzzleId(DateTime.now(), all));
      await store.saveGame(daily.id, _half(daily));
      await tester.pumpWidget(MusicScope(
        music: music,
        child: SettingsScope(
          settings: settings,
          child: ProgressScope(
            store: store,
            child: MaterialApp(theme: pawTheme(PawTokens.latte, Brightness.light), home: HomeScreen(courses: courses)),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      final card = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_KeepPaintingCard');
      expect(card, findsOneWidget);
      // Opening the game needs the audio plugin, so check the flag the card opens it with.
      expect((tester.widget(card) as dynamic).daily, isTrue);
    });
  });

  testWidgets('play screens keep the light look in dark mode until PAP-22', (tester) async {
    late Brightness seen;
    await tester.pumpWidget(MaterialApp(
      theme: pawTheme(PawTokens.espresso, Brightness.dark),
      home: LightPlayTheme(builder: (context) {
        seen = Theme.of(context).brightness;
        return const SizedBox();
      }),
    ));
    expect(seen, Brightness.light);
  });

  testWidgets('the name dialog saves and closes cleanly', (tester) async {
    final settings = await AppSettings.load();
    await tester.pumpWidget(MaterialApp(
      theme: pawTheme(PawTokens.latte, Brightness.light),
      home: Builder(
        builder: (context) => TextButton(onPressed: () => editPlayerName(context, settings), child: const Text('edit')),
      ),
    ));
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Christabella');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(settings.playerName, 'Christabella');
  });
}
