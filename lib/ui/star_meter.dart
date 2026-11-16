import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/scoring.dart';

/// Star gold, the same as the finish sheet and the course tiles.
const _gold = Color(0xFFFFC107);

String _plural(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

/// The line under the stars. [fresh] is before the first move, when it
/// states the 3-star limit instead of counting down.
String starMeterText(StarMeter meter, {bool fresh = false}) {
  final left = meter.left;
  if (left == null) return '1 star: finish the picture';
  if (fresh && meter.stars == 3) {
    return switch (meter.counts) {
      MeterCount.wrongTap => '3 stars: up to ${_plural(left, 'wrong tap')}, no shakes',
      _ => '3 stars: up to ${_plural(left, 'mistake')}',
    };
  }
  final nth = meter.stars == 3 ? '3rd' : '2nd';
  if (left == 0) {
    return switch (meter.counts) {
      MeterCount.mistake => 'Next mistake costs the $nth star',
      MeterCount.wrongTap => 'Next wrong tap or a shake costs the 3rd star',
      MeterCount.shake => 'Next shake costs the 2nd star',
    };
  }
  return switch (meter.counts) {
    MeterCount.mistake => '${_plural(left, 'mistake')} left for ${meter.stars} stars',
    MeterCount.wrongTap => '${_plural(left, 'wrong tap')} left for 3 stars · no shakes',
    MeterCount.shake => '${_plural(left, 'shake')} left for 2 stars',
  };
}

/// The star meter under the Paint and Sort progress bar (PAP-8): the best
/// stars still possible and what is left before the next one goes.
///
/// When a star drops, that star wobbles once and [onStarLost] runs. The first
/// build only remembers the stars, so a resumed save never fires the cue.
class StarMeterBar extends StatefulWidget {
  const StarMeterBar({super.key, required this.meter, this.fresh = false, this.onStarLost});

  final StarMeter meter;
  final bool fresh;
  final VoidCallback? onStarLost;

  @override
  State<StarMeterBar> createState() => _StarMeterBarState();
}

class _StarMeterBarState extends State<StarMeterBar> with SingleTickerProviderStateMixin {
  /// Seeded in [initState]: a lazy `late` initializer would first run in
  /// [didUpdateWidget], after the stars already dropped, and miss the cue.
  late int _stars;
  late final AnimationController _wobble;

  @override
  void initState() {
    super.initState();
    _stars = widget.meter.stars;
    _wobble = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void didUpdateWidget(StarMeterBar old) {
    super.didUpdateWidget(old);
    final now = widget.meter.stars;
    if (now < _stars) {
      if (!MediaQuery.disableAnimationsOf(context)) _wobble.forward(from: 0);
      widget.onStarLost?.call();
    }
    _stars = now;
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meter = widget.meter;
    final line = starMeterText(meter, fresh: widget.fresh);
    final last = meter.left == 0;
    Widget star(int i) {
      final on = i < meter.stars;
      final icon = Icon(
        on ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 16,
        color: on ? _gold : scheme.outlineVariant,
      );
      // Only the star that was just lost wobbles: it stays gold while it
      // shakes and fades into its outline, so the loss is easy to see.
      if (i != meter.stars) return icon;
      return AnimatedBuilder(
        animation: _wobble,
        builder: (context, child) {
          final t = _wobble.value;
          if (!_wobble.isAnimating) return child!;
          final decay = 1 - t;
          return Transform.rotate(
            angle: 0.35 * math.sin(t * math.pi * 5) * decay,
            child: Transform.scale(
              scale: 1 + 0.4 * decay,
              child: Stack(children: [
                child!,
                Opacity(opacity: decay, child: const Icon(Icons.star_rounded, size: 16, color: _gold)),
              ]),
            ),
          );
        },
        child: icon,
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${meter.stars} ${meter.stars == 1 ? 'star' : 'stars'} possible. $line',
      excludeSemantics: true,
      // At least 20 high, growing with the font size; the text only shrinks
      // to fit the width.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 2), star(i)],
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  line,
                  maxLines: 1,
                  style: text.labelMedium?.copyWith(color: last ? scheme.primary : scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
