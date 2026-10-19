import 'dart:math' as math;
import 'dart:typed_data';

/// One bead flying from a tray slot into a cell.
typedef Fill = ({int cell, int traySlot, int color});

/// What a tap did, so the screen can animate it.
class SortMove {
  SortMove(this.removed, this.fills);

  /// Cells whose wrong bead went down to the tray, in order, with the tray
  /// slot each one landed in.
  final List<({int cell, int traySlot, int color})> removed;

  /// Beads that flew from the tray into a hole that wanted their color.
  final List<Fill> fills;

  bool get isEmpty => removed.isEmpty;
}

/// Pure rules for Sort mode, Jewel Coloring style.
///
/// The picture starts full, but some beads are swapped around so they sit in
/// the wrong place. Tapping a wrong bead sends it (and the wrong beads of the
/// same color touching it) down to the tray; any hole whose correct color is
/// waiting in the tray is filled straight away. Beads are never created or
/// lost, so holes on the board always equal beads in the tray.
class SortGame {
  SortGame({
    required this.width,
    required this.target,
    required this.current,
    required List<int> tray,
    required this.capacity,
  }) : tray = List<int>.of(tray);

  /// A scrambled board for a picture: [fraction] of its cells have their
  /// beads shuffled among themselves. The same [seed] gives the same board.
  factory SortGame.scrambled({
    required int width,
    required Uint8List target,
    required double fraction,
    required int capacity,
    required int seed,
  }) {
    final rng = math.Random(seed);
    final cells = List<int>.generate(target.length, (i) => i)..shuffle(rng);
    final chosen = cells.take((target.length * fraction).round()).toList();
    final colors = [for (final c in chosen) target[c]]..shuffle(rng);
    // Nudge beads that landed back on their own color so most really move.
    for (var i = 0; i < chosen.length; i++) {
      if (colors[i] != target[chosen[i]]) continue;
      for (var j = 0; j < chosen.length; j++) {
        if (colors[j] != target[chosen[i]] && colors[i] != target[chosen[j]]) {
          final t = colors[i];
          colors[i] = colors[j];
          colors[j] = t;
          break;
        }
      }
    }
    final current = Int16List.fromList(target);
    for (var i = 0; i < chosen.length; i++) {
      current[chosen[i]] = colors[i];
    }
    return SortGame(width: width, target: target, current: current, tray: const [], capacity: capacity);
  }

  final int width;
  final Uint8List target;

  /// Bead color in each cell, or -1 for an empty hole.
  final Int16List current;
  final List<int> tray;
  final int capacity;

  int shakes = 0;
  int mistakes = 0;
  int placed = 0;

  int get height => target.length ~/ width;
  int get freeSlots => capacity - tray.length;
  bool isWrong(int cell) => current[cell] >= 0 && current[cell] != target[cell];
  bool isHole(int cell) => current[cell] < 0;
  int get wrongCount {
    var n = 0;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != target[i]) n++;
    }
    return n;
  }

  bool get isComplete => wrongCount == 0;

  /// True when the tray is full and no hole wants anything in it.
  bool get isStuck => freeSlots <= 0 && !isComplete;

  /// Taps [cell]: sends the patch of touching wrong beads of the same color
  /// down to the tray, as far as there is room, filling holes as it goes.
  SortMove tap(int cell) {
    if (!isWrong(cell)) {
      if (current[cell] >= 0) mistakes++;
      return SortMove(const [], const []);
    }
    final color = current[cell];
    final removed = <({int cell, int traySlot, int color})>[];
    final fills = <Fill>[];
    final queue = <int>[cell];
    final seen = <int>{cell};
    while (queue.isNotEmpty && freeSlots > 0) {
      final c = queue.removeAt(0);
      current[c] = -1;
      tray.add(color);
      removed.add((cell: c, traySlot: tray.length - 1, color: color));
      fills.addAll(_fillHoles());
      final x = c % width, y = c ~/ width;
      for (final (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]) {
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        final n = ny * width + nx;
        if (seen.add(n) && current[n] == color && isWrong(n)) queue.add(n);
      }
    }
    return SortMove(removed, fills);
  }

  /// Fills every hole whose color is waiting in the tray, oldest bead first.
  List<Fill> _fillHoles() {
    final fills = <Fill>[];
    for (var i = 0; i < current.length; i++) {
      if (current[i] >= 0) continue;
      final slot = tray.indexOf(target[i]);
      if (slot < 0) continue;
      tray.removeAt(slot);
      current[i] = target[i];
      placed++;
      fills.add((cell: i, traySlot: slot, color: target[i]));
    }
    return fills;
  }

  /// A good cell to tap next, for the hint button: first a wrong bead whose
  /// own spot is wanted by a bead already in the tray (it sorts right away),
  /// then one whose color an open hole is waiting for, then any wrong bead.
  int? bestMove() {
    final wanted = <int>{
      for (var i = 0; i < current.length; i++)
        if (current[i] < 0) target[i]
    };
    final inTray = tray.toSet();
    int? fallback, good;
    for (var i = 0; i < current.length; i++) {
      if (!isWrong(i)) continue;
      if (inTray.contains(target[i])) return i;
      if (good == null && wanted.contains(current[i])) good = i;
      fallback ??= i;
    }
    return good ?? fallback;
  }

  /// Frees tray room by putting up to [count] tray beads back into holes
  /// (in the wrong place). Returns the cells that got a bead back.
  List<({int cell, int traySlot, int color})> shake({int count = 6}) {
    final back = <({int cell, int traySlot, int color})>[];
    for (var i = 0; i < current.length && back.length < count && tray.isNotEmpty; i++) {
      if (current[i] >= 0) continue;
      final color = tray.removeAt(0);
      current[i] = color;
      back.add((cell: i, traySlot: 0, color: color));
    }
    if (back.isNotEmpty) shakes++;
    return back;
  }

  /// Compact text form for saving: one character per cell, '.' for holes.
  String encodeBoard() => String.fromCharCodes([for (final c in current) c < 0 ? 0x2E : 0x41 + c]);
  String encodeTray() => String.fromCharCodes([for (final c in tray) 0x41 + c]);

  static Int16List decodeBoard(String s) =>
      Int16List.fromList([for (final u in s.codeUnits) u == 0x2E ? -1 : u - 0x41]);
  static List<int> decodeTray(String s) => [for (final u in s.codeUnits) u - 0x41];
}
