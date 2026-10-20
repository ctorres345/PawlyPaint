import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import '../state/settings.dart' show currentLook;
import 'gem_style.dart';

enum TraySort { number, remaining }

/// The drill tray: one chip per color with its symbol and how many are left.
/// Finished colors move to the end, and the selected color scrolls into view.
class Tray extends StatefulWidget {
  const Tray({
    super.key,
    required this.game,
    required this.paints,
    required this.sort,
    required this.onSortChanged,
    this.axis = Axis.horizontal,
  });

  final GameController game;
  final List<GemPaints> paints;
  final TraySort sort;
  final ValueChanged<TraySort> onSortChanged;

  /// Horizontal along the bottom in portrait, vertical along the side in landscape.
  final Axis axis;

  @override
  State<Tray> createState() => _TrayState();
}

class _TrayState extends State<Tray> {
  double get _chipExtent => widget.axis == Axis.horizontal ? 66 : 92; // chip size plus margins
  final _scroll = ScrollController();
  List<int> _order = const [];
  Object? _orderKey;
  int? _shownSelected;

  /// Finished colors the order has caught up with. A newly finished chip
  /// stays put for a moment so its celebration plays where she saw it.
  int? _doneShown;
  Timer? _reorder;

  GameController get game => widget.game;

  /// The order only changes when sorting is toggled or a color finishes, so
  /// chips never shuffle under the thumb while playing.
  List<int> _currentOrder() {
    final doneCount = Iterable<int>.generate(game.remaining.length).where(game.isColorDone).length;
    _doneShown ??= doneCount;
    if (doneCount != _doneShown && !(_reorder?.isActive ?? false)) {
      _reorder = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _doneShown = null);
      });
    }
    final key = (widget.sort, _doneShown);
    if (key == _orderKey) return _order;
    _orderKey = key;
    final colors = List<int>.generate(game.remaining.length, (i) => i);
    final open = colors.where((c) => !game.isColorDone(c)).toList();
    final done = colors.where(game.isColorDone).toList();
    if (widget.sort == TraySort.remaining) {
      open.sort((a, b) => game.remaining[b].compareTo(game.remaining[a]));
    }
    return _order = [...open, ...done];
  }

  void _revealSelected(List<int> order) {
    if (_shownSelected == game.selected) return;
    _shownSelected = game.selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final index = order.indexOf(game.selected);
      final pos = _scroll.position;
      final target = (index * _chipExtent - (pos.viewportDimension - _chipExtent) / 2)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      _scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _reorder?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sort = widget.sort;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final order = _currentOrder();
        _revealSelected(order);
        final horizontal = widget.axis == Axis.horizontal;
        final list = ListView.builder(
          controller: _scroll,
          scrollDirection: widget.axis,
          padding: const EdgeInsets.all(6),
          itemExtent: _chipExtent,
          itemCount: order.length,
          itemBuilder: (context, i) {
            final c = order[i];
            return Center(
              child: _ColorChip(
                key: ValueKey(c),
                symbol: game.puzzle.symbolFor(c),
                paints: widget.paints[c],
                remaining: game.remaining[c],
                total: game.puzzle.counts[c],
                selected: game.selected == c,
                onTap: () => game.select(c),
              ),
            );
          },
        );
        final sortButton = IconButton(
          tooltip: sort == TraySort.number ? 'Sorted by number' : 'Sorted by drills left',
          icon: Icon(sort == TraySort.number ? Icons.format_list_numbered_rounded : Icons.sort_rounded),
          onPressed: () => widget.onSortChanged(sort == TraySort.number ? TraySort.remaining : TraySort.number),
        );
        // Chips have a fixed size, so very large system text is capped here
        // rather than overflowing them.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Material(
            color: scheme.surface,
            elevation: 6,
            shadowColor: const Color(0x55000000),
            borderRadius: horizontal
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : const BorderRadius.horizontal(left: Radius.circular(20)),
            child: SizedBox(
              height: horizontal ? 108 : null,
              width: horizontal ? null : 96,
              child: Flex(
                direction: widget.axis,
                children: [
                  Padding(padding: const EdgeInsets.all(4), child: sortButton),
                  Expanded(child: list),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColorChip extends StatefulWidget {
  const _ColorChip({
    super.key,
    required this.symbol,
    required this.paints,
    required this.remaining,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final String symbol;
  final GemPaints paints;
  final int remaining;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ColorChip> createState() => _ColorChipState();
}

class _ColorChipState extends State<_ColorChip> with SingleTickerProviderStateMixin {
  /// The burst when this color is finished.
  late final _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didUpdateWidget(_ColorChip old) {
    super.didUpdateWidget(old);
    if (old.remaining > 0 && widget.remaining == 0 && !MediaQuery.of(context).disableAnimations) {
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = widget.remaining, symbol = widget.symbol, paints = widget.paints, selected = widget.selected;
    final done = remaining == 0;
    final progress = widget.total == 0 ? 1.0 : 1 - remaining / widget.total;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !done,
      label: done ? 'Color $symbol, done' : 'Color $symbol, $remaining left',
      excludeSemantics: true,
      child: InkWell(
        onTap: done ? null : widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedBuilder(
          animation: _burst,
          builder: (context, child) {
            final t = _burst.value;
            // A quick bounce, then the chip settles and fades like other finished ones.
            final bounce = _burst.isAnimating ? 1 + 0.25 * math.sin(math.pi * math.min(1, t * 2)) : 1.0;
            return CustomPaint(
              foregroundPainter: _burst.isAnimating ? _BurstPainter(t, paints.color) : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: done && !_burst.isAnimating ? 0.45 : 1,
                child: Transform.scale(scale: bounce, child: child),
              ),
            );
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: selected ? 1.12 : 1,
            child: Container(
              width: 58,
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected ? scheme.primaryContainer : Colors.transparent,
                border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CustomPaint(
                      painter: _ChipGemPainter(paints, progress, scheme.outlineVariant),
                      child: Center(
                        child: done
                            ? Icon(Icons.check_rounded, size: 22, color: paints.onColor)
                            : Text(
                                symbol,
                                style: TextStyle(fontWeight: FontWeight.w800, color: paints.onColor),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done ? 'Done' : '$remaining',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Little stars flying out of a chip whose color was just finished.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color);

  final double t;
  final Color color;

  static final _star = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final reach = 18 + 26 * Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < 10; i++) {
      final a = i * 2 * math.pi / 10 + 0.3;
      final p = center + Offset(math.cos(a), math.sin(a)) * reach;
      _star.color = (i.isEven ? const Color(0xFFFFD54F) : color).withValues(alpha: fade);
      final r = 3.5 * (1 - 0.5 * t);
      final path = Path()
        ..moveTo(p.dx, p.dy - r * 1.6)
        ..lineTo(p.dx + r * 0.45, p.dy - r * 0.45)
        ..lineTo(p.dx + r * 1.6, p.dy)
        ..lineTo(p.dx + r * 0.45, p.dy + r * 0.45)
        ..lineTo(p.dx, p.dy + r * 1.6)
        ..lineTo(p.dx - r * 0.45, p.dy + r * 0.45)
        ..lineTo(p.dx - r * 1.6, p.dy)
        ..lineTo(p.dx - r * 0.45, p.dy - r * 0.45)
        ..close();
      canvas.drawPath(path, _star);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.color != color;
}

/// The chip's gem with a ring around it that fills as the color is painted.
class _ChipGemPainter extends CustomPainter {
  _ChipGemPainter(this.paints, this.progress, this.track);

  final GemPaints paints;
  final double progress;
  final Color track;
  final Object look = currentLook();

  static final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    drawGem(canvas, box.deflate(5), paints);
    final arc = box.deflate(1.5);
    canvas.drawArc(arc, 0, 2 * math.pi, false, _ring..color = track);
    // Very light colors get a darker ring so it shows on the light tray.
    final c =
        paints.color.computeLuminance() > 0.7 ? Color.lerp(paints.color, const Color(0xFF000000), 0.35)! : paints.color;
    if (progress > 0) canvas.drawArc(arc, -math.pi / 2, 2 * math.pi * progress, false, _ring..color = c);
  }

  @override
  bool shouldRepaint(_ChipGemPainter old) =>
      old.paints != paints || old.look != look || old.progress != progress || old.track != track;
}
