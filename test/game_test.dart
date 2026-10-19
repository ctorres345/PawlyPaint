import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/scoring.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/game_controller.dart';
import 'package:pawlypaint/state/progress_store.dart';

Puzzle _tiny() => Puzzle(
      id: 't',
      title: 'Tiny',
      width: 2,
      height: 2,
      cells: Uint8List.fromList([0, 1, 1, 1]),
      palette: const [Color(0xFF000000), Color(0xFFFFFFFF)],
    );

void main() {
  group('courses', () {
    final courses = buildCourses();

    test('every picture builds at its course size and uses every palette color', () {
      for (final course in courses) {
        for (final p in course.puzzles) {
          expect(p.cells.length, p.width * p.height, reason: p.id);
          expect(p.counts.every((c) => c > 0), isTrue, reason: '${p.id} has an unused color');
          expect(p.colorCount, greaterThanOrEqualTo(3), reason: '${p.id} is too plain');
        }
      }
    });

    test('puzzle ids are unique', () {
      final ids = [for (final c in courses) ...c.puzzles.map((p) => p.id)];
      expect(ids.toSet().length, ids.length);
    });
  });

  group('scoring', () {
    test('combo adds up to 5 bonus points per drill', () {
      expect(Scoring.pointsForDrill(1), 10);
      expect(Scoring.pointsForDrill(25), 12);
      expect(Scoring.pointsForDrill(500), 15);
    });

    test('a mistake never makes the score negative', () {
      expect(Scoring.afterMistake(5), 0);
      expect(Scoring.afterMistake(100), 85);
    });

    test('stars come from accuracy and time', () {
      expect(Scoring.stars(mistakes: 0, cells: 256, seconds: 100, parSeconds: 300), 3);
      expect(Scoring.stars(mistakes: 0, cells: 256, seconds: 400, parSeconds: 300), 2);
      expect(Scoring.stars(mistakes: 10, cells: 256, seconds: 100, parSeconds: 300), 2);
      expect(Scoring.stars(mistakes: 40, cells: 256, seconds: 100, parSeconds: 300), 1);
    });
  });

  group('game', () {
    test('a wrong tap is a mistake, a wrong drag is ignored', () {
      final g = GameController(_tiny());
      expect(g.selected, 0);
      expect(g.place(1), PlaceResult.wrong);
      expect(g.mistakes, 1);
      expect(g.place(1, dragging: true), PlaceResult.ignored);
      expect(g.mistakes, 1);
    });

    test('finishing a color moves to the next one, finishing all completes', () {
      final g = GameController(_tiny());
      expect(g.place(0), PlaceResult.colorComplete);
      expect(g.selected, 1);
      expect(g.place(1), PlaceResult.placed);
      expect(g.place(1), PlaceResult.ignored);
      expect(g.place(2), PlaceResult.placed);
      expect(g.place(3), PlaceResult.puzzleComplete);
      expect(g.isComplete, isTrue);
    });

    test('a snapshot resumes the same board', () {
      final g = GameController(_tiny())..place(0);
      final resumed = GameController(_tiny(), resume: g.snapshot());
      expect(resumed.placedCount, 1);
      expect(resumed.remaining, [0, 3]);
      expect(resumed.score, g.score);
    });
  });

  group('progress', () {
    test('courses and pictures unlock in order', () async {
      final courses = buildCourses();
      final store = ProgressStore.memory();
      final beginner = courses.first;
      expect(store.isPuzzleUnlocked(beginner, 0), isTrue);
      expect(store.isPuzzleUnlocked(beginner, 1), isFalse);
      expect(store.isCourseUnlocked(courses, 1), isFalse);
      for (var i = 0; i < unlockAfter; i++) {
        await store.recordCompletion(beginner.puzzles[i].id, score: 100, stars: 2, seconds: 60);
      }
      expect(store.isPuzzleUnlocked(beginner, unlockAfter), isTrue);
      expect(store.isCourseUnlocked(courses, 1), isTrue);
    });

    test('best results are kept', () async {
      final store = ProgressStore.memory();
      expect(await store.recordCompletion('a', score: 100, stars: 2, seconds: 90), isTrue);
      expect(await store.recordCompletion('a', score: 80, stars: 3, seconds: 60), isFalse);
      final r = store.record('a')!;
      expect((r.bestScore, r.bestStars, r.bestSeconds), (100, 3, 60));
    });
  });
}
