import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/line.dart';
import 'package:pawlypaint/logic/scoring.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/game_controller.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/ui/board.dart';

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

    test('every course has at least 5 pictures for each difficulty', () {
      for (final course in courses) {
        expect(course.levels.map((l) => l.difficulty), Difficulty.values, reason: course.id);
        for (final level in course.levels) {
          expect(level.puzzles.length, greaterThanOrEqualTo(5), reason: '${course.id} ${level.difficulty}');
        }
      }
    });

    test('every picture builds at its course size and uses every palette color', () {
      for (final course in courses) {
        for (final p in course.puzzles) {
          expect(p.cells.length, p.width * p.height, reason: p.id);
          expect(p.counts.every((c) => c > 0), isTrue, reason: '${p.id} has an unused color');
          expect(p.colorCount, greaterThanOrEqualTo(3), reason: '${p.id} is too plain');
        }
      }
    });

    test('no picture has two colors that are hard to tell apart', () {
      final close = <String>[];
      for (final p in [for (final c in courses) ...c.puzzles]) {
        for (var a = 0; a < p.colorCount; a++) {
          for (var b = a + 1; b < p.colorCount; b++) {
            final ca = p.palette[a], cb = p.palette[b];
            final dr = (ca.r - cb.r) * 255, dg = (ca.g - cb.g) * 255, db = (ca.b - cb.b) * 255;
            if (dr * dr + dg * dg + db * db <= 18 * 18) close.add('${p.id}: colors ${a + 1} and ${b + 1}');
          }
        }
      }
      expect(close, isEmpty);
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

    test('stars only depend on accuracy', () {
      expect(Scoring.stars(mistakes: 3, cells: 256), 3);
      expect(Scoring.stars(mistakes: 10, cells: 256), 2);
      expect(Scoring.stars(mistakes: 40, cells: 256), 1);
    });

    test('the time bonus is capped at a fifth of the drill points', () {
      expect(Scoring.timeBonus(100, 300, 256), 200);
      expect(Scoring.timeBonus(0, 1200, 1024), 1200);
      expect(Scoring.timeBonus(10, 5000, 100), 200);
      expect(Scoring.timeBonus(400, 300, 256), 0);
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

    test('a save from a different picture is not resumed', () {
      final g = GameController(_tiny())..place(0);
      final other = Puzzle(
        id: 't',
        title: 'Changed',
        width: 2,
        height: 2,
        cells: Uint8List.fromList([1, 0, 1, 1]),
        palette: const [Color(0xFF000000), Color(0xFFFFFFFF)],
      );
      final store = ProgressStore.memory()..saveGame('t', g.snapshot());
      expect(store.savedFor(other), isNull);
      expect(store.savedFor(_tiny()), isNotNull);
      expect(GameController(other, resume: g.snapshot()).placedCount, 0);
    });

    test('saved games and records survive a JSON round trip', () {
      final g = GameController(_tiny())..place(0);
      final saved = SavedGame.fromJson(g.snapshot().toJson());
      expect((saved.signature, saved.placed, saved.score), (_tiny().signature, '1000', g.score));
      final r = PuzzleRecord.fromJson(const PuzzleRecord(bestScore: 5, bestStars: 2, bestSeconds: 9).toJson());
      expect((r.bestScore, r.bestStars, r.bestSeconds), (5, 2, 9));
    });

    test('a snapshot resumes the same board', () {
      final g = GameController(_tiny())..place(0);
      final resumed = GameController(_tiny(), resume: g.snapshot());
      expect(resumed.placedCount, 1);
      expect(resumed.remaining, [0, 3]);
      expect(resumed.score, g.score);
    });
  });

  group('drag line', () {
    test('covers every cell between the ends, both included', () {
      expect(cellsOnLine((0, 0), (3, 0)).toList(), [(0, 0), (1, 0), (2, 0), (3, 0)]);
      expect(cellsOnLine((2, 2), (2, 2)).toList(), [(2, 2)]);
      final diag = cellsOnLine((0, 0), (4, 2)).toList();
      expect((diag.first, diag.last, diag.length), ((0, 0), (4, 2), 5));
    });
  });

  group('view', () {
    test('fits the canvas, finds cells and keeps zoom in range', () {
      final v = BoardView()..fit(const Size(400, 600), 16, 16);
      expect(v.cellSize * 16, closeTo(400 - 2 * BoardView.edge, 0.001));
      expect(v.cellAt(v.offset + Offset(v.cellSize * 2.5, v.cellSize * 3.5)), (2, 3));
      expect(v.cellAt(v.offset - const Offset(1, 1)), isNull);
      v.zoomAt(const Offset(200, 300), 100);
      expect(v.scale, v.maxScale);
    });
  });

  group('music', () {
    test('shuffle never repeats the theme that just played', () {
      final rng = math.Random(1);
      var last = MusicTheme.chill;
      final seen = <MusicTheme>{};
      for (var i = 0; i < 50; i++) {
        final next = nextShuffleTheme(last, rng);
        expect(next, isNot(last));
        seen.add(next);
        last = next;
      }
      expect(seen, MusicTheme.values.toSet());
    });
  });

  group('progress', () {
    test('levels and pictures unlock in order', () async {
      final course = buildCourses().first;
      final store = ProgressStore.memory();
      final easy = course.levels.first;
      expect(store.isLevelUnlocked(course, 0), isTrue);
      expect(store.isPuzzleUnlocked(easy, 0), isTrue);
      expect(store.isPuzzleUnlocked(easy, 1), isFalse);
      expect(store.isLevelUnlocked(course, 1), isFalse);
      for (var i = 0; i < unlockAfter; i++) {
        await store.recordCompletion(easy.puzzles[i].id, score: 100, stars: 2, seconds: 60);
      }
      expect(store.isPuzzleUnlocked(easy, unlockAfter), isTrue);
      expect(store.isLevelUnlocked(course, 1), isTrue);
      expect(store.isLevelUnlocked(course, 2), isFalse);
      expect(store.starsIn(course.puzzles), unlockAfter * 2);
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
