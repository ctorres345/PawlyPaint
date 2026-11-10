import 'package:flutter/services.dart' show appFlavor;

/// True in the Google Play build (`--flavor store`). That build has its own
/// app id and leaves out fan art and the private gift course.
const isStoreBuild = appFlavor == 'store';
