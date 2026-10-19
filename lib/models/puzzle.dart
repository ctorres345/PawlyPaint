import 'dart:typed_data';
import 'dart:ui' show Color;

/// One picture to fill with drills: a grid of palette indices plus the palette.
class Puzzle {
  Puzzle({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.cells,
    required this.palette,
  })  : assert(cells.length == width * height),
        counts = _countColors(cells, palette.length),
        cellsByColor = _groupCells(cells, palette.length),
        signature = _signature(width, cells);

  final String id;
  final String title;
  final int width;
  final int height;

  /// Palette index for every cell, row by row.
  final Uint8List cells;
  final List<Color> palette;

  /// How many cells use each palette color.
  final List<int> counts;

  /// Cell indices for each palette color.
  final List<List<int>> cellsByColor;

  /// Fingerprint of the picture, so a saved game is never resumed onto a
  /// picture that changed.
  final int signature;

  int get cellCount => width * height;
  int get colorCount => palette.length;

  /// Target time for the 3-star rating.
  int get parSeconds => (cellCount * 1.2).round();

  /// Label printed on the canvas and in the tray for a color.
  String symbolFor(int color) => '${color + 1}';

  static List<List<int>> _groupCells(Uint8List cells, int colors) {
    final groups = List.generate(colors, (_) => <int>[]);
    for (var i = 0; i < cells.length; i++) {
      groups[cells[i]].add(i);
    }
    return groups;
  }

  /// 32-bit FNV-1a over the width and cells.
  static int _signature(int width, Uint8List cells) {
    var h = ((0x811C9DC5 ^ width) * 0x01000193) & 0xFFFFFFFF;
    for (final b in cells) {
      h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static List<int> _countColors(Uint8List cells, int colors) {
    final counts = List<int>.filled(colors, 0);
    for (final c in cells) {
      counts[c]++;
    }
    return counts;
  }
}

enum Difficulty {
  easy('Easy', 'Small canvases, a handful of colors'),
  medium('Medium', 'Bigger pictures with soft shading'),
  hard('Hard', 'Large canvases and rich palettes');

  const Difficulty(this.label, this.blurb);

  final String label;
  final String blurb;
}

/// One difficulty section of a course.
class Level {
  const Level({required this.difficulty, required this.puzzles});

  final Difficulty difficulty;
  final List<Puzzle> puzzles;
}

/// A themed collection of pictures, split into Easy, Medium and Hard.
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.levels,
    this.special = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color accent;
  final List<Level> levels;

  /// Themed fan collections, shown under their own heading.
  final bool special;

  List<Puzzle> get puzzles => [for (final l in levels) ...l.puzzles];
}
