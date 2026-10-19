/// Pure scoring rules, kept free of Flutter so they are easy to test.
class Scoring {
  static const drillPoints = 10;
  static const mistakePenalty = 15;
  static const maxComboBonus = 5;

  /// Points for one correct drill when the combo (including this drill) is [combo].
  static int pointsForDrill(int combo) => drillPoints + (combo ~/ 10).clamp(0, maxComboBonus);

  /// Score after a wrong tap; never drops below zero.
  static int afterMistake(int score) => score > mistakePenalty ? score - mistakePenalty : 0;

  /// Bonus added at the end for beating the par time.
  static int timeBonus(int seconds, int parSeconds) => (parSeconds - seconds).clamp(0, parSeconds);

  /// 1 to 3 stars, from accuracy and time.
  static int stars({required int mistakes, required int cells, required int seconds, required int parSeconds}) {
    final perfectLimit = (cells * 0.01).ceil().clamp(1, cells);
    final goodLimit = (cells * 0.05).ceil().clamp(3, cells);
    if (mistakes <= perfectLimit && seconds <= parSeconds) return 3;
    if (mistakes <= goodLimit) return 2;
    return 1;
  }
}
