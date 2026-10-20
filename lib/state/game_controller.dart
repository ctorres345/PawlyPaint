import 'dart:math' as math;

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
    if (resume != null && resume.signature == puzzle.signature && resume.placed.length == puzzle.cellCount) {
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
      excusedMistakes = resume.excusedMistakes;
      // Older saves have no order; their drills replay first, color by color.
      final seen = <int>{};
      for (final c in resume.order) {
        if (c >= 0 && c < puzzle.cellCount && placed[c] == 1 && seen.add(c)) order.add(c);
      }
      if (order.length < _placedCount) {
        order.insertAll(0, [
          for (final cells in puzzle.cellsByColor)
            for (final c in cells)
              if (placed[c] == 1 && !seen.contains(c)) c,
        ]);
      }
      final b = resume.brushColor;
      if (b != null && b < remaining.length && remaining[b] > 0) brushColor = b;
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

  /// Relaxed mode: wrong taps still show a cross but aren't counted.
  bool relaxed = false;

  /// Set once Relaxed mode lets a wrong tap go uncounted; the finish then
  /// counts as relaxed even if the setting was switched off later.
  bool excusedMistakes = false;
  int score = 0;
  int combo = 0;
  int mistakes = 0;
  int _placedCount = 0;

  int _baseSeconds = 0;
  DateTime? _runningSince;

  /// Cells in the order their drills went down, for the finished replay.
  final List<int> order = [];

  /// When each recent drill landed, for the pop animation.
  final Map<int, DateTime> recentPlacements = {};

  /// The last wrong tap, for a short red flash on the canvas.
  int? lastMistakeCell;
  DateTime? lastMistakeAt;

  /// Bumped whenever the board's look changes (a drill placed or a new
  /// color selected), so the canvas knows when to redraw its cached layer.
  int boardVersion = 0;

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
    boardVersion++;
    notifyListeners();
  }

  /// Places the selected color at [cell]. A drag only fills matching cells,
  /// while a tap on the wrong cell counts as a mistake. With the wide brush
  /// the matching cells around [cell] fill too.
  PlaceResult place(int cell, {bool dragging = false}) {
    if (isComplete) return PlaceResult.ignored;
    final brush = brushActive ? _brushCells(cell) : const <int>[];
    if (brush.isNotEmpty) {
      final now = _clock();
      resume();
      var result = PlaceResult.placed;
      for (final c in brush) {
        combo++;
        score += Scoring.pointsForDrill(combo);
        if (_put(c, now)) result = PlaceResult.colorComplete;
      }
      return _settle(result);
    }
    if (placed[cell] == 1) return PlaceResult.ignored;
    final color = puzzle.cells[cell];
    if (color != selected) {
      if (dragging) return PlaceResult.ignored;
      lastMistakeCell = cell;
      lastMistakeAt = _clock();
      if (!relaxed) {
        mistakes++;
        combo = 0;
        score = Scoring.afterMistake(score);
      } else if (!excusedMistakes) {
        excusedMistakes = true;
        boardVersion++;
      }
      notifyListeners();
      return PlaceResult.wrong;
    }
    resume();
    combo++;
    score += Scoring.pointsForDrill(combo);
    final done = _put(cell, _clock());
    return _settle(done ? PlaceResult.colorComplete : PlaceResult.placed);
  }

  /// Fills [cells] with their own colors, as the bomb and magic wand do.
  /// Drills pop in a wave outward from [origin]. Booster drills earn the
  /// plain drill points and leave the combo alone.
  PlaceResult fill(Iterable<int> cells, {required int origin}) {
    if (isComplete) return PlaceResult.ignored;
    final now = _clock();
    final ox = origin % puzzle.width, oy = origin ~/ puzzle.width;
    var any = false, colorDone = false;
    for (final c in cells) {
      if (placed[c] == 1) continue;
      any = true;
      final dx = c % puzzle.width - ox, dy = c ~/ puzzle.width - oy;
      final delay = (math.sqrt(dx * dx + dy * dy) * 45).round().clamp(0, 700);
      score += Scoring.drillPoints;
      if (_put(c, now.add(Duration(milliseconds: delay)))) colorDone = true;
    }
    if (!any) return PlaceResult.ignored;
    resume();
    lastBlastCell = origin;
    lastBlastAt = now;
    return _settle(colorDone ? PlaceResult.colorComplete : PlaceResult.placed);
  }

  /// Places one drill and returns whether it finished its color.
  bool _put(int cell, DateTime at) {
    final color = puzzle.cells[cell];
    placed[cell] = 1;
    remaining[color]--;
    _placedCount++;
    boardVersion++;
    order.add(cell);
    recentPlacements[cell] = at;
    if (remaining[color] > 0) return false;
    lastColorDone = color;
    lastColorDoneAt = at;
    if (brushColor == color) brushColor = null;
    return true;
  }

  /// Ends a move: finishes the picture or moves on from a finished color.
  PlaceResult _settle(PlaceResult result) {
    final now = _clock();
    recentPlacements.removeWhere((_, t) => now.difference(t).inMilliseconds > 400);
    if (isComplete) {
      pause();
      score += Scoring.timeBonus(seconds, puzzle.parSeconds, puzzle.cellCount);
      result = PlaceResult.puzzleComplete;
    } else if (isColorDone(selected)) {
      selected = firstIncompleteColor() ?? selected;
      boardVersion++;
    }
    notifyListeners();
    return result;
  }

  // ---- Boosters -----------------------------------------------------------

  /// The color the wide brush was used on, while it is still unfinished.
  int? brushColor;

  /// Whether drills go down 3 wide right now (only on the brush's own color).
  bool get brushActive => brushColor != null && brushColor == selected;

  void startBrush() {
    if (isColorDone(selected)) return;
    brushColor = selected;
    notifyListeners();
  }

  /// Unplaced cells of the selected color in the 3×3 around [cell].
  List<int> _brushCells(int cell) {
    final w = puzzle.width, x0 = cell % w, y0 = cell ~/ w;
    return [
      for (var y = y0 - 1; y <= y0 + 1; y++)
        for (var x = x0 - 1; x <= x0 + 1; x++)
          if (x >= 0 && y >= 0 && x < w && y < puzzle.height)
            if (placed[y * w + x] == 0 && puzzle.cells[y * w + x] == selected) y * w + x,
    ];
  }

  /// The last bomb or wand, for the shock ring on the canvas.
  int? lastBlastCell;
  DateTime? lastBlastAt;

  /// The color finished most recently, for a sparkle over its drills.
  int? lastColorDone;
  DateTime? lastColorDoneAt;

  /// Changes whenever anything worth saving changes (drills or counted mistakes).
  int get saveVersion => boardVersion + mistakes + (brushColor == null ? 0 : 1 << 20);

  int get stars => Scoring.stars(mistakes: mistakes, cells: puzzle.cellCount);

  /// The next color that still needs drills, preferring the lowest number.
  int? firstIncompleteColor() {
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i] > 0) return i;
    }
    return null;
  }

  SavedGame snapshot() => SavedGame(
        signature: puzzle.signature,
        placed: String.fromCharCodes(placed.map((p) => p == 1 ? 0x31 : 0x30)),
        score: score,
        combo: combo,
        mistakes: mistakes,
        seconds: seconds,
        excusedMistakes: excusedMistakes,
        brushColor: brushColor,
        order: List.of(order),
      );
}
