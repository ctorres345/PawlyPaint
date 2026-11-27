import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/course_builder.dart' show minColorGap;
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/data/pictures.dart';
import 'package:pawlypaint/data/simplify.dart' show colorDistance;
import 'package:pawlypaint/models/puzzle.dart';

import 'support/pictures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the game measures colour gaps as tool/art_to_puzzle.py does', () {
    const pairs = [
      (0xFFDC1E28, 0xFFC82832, 4.6386),
      (0xFFFFFFFF, 0xFF000000, 100.0),
      (0xFF28A03C, 0xFF1E3CC8, 61.2893),
      (0xFFFADC28, 0xFFFFF078, 7.5354),
    ];
    for (final (a, b, de) in pairs) {
      expect(colorDistance(Color(a), Color(b)), closeTo(de, 1e-4), reason: '$a $b');
    }
  });

  test('the converter enforces the same colour gap per level as the game', () {
    final line = File('tool/art_to_puzzle.py').readAsLinesSync().singleWhere((l) => l.startsWith('LEVEL_GAP = '));
    final levelGap = {
      for (final m in RegExp(r'(\d+): ([\d.]+)').allMatches(line)) int.parse(m[1]!): double.parse(m[2]!),
    };
    const grid = {Difficulty.easy: 16, Difficulty.medium: 24, Difficulty.hard: 32, Difficulty.extreme: 40};
    expect(levelGap, {for (final d in Difficulty.values) grid[d]!: minColorGap[d]});
  });

  test('every PNG picture meets the converter minimum cells per colour', () {
    final line = File('tool/art_to_puzzle.py').readAsLinesSync().singleWhere((l) => l.startsWith('MIN_CELLS = '));
    final minCells = {
      for (final m in RegExp(r'(\d+): (\d+)').allMatches(line)) int.parse(m[1]!): int.parse(m[2]!),
    };
    expect(minCells, {16: 2, 24: 2, 32: 2, 40: 2});
    for (final course in buildCourses()) {
      for (final puzzle in course.puzzles) {
        if (picturePuzzle(puzzle.id, puzzle.title) == null) continue;
        final counts = List.filled(puzzle.colorCount, 0);
        for (final c in puzzle.cells) {
          counts[c]++;
        }
        final floor = minCells[puzzle.width]!;
        for (var i = 0; i < counts.length; i++) {
          expect(counts[i], greaterThanOrEqualTo(floor), reason: '${puzzle.id} colour $i has ${counts[i]} cells');
        }
      }
    }
  });

  test('reading the course list before the picture load fails loudly', () {
    resetPicturesForTest();
    addTearDown(preloadPicturesFromDisk);
    expect(() => buildCourses(), throwsStateError);
    expect(() => buildCourses(store: true), throwsStateError);
    expect(() => allCourses, throwsStateError);
  });

  test('the app loads the same pictures from its asset bundle as the tests do from disk', () async {
    final fromDisk = {for (final c in buildCourses()) ...c.puzzles.map((p) => (p.id, p.signature))};
    resetPicturesForTest();
    addTearDown(preloadPicturesFromDisk);
    await loadPictures(rootBundle);
    expect({for (final c in buildCourses()) ...c.puzzles.map((p) => (p.id, p.signature))}, fromDisk);
  });
}
