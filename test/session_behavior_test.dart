import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawlypaint/data/courses.dart';
import 'package:pawlypaint/logic/scoring.dart';
import 'package:pawlypaint/models/puzzle.dart';
import 'package:pawlypaint/state/game_controller.dart';
import 'package:pawlypaint/state/play_session.dart';
import 'package:pawlypaint/state/progress_store.dart';
import 'package:pawlypaint/state/sort_controller.dart';

/// Pins the timer, relaxed flags and save keys of both game controllers, so
/// moving them into a shared play session (PAP-24) cannot change behavior.
Puzzle _tiny() => Puzzle(
      id: 't',
      title: 'Tiny',
      width: 2,
      height: 2,
      cells: Uint8List.fromList([0, 1, 1, 1]),
      palette: const [Color(0xFF000000), Color(0xFFFFFFFF)],
    );

void main() {
  test('both games can be read as PlayStats', () {
    final sort = SortController(buildCourses().first.levels[1].puzzles.first);
    final paint = GameController(_tiny())..place(1);
    final stats = <PlayStats>[paint, sort];
    expect(stats[0].mistakes, 1);
    expect(stats[0].stars, paint.stars);
    expect(stats[1].mistakes, sort.game.mistakes);
    expect(stats[1].stars, 3);
    expect(stats.map((s) => s.isComplete), [false, false]);
    expect(stats.map((s) => s.seconds), [0, 0]);
  });

  group('Paint session', () {
    test('seconds count only while running, across pause and resume', () {
      var now = DateTime(2026, 11, 9, 12);
      final g = GameController(_tiny(), clock: () => now);
      expect(g.seconds, 0);
      now = now.add(const Duration(seconds: 5));
      expect(g.seconds, 0, reason: 'not started until the first move or resume');
      g.resume();
      now = now.add(const Duration(seconds: 7));
      expect(g.seconds, 7);
      g.pause();
      now = now.add(const Duration(seconds: 30));
      expect(g.seconds, 7);
      g.resume();
      g.resume();
      now = now.add(const Duration(seconds: 3));
      expect(g.seconds, 10, reason: 'a second resume does not restart the clock');
    });

    test('the first drill starts the clock and finishing stops it', () {
      var now = DateTime(2026, 11, 9, 12);
      final g = GameController(_tiny(), clock: () => now);
      g.place(0);
      now = now.add(const Duration(seconds: 4));
      expect(g.seconds, 4);
      g
        ..place(1)
        ..place(2);
      now = now.add(const Duration(seconds: 2));
      expect(g.place(3), PlaceResult.puzzleComplete);
      final done = g.seconds;
      now = now.add(const Duration(seconds: 60));
      expect(g.seconds, done);
      g.resume();
      now = now.add(const Duration(seconds: 60));
      expect(g.seconds, done, reason: 'a finished picture never restarts');
    });

    test('the time bonus uses the seconds at the moment of finishing', () {
      var now = DateTime(2026, 11, 9, 12);
      final g = GameController(_tiny(), clock: () => now);
      g
        ..place(0)
        ..place(1)
        ..place(2);
      now = now.add(const Duration(seconds: 9));
      final before = g.score;
      g.place(3);
      final drill = Scoring.pointsForDrill(g.combo);
      expect(g.score, before + drill + Scoring.timeBonus(9, _tiny().parSeconds, _tiny().cellCount));
    });

    test('a snapshot keeps live seconds and the relaxed excuse', () {
      var now = DateTime(2026, 11, 9, 12);
      final g = GameController(_tiny(), clock: () => now)
        ..relaxed = true
        ..resume();
      now = now.add(const Duration(seconds: 6));
      expect(g.place(1), PlaceResult.wrong, reason: 'color 0 is selected, cell 1 is color 1');
      expect(g.mistakes, 0, reason: 'relaxed taps are not counted');
      expect(g.excusedMistakes, isTrue);
      final saved = SavedGame.fromJson(g.snapshot().toJson());
      expect(saved.seconds, 6);
      expect(saved.excusedMistakes, isTrue);
      now = now.add(const Duration(seconds: 100));
      final again = GameController(_tiny(), resume: saved, clock: () => now);
      expect(again.seconds, 6, reason: 'a resumed game is paused until the next move');
      expect(again.excusedMistakes, isTrue);
      again.resume();
      now = now.add(const Duration(seconds: 2));
      expect(again.seconds, 8);
    });
  });

  group('Sort session', () {
    final puzzle = buildCourses().first.levels[1].puzzles.first;

    void play(SortController c) {
      final s = c.game.bestStep()!;
      if (s.trayColor != null) {
        c.tapTray(c.game.tray.indexOf(s.trayColor!));
      } else {
        c.tapCell(s.fromCell!);
      }
      s.toCell == null ? c.tapTray(null) : c.tapCell(s.toCell!);
    }

    test('seconds count only while running, across pause and resume', () {
      var now = DateTime(2026, 11, 9, 12);
      final c = SortController(puzzle, clock: () => now);
      expect(c.seconds, 0);
      c.resume();
      now = now.add(const Duration(seconds: 7));
      expect(c.seconds, 7);
      c.pause();
      now = now.add(const Duration(seconds: 30));
      expect(c.seconds, 7);
      c.resume();
      c.resume();
      now = now.add(const Duration(seconds: 3));
      expect(c.seconds, 10);
    });

    test('a save keeps seconds, the relaxed excuse and combo totals under the same keys', () {
      var now = DateTime(2026, 11, 9, 12);
      final c = SortController(puzzle, clock: () => now)..resume();
      for (var i = 0; i < 3; i++) {
        play(c);
        now = now.add(const Duration(seconds: 1));
      }
      c.excusedMistakes = true;
      now = now.add(const Duration(seconds: 4));
      final json = c.toJson();
      expect(json['seconds'], c.seconds);
      expect(json['relaxed'], isTrue, reason: 'the save key stays "relaxed"');
      expect(json['bestCombo'], c.bestCombo);
      expect(json['comboBonus'], c.comboBonus);

      now = now.add(const Duration(seconds: 100));
      final again = SortController(puzzle, resume: json, clock: () => now);
      expect(again.seconds, json['seconds'], reason: 'paused until the next move');
      expect(again.excusedMistakes, isTrue);
      expect(again.bestCombo, c.bestCombo);
      expect(again.comboBonus, c.comboBonus);
      again.resume();
      now = now.add(const Duration(seconds: 2));
      expect(again.seconds, (json['seconds'] as int) + 2);
    });

    test('a relaxed tap in a timed run still counts as a mistake', () {
      final now = DateTime(2026, 11, 9, 12);
      final c = SortController.timed(puzzle, seed: 7, clock: () => now)..relaxed = true;
      final wrongTargets = [
        for (var i = 0; i < puzzle.cellCount; i++)
          if (!c.game.isWrong(i) && !c.game.isHole(i)) i
      ];
      expect(wrongTargets, isNotEmpty);
      c.tapCell(wrongTargets.first);
      expect(c.game.mistakes, greaterThan(0));
      expect(c.excusedMistakes, isFalse);
    });

    test('a relaxed tap on a right bead in regular Sort is excused, not counted', () {
      final now = DateTime(2026, 11, 9, 12);
      final c = SortController(puzzle, clock: () => now)..relaxed = true;
      final right =
          List.generate(puzzle.cellCount, (i) => i).firstWhere((i) => !c.game.isWrong(i) && !c.game.isHole(i));
      final before = c.saveVersion;
      c.tapCell(right);
      expect(c.game.mistakes, 0);
      expect(c.excusedMistakes, isTrue);
      expect(c.saveVersion, isNot(before), reason: 'the first excuse marks the game as needing a save');
    });
  });
}
