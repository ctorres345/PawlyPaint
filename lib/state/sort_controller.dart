import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../logic/scoring.dart';
import '../logic/sort_game.dart';
import '../logic/time_attack.dart';
import '../models/puzzle.dart';

/// A bead in the air: from a board cell or tray slot to a board cell or tray
/// slot (exactly one of each pair is set).
class Flight {
  Flight({this.fromCell, this.fromSlot, this.toCell, this.toSlot, required this.color, required this.start});

  final int? fromCell;
  final int? fromSlot;
  final int? toCell;
  final int? toSlot;
  final int color;
  final DateTime start;

  static const duration = Duration(milliseconds: 420);

  /// 0..1 progress at [now], or null before it starts.
  double? progress(DateTime now) {
    final t = now.difference(start).inMicroseconds / duration.inMicroseconds;
    if (t < 0) return null;
    return t > 1 ? 1 : t;
  }

  DateTime get end => start.add(duration);
}

enum SortTapResult { selected, deselected, moved, sorted, wrong, trayFull, ignored, complete }

/// The state before a move, so it can be undone.
typedef _Snapshot = ({Int16List board, List<int> tray, int placed, int comboBonus, int bestCombo, int bonusSeconds});

/// Live state of one picture in Sort mode (or a Time Attack run): the rules
/// plus timing, combos, animation bookkeeping and saving.
class SortController extends ChangeNotifier {
  SortController(Puzzle puzzle, {Map<String, dynamic>? resume, DateTime Function()? clock})
      : this._resumed(puzzle, _restore(puzzle, resume), resume, clock);

  SortController._resumed(this.puzzle, SortGame? saved, Map<String, dynamic>? resume, DateTime Function()? clock)
      : _clock = clock ?? DateTime.now,
        timeLimit = null,
        game = saved ?? _fresh(puzzle) {
    if (saved != null) {
      _baseSeconds = resume!['seconds'] as int? ?? 0;
      excusedMistakes = resume['relaxed'] == true;
      bestCombo = resume['bestCombo'] as int? ?? 0;
      comboBonus = resume['comboBonus'] as int? ?? 0;
    }
  }

  /// A Time Attack run on [puzzle], scrambled by [seed]; never saved.
  SortController.timed(Puzzle puzzle, {required int seed, DateTime Function()? clock})
      : this._timed(puzzle, _timedBoard(puzzle, seed), clock);

  SortController._timed(this.puzzle, this.game, DateTime Function()? clock)
      : _clock = clock ?? DateTime.now,
        timeLimit = TimeAttack.timeLimit(game);

  /// Scramble amount and tray size (full rows of 12) by canvas size: harder
  /// pictures mix more of their beads.
  static ({double mix, int capacity}) settingsFor(Puzzle p) => switch (p.width) {
        <= 16 => (mix: 0.3, capacity: 24),
        <= 24 => (mix: 0.45, capacity: 48),
        <= 32 => (mix: 0.6, capacity: 60),
        _ => (mix: 0.8, capacity: 60),
      };

  /// The difficulty a picture's canvas size belongs to.
  static Difficulty difficultyOf(Puzzle p) => switch (p.width) {
        <= 16 => Difficulty.easy,
        <= 24 => Difficulty.medium,
        <= 32 => Difficulty.hard,
        _ => Difficulty.extreme,
      };

  static SortGame _fresh(Puzzle p) {
    final s = settingsFor(p);
    return SortGame.scrambled(
      width: p.width,
      target: p.cells,
      fraction: s.mix,
      capacity: s.capacity,
      seed: p.signature,
    );
  }

  static SortGame _timedBoard(Puzzle p, int seed) {
    final s = TimeAttack.settingsFor(difficultyOf(p));
    return SortGame.scrambled(width: p.width, target: p.cells, fraction: s.mix, capacity: s.capacity, seed: seed);
  }

  static SortGame? _restore(Puzzle p, Map<String, dynamic>? j) {
    if (j == null || j['signature'] != p.signature) return null;
    try {
      final board = SortGame.decodeBoard(j['board'] as String);
      final tray = SortGame.decodeTray(j['tray'] as String);
      final capacity = settingsFor(p).capacity;
      final colors = p.colorCount;
      // Holes always equal tray beads; anything else is a broken save.
      if (board.length != p.cellCount ||
          tray.length > capacity ||
          board.where((c) => c < 0).length != tray.length ||
          board.any((c) => c >= colors) ||
          tray.any((c) => c < 0 || c >= colors)) {
        return null;
      }
      return SortGame(width: p.width, target: p.cells, current: board, tray: tray, capacity: capacity)
        ..shakes = j['shakes'] as int? ?? 0
        ..mistakes = j['mistakes'] as int? ?? 0
        ..placed = j['placed'] as int? ?? 0;
    } catch (_) {
      return null;
    }
  }

