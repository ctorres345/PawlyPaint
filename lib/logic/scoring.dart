/// Pure scoring rules, kept free of Flutter so they are easy to test.
///
/// The game is meant to be calm rather than a race, so stars only depend on
/// accuracy and the time bonus is a small extra.
class Scoring {
  static const drillPoints = 10;
  static const mistakePenalty = 15;
  static const maxComboBonus = 5;

  /// Points for one correct drill when the combo (including this drill) is [combo].
  static int pointsForDrill(int combo) => drillPoints + (combo ~/ 10).clamp(0, maxComboBonus);

  /// Score after a wrong tap; never drops below zero.
  static int afterMistake(int score) => score > mistakePenalty ? score - mistakePenalty : 0;

  /// Bonus for finishing under par, capped at a fifth of the base drill points.
  static int timeBonus(int seconds, int parSeconds, int cells) {
    final cap = cells * drillPoints ~/ 5;
    return (parSeconds - seconds).clamp(0, cap);
  }

  /// 3 stars for at most 1% mistakes, 2 for at most 5%, otherwise 1.
  static int stars({required int mistakes, required int cells}) {
    final perfectLimit = (cells * 0.01).ceil().clamp(1, cells);
    final goodLimit = (cells * 0.05).ceil().clamp(3, cells);
    if (mistakes <= perfectLimit) return 3;
    if (mistakes <= goodLimit) return 2;
    return 1;
  }

  /// Sort mode: 3 stars with no shakes of the tray and few wrong taps, 2 with
  /// a couple of shakes, otherwise 1. A move always exists, so careful play
  /// never needs a shake.
  static int sortStars({required int shakes, required int mistakes}) {
    if (shakes == 0 && mistakes <= 3) return 3;
    if (shakes <= 2) return 2;
    return 1;
  }

  /// Sort mode score: points for each bead sorted into place plus the combo
  /// bonus, minus a little for shakes and wrong taps.
  static int sortScore({required int placed, required int shakes, required int mistakes, int comboBonus = 0}) {
    final s = placed * drillPoints + comboBonus - shakes * 20 - mistakes * 5;
    return s < 0 ? 0 : s;
  }

  /// Seconds after a good move within which the next one keeps the combo going.
  static const comboWindow = Duration(seconds: 6);

  /// Highest combo step that still raises the bonus.
  static const maxCombo = 10;

  /// Extra points for [beads] dropped into place at combo [combo] (1 = no
  /// combo yet): 2 points a bead for each step past the first, up to [maxCombo].
  static int comboBonus(int combo, int beads) => beads * 2 * (combo.clamp(1, maxCombo) - 1);
}
