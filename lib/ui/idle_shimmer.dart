import 'dart:async';

import 'package:flutter/animation.dart';

/// The canvas shimmer, which rests after a while without touches so the
/// screen stops redrawing (and the battery rests) while she just looks.
class IdleShimmer {
  IdleShimmer(TickerProvider vsync, {this.idleAfter = const Duration(seconds: 15)})
      : controller = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 4200)) {
    animation = ThrottledAnimation(controller);
  }

  final AnimationController controller;

  /// What painters should listen to: it follows [controller] but repaints at
  /// most about 30 times a second, since a slow band of light needs no more
  /// and a 120 Hz screen would otherwise redraw the whole canvas 120 times.
  late final ThrottledAnimation animation;
  final Duration idleAfter;
  Timer? _idle;
  bool _allowed = true;

  /// Whether animation is allowed at all (false with "remove animations").
  set allowed(bool value) {
    _allowed = value;
    if (!value) {
      _idle?.cancel();
      controller.stop();
    } else {
      poke();
    }
  }

  /// Call on any touch or game event: wakes the shimmer and restarts the
  /// idle countdown.
  void poke() {
    if (!_allowed) return;
    if (!controller.isAnimating) controller.repeat();
    _idle?.cancel();
    _idle = Timer(idleAfter, controller.stop);
  }

  void dispose() {
    _idle?.cancel();
    animation.dispose();
    controller.dispose();
  }
}

/// An animation that reports [parent]'s value but notifies its listeners at
/// most once every [minInterval], so whatever repaints on it runs at a lower
/// frame rate than the screen.
class ThrottledAnimation extends Animation<double> with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  ThrottledAnimation(this.parent, {this.minInterval = const Duration(milliseconds: 30)}) {
    parent.addListener(_tick);
    parent.addStatusListener(notifyStatusListeners);
  }

  final Animation<double> parent;
  final Duration minInterval;
  int _lastUs = 0;

  void _tick() {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (now - _lastUs < minInterval.inMicroseconds) return;
    _lastUs = now;
    notifyListeners();
  }

  @override
  double get value => parent.value;

  @override
  AnimationStatus get status => parent.status;

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}

  void dispose() {
    parent.removeListener(_tick);
    parent.removeStatusListener(notifyStatusListeners);
    clearListeners();
    clearStatusListeners();
  }
}
