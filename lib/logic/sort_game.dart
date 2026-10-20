import 'dart:math' as math;
import 'dart:typed_data';

/// One bead moving because of a tap. [fromCell] or [fromSlot] says where it
/// starts, [toCell] or [toSlot] where it lands (exactly one of each is set).
typedef BeadHop = ({int? fromCell, int? fromSlot, int? toCell, int? toSlot, int color});

/// What a tap did, so the screen can react to it.
enum SortAction {
  /// Beads were picked up (on the canvas or in the tray).
  selected,

  /// The picked-up beads were put down again.
  deselected,

  /// Picked-up canvas beads went down to the tray.
  toTray,

  /// Beads landed in empty spots that wanted their color.
  placed,

  /// A tap on a bead that was already right, or on a spot that wants another
  /// color.
  wrong,

  /// The tray has no room for the picked-up beads.
  trayFull,

  /// Nothing happened (say, an empty spot tapped with nothing picked up).
  ignored,
}

class SortMove {
  const SortMove(this.action, [this.hops = const []]);

  final SortAction action;
  final List<BeadHop> hops;

  static const ignored = SortMove(SortAction.ignored);
}

/// Beads picked up and waiting for a destination: a patch of wrong beads on
/// the canvas ([cells] not empty), or every bead of one color in the tray.
class SortSelection {
  const SortSelection.board(this.color, this.cells);
  const SortSelection.tray(this.color) : cells = const [];

  final int color;
  final List<int> cells;

  bool get fromTray => cells.isEmpty;
}

/// A good next move: pick up the canvas patch at [fromCell] or the tray
/// beads of [trayColor], then drop them on [toCell] (or in the tray when null).
typedef SortStep = ({int? fromCell, int? trayColor, int? toCell});

