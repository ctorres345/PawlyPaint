import 'package:flutter/foundation.dart';

import '../logic/scoring.dart';
import '../logic/sort_game.dart';
import '../models/puzzle.dart';

/// A bead in the air between a board cell and a tray slot.
class Flight {
  Flight({required this.cell, required this.slot, required this.color, required this.toTray, required this.start});

  final int cell;
  final int slot;
  final int color;
  final bool toTray;
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

enum SortTapResult { moved, sorted, wrong, trayFull, ignored, complete }

/// Live state of one picture in Sort mode: the rules plus timing, animation
/// bookkeeping and saving.
class SortController extends ChangeNotifier {
  SortController(this.puzzle, {Map<String, dynamic>? resume, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        game = _restore(puzzle, resume) ?? _fresh(puzzle) {
    if (resume != null && _restore(puzzle, resume) != null) {
      game
        ..shakes = resume['shakes'] as int
        ..mistakes = resume['mistakes'] as int
        ..placed = resume['placed'] as int;
      _baseSeconds = resume['seconds'] as int;
    }
  }

  /// Scramble amount and tray size by canvas size. The tray is roomy (full
  /// rows of 12) so a careful player never has to shake it.
  static (double, int) settingsFor(Puzzle p) => switch (p.width) {
        <= 16 => (0.2, 24),
        <= 24 => (0.25, 36),
        _ => (0.3, 48),
      };

  static SortGame _fresh(Puzzle p) {
    final (fraction, capacity) = settingsFor(p);
    return SortGame.scrambled(
      width: p.width,
      target: p.cells,
      fraction: fraction,
      capacity: capacity,
      seed: p.signature,
    );
  }

  static SortGame? _restore(Puzzle p, Map<String, dynamic>? j) {
    if (j == null || j['signature'] != p.signature) return null;
    try {
      final board = SortGame.decodeBoard(j['board'] as String);
      if (board.length != p.cellCount) return null;
      return SortGame(
        width: p.width,
        target: p.cells,
        current: board,
        tray: SortGame.decodeTray(j['tray'] as String),
        capacity: settingsFor(p).$2,
      );
    } catch (_) {
      return null;
    }
  }

  final Puzzle puzzle;
  final SortGame game;
  final DateTime Function() _clock;

  final List<Flight> flights = [];

  /// Cells waiting for a flying bead; drawn empty until it lands.
  final Map<int, DateTime> arriving = {};

  /// Relaxed mode: taps on beads that were already right aren't counted.
  bool relaxed = false;

  int? hintCell;
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

  int get seconds {
    final since = _runningSince;
    return since == null ? _baseSeconds : _baseSeconds + _clock().difference(since).inSeconds;
  }

  int get stars => Scoring.sortStars(shakes: game.shakes, mistakes: game.mistakes);
  int get score => Scoring.sortScore(placed: game.placed, shakes: game.shakes, mistakes: game.mistakes);

  void resume() {
    if (!isComplete) _runningSince ??= _clock();
  }

  void pause() {
    final since = _runningSince;
    if (since == null) return;
    _baseSeconds += _clock().difference(since).inSeconds;
    _runningSince = null;
  }

  SortTapResult tap(int cell) {
    if (isComplete) return SortTapResult.ignored;
    if (game.isHole(cell)) return SortTapResult.ignored;
    if (!game.isWrong(cell)) {
      if (!relaxed) game.tap(cell);
      mistakeCell = cell;
      mistakeAt = _clock();
      notifyListeners();
      return SortTapResult.wrong;
    }
    if (game.freeSlots == 0) {
      notifyListeners();
      return SortTapResult.trayFull;
    }
    resume();
    hintCell = null;
    final move = game.tap(cell);
    final now = _clock();
    _prune(now);
    for (var i = 0; i < move.removed.length; i++) {
      final r = move.removed[i];
      flights.add(Flight(
          cell: r.cell,
          slot: r.traySlot,
          color: r.color,
          toTray: true,
          start: now.add(Duration(milliseconds: i * 35))));
    }
    final fillStart = now.add(Duration(milliseconds: 220 + move.removed.length * 35));
    for (var i = 0; i < move.fills.length; i++) {
      final f = move.fills[i];
      final start = fillStart.add(Duration(milliseconds: i * 45));
      flights.add(Flight(cell: f.cell, slot: f.traySlot, color: f.color, toTray: false, start: start));
      arriving[f.cell] = start.add(Flight.duration);
    }
    boardVersion++;
    if (isComplete) pause();
    notifyListeners();
    if (isComplete) return SortTapResult.complete;
    return move.fills.isNotEmpty ? SortTapResult.sorted : SortTapResult.moved;
  }

  /// Puts a few tray beads back on the board to make room.
  bool shake() {
    final back = game.shake();
    if (back.isEmpty) return false;
    final now = _clock();
    _prune(now);
    for (var i = 0; i < back.length; i++) {
      final b = back[i];
      final start = now.add(Duration(milliseconds: i * 50));
      flights.add(Flight(cell: b.cell, slot: i, color: b.color, toTray: false, start: start));
      arriving[b.cell] = start.add(Flight.duration);
    }
    boardVersion++;
    notifyListeners();
    return true;
  }

  /// Highlights a good next move for a couple of seconds.
  int? hint() {
    hintCell = game.bestMove();
    hintAt = _clock();
    notifyListeners();
    return hintCell;
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
      };
}
