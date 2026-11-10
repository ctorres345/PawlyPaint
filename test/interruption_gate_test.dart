import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/state/music.dart';

void main() {
  group('InterruptionGate', () {
    test('resumes the music that a call paused when the call ends in the app', () {
      final gate = InterruptionGate()..begin(wasPlaying: true);
      expect(gate.end(appActive: true, muted: false), isTrue);
    });

    test('does not resume while the app is in the background (PAP-55 review)', () {
      final gate = InterruptionGate()..begin(wasPlaying: true);
      expect(gate.end(appActive: false, muted: false), isFalse);
      // The lifecycle brings the music back later; a second end must not.
      expect(gate.end(appActive: true, muted: false), isFalse);
    });

    test('does not resume music the player muted meanwhile', () {
      final gate = InterruptionGate()..begin(wasPlaying: true);
      expect(gate.end(appActive: true, muted: true), isFalse);
    });

    test('does not start music that was not playing when the other app came', () {
      expect(InterruptionGate().end(appActive: true, muted: false), isFalse);
    });

    test('an interruption that ends as unknown is forgotten', () {
      final gate = InterruptionGate()
        ..begin(wasPlaying: true)
        ..clear();
      expect(gate.end(appActive: true, muted: false), isFalse);
    });

    test('holds the audio during a call even when the music was not playing (PAP-55 review)', () {
      final gate = InterruptionGate()..begin(wasPlaying: false);
      expect(gate.held, isTrue);
      // Returning to the app or a level change during the call must not play.
      gate.deferPlay();
      expect(gate.end(appActive: true, muted: false), isTrue);
      expect(gate.held, isFalse);
    });

    test('music that was not wanted when the call ends stays off', () {
      final gate = InterruptionGate()..begin(wasPlaying: false);
      expect(gate.end(appActive: true, muted: false), isFalse);
    });

    test('losing the audio for good releases the hold', () {
      final gate = InterruptionGate()
        ..begin(wasPlaying: true)
        ..clear();
      expect(gate.held, isFalse);
    });
  });
}
