import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/state/music.dart';

void main() {
  group('InterruptionGate', () {
    test('resumes the music that a call paused when the call ends in the app', () {
      final gate = InterruptionGate()..begin();
      expect(gate.shouldResume(appActive: true, muted: false), isTrue);
    });

    test('does not resume while the app is in the background (PAP-55 review)', () {
      final gate = InterruptionGate()..begin();
      expect(gate.shouldResume(appActive: false, muted: false), isFalse);
      // The lifecycle brings the music back later; a second end must not.
      expect(gate.shouldResume(appActive: true, muted: false), isFalse);
    });

    test('does not resume music the player muted meanwhile', () {
      final gate = InterruptionGate()..begin();
      expect(gate.shouldResume(appActive: true, muted: true), isFalse);
    });

    test('does not start music that was not playing when the other app came', () {
      expect(InterruptionGate().shouldResume(appActive: true, muted: false), isFalse);
    });

    test('an interruption that ends as unknown is forgotten', () {
      final gate = InterruptionGate()
        ..begin()
        ..clear();
      expect(gate.shouldResume(appActive: true, muted: false), isFalse);
    });
  });
}
