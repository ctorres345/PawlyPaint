import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Paces the decorative effects of a play screen (the shimmer band, twinkles,
/// pulses, pops and rings) at about 30 frames a second, and only while one
/// of them can be seen.
///
/// An animation controller would ask the engine for a frame on every vsync,
/// 120 a second on a 120 Hz phone, and every one of those frames redraws the
/// whole screen even if its painters skip their turn. This clock uses a
/// timer instead, so the screen draws only the frames the effects need.
///
/// It runs for [idleAfter] after each [poke] (a touch or game event), and
/// for as long as [keepAliveWhile] holds. It stops while the app is in the
/// background, while its screen is covered ([onScreen]), and for good when
/// animations are not [allowed]. Its [value] is the shimmer phase (0..1),
/// which advances only while it runs.
class EffectClock extends ChangeNotifier with WidgetsBindingObserver implements ValueListenable<double> {
  EffectClock({
    this.idleAfter = const Duration(seconds: 15),
    this.interval = const Duration(milliseconds: 33),
    this.period = const Duration(milliseconds: 4200),
    Duration Function()? elapsed,
  }) : _elapsed = elapsed ?? _stopwatch() {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _appActive = state == null || state == AppLifecycleState.resumed;
  }

  static Duration Function() _stopwatch() {
    final s = Stopwatch()..start();
    return () => s.elapsed;
  }

  /// How long the effects keep running after the last [poke].
  final Duration idleAfter;

  /// Time between ticks: about 30 a second, enough for slow light and pulses.
  final Duration interval;

  /// One shimmer cycle.
  final Duration period;

  final Duration Function() _elapsed;

  /// Keeps the clock running past its idle time while this returns true,
  /// for example while a Sort bead is picked up and pulses.
  bool Function()? keepAliveWhile;

  Timer? _timer;
  Duration _deadline = Duration.zero;
  Duration _ran = Duration.zero;
  Duration? _since;
  bool _allowed = true;
  bool _onScreen = true;
  bool _appActive = true;
  bool _disposed = false;

  /// Whether the clock is ticking now.
  bool get isRunning => _timer != null;

  @override
  double get value {
    final ran = _ran + (_since == null ? Duration.zero : _elapsed() - _since!);
    return (ran.inMicroseconds % period.inMicroseconds) / period.inMicroseconds;
  }

  /// False with the system "remove animations" setting: the clock never runs.
  set allowed(bool v) {
    if (v == _allowed) return;
    _allowed = v;
    v ? poke() : _stop();
  }

  /// False while another screen covers this one.
  set onScreen(bool v) {
    if (v == _onScreen) return;
    _onScreen = v;
    v ? _maybeStart() : _stop();
  }

  /// A touch or game event: run the effects for [idleAfter] from now.
  void poke() {
    final until = _elapsed() + idleAfter;
    if (until > _deadline) _deadline = until;
    _maybeStart();
  }

  /// Starts the clock if [keepAliveWhile] wants it, without the idle time.
  void wake() => _maybeStart();

  bool get _wanted => _elapsed() < _deadline || (keepAliveWhile?.call() ?? false);

  void _maybeStart() {
    if (_disposed || _timer != null || !_allowed || !_onScreen || !_appActive || !_wanted) return;
    _since = _elapsed();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    notifyListeners();
    if (!_wanted) _stop();
  }

  void _stop() {
    final t = _timer;
    if (t == null) return;
    t.cancel();
    _timer = null;
    _ran += _elapsed() - _since!;
    _since = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _appActive ? _maybeStart() : _stop();
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
