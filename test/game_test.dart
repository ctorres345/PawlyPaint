import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/data/simplify.dart';
import 'package:pawlypaint/logic/line.dart';
import 'package:pawlypaint/logic/scoring.dart';
import 'package:pawlypaint/logic/sort_game.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/achievements.dart';
import 'package:pawlypaint/state/game_controller.dart';
import 'package:pawlypaint/state/music.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/sort_controller.dart';
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

    test('simplifying flattens backdrop dots and merges look-alike shades, but keeps shapes', () {
      // 0 background, 1 dots, 2 and 3 nearly the same red, 4 white shape.
      const rows = [
        '01000100',
        '00000000',
        '00222200',
        '00233300',
        '00000000',
        '00444400',
        '10000001',
        '00000000',
      ];
      final p = Puzzle(
        id: 's',
        title: 'S',
        width: 8,
        height: 8,
        cells: Uint8List.fromList([for (final r in rows) ...r.split('').map(int.parse)]),
        palette: const [
          Color(0xFFFCE4EC),
          Color(0xFFF8BBD0),
          Color(0xFFE53950),
          Color(0xFFE8455A),
          Color(0xFF3949AB),
        ],
      );
      final s = simplifyPicture(p, minDistance: 22);
      expect(s.colorCount, 3);
      expect(s.cells[1], s.cells[0], reason: 'dots join the background');
      expect(s.cells[2 * 8 + 2], s.cells[3 * 8 + 4], reason: 'look-alike reds merge');
      expect(s.cells[5 * 8 + 2], isNot(s.cells[0]), reason: 'shapes stay');
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

  group('sort mode', () {
    test('every Sort picture can earn 3 stars by following hints, with no shakes', () {
      for (final p in buildCourses().expand((c) => c.puzzles)) {
        final g = SortController(p).game;
        var steps = 0;
        for (var next = g.bestStep(); next != null; next = g.bestStep()) {
          g.play(next);
          steps++;
        }
        expect(g.isComplete, isTrue, reason: p.id);
        expect(g.shakes, 0, reason: p.id);
        expect(g.mistakes, 0, reason: p.id);
        expect(steps, lessThan(p.cellCount * 2), reason: p.id);
      }
    });

    test('a broken or mismatched Sort save starts fresh instead of crashing', () {
      final p = buildCourses().first.levels.first.puzzles.first;
      final good = SortController(p).toJson();
      expect(SortController(p, resume: good).game.encodeBoard(), good['board']);
      final missing = Map<String, dynamic>.of(good)..remove('shakes');
      expect(SortController(p, resume: missing).game.shakes, 0);
      final tooMany = Map<String, dynamic>.of(good)..['tray'] = 'A' * 99;
      expect(SortController(p, resume: tooMany).game.tray, isEmpty);
    });

    test('wrong taps mark the game as needing a save', () {
      final p = buildCourses().first.levels.first.puzzles.first;
      final c = SortController(p);
      final before = c.saveVersion;
      final right = List.generate(p.cellCount, (i) => i).firstWhere((i) => !c.game.isWrong(i));
      c.tapCell(right);
      expect(c.saveVersion, isNot(before));
    });

    final puzzle = buildCourses().first.levels[1].puzzles.first;
    SortGame fresh() => SortGame.scrambled(
          width: puzzle.width,
          target: puzzle.cells,
          fraction: 0.25,
          capacity: 18,
          seed: puzzle.signature,
        );
    List<int> holesOf(SortGame g) => [
          for (var i = 0; i < g.current.length; i++)
            if (g.isHole(i)) i
        ];

    test('scrambling keeps every bead and is the same for the same seed', () {
      final a = fresh(), b = fresh();
      expect(a.encodeBoard(), b.encodeBoard());
      final counts = List<int>.filled(puzzle.colorCount, 0);
      for (final c in a.current) {
        counts[c]++;
      }
      expect(counts, puzzle.counts);
      expect(a.wrongCount, greaterThan(puzzle.cellCount * 0.15));
    });

    test('tapping picks beads up, and nothing moves until a destination is tapped', () {
      final g = fresh();
      final right = List.generate(g.current.length, (i) => i).firstWhere((i) => !g.isWrong(i));
      expect(g.tapCell(right).action, SortAction.wrong);
      expect(g.mistakes, 1);
      final wrong = List.generate(g.current.length, (i) => i).firstWhere(g.isWrong);
      final board = g.encodeBoard();
      expect(g.tapCell(wrong).action, SortAction.selected);
      expect(g.isSelected(wrong), isTrue);
      expect(g.encodeBoard(), board);
      // Tapping the picked-up bead again puts it down.
      expect(g.tapCell(wrong).action, SortAction.deselected);
      expect(g.selection, isNull);
      g.tapCell(wrong);
      final move = g.tapTray(null);
      expect(move.action, SortAction.toTray);
      expect(move.hops, isNotEmpty);
      expect(g.isHole(wrong), isTrue);
      expect(holesOf(g).length, g.tray.length);
    });

    test('beads only drop into spots that want their color', () {
      final g = fresh();
      final wrong = List.generate(g.current.length, (i) => i).firstWhere(g.isWrong);
      g
        ..tapCell(wrong)
        ..tapTray(null);
      final hole = holesOf(g).first;
      // Pick up a tray bead of another color: the hole refuses it.
      final other = g.tray.indexWhere((c) => c != g.target[hole]);
      if (other >= 0) {
        g.tapTray(other);
        expect(g.tapCell(hole).action, SortAction.wrong);
      }
      // A wrong canvas bead of the right color drops straight in.
      final source =
          List.generate(g.current.length, (i) => i).firstWhere((i) => g.isWrong(i) && g.current[i] == g.target[hole]);
      g
        ..selection = null
        ..tapCell(source);
      final move = g.tapCell(hole);
      expect(move.action, SortAction.placed);
      expect(g.current[hole], g.target[hole]);
      expect(holesOf(g).length, g.tray.length);
    });

    test('a full tray refuses more beads but the game never gets stuck', () {
      final g = SortGame.scrambled(
        width: puzzle.width,
        target: puzzle.cells,
        fraction: 0.5,
        capacity: 3,
        seed: puzzle.signature,
      );
      while (g.freeSlots > 0) {
        g
          ..tapCell(List.generate(g.current.length, (i) => i).firstWhere(g.isWrong))
          ..tapTray(null);
      }
      final wrong = List.generate(g.current.length, (i) => i).firstWhere(g.isWrong);
      g.tapCell(wrong);
      expect(g.tapTray(null).action, SortAction.trayFull);
      for (var next = g.bestStep(); next != null; next = g.bestStep()) {
        g.play(next);
      }
      expect(g.isComplete, isTrue);
      expect(g.tray, isEmpty);
      expect(g.shakes, 0);
    });

    test('a saved board decodes to the same board', () {
      final g = fresh();
      g
        ..tapCell(List.generate(puzzle.cellCount, (i) => i).firstWhere(g.isWrong))
        ..tapTray(null);
      expect(SortGame.decodeBoard(g.encodeBoard()), g.current);
      expect(SortGame.decodeTray(g.encodeTray()), g.tray);
    });

    test('good drops in a row build a combo; a mistake or a pause breaks it', () {
      var now = DateTime(2026, 10, 19, 12);
      final p = puzzle;
      final c = SortController(p, clock: () => now);
      void step() {
        final s = c.game.bestStep()!;
        if (s.trayColor != null) {
          c.tapTray(c.game.tray.indexOf(s.trayColor!));
        } else {
          c.tapCell(s.fromCell!);
        }
        s.toCell == null ? c.tapTray(null) : c.tapCell(s.toCell!);
        now = now.add(const Duration(seconds: 1));
      }

      while (c.comboNow() < 3) {
        step();
      }
      expect(c.bestCombo, greaterThanOrEqualTo(3));
      expect(c.comboBonus, greaterThan(0));
      now = now.add(Scoring.comboWindow * 2);
      expect(c.comboNow(), 0);
      final right = List.generate(p.cellCount, (i) => i).firstWhere((i) => !c.game.isWrong(i) && !c.game.isHole(i));
      while (c.comboNow() < 1) {
        step();
      }
      c.tapCell(right);
      expect(c.comboNow(), 0);
    });

    test('Time Attack runs on a timer and good drops buy back seconds', () {
      var now = DateTime(2026, 10, 19, 12);
      final c = SortController.timed(puzzle, seed: 7, clock: () => now);
      expect(c.timeLimit, greaterThan(15));
      c.resume();
      now = now.add(Duration(seconds: c.timeLimit! - 1));
      expect(c.timeUp, isFalse);
      final s = c.game.bestStep()!;
      c.tapCell(s.fromCell!);
      c.tapTray(null);
      final t = c.game.bestStep()!;
      t.trayColor != null ? c.tapTray(c.game.tray.indexOf(t.trayColor!)) : c.tapCell(t.fromCell!);
      c.tapCell(t.toCell!);
      expect(c.bonusSeconds, greaterThan(0));
      now = now.add(const Duration(seconds: 10));
      expect(c.timeUp, isTrue);
      expect(c.tapCell(0), SortTapResult.ignored);
    });
  });

  group('daily picture', () {
    test('the streak grows day by day and restarts after a gap', () {
      final d1 = DateTime(2026, 10, 19);
      expect(nextStreak(streak: 0, lastDone: null, today: d1), 1);
      expect(nextStreak(streak: 1, lastDone: '2026-10-19', today: d1), 1);
      expect(nextStreak(streak: 1, lastDone: '2026-10-18', today: d1), 2);
      expect(nextStreak(streak: 5, lastDone: '2026-10-16', today: d1), 1);
      expect(nextStreak(streak: 2, lastDone: '2026-10-31', today: DateTime(2026, 11, 1)), 3);
    });

    test('the daily picture stays the same all day and prefers unfinished ones', () async {
      final all = buildCourses().expand((c) => c.puzzles).toList();
      final store = ProgressStore.memory();
      final today = DateTime(2026, 10, 19);
      final first = store.dailyPuzzleId(today, all);
      await store.recordCompletion(first, score: 1, stars: 1, seconds: 1);
      expect(store.dailyPuzzleId(today, all), first);
      final tomorrow = store.dailyPuzzleId(DateTime(2026, 10, 20), all);
      expect(store.isCompleted(tomorrow), isFalse);
      await store.recordDaily(today);
      expect(store.streak(today), 1);
      expect(store.streak(DateTime(2026, 10, 22)), 0);
    });
  });

  group('achievements', () {
    test('badges unlock from progress and are celebrated once', () async {
      final courses = buildCourses();
      final store = ProgressStore.memory();
      expect(earnedAchievements(courses, store), isEmpty);
      final easy = courses.first.levels.first.puzzles.first;
      await store.recordCompletion(easy.id, score: 1, stars: 3, seconds: 1);
      await store.recordCompletion(PlayMode.sort.key(easy.id), score: 1, stars: 3, seconds: 1);
      final fresh = takeNewAchievements(courses, store).map((a) => a.id).toSet();
      expect(fresh, {'first', 'both', 'cleansort'});
      expect(takeNewAchievements(courses, store), isEmpty);
      for (final p in courses.first.puzzles) {
        await store.recordCompletion(p.id, score: 1, stars: 1, seconds: 1);
      }
      expect(earnedAchievements(courses, store), containsAll(['course', 'hard']));
    });
  });

  test('every picture has clearly distinct colors, Hard included', () {
    const minGap = {
      Difficulty.easy: 17.9,
      Difficulty.medium: 15.9,
      Difficulty.hard: 13.9,
      Difficulty.extreme: 11.9,
    };
    for (final c in buildCourses()) {
      for (final l in c.levels) {
        for (final p in l.puzzles) {
          for (var a = 0; a < p.colorCount; a++) {
            for (var b = a + 1; b < p.colorCount; b++) {
              expect(colorDistance(p.palette[a], p.palette[b]), greaterThan(minGap[l.difficulty]!),
                  reason: '${p.id} colors $a and $b');
            }
          }
        }
      }
    }
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

    test('home totals count Sort finishes too', () async {
      final course = buildCourses().first;
      final store = ProgressStore.memory();
      final easy = course.levels.first;
      for (var i = 0; i < unlockAfter; i++) {
        await store.recordCompletion(PlayMode.sort.key(easy.puzzles[i].id), score: 1, stars: 3, seconds: 1);
      }
      await store.recordCompletion(easy.puzzles[0].id, score: 1, stars: 2, seconds: 1);
      expect(store.completedIn(course.puzzles), unlockAfter);
      expect(store.completedIn(course.puzzles, PlayMode.paint), 1);
      expect(store.starsIn(course.puzzles), unlockAfter * 3 + 2);
      expect(store.starsIn(course.puzzles, PlayMode.sort), unlockAfter * 3);
      expect(ProgressStore.maxStarsIn(course.puzzles), course.puzzles.length * 6);
      expect(store.isLevelUnlocked(course, 1), isTrue);
      expect(store.isLevelUnlocked(course, 1, PlayMode.paint), isFalse);
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
