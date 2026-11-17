import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks Android to run the display at 60 Hz while a play screen is open
/// (PAP-59). On a 120 Hz phone this halves the frames drawn during a drag,
/// which is where the raster thread spends its time.
///
/// Play screens call [hold] when they open and [release] when they close.
/// Holds are counted, so replacing one play screen with another (a restart)
/// keeps the cap. Home and the menus run at the system default. Other
/// platforms and a missing platform side are ignored.
abstract final class DisplayRate {
  static const channel = MethodChannel('pawlypaint/display_rate');

  static int _holds = 0;

  /// How many play screens hold the cap right now.
  static int get holds => _holds;

  static void hold() {
    _holds++;
    if (_holds == 1) _call('cap60');
  }

  static void release() {
    if (_holds == 0) return;
    _holds--;
    if (_holds == 0) _call('release');
  }

  static void _call(String method) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    channel
        .invokeMethod<void>(method)
        .catchError((Object _) {}, test: (e) => e is PlatformException || e is MissingPluginException);
  }

  @visibleForTesting
  static void resetForTest() => _holds = 0;
}
