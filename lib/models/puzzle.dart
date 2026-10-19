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
        counts = _countColors(cells, palette.length);

  final String id;
  final String title;
  final int width;
  final int height;

  /// Palette index for every cell, row by row.
  final Uint8List cells;
  final List<Color> palette;

  /// How many cells use each palette color.
  final List<int> counts;

  int get cellCount => width * height;
  int get colorCount => palette.length;

  /// Target time for the 3-star rating.
  int get parSeconds => (cellCount * 1.2).round();

  /// Label printed on the canvas and in the tray for a color.
  String symbolFor(int color) => '${color + 1}';

  static List<int> _countColors(Uint8List cells, int colors) {
    final counts = List<int>.filled(colors, 0);
    for (final c in cells) {
      counts[c]++;
    }
    return counts;
  }
}

class Course {
  const Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.puzzles,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color accent;
  final List<Puzzle> puzzles;
}
