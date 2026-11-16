import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/logic/scoring.dart';

/// PAP-8: the star meter must never promise more stars than the finish sheet
/// gives, so it is checked against [Scoring.stars] and [Scoring.sortStars].
void main() {
  group('paint meter', () {
    // The four course sizes (16, 24, 32, 40 square), the tutorial-sized
    // pictures and a few odd shapes.
    const cellCounts = [16 * 16, 24 * 24, 32 * 32, 40 * 40, 4, 30, 99, 100, 101, 250, 700, 16 * 40];

    test('limits match the ticket examples', () {
      expect(Scoring.paintLimits(16 * 16), (three: 3, two: 13));
      expect(Scoring.paintLimits(40 * 40), (three: 16, two: 80));
    });

    for (final cells in cellCounts) {
      test('$cells cells: meter agrees with the finish at every mistake count', () {
        final limits = Scoring.paintLimits(cells);
        for (var m = 0; m <= limits.two + 2; m++) {
          final meter = Scoring.paintMeter(mistakes: m, cells: cells);
          expect(meter.stars, Scoring.stars(mistakes: m, cells: cells), reason: '$m mistakes');
          expect(meter.counts, MeterCount.mistake);
          if (meter.stars == 3) expect(meter.left, limits.three - m);
          if (meter.stars == 2) expect(meter.left, limits.two - m);
          if (meter.stars == 1) expect(meter.left, isNull);
          // One more mistake than "left" is exactly what drops a star.
          final left = meter.left;
          if (left != null) {
            expect(Scoring.stars(mistakes: m + left, cells: cells), meter.stars);
            expect(Scoring.stars(mistakes: m + left + 1, cells: cells), meter.stars - 1);
          }
        }
      });
    }
  });

  group('sort meter', () {
    test('agrees with the finish for every mix of shakes and wrong taps', () {
      for (var shakes = 0; shakes <= 4; shakes++) {
        for (var m = 0; m <= 8; m++) {
          final meter = Scoring.sortMeter(shakes: shakes, mistakes: m);
          expect(meter.stars, Scoring.sortStars(shakes: shakes, mistakes: m), reason: '$shakes shakes, $m taps');
        }
      }
    });

    test('counts wrong taps while 3 stars are possible', () {
      expect(Scoring.sortMeter(shakes: 0, mistakes: 0), (stars: 3, left: 3, counts: MeterCount.wrongTap));
      expect(Scoring.sortMeter(shakes: 0, mistakes: 3), (stars: 3, left: 0, counts: MeterCount.wrongTap));
    });

    test('then counts shakes left for 2 stars', () {
      expect(Scoring.sortMeter(shakes: 0, mistakes: 4), (stars: 2, left: 2, counts: MeterCount.shake));
      expect(Scoring.sortMeter(shakes: 1, mistakes: 0), (stars: 2, left: 1, counts: MeterCount.shake));
      expect(Scoring.sortMeter(shakes: 2, mistakes: 9), (stars: 2, left: 0, counts: MeterCount.shake));
      expect(Scoring.sortMeter(shakes: 3, mistakes: 0), (stars: 1, left: null, counts: MeterCount.shake));
    });
  });
}