/// Pure rules for Sort mode, Jewel Coloring style.
///
/// The picture starts full, but some beads are swapped around so they sit in
/// the wrong place. Everything works by taps: tap a wrong bead to pick up
/// every misplaced bead of its color, then tap the tray to put them there, or
/// tap an empty spot that wants their color to drop them into every spot
/// that wants it, nearest first. Tray beads are picked up the same way. Beads are never
/// created or lost, so holes on the board always equal beads in the tray.
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

  /// The beads picked up right now, if any.
  SortSelection? selection;

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

  bool isSelected(int cell) => selection?.cells.contains(cell) ?? false;

  /// Up to [limit] cells that pass [test], [start] first and then the rest
  /// by distance from it, so groups ripple out from the tapped spot.
  List<int> _nearest(int start, bool Function(int) test, [int limit = 1 << 30]) {
    final sx = start % width, sy = start ~/ width;
    int dist(int c) {
      final dx = c % width - sx, dy = c ~/ width - sy;
      return dx * dx + dy * dy;
    }

    final out = [
      for (var i = 0; i < current.length; i++)
        if (i == start || test(i)) i
    ]..sort((a, b) => dist(a).compareTo(dist(b)));
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  /// Taps a canvas cell: picks up the misplaced beads of a color, drops the
  /// picked-up beads into an empty spot that wants them, or counts a mistake
  /// when [countMistakes] is set.
  SortMove tapCell(int cell, {bool countMistakes = true}) {
    final sel = selection;
    if (isHole(cell)) {
      if (sel == null) return SortMove.ignored;
      if (target[cell] != sel.color) return _wrong(countMistakes);
      return _place(cell, sel);
    }
    if (isSelected(cell)) {
      selection = null;
      return const SortMove(SortAction.deselected);
    }
    if (!isWrong(cell)) return _wrong(countMistakes);
    final color = current[cell];
    selection = SortSelection.board(color, _nearest(cell, (n) => current[n] == color && isWrong(n)));
    return const SortMove(SortAction.selected);
  }

  /// Taps the tray: puts picked-up canvas beads into it, or picks up every
  /// tray bead of the color in [slot].
  SortMove tapTray(int? slot) {
    final sel = selection;
    if (sel != null && !sel.fromTray) {
      if (freeSlots <= 0) return const SortMove(SortAction.trayFull);
      final hops = <BeadHop>[];
      // Beads join others of their color, so the tray stays grouped.
      var at = tray.lastIndexOf(sel.color) + 1;
      if (at == 0) at = tray.length;
      for (final c in sel.cells.take(freeSlots)) {
        current[c] = -1;
        tray.insert(at, sel.color);
        hops.add((fromCell: c, fromSlot: null, toCell: null, toSlot: at++, color: sel.color));
      }
      final left = sel.cells.skip(hops.length).toList();
      selection = left.isEmpty ? null : SortSelection.board(sel.color, left);
      return SortMove(SortAction.toTray, hops);
    }
    if (slot == null || slot < 0 || slot >= tray.length) return SortMove.ignored;
    final color = tray[slot];
    if (sel != null && sel.color == color) {
      selection = null;
      return const SortMove(SortAction.deselected);
    }
    selection = SortSelection.tray(color);
    return const SortMove(SortAction.selected);
  }

  SortMove _wrong(bool count) {
    if (count) mistakes++;
    return const SortMove(SortAction.wrong);
  }

  /// Drops [sel] into the hole at [cell] and the other holes that want the
  /// same color, nearest first, as far as the picked-up beads go.
  SortMove _place(int cell, SortSelection sel) {
    final available = sel.fromTray ? tray.where((c) => c == sel.color).length : sel.cells.length;
    final spots = _nearest(cell, (n) => isHole(n) && target[n] == sel.color, available);
    final hops = <BeadHop>[];
    final sources = List<int>.of(sel.cells);
    for (final spot in spots) {
      if (sel.fromTray) {
        final slot = tray.indexOf(sel.color);
        tray.removeAt(slot);
        hops.add((fromCell: null, fromSlot: slot, toCell: spot, toSlot: null, color: sel.color));
      } else {
        final from = sources.removeAt(0);
        current[from] = -1;
        hops.add((fromCell: from, fromSlot: null, toCell: spot, toSlot: null, color: sel.color));
      }
      current[spot] = sel.color;
      placed++;
    }
    if (sel.fromTray) {
      selection = tray.contains(sel.color) ? sel : null;
    } else {
      selection = sources.isEmpty ? null : SortSelection.board(sel.color, sources);
    }
    return SortMove(SortAction.placed, hops);
  }

  /// A good next move, for the hint button: fill a hole from the tray, else
  /// fill a hole with a wrong bead from the canvas, else send a wrong bead to
  /// the tray. Every hole's color is either in the tray or misplaced on the
  /// canvas, so there is always a move until the picture is done.
  SortStep? bestStep() {
    if (isComplete) return null;
    final inTray = tray.toSet();
    // First wrong bead of each color, for filling holes straight from the canvas.
    final wrongOf = <int, int>{};
    for (var i = 0; i < current.length; i++) {
      if (isWrong(i)) wrongOf.putIfAbsent(current[i], () => i);
    }
    int? fromBoard;
    for (var i = 0; i < current.length; i++) {
      if (!isHole(i)) continue;
      if (inTray.contains(target[i])) return (fromCell: null, trayColor: target[i], toCell: i);
      if (fromBoard == null && wrongOf.containsKey(target[i])) fromBoard = i;
    }
    if (fromBoard != null) return (fromCell: wrongOf[target[fromBoard]], trayColor: null, toCell: fromBoard);
    if (freeSlots <= 0) return null;
    // Nothing to fill yet: free a spot, preferring one a tray bead can fill next.
    int? fallback;
    for (var i = 0; i < current.length; i++) {
      if (!isWrong(i)) continue;
      if (inTray.contains(target[i])) return (fromCell: i, trayColor: null, toCell: null);
      fallback ??= i;
    }
    return fallback == null ? null : (fromCell: fallback, trayColor: null, toCell: null);
  }

  /// Plays [step] as the two taps a player would make.
  SortMove play(SortStep step) {
    selection = null;
    if (step.trayColor != null) {
      tapTray(tray.indexOf(step.trayColor!));
    } else {
      tapCell(step.fromCell!);
    }
    final to = step.toCell;
    return to == null ? tapTray(null) : tapCell(to);
  }

  /// Frees tray room by putting up to [count] tray beads back into holes
  /// (in the wrong place). Returns the moves made.
  List<BeadHop> shake({int count = 6}) {
    final back = <BeadHop>[];
    selection = null;
    for (var i = 0; i < current.length && back.length < count && tray.isNotEmpty; i++) {
      if (current[i] >= 0) continue;
      final color = tray.removeAt(0);
      current[i] = color;
      back.add((fromCell: null, fromSlot: 0, toCell: i, toSlot: null, color: color));
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
