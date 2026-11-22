import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/data/pictures.dart';
import 'package:pawlypaint/models/puzzle.dart';

import 'support/pictures.dart';

/// Cozy Classics as it shipped on shape art: the ids and titles the PNGs keep.
const _classics = {
  Difficulty.easy: {
    'classics-heart': 'Sweetheart',
    'classics-paw': 'Little Paw',
    'classics-sun': 'Sunny Day',
    'classics-mushroom': 'Forest Friend',
    'classics-cherries': 'Cherry Pair',
  },
  Difficulty.medium: {
    'classics-cat': 'Curious Cat',
    'classics-daisy': 'Daisy',
    'classics-strawberry': 'Berry Picnic',
    'classics-rainbow': 'After the Rain',
    'classics-cupcake': 'Party Cupcake',
  },
  Difficulty.hard: {
    'classics-sunset': 'Golden Hour',
    'classics-butterfly': 'Garden Flutter',
    'classics-puppy': 'Best Buddy',
    'classics-tulips': 'Tulip Bouquet',
    'classics-moonlight': 'Moonlit Watch',
  },
  Difficulty.extreme: {
    'classics-heart-balloons': 'Heart Balloons',
    'classics-picnic': 'Picnic Day',
    'classics-yarn-kitten': 'Yarn Kitten',
    'classics-carousel': 'Carousel',
    'classics-fireside': 'Fireside Nap',
  },
};

const _grid = {Difficulty.easy: 16, Difficulty.medium: 24, Difficulty.hard: 32, Difficulty.extreme: 40};
const _colorLimit = {Difficulty.easy: 6, Difficulty.medium: 8, Difficulty.hard: 12, Difficulty.extreme: 16};

/// The PNG's pixels as 0xAARRGGBB, read by the engine's own decoder.
Future<List<int>> _pixels(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return [
    for (var i = 0; i < image.width * image.height; i++)
      data.getUint8(i * 4 + 3) << 24 |
          data.getUint8(i * 4) << 16 |
          data.getUint8(i * 4 + 1) << 8 |
          data.getUint8(i * 4 + 2),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reading the course list before the picture load fails loudly', () {
    resetPicturesForTest();
    addTearDown(preloadPicturesFromDisk);
    expect(() => buildCourses(), throwsStateError);
    expect(() => buildCourses(store: true), throwsStateError);
    // ProgressStore and the home screen read allCourses: it must not freeze shape art either.
    expect(() => allCourses, throwsStateError);
  });

  test('Cozy Classics pictures come from their PNGs, with the same ids and titles', () async {
    final classics = buildCourses().firstWhere((c) => c.id == 'classics');
    expect(classics.levels.map((l) => l.difficulty), _classics.keys);
    for (final level in classics.levels) {
      final d = level.difficulty;
      expect({for (final p in level.puzzles) p.id: p.title}, _classics[d], reason: '$d');
      for (final p in level.puzzles) {
        expect((p.width, p.height), (_grid[d], _grid[d]), reason: p.id);
        expect(p.colorCount, inInclusiveRange(3, _colorLimit[d]!), reason: p.id);
        final slug = p.id.substring('classics-'.length);
        final pixels = await _pixels('assets/pictures/classics/$slug.png');
        expect([for (final c in p.cells) p.palette[c].toARGB32()], pixels, reason: '${p.id} cells match its PNG');
      }
    }
  });

  test('every other course still builds from its shape art, picture for picture', () {
    // FNV-1a over each picture's id, title, size, cells and palette, recorded on
    // main before PAP-77 (sideload 140 pictures, store 80).
    (int, int) digest(bool store) {
      var h = 0x811c9dc5, n = 0;
      for (final c in buildCourses(store: store)) {
        if (c.id == 'classics') continue;
        for (final p in c.puzzles) {
          n++;
          final s = '${p.id}|${p.title}|${p.width}|${p.cells.join(',')}|'
              '${p.palette.map((c) => c.toARGB32()).join(',')};';
          for (final u in s.codeUnits) {
            h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
          }
        }
      }
      return (n, h);
    }

    expect(digest(false), (140, 1787030827));
    expect(digest(true), (80, 1236448668));
  });

  test('the app loads the same pictures from its asset bundle as the tests do from disk', () async {
    final fromDisk = {for (final c in buildCourses()) ...c.puzzles.map((p) => (p.id, p.signature))};
    resetPicturesForTest();
    addTearDown(preloadPicturesFromDisk);
    await loadPictures(rootBundle);
    expect({for (final c in buildCourses()) ...c.puzzles.map((p) => (p.id, p.signature))}, fromDisk);
  });
}
