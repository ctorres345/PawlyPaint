import 'dart:io';

import 'package:pawlypaint/data/pictures.dart';

/// Fills the picture cache from the PNGs on disk, as startup does from the
/// asset bundle. `test/flutter_test_config.dart` runs it before every test
/// file, so code that builds the course list at declaration time works.
void preloadPicturesFromDisk() {
  final dir = Directory(picturesDir);
  loadPicturesFrom({
    if (dir.existsSync())
      for (final f in dir.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.png')) f.path.replaceAll(r'\', '/'): f.readAsBytesSync(),
  });
}
