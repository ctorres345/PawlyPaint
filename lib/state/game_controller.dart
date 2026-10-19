import 'package:flutter/foundation.dart';

import '../logic/scoring.dart';
import '../models/puzzle.dart';
import 'progress_store.dart';

enum PlaceResult { placed, colorComplete, puzzleComplete, wrong, ignored }

/// Live state of one picture being filled in.
class GameController extends ChangeNotifier {
  GameController(this.puzzle, {SavedGame? resume, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        placed = Uint8List(puzzle.cellCount),
        remaining = List<int>.of(puzzle.counts) {
    if (resume != null && resume.placed.length == puzzle.cellCount) {
      for (var i = 0; i < puzzle.cellCount; i++) {
        if (resume.placed.codeUnitAt(i) == 0x31) {
          placed[i] = 1;
          remaining[puzzle.cells[i]]--;
          _placedCount++;
        }
      }
      score = resume.score;
      combo = resume.combo;
      mistakes = resume.mistakes;
      _baseSeconds = resume.seconds;
    }
    selected = firstIncompleteColor() ?? 0;
  }

  final Puzzle puzzle;
  final DateTime Function() _clock;

  /// 1 where a drill has been placed.
  final Uint8List placed;

  /// Drills still missing for each color.
  final List<int> remaining;

  int selected = 0;
  int score = 0;
  int combo = 0;
  int mistakes = 0;
  int _placedCount = 0;

  int _baseSeconds = 0;
  DateTime? _runningSince;

  /// When each recent drill landed, for the pop animation.
  final Map<int, DateTime> recentPlacements = {};

  /// The last wrong tap, for a short red flash on the canvas.
  int? lastMistakeCell;
  DateTime? lastMistakeAt;

  int get placedCount => _placedCount;
  bool get isComplete => _placedCount == puzzle.cellCount;
  double get progress => _placedCount / puzzle.cellCount;
  bool isColorDone(int color) => remaining[color] == 0;

  int get seconds {
    final since = _runningSince;
    if (since == null) return _baseSeconds;
    return _baseSeconds + _clock().difference(since).inSeconds;
  }

  void resume() {
    if (isComplete) return;
    _runningSince ??= _clock();
  }

  void pause() {
    final since = _runningSince;
    if (since == null) return;
    _baseSeconds += _clock().difference(since).inSeconds;
    _runningSince = null;
  }

  void select(int color) {
    if (color == selected) return;
    selected = color;
    notifyListeners();
  }

  /// Places the selected color at [cell]. A drag only fills matching cells,
  /// while a tap on the wrong cell counts as a mistake.
  PlaceResult place(int cell, {bool dragging = false}) {
    if (isComplete || placed[cell] == 1) return PlaceResult.ignored;
    final color = puzzle.cells[cell];
    if (color != selected) {
      if (dragging) return PlaceResult.ignored;
      mistakes++;
      combo = 0;
      lastMistakeCell = cell;
      lastMistakeAt = _clock();
      score = Scoring.afterMistake(score);
      notifyListeners();
      return PlaceResult.wrong;
    }
    resume();
    placed[cell] = 1;
    remaining[color]--;
    _placedCount++;
    combo++;
    score += Scoring.pointsForDrill(combo);
    final now = _clock();
    recentPlacements[cell] = now;
    recentPlacements.removeWhere((_, t) => now.difference(t).inMilliseconds > 400);

    var result = PlaceResult.placed;
    if (isComplete) {
      pause();
      score += Scoring.timeBonus(seconds, puzzle.parSeconds);
      result = PlaceResult.puzzleComplete;
    } else if (remaining[color] == 0) {
      selected = firstIncompleteColor() ?? selected;
      result = PlaceResult.colorComplete;
    }
    notifyListeners();
    return result;
  }

  int get stars => Scoring.stars(
        mistakes: mistakes,
        cells: puzzle.cellCount,
        seconds: seconds,
        parSeconds: puzzle.parSeconds,
      );

  /// The next color that still needs drills, preferring the lowest number.
  int? firstIncompleteColor() {
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i] > 0) return i;
    }
    return null;
  }

  SavedGame snapshot() => SavedGame(
        placed: String.fromCharCodes(placed.map((p) => p == 1 ? 0x31 : 0x30)),
        score: score,
        combo: combo,
        mistakes: mistakes,
        seconds: seconds,
      );
}
