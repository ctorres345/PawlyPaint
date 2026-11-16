import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/logic/scoring.dart';
import 'package:pawlypaint/ui/star_meter.dart';

StarMeter _paint(int mistakes) => Scoring.paintMeter(mistakes: mistakes, cells: 16 * 16);

void main() {
  group('meter copy', () {
    test('Paint counts down, then names the last chance', () {
      expect(starMeterText(_paint(0), fresh: true), '3 stars: up to 3 mistakes');
      expect(starMeterText(_paint(0)), '3 mistakes left for 3 stars');
      expect(starMeterText(_paint(2)), '1 mistake left for 3 stars');
      expect(starMeterText(_paint(3)), 'Next mistake costs the 3rd star');
      expect(starMeterText(_paint(4)), '9 mistakes left for 2 stars');
      expect(starMeterText(_paint(13)), 'Next mistake costs the 2nd star');
      expect(starMeterText(_paint(14)), '1 star: finish the picture');
    });

    test('Sort counts wrong taps, then shakes', () {
      StarMeter sort(int shakes, int taps) => Scoring.sortMeter(shakes: shakes, mistakes: taps);
      expect(starMeterText(sort(0, 0), fresh: true), '3 stars: up to 3 wrong taps, no shakes');
      expect(starMeterText(sort(0, 1)), '2 wrong taps left for 3 stars · no shakes');
      expect(starMeterText(sort(0, 3)), 'Next wrong tap or a shake costs the 3rd star');
      expect(starMeterText(sort(1, 0)), '1 shake left for 2 stars');
      expect(starMeterText(sort(2, 0)), 'Next shake costs the 2nd star');
      expect(starMeterText(sort(3, 0)), '1 star: finish the picture');
    });

    test('a fresh meter only states the limit while 3 stars are possible', () {
      expect(starMeterText(_paint(14), fresh: true), '1 star: finish the picture');
    });
  });

  group('star-lost cue', () {
    Future<void> pump(WidgetTester tester, StarMeter meter, VoidCallback onLost, {bool reduceMotion = false}) =>
        tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(body: StarMeterBar(meter: meter, onStarLost: onLost)),
          ),
        ));

    testWidgets('fires once per lost star, not on every mistake', (tester) async {
      var lost = 0;
      void onLost() => lost++;
      for (final m in [0, 1, 2, 3]) {
        await pump(tester, _paint(m), onLost);
      }
      expect(lost, 0);
      await pump(tester, _paint(4), onLost); // 3rd star goes
      expect(lost, 1);
      for (final m in [5, 6, 13]) {
        await pump(tester, _paint(m), onLost);
      }
      expect(lost, 1);
      await pump(tester, _paint(14), onLost); // 2nd star goes
      expect(lost, 2);
      await pump(tester, _paint(40), onLost);
      expect(lost, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('a resumed save that already lost a star does not fire it', (tester) async {
      var lost = 0;
      await pump(tester, _paint(10), () => lost++);
      await pump(tester, _paint(10), () => lost++);
      expect(lost, 0);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    Finder wobble() => find.descendant(of: find.byType(StarMeterBar), matching: find.byType(Transform));

    testWidgets('the lost star wobbles, then settles', (tester) async {
      await pump(tester, _paint(3), () {});
      await pump(tester, _paint(4), () {});
      await tester.pump(const Duration(milliseconds: 100));
      expect(wobble(), findsWidgets);
      await tester.pumpAndSettle();
      expect(wobble(), findsNothing);
    });

    testWidgets('reduce motion still fires the cue, without the wobble', (tester) async {
      var lost = 0;
      await pump(tester, _paint(3), () => lost++, reduceMotion: true);
      await pump(tester, _paint(4), () => lost++, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(lost, 1);
      expect(wobble(), findsNothing);
    });
  });

  testWidgets('the line grows with the font size', (tester) async {
    Future<double> lineHeight(double scale) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: StarMeterBar(meter: _paint(1))),
        ),
      ));
      return tester.getSize(find.byType(FittedBox)).height;
    }

    final normal = await lineHeight(1);
    final large = await lineHeight(2);
    expect(large, greaterThan(normal * 1.5));
  });

  testWidgets('screen readers hear the stars and the line', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StarMeterBar(meter: _paint(1)))));
    expect(find.bySemanticsLabel('3 stars possible. 2 mistakes left for 3 stars'), findsOneWidget);
    handle.dispose();
  });
}