  final Puzzle puzzle;
  final SortGame game;
  final DateTime Function() _clock;

  /// Seconds on the clock for a Time Attack run; null in regular Sort.
  final int? timeLimit;
  bool get timed => timeLimit != null;

  /// Seconds won back by good drops during a Time Attack run.
  int bonusSeconds = 0;

  /// Seconds lost to hints and shakes during a Time Attack run.
  int penaltySeconds = 0;

  /// Moves that can be undone, oldest first.
  final List<_Snapshot> _history = [];
  static const _maxUndo = 30;

  final List<Flight> flights = [];

  /// Cells waiting for a flying bead; drawn empty until it lands.
  final Map<int, DateTime> arriving = {};

  /// Relaxed mode: taps on beads that were already right aren't counted.
  bool relaxed = false;

  /// Set once Relaxed mode lets a wrong tap go uncounted; the finish then
  /// counts as relaxed even if the setting was switched off later.
  bool excusedMistakes = false;

  /// Good drops in a row, each within [Scoring.comboWindow] of the last.
  int combo = 0;
  int bestCombo = 0;
  int comboBonus = 0;

  /// When the combo was last fed; it lapses [Scoring.comboWindow] later.
  DateTime? comboAt;

  SortStep? hintStep;
  DateTime? hintAt;
  int? mistakeCell;
  DateTime? mistakeAt;

  /// Bumped whenever the board changes, so the canvas re-records its cache.
  int boardVersion = 0;

  int _baseSeconds = 0;
  DateTime? _runningSince;

  int get correctCount => puzzle.cellCount - game.wrongCount;
  double get progress => correctCount / puzzle.cellCount;
  bool get isComplete => game.isComplete;
  bool get animating => flights.isNotEmpty;
  SortSelection? get selection => game.selection;

  int get seconds {
    final since = _runningSince;
    return since == null ? _baseSeconds : _baseSeconds + _clock().difference(since).inSeconds;
  }

  /// Seconds left in a Time Attack run (0 in regular Sort).
  int get timeLeft => timed ? (timeLimit! + bonusSeconds - penaltySeconds - seconds).clamp(0, 1 << 30) : 0;
  bool get timeUp => timed && !isComplete && timeLeft <= 0;

  /// The live combo, or 0 once its window has passed.
  int comboNow([DateTime? now]) {
    final at = comboAt;
    if (at == null || (now ?? _clock()).difference(at) > Scoring.comboWindow) return 0;
    return combo;
  }

  /// Changes whenever anything worth saving changes (board or counted mistakes).
  int get saveVersion => boardVersion + game.mistakes;

  int get stars => Scoring.sortStars(shakes: game.shakes, mistakes: game.mistakes);
  int get score => timed
      ? TimeAttack.score(
          placed: game.placed,
          comboBonus: comboBonus,
          mistakes: game.mistakes,
          secondsLeft: isComplete ? timeLeft : 0,
        )
      : Scoring.sortScore(placed: game.placed, shakes: game.shakes, mistakes: game.mistakes, comboBonus: comboBonus);

  void resume() {
    if (!isComplete) _runningSince ??= _clock();
  }

  void pause() {
    final since = _runningSince;
    if (since == null) return;
    _baseSeconds += _clock().difference(since).inSeconds;
    _runningSince = null;
  }

  bool get _locked => isComplete || timeUp;

  bool get canUndo => _history.isNotEmpty && !_locked;

  _Snapshot _snapshot() => (
        board: Int16List.fromList(game.current),
        tray: List<int>.of(game.tray),
        placed: game.placed,
        comboBonus: comboBonus,
        bestCombo: bestCombo,
        bonusSeconds: bonusSeconds,
      );

  /// Remembers [before] when [move] changed the board, so it can be undone.
  SortMove _remember(_Snapshot before, SortMove move) {
    if (move.action == SortAction.toTray || move.action == SortAction.placed) {
      _history.add(before);
      if (_history.length > _maxUndo) _history.removeAt(0);
    }
    return move;
  }

  SortTapResult tapCell(int cell) {
    if (_locked) return SortTapResult.ignored;
    // A cell whose bead is still flying in looks empty, so leave it alone.
    if (arriving.containsKey(cell)) return SortTapResult.ignored;
    final before = _snapshot();
    return _apply(_remember(before, game.tapCell(cell, countMistakes: !relaxed || timed)), cell);
  }

  SortTapResult tapTray(int? slot) {
    if (_locked) return SortTapResult.ignored;
    final before = _snapshot();
    return _apply(_remember(before, game.tapTray(slot)), null);
  }

