import 'package:flutter/material.dart';

/// A "Combo ×25!" badge that pops in over the canvas and floats away.
/// Give each milestone a new key so it plays again.
class ComboPop extends StatefulWidget {
  const ComboPop({super.key, required this.combo});

  final int combo;

  @override
  State<ComboPop> createState() => _ComboPopState();
}

class _ComboPopState extends State<ComboPop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final text = Theme.of(context).textTheme;
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFEC407A)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x55EC407A), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Text(
              'Combo ×${widget.combo}!',
              style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: 'Combo ${widget.combo}',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            // Pop in with a little overshoot, hold, then drift up and fade.
            final scale = still ? 1.0 : Curves.elasticOut.transform((t / 0.35).clamp(0.0, 1.0)) * 0.9 + 0.1;
            final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
            final rise = still || t < 0.7 ? 0.0 : (t - 0.7) / 0.3 * -24;
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, rise),
                child: Transform.scale(scale: t == 0 ? 0.1 : scale, child: child),
              ),
            );
          },
          child: badge,
        ),
      ),
    );
  }
}
