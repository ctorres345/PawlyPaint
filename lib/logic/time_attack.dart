import 'dart:typed_data';

import '../models/puzzle.dart';
import 'scoring.dart';
import 'sort_game.dart';

/// Rules for Time Attack: Sort against the clock on a random picture of one
/// difficulty. Good moves buy back a little time, combos buy more.
class TimeAttack {
  /// Scramble amount and tray size. Lighter than regular Sort, since the
  /// clock is the challenge here.
  static ({double mix, int capacity}) settingsFor(Difficulty d) => switch (d) {
        Difficulty.easy => (mix: 0.3, capacity: 24),
        Difficulty.medium => (mix: 0.3, capacity: 36),
        Difficulty.hard => (mix: 0.3, capacity: 48),
        Difficulty.extreme => (mix: 0.3, capacity: 60),
      };

  /// Seconds lost for a hint or a shake.
  static const helpCost = 5;

  /// Seconds a successful drop adds back: 1, or 2 once the combo reaches 5.
  static int secondsFor(int combo) => combo >= 5 ? 2 : 1;

  /// Seconds on the clock at the start: two and a half for each move the
  /// hint player needs on this board, plus a little breathing room.
  static int timeLimit(SortGame g) {
    final copy = SortGame(
      width: g.width,
      target: g.target,
      current: Int16List.fromList(g.current),
      tray: g.tray,
      capacity: g.capacity,
    );
    var steps = 0;
    for (var next = copy.bestStep(); next != null; next = copy.bestStep()) {
      copy.play(next);
      steps++;
    }
    final raw = 20 + steps * 5 ~/ 2;
    return (raw + 4) ~/ 5 * 5;
  }

  /// Final score for a won run: Sort points plus 25 for each second left.
  static int score({required int placed, required int comboBonus, required int mistakes, required int secondsLeft}) =>
      Scoring.sortScore(placed: placed, shakes: 0, mistakes: mistakes, comboBonus: comboBonus) + secondsLeft * 25;
}
