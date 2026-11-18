import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Folders under assets/art/ that the app bundles. app_icon/ is read only by
/// the launcher icon tool, so it is checked on disk but not bundled.
const _bundled = [
  'badges',
  'brand',
  'courses',
  'difficulty',
  'icons',
  'mochi',
  'tiers'
];

/// Share of border pixels that must be fully transparent. Some art is cropped
/// on purpose (a head-and-shoulders Mochi), so the border is not 100% clear.
const _minClearBorder = 0.85;

/// Names of the visible files in [dir], sorted. Names only, so asset keys are
/// built with '/' on every OS.
List<String> _names(String dir) => Directory(dir)
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last)
    .where((n) => !n.startsWith('.'))
    .toList()
  ..sort();

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

/// Alpha of the four corners, and the share of border pixels with alpha 0.
Future<({List<int> corners, double clearBorder})> _edges(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = image.width, h = image.height;
  int alpha(int x, int y) => data.getUint8((y * w + x) * 4 + 3);
  var border = 0, clear = 0;
  void count(int x, int y) {
    border++;
    if (alpha(x, y) == 0) clear++;
  }

  for (var x = 0; x < w; x++) {
    count(x, 0);
    count(x, h - 1);
  }
  for (var y = 1; y < h - 1; y++) {
    count(0, y);
    count(w - 1, y);
  }
  return (
    corners: [
      alpha(0, 0),
      alpha(w - 1, 0),
      alpha(0, h - 1),
      alpha(w - 1, h - 1)
    ],
    clearBorder: clear / border,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every art folder on disk is either bundled or app_icon', () {
    final folders = Directory('assets/art')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    expect(folders, {..._bundled, 'app_icon', 'frames'});
  });

  test('pubspec declares every bundled art folder', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final f in _bundled) {
      expect(pubspec, contains('- assets/art/$f/'), reason: f);
    }
  });

  for (final folder in _bundled) {
    test(
        'assets/art/$folder: only PNGs, each loads, is transparent and at most 1024 px',
        () async {
      final dir = 'assets/art/$folder';
      // Flutter bundles only the folder's own files, never subfolders.
      expect(Directory(dir).listSync().whereType<Directory>(), isEmpty,
          reason: '$dir has subfolders that would not ship');
      final names = _names(dir);
      expect(names, isNotEmpty);
      for (final name in names) {
        final key = 'assets/art/$folder/$name';
        // The folder is bundled whole, so anything else in it would ship unchecked.
        expect(name, endsWith('.png'), reason: '$key is not a lowercase .png');
        final data = await rootBundle.load(key);
        final image = await _decode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        expect(image.width <= 1024 && image.height <= 1024, isTrue,
            reason: key);
        final edges = await _edges(image);
        expect(edges.corners, everyElement(0),
            reason: '$key corners should be transparent');
        expect(edges.clearBorder, greaterThanOrEqualTo(_minClearBorder),
            reason: '$key border should be mostly transparent');
      }
    });
  }

  test('pubspec declares the frames folder', () {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('- assets/art/frames/'));
  });

  // Frames fill their border, so they get their own check: the same names at
  // 1x, 2.0x and 3.0x, at most 1024 px, transparent corners and middle.
  test('assets/art/frames: every frame at three sizes, clear corners and middle',
      () async {
    const dir = 'assets/art/frames';
    final names = _names(dir);
    expect(names, isNotEmpty);
    expect(
        Directory(dir)
            .listSync()
            .whereType<Directory>()
            .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
            .toSet(),
        {'2.0x', '3.0x', 'export'});
    for (final variant in ['', '2.0x/', '3.0x/']) {
      expect(_names('$dir/$variant'), names, reason: '$dir/$variant');
      for (final name in names) {
        final key = '$dir/$variant$name';
        expect(name, endsWith('.png'), reason: key);
        final data = await rootBundle.load(key);
        final image = await _decode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        expect(image.width <= 1024 && image.height <= 1024, isTrue,
            reason: key);
        expect((await _edges(image)).corners, everyElement(0),
            reason: '$key corners should be transparent');
        final rgba =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final mid = (image.height ~/ 2 * image.width + image.width ~/ 2) * 4 + 3;
        expect(rgba.getUint8(mid), 0,
            reason: '$key middle should be transparent');
      }
    }
  });

  // Saves draw the frame from full-size copies, so it stays sharp at about 2500 px.
  test('assets/art/frames/export: every frame at 2048 px, declared, clear corners and middle', () async {
    const dir = 'assets/art/frames/export';
    expect(File('pubspec.yaml').readAsStringSync(), contains('- $dir/'));
    expect(_names(dir), _names('assets/art/frames'));
    for (final name in _names(dir)) {
      final data = await rootBundle.load('$dir/$name');
      final image = await _decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      expect([image.width, image.height], [2048, 2048], reason: name);
      expect((await _edges(image)).corners, everyElement(0), reason: name);
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      expect(rgba.getUint8((image.height ~/ 2 * image.width + image.width ~/ 2) * 4 + 3), 0, reason: name);
    }
  });

  test('app icon art decodes; only the full icon has a solid background',
      () async {
    expect(_names('assets/art/app_icon'),
        ['app_icon.png', 'app_icon_foreground.png']);
    final full = await _decode(
        File('assets/art/app_icon/app_icon.png').readAsBytesSync());
    final fg = await _decode(
        File('assets/art/app_icon/app_icon_foreground.png').readAsBytesSync());
    expect([full.width, full.height, fg.width, fg.height], everyElement(1024));
    expect((await _edges(full)).corners, everyElement(255));
    expect((await _edges(fg)).clearBorder, 1.0);
  });
}
