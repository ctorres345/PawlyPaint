import 'dart:async';

import 'support/pictures.dart';

/// Runs before every test file: the course list needs the picture PNGs.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  preloadPicturesFromDisk();
  await testMain();
}
