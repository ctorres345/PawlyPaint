import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/state/play_session.dart';

void main() {
  group('PlaySession', () {
    test('starts paused at the base seconds', () {
      var now = DateTime(2026, 11, 9, 12);
      final s = PlaySession(clock: () => now, baseSeconds: 12);
      expect(s.seconds, 12);
      now = now.add(const Duration(minutes: 5));
      expect(s.seconds, 12);
      expect(s.running, isFalse);
    });

    test('counts only while running; a second start keeps the first start time', () {
      var now = DateTime(2026, 11, 9, 12);
      final s = PlaySession(clock: () => now)..start();
      now = now.add(const Duration(seconds: 7));
      s.start();
      expect(s.seconds, 7);
      expect(s.running, isTrue);
      s.pause();
      now = now.add(const Duration(seconds: 30));
      expect(s.seconds, 7);
      s
        ..start()
        ..pause()
        ..pause();
      expect(s.seconds, 7);
    });

    test('whole seconds only: a pause keeps the seconds that were counted', () {
      var now = DateTime(2026, 11, 9, 12);
      final s = PlaySession(clock: () => now)..start();
      now = now.add(const Duration(milliseconds: 1500));
      s.pause();
      expect(s.seconds, 1);
    });

    test('keeps the relaxed flags', () {
      final s = PlaySession(excusedMistakes: true);
      expect(s.relaxed, isFalse);
      expect(s.excusedMistakes, isTrue);
      s.relaxed = true;
      expect(s.relaxed, isTrue);
    });
  });
}