  /// Takes back the last move. Points and seconds it earned go back too, and
  /// the combo ends; mistakes, shakes and help costs stay counted.
  bool undo() {
    if (!canUndo) return false;
    final s = _history.removeLast();
    game.current.setAll(0, s.board);
    game.tray
      ..clear()
      ..addAll(s.tray);
    game.placed = s.placed;
    game.selection = null;
    comboBonus = s.comboBonus;
    bestCombo = s.bestCombo;
    bonusSeconds = s.bonusSeconds;
    combo = 0;
    comboAt = null;
    hintStep = null;
    flights.clear();
    arriving.clear();
    boardVersion++;
    notifyListeners();
    return true;
  }

  SortTapResult _apply(SortMove move, int? cell) {
    final now = _clock();
    switch (move.action) {
      case SortAction.ignored:
        return SortTapResult.ignored;
      case SortAction.selected:
      case SortAction.deselected:
        resume();
        hintStep = null;
        notifyListeners();
        return move.action == SortAction.selected ? SortTapResult.selected : SortTapResult.deselected;
      case SortAction.trayFull:
        notifyListeners();
        return SortTapResult.trayFull;
      case SortAction.wrong:
        if (relaxed && !timed) {
          if (!excusedMistakes) {
            excusedMistakes = true;
            boardVersion++;
          }
        } else {
          combo = 0;
          comboAt = null;
        }
        mistakeCell = cell;
        mistakeAt = now;
        notifyListeners();
        return SortTapResult.wrong;
      case SortAction.toTray:
      case SortAction.placed:
        break;
    }
    resume();
    hintStep = null;
    _prune(now);
    final placing = move.action == SortAction.placed;
    for (var i = 0; i < move.hops.length; i++) {
      final h = move.hops[i];
      final start = now.add(Duration(milliseconds: i * 35));
      flights.add(Flight(
        fromCell: h.fromCell,
        fromSlot: h.fromSlot,
        toCell: h.toCell,
        toSlot: h.toSlot,
        color: h.color,
        start: start,
      ));
      if (h.toCell != null) arriving[h.toCell!] = start.add(Flight.duration);
    }
    if (placing) {
      combo = comboNow(now) + 1;
      comboAt = now;
      if (combo > bestCombo) bestCombo = combo;
      comboBonus += Scoring.comboBonus(combo, move.hops.length);
      if (timed) bonusSeconds += TimeAttack.secondsFor(combo);
    } else if (comboNow(now) > 0) {
      // Clearing room for the next drop keeps the combo alive.
      comboAt = now;
    }
    boardVersion++;
    if (isComplete) pause();
    notifyListeners();
    if (isComplete) return SortTapResult.complete;
    return placing ? SortTapResult.sorted : SortTapResult.moved;
  }

  /// Puts a few tray beads back on the board to make room.
  bool shake() {
    if (_locked) return false;
    final back = game.shake();
    if (back.isEmpty) return false;
    final now = _clock();
    _prune(now);
    for (var i = 0; i < back.length; i++) {
      final b = back[i];
      final start = now.add(Duration(milliseconds: i * 50));
      flights.add(Flight(fromSlot: i, toCell: b.toCell, color: b.color, start: start));
      arriving[b.toCell!] = start.add(Flight.duration);
    }
    combo = 0;
    comboAt = null;
    // Shaken beads land anywhere, so earlier moves can't be taken back.
    _history.clear();
    if (timed) penaltySeconds += TimeAttack.helpCost;
    boardVersion++;
    notifyListeners();
    return true;
  }

  /// Shows a good next move for a few seconds: what to pick up and where it goes.
  SortStep? hint() {
    if (_locked) return null;
    game.selection = null;
    hintStep = game.bestStep();
    hintAt = _clock();
    if (timed && hintStep != null) penaltySeconds += TimeAttack.helpCost;
    notifyListeners();
    return hintStep;
  }

  void _prune(DateTime now) {
    flights.removeWhere((f) => now.isAfter(f.end));
    arriving.removeWhere((_, t) => now.isAfter(t));
  }

  /// Drops finished flights; the screen calls this every frame.
  void tick() {
    final before = flights.length;
    _prune(_clock());
    if (flights.length != before) notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'signature': puzzle.signature,
        'board': game.encodeBoard(),
        'tray': game.encodeTray(),
        'shakes': game.shakes,
        'mistakes': game.mistakes,
        'placed': game.placed,
        'seconds': seconds,
        'relaxed': excusedMistakes,
        'bestCombo': bestCombo,
        'comboBonus': comboBonus,
      };
}
