import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/achievements.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/settings.dart';
import 'package:pawlypaint/ui/badges.dart';
import 'package:pawlypaint/ui/badges_screen.dart';
import 'package:pawlypaint/ui/home_screen.dart';
import 'package:pawlypaint/ui/theme/paw_widgets.dart';
import 'package:pawlypaint/ui/theme/tokens.dart';
import 'package:pawlypaint/ui/unlock_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _courses = buildCourses();

/// A fixture save: 12 pictures painted with 3 stars, 3 of them sorted too, a 12 combo, one Time Attack win.
Future<ProgressStore> _fixture() async {
  final store = await ProgressStore.load(pictureCount: 160);
  final pictures = [for (final c in _courses) ...c.puzzles];
  for (final p in pictures.take(12)) {
    await store.recordCompletion(p.id, score: 1, stars: 3, seconds: 1);
  }
  for (final p in pictures.take(3)) {
    await store.recordCompletion(PlayMode.sort.key(p.id), score: 1, stars: 2, seconds: 1);
  }
  await store.noteCombo(12);
  await store.recordTimeAttack(Difficulty.easy, won: true, score: 1, combo: 1, secondsLeft: 10);
  return store;
}

Achievement _badge(String id) => achievementsShown(_courses, ProgressStore.memory()).firstWhere((a) => a.id == id);

/// The Semantics label of the badge row whose name is [name].
Finder _row(String name) => find.bySemanticsLabel(RegExp('^${RegExp.escape(name)}, '));

