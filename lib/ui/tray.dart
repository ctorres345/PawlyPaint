import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import 'gem_style.dart';

enum TraySort { number, remaining }

/// The drill tray: one chip per color with its symbol and how many are left.
/// Finished colors move to the end, and the selected color scrolls into view.
class Tray extends StatefulWidget {
  const Tray({super.key, required this.game, required this.paints, required this.sort, required this.onSortChanged});

  final GameController game;
  final List<GemPaints> paints;
  final TraySort sort;
  final ValueChanged<TraySort> onSortChanged;

  @override
  State<Tray> createState() => _TrayState();
}

class _TrayState extends State<Tray> {
  static const _chipExtent = 66.0; // chip width plus its margins
  final _scroll = ScrollController();
  List<int> _order = const [];
  Object? _orderKey;
  int? _shownSelected;

  GameController get game => widget.game;

  /// The order only changes when sorting is toggled or a color finishes, so
  /// chips never shuffle under the thumb while playing.
  List<int> _currentOrder() {
    final doneCount = Iterable<int>.generate(game.remaining.length).where(game.isColorDone).length;
    final key = (widget.sort, doneCount);
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
        return Container(
          height: 104,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -2))],
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: sort == TraySort.number ? 'Sorted by number' : 'Sorted by drills left',
                icon: Icon(sort == TraySort.number ? Icons.format_list_numbered : Icons.sort),
                onPressed: () => widget.onSortChanged(sort == TraySort.number ? TraySort.remaining : TraySort.number),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  itemExtent: _chipExtent,
                  itemCount: order.length,
                  itemBuilder: (context, i) {
                    final c = order[i];
                    return _ColorChip(
                      key: ValueKey(c),
                      symbol: game.puzzle.symbolFor(c),
                      paints: widget.paints[c],
                      remaining: game.remaining[c],
                      selected: game.selected == c,
                      onTap: () => game.select(c),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    super.key,
    required this.symbol,
    required this.paints,
    required this.remaining,
    required this.selected,
    required this.onTap,
  });

  final String symbol;
  final GemPaints paints;
  final int remaining;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = remaining == 0;
    return GestureDetector(
      onTap: done ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: done ? 0.45 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: selected ? 1.12 : 1,
          child: Container(
            width: 58,
            margin: const EdgeInsets.symmetric(horizontal: 4),
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
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: _ChipGemPainter(paints),
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipGemPainter extends CustomPainter {
  _ChipGemPainter(this.paints);

  final GemPaints paints;

  @override
  void paint(Canvas canvas, Size size) => drawGem(canvas, Offset.zero & size, paints);

  @override
  bool shouldRepaint(_ChipGemPainter old) => old.paints != paints;
}
