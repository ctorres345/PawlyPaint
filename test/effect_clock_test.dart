import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/ui/effect_clock.dart';

/// A clock whose time only moves when the test says so, in step with the
/// fake timers that `tester.pump` advances.
class _FakeTime {
  Duration now = Duration.zero;
  Duration call() => now;
}

void main() {
  late _FakeTime time;
  late EffectClock clock;
  late int ticks;

  Future<void> advance(WidgetTester tester, Duration d) async {
    // Move in timer-sized steps so the fake clock and the timers agree.
    const step = Duration(milliseconds: 10);
    var left = d;
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      time.now += s;
      await tester.pump(s);
      left -= s;
    }
  }

  setUp(() {
    time = _FakeTime();
    ticks = 0;
  });

  EffectClock make({Duration idleAfter = const Duration(seconds: 15)}) {
    clock = EffectClock(idleAfter: idleAfter, elapsed: time.call)..addListener(() => ticks++);
    return clock;
  }

  testWidgets('starts still and asks for no frames', (tester) async {
    make();
    await advance(tester, const Duration(seconds: 1));
    expect(clock.isRunning, isFalse);
    expect(ticks, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    clock.dispose();
  });

  testWidgets('a poke ticks about 30 times a second, not every vsync', (tester) async {
    make().poke();
    await advance(tester, const Duration(seconds: 1));
    expect(clock.isRunning, isTrue);
    expect(ticks, inInclusiveRange(28, 32));
    clock.dispose();
  });

  testWidgets('rests after idleAfter with no poke, and a poke wakes it again', (tester) async {
    make(idleAfter: const Duration(seconds: 2)).poke();
    await advance(tester, const Duration(milliseconds: 2100));
    expect(clock.isRunning, isFalse);
    final rested = ticks;
    await advance(tester, const Duration(seconds: 1));
    expect(ticks, rested, reason: 'no ticks while resting');

    clock.poke();
    await advance(tester, const Duration(milliseconds: 200));
    expect(clock.isRunning, isTrue);
    expect(ticks, greaterThan(rested));
    clock.dispose();
  });

  testWidgets('by default the effects rest 15 s after the last poke', (tester) async {
    make().poke();
    await advance(tester, const Duration(milliseconds: 14900));
    expect(clock.isRunning, isTrue);
    await advance(tester, const Duration(milliseconds: 200));
    expect(clock.isRunning, isFalse);
    clock.dispose();
  });

  testWidgets('each poke restarts the idle countdown', (tester) async {
    make(idleAfter: const Duration(seconds: 2)).poke();
    await advance(tester, const Duration(milliseconds: 1500));
    clock.poke();
    await advance(tester, const Duration(milliseconds: 1500));
    expect(clock.isRunning, isTrue, reason: '1.5 s since the last poke');
    await advance(tester, const Duration(milliseconds: 600));
    expect(clock.isRunning, isFalse);
    clock.dispose();
  });

  testWidgets('keeps ticking while a keep-alive test holds, then rests', (tester) async {
    var held = true;
    make(idleAfter: const Duration(milliseconds: 500))
      ..keepAliveWhile = (() => held)
      ..poke();
    await advance(tester, const Duration(seconds: 2));
    expect(clock.isRunning, isTrue, reason: 'held past the idle time');
    held = false;
    await advance(tester, const Duration(milliseconds: 100));
    expect(clock.isRunning, isFalse);
    clock.dispose();
  });

  testWidgets('wake starts it for a keep-alive test without the idle time', (tester) async {
    var held = false;
    make(idleAfter: const Duration(seconds: 15)).keepAliveWhile = () => held;
    clock.wake();
    await advance(tester, const Duration(milliseconds: 100));
    expect(clock.isRunning, isFalse, reason: 'nothing to show');
    held = true;
    clock.wake();
    await advance(tester, const Duration(milliseconds: 500));
    expect(clock.isRunning, isTrue);
    held = false;
    await advance(tester, const Duration(milliseconds: 100));
    expect(clock.isRunning, isFalse, reason: 'wake does not start the 15 s shimmer');
    clock.dispose();
  });

  testWidgets('not allowed (remove animations): never ticks, even when poked', (tester) async {
    make()
      ..allowed = false
      ..poke();
    await advance(tester, const Duration(seconds: 1));
    expect(clock.isRunning, isFalse);
    expect(ticks, 0);
    clock.allowed = true;
    await advance(tester, const Duration(milliseconds: 200));
    expect(clock.isRunning, isTrue, reason: 'allowing again wakes it like a poke');
    clock.dispose();
  });

  testWidgets('off screen: stops, and picks up where it was when back', (tester) async {
    make().poke();
    await advance(tester, const Duration(seconds: 1));
    clock.onScreen = false;
    final before = ticks;
    await advance(tester, const Duration(seconds: 2));
    expect(clock.isRunning, isFalse);
    expect(ticks, before);
    clock.onScreen = true;
    await advance(tester, const Duration(milliseconds: 200));
    expect(clock.isRunning, isTrue, reason: 'still inside the idle time');
    clock.dispose();
  });

  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    testWidgets('app $state: no ticks until resumed', (tester) async {
      make().poke();
      await advance(tester, const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(state);
      final before = ticks;
      await advance(tester, const Duration(seconds: 2));
      expect(clock.isRunning, isFalse);
      expect(ticks, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await advance(tester, const Duration(milliseconds: 200));
      expect(clock.isRunning, isTrue);
      clock.dispose();
    });
  }

  testWidgets('the phase follows running time and holds while stopped', (tester) async {
    make(idleAfter: const Duration(seconds: 1)).poke();
    expect(clock.value, 0);
    await advance(tester, const Duration(milliseconds: 420));
    expect(clock.value, closeTo(420 / 4200, 0.001));
    await advance(tester, const Duration(seconds: 1));
    expect(clock.isRunning, isFalse);
    final held = clock.value;
    await advance(tester, const Duration(seconds: 3));
    expect(clock.value, held, reason: 'frozen while resting');
    clock.poke();
    await advance(tester, const Duration(milliseconds: 100));
    expect(clock.value, closeTo(held + 100 / 4200, 0.001));
    clock.dispose();
  });

  testWidgets('the phase wraps around every period', (tester) async {
    make(idleAfter: const Duration(seconds: 10)).poke();
    await advance(tester, const Duration(milliseconds: 4200 + 840));
    expect(clock.value, closeTo(0.2, 0.001));
    clock.dispose();
  });

  testWidgets('dispose cancels its timer and lifecycle listener', (tester) async {
    make().poke();
    await advance(tester, const Duration(milliseconds: 100));
    clock.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    // A pending timer or a notify after dispose would fail the test.
  });
}