Future<void> _pumpBadges(
  WidgetTester tester,
  ProgressStore store,
  AppSettings settings, {
  bool reduceMotion = false,
  ThemeData? theme,
}) async {
  // Tall enough that the whole list is built.
  tester.view.physicalSize = const Size(1200, 12000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SettingsScope(
    settings: settings,
    child: ProgressScope(
      store: store,
      child: MaterialApp(
        theme: theme ?? pawTheme(PawTokens.latte, Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(400, 4000), disableAnimations: reduceMotion),
          child: BadgesScreen(courses: _courses),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MusicController music;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    music = await MusicController.load();
  });
  tearDown(() {
    resetRegisteredBadges();
    music.dispose();
  });

  group('rows follow the engine', () {
    testWidgets('frames, bars and the percentage match the engine for a fixture save', (tester) async {
      final semantics = tester.ensureSemantics();
      final store = await _fixture();
      await _pumpBadges(tester, store, AppSettings.memory());

      final earned = earnedAchievements(_courses, store);
      final facts = progressFacts(_courses, store);
      final pct = completionPercent(_courses, store);
      expect(pct, greaterThan(0));
      expect(find.text('$pct%'), findsOneWidget);

      // Perfectionist: bronze earned at 10, so the bar counts toward silver.
      final silver = badgeProgress(_badge('stars.silver'), facts)!;
      expect(earned, contains('stars10'));
      expect(earned, isNot(contains('stars.silver')));
      expect(_row('Perfectionist'), findsOneWidget);
      expect(
        tester.getSemantics(_row('Perfectionist')).label,
        'Perfectionist, Bronze. Silver at ${silver.target} three-star pictures. '
        '${silver.current} of ${silver.target}',
      );
      expect(find.text('${silver.current} / ${silver.target}'), findsWidgets);

      // Sort combo: bronze (10) earned, bar toward the 20 combo.
      expect(tester.getSemantics(_row('Sort combo')).label, endsWith('12 of 20'));

      // Days played: nothing yet, so the row is locked and counts toward bronze.
      expect(tester.getSemantics(_row('Days played')).label, startsWith('Days played, Locked. Bronze at 3 days.'));

      // A series counts even while its first step needs only one.
      expect(tester.getSemantics(_row('Extreme')).label, endsWith('0 of 1'));

      // A single badge with a one-step goal has no bar.
      expect(tester.getSemantics(_row('First sparkle')).label, 'First sparkle, Bronze. Finish your first picture.');

      // Platinum counts every other badge.
      expect(
        tester.getSemantics(_row('Pawly Master')).label,
        endsWith('${facts.platinumCurrent} of ${facts.platinumTarget}'),
      );

      // Earned rows wear their tier's frame, locked ones the outline.
      const t = PawTokens.latte;
      final frames = tester.widgetList<Container>(find.descendant(
        of: find.byWidgetPredicate((w) => w is Row),
        matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 60),
      ));
      expect(
        frames.map((c) => ((c.decoration as BoxDecoration).border as Border).top.color),
        containsAll([t.tiers[BadgeTier.bronze]!.frame, t.outline]),
      );
      semantics.dispose();
    });

    test('rows group a series in tier order and point at the next step', () {
      final shown = achievementsShown(_courses, ProgressStore.memory());
      final rows = badgeRows(shown, {'combo10', 'combo.silver'});
      final combo = rows.firstWhere((r) => r.steps.first.series == 'Sort combo');
      expect(combo.steps.map((a) => a.id), ['combo10', 'combo.silver', 'combo.gold']);
      expect(combo.top?.id, 'combo.silver');
      expect(combo.next?.id, 'combo.gold');
      expect(rows.any((r) => r.steps.any((a) => a.tier == BadgeTier.platinum)), isFalse);
      final done = badgeRows(shown, {'combo10', 'combo.silver', 'combo.gold'});
      expect(done.firstWhere((r) => r.steps.first.series == 'Sort combo').next, isNull);

      // Course master gold needs only the Extreme pictures, so it can come before bronze and silver.
      final master = courseMasterSeries + _courses.first.id;
      final gold = shown.firstWhere((a) => a.series == master && a.tier == BadgeTier.gold);
      final out = badgeRows(shown, {gold.id}).firstWhere((r) => r.steps.first.series == master);
      expect(out.top, gold);
      expect(out.next?.tier, BadgeTier.bronze);
    });
  });

  group('rainbow slot', () {
    testWidgets('with no rainbow badge there is no slot and no gap', (tester) async {
      final store = await _fixture();
      await _pumpBadges(tester, store, AppSettings.memory());
      expect(find.text('Rainbow'), findsNothing);
      final without = tester.getTopLeft(find.text('Pawly Master')).dy;

      registerBadge(
          Achievement('rainbow.test', 'Placeholder', 'Placeholder text', (f) => false, tier: BadgeTier.rainbow));
      await _pumpBadges(tester, store, AppSettings.memory());
      final rainbow = find.text('Rainbow');
      expect(rainbow, findsOneWidget);
      // Above platinum, and platinum moves down by exactly the slot and its gap.
      final with_ = tester.getTopLeft(find.text('Pawly Master')).dy;
      expect(tester.getTopLeft(rainbow).dy, lessThan(with_));
      final slot = find.ancestor(of: rainbow, matching: find.byType(Semantics)).first;
      expect(with_ - without, closeTo(tester.getSize(slot).height + 10, 0.01));
    });

    testWidgets('the rainbow frame turns, and holds still with reduced motion', (tester) async {
      registerBadge(
          Achievement('rainbow.test', 'Placeholder', 'Placeholder text', (f) => false, tier: BadgeTier.rainbow));
      final store = await _fixture();
      await _pumpBadges(tester, store, AppSettings.memory());
      expect(tester.binding.hasScheduledFrame, isTrue);

      await _pumpBadges(tester, store, AppSettings.memory(), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('Rainbow'), findsOneWidget);
    });

    testWidgets('an earned rainbow badge shows its name, and never counts toward the percentage', (tester) async {
      registerBadge(
          Achievement('rainbow.test', 'Placeholder', 'Placeholder text', (f) => true, tier: BadgeTier.rainbow));
      final store = await _fixture();
      final pct = completionPercent(_courses, store);
      resetRegisteredBadges();
      expect(completionPercent(_courses, store), pct);
      registerBadge(
          Achievement('rainbow.test', 'Placeholder', 'Placeholder text', (f) => true, tier: BadgeTier.rainbow));
      await _pumpBadges(tester, store, AppSettings.memory(), reduceMotion: true);
      expect(find.text('Placeholder'), findsOneWidget);
      expect(find.text('Rainbow'), findsNothing);
    });
  });

  group('title picker', () {
    test('lists each title once, and a rainbow title only once earned', () {
      registerBadge(Achievement('rainbow.test', 'Placeholder', 'Placeholder', (f) => false,
          tier: BadgeTier.rainbow, mochiTitle: 'Secret'));
      final shown = achievementsShown(_courses, ProgressStore.memory());
      final titles = titleChoices(shown, {}).map((c) => c.title).toList();
      expect(titles.first, starterTitle);
      expect(titles.where((t) => t == 'Course Champ'), hasLength(1));
      expect(titles, isNot(contains('Secret')));
      expect(titleChoices(shown, {'rainbow.test'}).map((c) => c.title), contains('Secret'));
      // Course Champ is earned when any course's gold is.
      final gold = shown.lastWhere((a) => a.mochiTitle == 'Course Champ');
      expect(titleChoices(shown, {gold.id}).firstWhere((c) => c.title == 'Course Champ').earned, isTrue);
      // Earned titles sit together, right after the starter, above the locked ones.
      final picked = titleChoices(shown, {gold.id}).map((c) => c.earned).toList();
      expect(picked.take(2), [true, true]);
      expect(picked.skip(2), everyElement(isFalse));
    });

    test('a chosen title is worn only while it is earned', () async {
      final store = await _fixture();
      final earned = earnedAchievements(_courses, store);
      expect(earned, contains('first'));
      expect(currentTitleChoice(_courses, store, chosen: 'Sparkle Kitten').title, 'Sparkle Kitten');
      // Not earned: back to her best title.
      expect(currentTitleChoice(_courses, store, chosen: 'Curator').title, currentTitleChoice(_courses, store).title);
      expect(currentTitleChoice(_courses, store, chosen: 'Made up').title, currentTitleChoice(_courses, store).title);
    });

    testWidgets('picking her best title clears the choice, so a better one is worn later', (tester) async {
      final store = await _fixture();
      await store.noteCombo(30); // Combo Cat is her best.
      final settings = AppSettings.memory();
      await settings.setPlayerTitle('Sparkle Kitten');
      await _pumpBadges(tester, store, settings);
      await tester.tap(find.text('Combo Cat'));
      await tester.pump();
      expect(settings.playerTitle, isNull);
    });

    testWidgets('picking a title saves it, Home wears it, and it survives a restart', (tester) async {
      final store = await _fixture();
      await store.noteCombo(30); // Combo Cat, a gold title, is now her best.
      expect(currentTitleChoice(_courses, store).title, 'Combo Cat');
      final settings = await AppSettings.load();
      await _pumpBadges(tester, store, settings);

      // A locked title can't be picked.
      await tester.tap(find.text('Curator'));
      await tester.pump();
      expect(settings.playerTitle, isNull);

      // Picked the way a screen reader does it.
      final semantics = tester.ensureSemantics();
      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Sparkle Kitten, from')));
      await tester.pump();
      semantics.dispose();
      expect(settings.playerTitle, 'Sparkle Kitten');
      expect(
        find.descendant(of: find.byType(Nameplate), matching: find.text('Sparkle Kitten')),
        findsOneWidget,
      );

      final restarted = await AppSettings.load();
      expect(restarted.playerTitle, 'Sparkle Kitten');

      await tester.pumpWidget(MusicScope(
        music: music,
        child: SettingsScope(
          settings: restarted,
          child: ProgressScope(store: store, child: MaterialApp(home: HomeScreen(courses: _courses))),
        ),
      ));
      await tester.pump();
      expect(tester.widget<Nameplate>(find.byType(Nameplate)).title, 'Sparkle Kitten');
      expect(tester.widget<Nameplate>(find.byType(Nameplate)).tier, BadgeTier.bronze);
    });
  });

  group('fits a small phone', () {
    for (final (size, scale) in [
      (const Size(320, 640), 1.0),
      (const Size(360, 740), 2.0),
      (const Size(320, 640), 2.0)
    ]) {
      for (final (theme, brightness) in [(PawTokens.latte, Brightness.light), (PawTokens.espresso, Brightness.dark)]) {
        testWidgets('Badges with every slot at ${size.width.round()} pt, text ${scale}x ($brightness)', (tester) async {
          registerBadge(
              Achievement('rainbow.test', 'Placeholder', 'Placeholder text', (f) => true, tier: BadgeTier.rainbow));
          final store = await _fixture();
          await store.noteCombo(30);
          final settings = AppSettings.memory();
          tester.view.physicalSize = Size(size.width * 3, 9000 * 3);
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(SettingsScope(
            settings: settings,
            child: ProgressScope(
              store: store,
              child: MaterialApp(theme: pawTheme(theme, brightness), home: BadgesScreen(courses: _courses)),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Placeholder'), findsOneWidget);
          // Every title row is a full-height tap target.
          for (final row in tester.widgetList<InkWell>(find.ancestor(
            of: find.text('Sparkle Kitten').last,
            matching: find.byType(InkWell),
          ))) {
            expect(tester.getSize(find.byWidget(row)).height, greaterThanOrEqualTo(44));
          }
        });
      }
    }
  });

  group('earning', () {
    test('the announcement names the tier', () {
      expect(newBadgeLabel(_badge('stars.gold')), 'New gold badge: Perfectionist');
      expect(newBadgeLabel(_badge('first')), 'New bronze badge: First sparkle');
    });

    testWidgets('badges already earned when they reach the app show one summary on Home', (tester) async {
      final store = await _fixture();
      await store.markCelebrated(catchUpIds(store.unlockState(_courses)));
      final waiting = earnedAchievements(_courses, store).where((id) => !store.hasSeenBadge(id)).length;
      expect(waiting, greaterThan(1));
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MusicScope(
        music: music,
        child: ProgressScope(
          store: store,
          child: MaterialApp(navigatorObservers: [homeRouteObserver], home: HomeScreen(courses: _courses)),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse, reason: 'the note leaves by itself');
      expect(find.text('$waiting badges you had already earned are in your collection!'), findsOneWidget);
      expect(takeNewAchievements(_courses, store), isEmpty);

      await tester.pump(const Duration(milliseconds: 750)); // The note slides in.
      // The note stays on Home: another screen she opens doesn't carry it.
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Elsewhere'))));
      await tester.pumpAndSettle();
      expect(find.text('Elsewhere'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing, reason: 'the note was about Home when she left it');
    });

    testWidgets('a summary that left by itself does not close other notes', (tester) async {
      final store = await _fixture();
      await store.markCelebrated(catchUpIds(store.unlockState(_courses)));
      await tester.pumpWidget(MusicScope(
        music: music,
        child: ProgressScope(
          store: store,
          child: MaterialApp(navigatorObservers: [homeRouteObserver], home: HomeScreen(courses: _courses)),
        ),
      ));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 7)); // It times out.
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
          .showSnackBar(const SnackBar(content: Text('Gift'), duration: Duration(seconds: 30)));
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Game'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Gift'), findsOneWidget);
    });

    testWidgets('the summary opens Badges', (tester) async {
      final store = await _fixture();
      await store.markCelebrated(catchUpIds(store.unlockState(_courses)));
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MusicScope(
        music: music,
        child: ProgressScope(
          store: store,
          child: MaterialApp(navigatorObservers: [homeRouteObserver], home: HomeScreen(courses: _courses)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.text('See badges'));
      await tester.pumpAndSettle();
      expect(find.byType(BadgesScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a note on the root messenger outlives a screen Home opens', (tester) async {
      final store = await _fixture();
      await store.markCelebrated(catchUpIds(store.unlockState(_courses)));
      await tester.pumpWidget(MusicScope(
        music: music,
        child: ProgressScope(
          store: store,
          child: MaterialApp(navigatorObservers: [homeRouteObserver], home: HomeScreen(courses: _courses)),
        ),
      ));
      await tester.pump();
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Game'))));
      await tester.pumpAndSettle();
      // Like the days-played gift: shown from a game screen on the root messenger, then she goes back Home.
      ScaffoldMessenger.of(tester.element(find.text('Game')))
          .showSnackBar(const SnackBar(content: Text('Gift'), duration: Duration(seconds: 30)));
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.text('Gift'), findsOneWidget);
    });
  });
}
