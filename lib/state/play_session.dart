/// What a star meter or a multiplayer scoreboard reads from either game.
abstract interface class PlayStats {
  /// Counted mistakes so far.
  int get mistakes;
  int get stars;
  int get seconds;
  bool get isComplete;
}

/// What Paint and Sort share while a picture is being played: the clock that
/// only runs during play, and the Relaxed mode flags.
///
/// Each controller keeps its own rules for when play may start or whether a
/// tap counts; this only holds the state.
class PlaySession {
  PlaySession({DateTime Function()? clock, int baseSeconds = 0, this.excusedMistakes = false})
      : _clock = clock ?? DateTime.now,
        _baseSeconds = baseSeconds;

  final DateTime Function() _clock;
  int _baseSeconds;
  DateTime? _runningSince;

  /// Relaxed mode: wrong taps still show a cross but aren't counted.
  bool relaxed = false;

  /// Set once Relaxed mode lets a wrong tap go uncounted; the finish then
  /// counts as relaxed even if the setting was switched off later.
  bool excusedMistakes;

  bool get running => _runningSince != null;

  /// Whole seconds played so far.
  int get seconds {
    final since = _runningSince;
    return since == null ? _baseSeconds : _baseSeconds + _clock().difference(since).inSeconds;
  }

  /// Starts the clock; does nothing if it already runs.
  void start() => _runningSince ??= _clock();

  void pause() {
    final since = _runningSince;
    if (since == null) return;
    _baseSeconds += _clock().difference(since).inSeconds;
    _runningSince = null;
  }
}
