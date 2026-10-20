import 'package:flutter/material.dart';

import '../logic/boosters.dart';

IconData boosterIcon(Booster b) => switch (b) {
      Booster.bomb => Icons.flare_rounded,
      Booster.wand => Icons.auto_fix_high_rounded,
      Booster.brush => Icons.brush_rounded,
    };

/// The round booster buttons floating over the canvas corner, each with how
/// many are left. An armed bomb or a running brush glows.
class BoosterBar extends StatelessWidget {
  const BoosterBar({
    super.key,
    required this.count,
    required this.active,
    required this.onTap,
    this.axis = Axis.vertical,
  });

  final int Function(Booster) count;
  final bool Function(Booster) active;
  final ValueChanged<Booster> onTap;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: axis,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in Booster.values)
          Padding(
            padding: const EdgeInsets.all(4),
            child: _BoosterButton(booster: b, count: count(b), active: active(b), onTap: () => onTap(b)),
          ),
      ],
    );
  }
}

class _BoosterButton extends StatelessWidget {
  const _BoosterButton({required this.booster, required this.count, required this.active, required this.onTap});

  final Booster booster;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const gold = Color(0xFFFFC107);
    final empty = count == 0 && !active;
    return Tooltip(
      message: '${booster.label}: ${booster.help}',
      child: Semantics(
        button: true,
        toggled: booster == Booster.wand ? null : active,
        label: '${booster.label}, $count left',
        excludeSemantics: true,
        child: Badge(
          isLabelVisible: !active,
          label: Text('$count'),
          backgroundColor: empty ? scheme.outline : scheme.primary,
          offset: const Offset(-2, 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFFFFF3C4) : scheme.surface,
              border: Border.all(color: active ? gold : scheme.outlineVariant, width: active ? 3 : 1),
              boxShadow: [
                BoxShadow(
                  color: active ? gold.withValues(alpha: 0.6) : const Color(0x33000000),
                  blurRadius: active ? 12 : 6,
                  offset: active ? Offset.zero : const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Icon(
                  boosterIcon(booster),
                  color: empty ? scheme.outline : (active ? const Color(0xFFE65100) : scheme.primary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
