import 'dart:ui' show Color;

import '../models/puzzle.dart';
import 'artworks.dart';
import 'simplify.dart';

/// Canvas size for each difficulty.
const _sizes = {Difficulty.easy: 16, Difficulty.medium: 24, Difficulty.hard: 32, Difficulty.extreme: 40};

/// How far apart (CIE Lab ΔE) every two colors must be on Easy and Medium,
/// which also get a plain background. Hard keeps the full drawing: subtle
/// shades and busy backdrops are what make it hard.
const _minDistance = {Difficulty.easy: 22.0, Difficulty.medium: 16.0};

/// Smallest CIEDE2000 difference between any two drill colors.
const _minColorGap = {
  Difficulty.easy: 18.0,
  Difficulty.medium: 16.0,
  Difficulty.hard: 14.0,
  Difficulty.extreme: 12.0,
};

/// Pictures are keyed by a stable slug, so reordering or adding pictures
/// never moves saved progress onto a different one.
Course buildCourse(
  String id,
  String title,
  String subtitle,
  Color accent,
  Map<Difficulty, Map<String, Artwork>> art, {
  bool special = false,
}) =>
    Course(
      special: special,
      id: id,
      title: title,
      subtitle: subtitle,
      accent: accent,
      levels: [
        for (final MapEntry(key: difficulty, value: pictures) in art.entries)
          Level(
            difficulty: difficulty,
            puzzles: [
              for (final MapEntry(key: slug, value: draw) in pictures.entries)
                _forDifficulty(draw('$id-$slug', _sizes[difficulty]!), difficulty),
            ],
          ),
      ],
    );

Puzzle _forDifficulty(Puzzle p, Difficulty difficulty) {
  final minDistance = _minDistance[difficulty];
  final simple = minDistance == null ? p : simplifyPicture(p, minDistance: minDistance);
  return separateColors(simple, minDistance: _minColorGap[difficulty]!);
}
