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

  /// Sort mode: 3 stars within [freeShakes] shakes of the tray (and few wrong
  /// taps), 2 with a couple more, otherwise 1. Big, heavily mixed pictures
  /// allow a few shakes, since even careful play needs them there.
  static int sortStars({required int shakes, required int mistakes, int freeShakes = 0}) {
    if (shakes <= freeShakes && mistakes <= 3) return 3;
    if (shakes <= freeShakes + 2) return 2;
    return 1;
  }

  /// Sort mode score: points for each bead sorted into place, minus a little
  /// for shakes and wrong taps.
  static int sortScore({required int placed, required int shakes, required int mistakes}) {
    final s = placed * drillPoints - shakes * 20 - mistakes * 5;
    return s < 0 ? 0 : s;
  }
}
