import 'dart:async';

import 'package:flutter/animation.dart';

/// The canvas shimmer, which rests after a while without touches so the
/// screen stops redrawing (and the battery rests) while she just looks.
class IdleShimmer {
  IdleShimmer(TickerProvider vsync, {this.idleAfter = const Duration(seconds: 15)})
      : controller = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 4200));

  final AnimationController controller;
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
    controller.dispose();
  }
}
