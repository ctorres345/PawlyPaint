import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/photo_frames.dart';
import 'package:pawlypaint/logic/unlocks.dart';
import 'package:pawlypaint/state/achievements.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/settings.dart';
import 'package:pawlypaint/ui/frame_picker.dart';
import 'package:pawlypaint/ui/gem_style.dart';
import 'package:pawlypaint/ui/picture_export.dart';
import 'package:shared_preferences/shared_preferences.dart';

UnlockState _unlocks(int threeStars) => Unlocks.evaluate(UnlockInput(
      threeStarPictures: {for (var i = 0; i < threeStars; i++) 'p$i'},
      pictureCount: 160,
    ));

Future<int> _pixel(ui.Image image, int x, int y) async {
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * image.width + x) * 4;
  return (rgba.getUint8(i) << 24) | (rgba.getUint8(i + 1) << 16) | (rgba.getUint8(i + 2) << 8) | rgba.getUint8(i + 3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which frames are open', () {
    test('no frame and Wood are always open', () {
      expect(PhotoFrame.none.isOpen(_unlocks(0), {}), isTrue);
      expect(PhotoFrame.wood.isOpen(_unlocks(0), {}), isTrue);
    });

    test('Polaroid, Lace and Paw open at 15, 45 and 75 3-star pictures', () {
      for (final (frame, need) in [(PhotoFrame.polaroid, 15), (PhotoFrame.lace, 45), (PhotoFrame.paw, 75)]) {
        expect(frame.threshold(160), need);
        expect(frame.isOpen(_unlocks(need - 1), {}), isFalse, reason: frame.name);
        expect(frame.isOpen(_unlocks(need), {}), isTrue, reason: frame.name);
      }
    });

    test('every reward frame names a real PAP-14 reward', () {
      final ids = {for (final r in UnlockTables.rewards) r.id};
      for (final f in PhotoFrame.values) {
        if (f.rewardId != null) expect(ids, contains(f.rewardId), reason: f.name);
      }
    });

    test('the hidden frame is not shown or open until its secret is found', () {
      expect(PhotoFrame.secret.isVisible({}), isFalse);
      expect(PhotoFrame.secret.isOpen(_unlocks(200), {}), isFalse);
      expect(PhotoFrame.secret.isVisible({secretFrameId}), isTrue);
      expect(PhotoFrame.secret.isOpen(_unlocks(0), {secretFrameId}), isTrue);
    });

    test('3-star pictures are read back from the next reward', () {
      expect(threeStarPictures(_unlocks(0), 160), 0);
      expect(threeStarPictures(_unlocks(7), 160), 7);
      expect(threeStarPictures(_unlocks(200), 160), isNull);
    });

    test('a picked frame that is not open saves without a frame', () {
      expect(PhotoFrame.usable(PhotoFrame.paw, _unlocks(10), {}), PhotoFrame.none);
      expect(PhotoFrame.usable(PhotoFrame.paw, _unlocks(80), {}), PhotoFrame.paw);
    });
  });

  test('the picked frame is saved with the settings', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.frame, PhotoFrame.none);
    await settings.setFrame(PhotoFrame.lace);
    expect((await AppSettings.load()).frame, PhotoFrame.lace);
    SharedPreferences.setMockInitialValues({'photo_frame': 'gone'});
    expect((await AppSettings.load()).frame, PhotoFrame.none);
  });

  group('frame art', () {
    for (final f in PhotoFrame.values.where((f) => f != PhotoFrame.none)) {
      test('${f.name}: the opening is found, inside the art and roomy', () async {
        final art = await FrameArt.load(f);
        expect(
            art.bounds.contains(art.window.topLeft) && art.bounds.contains(art.window.bottomRight - const Offset(1, 1)),
            isTrue);
        expect(art.window.width / art.bounds.width, inInclusiveRange(0.4, 0.9));
        expect(art.window.height / art.bounds.height, inInclusiveRange(0.4, 0.9));
        art.image.dispose();
      });
    }
  });

  group('framed picture', () {
    final puzzle = allCourses.expand((c) => c.puzzles).firstWhere((p) => p.width == 40);

    test('holds the frame around the gems, within the size limit', () async {
      final plain = await renderPicture(puzzle, shape: GemShape.square);
      // 40 cells of 40 px, and a one-cell margin.
      expect(plain.width, 1680);
      for (final f in PhotoFrame.values.where((f) => f != PhotoFrame.none)) {
        final framed = await renderPicture(puzzle, shape: GemShape.square, frame: f);
        expect(math.max(framed.width, framed.height), inInclusiveRange(maxFramedSide * 0.85, maxFramedSide),
            reason: f.name);
        // The corner is paper, not see-through, so Photos shows no black or checkerboard.
        expect(await _pixel(framed, 0, 0), 0xFFFBF7FF, reason: f.name); // #FFFBF7, opaque, as RGBA
        final dir = Platform.environment['FRAME_DIR'];
        if (dir != null) {
          Directory(dir).createSync(recursive: true);
          final png = await framed.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/${f.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
        }
        framed.dispose();
      }
      plain.dispose();
    });
  });

  group('Frame it badge', () {
    setUp(resetRegisteredBadges);
    tearDown(resetRegisteredBadges);

    test('is earned by the first framed save', () async {
      registerFrameBadge();
      final store = ProgressStore.memory();
      expect(earnedAchievements(allCourses, store), isNot(contains('frame.it')));
      await store.addSecret(framedSaveSecret);
      expect(takeNewAchievements(allCourses, store).map((a) => a.id), contains('frame.it'));
      expect(takeNewAchievements(allCourses, store), isEmpty);
    });
  });

  group('framed preview', () {
    Future<void> pump(WidgetTester tester, PhotoFrame frame) async {
      // Measuring the art reads real files, so it runs outside the fake clock.
      if (frame != PhotoFrame.none) await tester.runAsync(() => FrameGeometry.of(frame));
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 200,
            child: FramedPreview(frame: frame, child: const ColoredBox(key: Key('pic'), color: Colors.red)),
          ),
        ),
      ));
      // FutureBuilder hears from that future on the real event loop too.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    testWidgets('no frame: the picture fills the space', (tester) async {
      await pump(tester, PhotoFrame.none);
      expect(tester.getSize(find.byKey(const Key('pic'))), const Size(200, 200));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a frame: its art is drawn and the picture sits in its opening', (tester) async {
      await pump(tester, PhotoFrame.lace);
      expect(find.image(const AssetImage('assets/art/frames/frame_photo_lace.png')), findsOneWidget);
      final pic = tester.getRect(find.byKey(const Key('pic')));
      expect(pic.width, lessThan(200 * windowFill));
      expect(pic.width, greaterThan(60));
      expect((pic.center - const Offset(400, 300)).distance, lessThan(30));
    });
  });

  group('frame picker', () {
    Future<(AppSettings, ProgressStore)> pump(WidgetTester tester, {Set<String> secrets = const {}}) async {
      final settings = AppSettings.memory();
      final store = ProgressStore.memory();
      for (final s in secrets) {
        await store.addSecret(s);
      }
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: ProgressScope(
          store: store,
          child: const MaterialApp(home: Scaffold(body: Center(child: FramePicker()))),
        ),
      ));
      return (settings, store);
    }

    testWidgets('shows the open and locked frames, not the hidden one', (tester) async {
      await pump(tester);
      for (final label in ['No frame', 'Wood', 'Polaroid', 'Lace', 'Paw print']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Secret'), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(3));
    });

    testWidgets('the hidden frame shows once its secret is found', (tester) async {
      await pump(tester, secrets: {secretFrameId});
      await tester.dragUntilVisible(find.text('Secret'), find.byType(ListView), const Offset(-100, 0));
      expect(find.text('Secret'), findsOneWidget);
    });

    testWidgets('tapping Wood picks it; tapping a locked frame says how to earn it', (tester) async {
      final (settings, _) = await pump(tester);
      await tester.tap(find.text('Wood'));
      await tester.pump();
      expect(settings.frame, PhotoFrame.wood);
      final pictures = allCourses.fold(0, (n, c) => n + c.puzzles.length);
      await tester.tap(find.text('Polaroid'));
      await tester.pumpAndSettle();
      expect(settings.frame, PhotoFrame.wood);
      expect(
          find.text('Earn 3 stars on ${PhotoFrame.polaroid.threshold(pictures)} pictures to unlock Polaroid.'
              ' You have 0 so far.'),
          findsOneWidget);
    });
  });
}
