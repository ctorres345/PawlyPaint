import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, visibleForTesting;
import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;

import '../models/puzzle.dart';
import 'artworks.dart';
import 'indexed_png.dart';

/// Bundled picture art: `assets/pictures/<course>/<slug>.png`, one indexed PNG
/// per picture at its level's grid, written by tool/art_to_puzzle.py --build.
/// Each course folder is declared on its own in pubspec.yaml.
const picturesDir = 'assets/pictures/';

/// Decoded PNGs by picture id (`<course>-<slug>`); null until loaded.
Map<String, IndexedPng>? _pictures;

/// Loads every bundled picture PNG once. Startup awaits it before anything
/// reads the course list (main.dart); tests fill the cache from disk instead
/// (test/flutter_test_config.dart).
Future<void> loadPictures([AssetBundle? bundle]) async {
  final assets = bundle ?? rootBundle;
  final watch = Stopwatch()..start();
  final manifest = await AssetManifest.loadFromAssetBundle(assets);
  final paths = manifest.listAssets().where((p) => p.startsWith(picturesDir) && p.endsWith('.png'));
  final files = {
    for (final (path, data) in await Future.wait(paths.map((p) async => (p, await assets.load(p)))))
      path: Uint8List.sublistView(data),
  };
  loadPicturesFrom(files);
  if (kDebugMode) debugPrint('pictures: ${files.length} PNGs loaded in ${watch.elapsedMilliseconds} ms');
}

/// Fills the cache from PNG bytes keyed by asset path.
void loadPicturesFrom(Map<String, Uint8List> files) {
  _pictures = {
    for (final MapEntry(key: path, value: bytes) in files.entries) _idOf(path): decodeIndexedPng(bytes, name: path),
  };
}

String _idOf(String path) {
  final parts = path.startsWith(picturesDir) ? path.substring(picturesDir.length).split('/') : const <String>[];
  if (parts.length != 2 || !parts[1].endsWith('.png')) {
    throw ArgumentError.value(path, 'path', 'not $picturesDir<course>/<slug>.png');
  }
  return '${parts[0]}-${parts[1].substring(0, parts[1].length - 4)}';
}

@visibleForTesting
void resetPicturesForTest() => _pictures = null;

Map<String, IndexedPng> get _loaded =>
    _pictures ??
    (throw StateError('The course list was read before loadPictures() finished, so pictures would '
        'stay on shape art. Await loadPictures() first (main.dart; tests: test/flutter_test_config.dart).'));

/// The ids of every picture that has a PNG.
Iterable<String> get pictureIds => _loaded.keys;

/// Picture [id] from its PNG, titled [title], or null when it has no PNG.
/// Throws [StateError] if the pictures are not loaded yet.
Puzzle? picturePuzzle(String id, String title) {
  final png = _loaded[id];
  if (png == null) return null;
  return Puzzle(
    id: id,
    title: title,
    width: png.width,
    height: png.height,
    cells: png.indexes,
    palette: [for (final c in png.palette) Color(c)],
  );
}

/// A picture that exists only as a PNG: no shape art to fall back to, so a
/// missing PNG (not built, or its folder missing from pubspec.yaml) throws.
Artwork pngArt(String title) => (id, size) =>
    picturePuzzle(id, title) ??
    (throw StateError('$id has no PNG in $picturesDir: build it with tool/art_to_puzzle.py --build '
        'and declare its course folder in pubspec.yaml'));
