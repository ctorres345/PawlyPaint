part of '../sort_screen.dart';

/// The tray of collected beads, with its shake button. Tap it to put
/// picked-up beads in, or tap a tray bead to pick up its color.
class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.trayKey,
    required this.game,
    required this.paints,
    required this.frame,
    required this.onTap,
    required this.onShake,
    required this.onUndo,
  });

  final GlobalKey trayKey;
  final SortController game;
  final List<GemPaints> paints;
  final Listenable frame;
  final void Function(Offset local, Size size) onTap;
  final VoidCallback onShake;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final g = game.game;
        final full = g.freeSlots <= 0 && !g.isComplete;
        final rows = (g.capacity / SortTrayPainter.columns).ceil();
        final sel = g.selection;
        final waiting = sel != null && !sel.fromTray;
        return Material(
          color: scheme.surface,
          elevation: 6,
          shadowColor: const Color(0x55000000),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: SortTrayPainter.columns / rows,
                  child: Semantics(
                    button: true,
                    label: 'Tray, ${g.tray.length} of ${g.capacity} slots used',
                    hint: waiting ? 'Tap to put the picked-up beads here' : 'Tap a bead to pick up its color',
                    child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => onTap(d.localPosition, box.biggest),
                        child: CustomPaint(
                          key: trayKey,
                          size: box.biggest,
                          painter: SortTrayPainter(
                            tray: g.tray,
                            capacity: g.capacity,
                            paints: paints,
                            full: full,
                            selectedColor: sel != null && sel.fromTray ? sel.color : null,
                            hintColor: game.hintStep?.trayColor,
                            invite: waiting || (game.hintStep != null && game.hintStep!.toCell == null),
                            frame: frame,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18, color: full ? scheme.error : null),
                    const SizedBox(width: 6),
                    Text(
                      full ? 'Tray full' : '${g.tray.length} / ${g.capacity}',
                      style: text.labelLarge?.copyWith(color: full ? scheme.error : null),
                    ),
                    if (waiting) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${sel.cells.length} in hand',
                          style: text.labelMedium?.copyWith(color: scheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else if (sel != null) ...[
                      // What's in hand, since the matching spots may be off-screen.
                      const SizedBox(width: 10),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: paints[sel.color].color,
                          shape: BoxShape.circle,
                          border: Border.all(color: ringInk, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${g.tray.where((c) => c == sel.color).length} held',
                          style: text.labelMedium?.copyWith(color: scheme.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton.outlined(
                      tooltip: 'Undo',
                      onPressed: game.canUndo ? onUndo : null,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: g.tray.isEmpty ? null : onShake,
                      icon: const Icon(Icons.vibration_rounded),
                      label: const Text('Shake'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SortTrayPainter extends CustomPainter {
  SortTrayPainter({
    required this.tray,
    required this.capacity,
    required this.paints,
    required this.full,
    this.selectedColor,
    this.hintColor,
    this.invite = false,
    Listenable? frame,
  }) : super(repaint: frame);

  static const columns = 12;

  final List<int> tray;
  final int capacity;
  final List<GemPaints> paints;
  final bool full;

  /// Tray beads of this color are picked up.
  final int? selectedColor;

  /// Tray beads of this color are the hint's suggestion.
  final int? hintColor;

  /// Canvas beads are picked up, so the tray glows to say "drop them here".
  final bool invite;

  /// Where tray slot [slot] sits inside a tray of [size].
  static Rect slotRect(Size size, int capacity, int slot) {
    final rows = (capacity / columns).ceil();
    final cw = size.width / columns, ch = size.height / rows;
    final s = math.min(cw, ch);
    return Rect.fromCenter(
      center: Offset((slot % columns + 0.5) * cw, (slot ~/ columns + 0.5) * ch),
      width: s,
      height: s,
    );
  }

  /// The slot under [local] in a tray of [size], or null outside it.
  static int? slotAt(Size size, int capacity, Offset local) {
    final rows = (capacity / columns).ceil();
    final col = (local.dx / (size.width / columns)).floor(), row = (local.dy / (size.height / rows)).floor();
    if (col < 0 || row < 0 || col >= columns || row >= rows) return null;
    final slot = row * columns + col;
    return slot < capacity ? slot : null;
  }

  static final _fullTint = Paint()..color = const Color(0x22E53935);
  static final _inviteTint = Paint();
  static final _ring = Paint()..style = PaintingStyle.stroke;
  static final _slotLine = Paint()
    ..color = const Color(0x55000000)
    ..style = PaintingStyle.stroke;

  /// An empty tray slot: a dashed outline, so the free space is easy to count.
  static void _drawSlot(Canvas canvas, Rect r) {
    final box = RRect.fromRectAndRadius(r.deflate(r.width * 0.1), Radius.circular(r.width * 0.25));
    _slotLine.strokeWidth = math.max(1, r.width * 0.05);
    final dash = r.width * 0.12;
    for (final metric in (Path()..addRRect(box)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        canvas.drawPath(metric.extractPath(d, d + dash), _slotLine);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 140);
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    if (full) canvas.drawRRect(box, _fullTint);
    if (invite && !full) {
      _inviteTint.color = const Color(0xFFFFC107).withValues(alpha: 0.12 + 0.14 * pulse);
      canvas.drawRRect(box, _inviteTint);
    }
    for (var i = 0; i < capacity; i++) {
      final r = slotRect(size, capacity, i);
      if (i >= tray.length) {
        _drawSlot(canvas, r);
        continue;
      }
      final color = tray[i];
      final lifted = color == selectedColor;
      drawCutGem(canvas, lifted ? r.shift(Offset(0, -r.height * 0.12)) : r, paints[color]);
      if (lifted) {
        final c = r.center.translate(0, -r.height * 0.12);
        drawSelectRing(canvas, Rect.fromCircle(center: c, radius: r.width * 0.5), math.max(1.5, r.width * 0.09));
      } else if (color == hintColor) {
        _ring
          ..color = const Color(0xFFFFC107).withValues(alpha: 0.5 + 0.5 * pulse)
          ..strokeWidth = math.max(1.5, r.width * 0.1);
        canvas.drawCircle(r.center, r.width * 0.5, _ring);
      }
    }
  }

  @override
  bool shouldRepaint(SortTrayPainter old) => true;
}

/// Draws beads in flight on top of everything.
class _FlightPainter extends CustomPainter {
  _FlightPainter({
    required this.game,
    required this.frame,
    required this.paints,
    required this.view,
    required this.cellCenter,
    required this.slotRect,
  }) : super(repaint: Listenable.merge([game, view, frame]));

  final SortController game;
  final Listenable frame;
  final List<GemPaints> paints;
  final BoardView view;
  final Offset? Function(int cell) cellCenter;
  final Rect? Function(int slot) slotRect;

  /// Where a flight end sits on screen, and how big a bead is there.
  (Offset, double)? _end(int? cell, int? slot) {
    if (cell != null) {
      final c = cellCenter(cell);
      return c == null ? null : (c, view.cellSize);
    }
    final r = slotRect(slot!);
    return r == null ? null : (r.center, r.width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (game.flights.isEmpty) return;
    final now = DateTime.now();
    for (final f in game.flights) {
      final t = f.progress(now);
      if (t == null || t >= 1) continue;
      final from = _end(f.fromCell, f.fromSlot), to = _end(f.toCell, f.toSlot);
      if (from == null || to == null) continue;
      final e = Curves.easeInOut.transform(t);
      final arc = math.sin(math.pi * e) * 60;
      final pos = Offset.lerp(from.$1, to.$1, e)! - Offset(0, arc);
      final s = lerpDouble(from.$2, to.$2, e)!;
      drawGem(canvas, Rect.fromCenter(center: pos, width: s * 1.1, height: s * 1.1), paints[f.color]);
    }
  }

  @override
  bool shouldRepaint(_FlightPainter old) => true;
}
