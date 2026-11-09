part of '../sort_screen.dart';

class _SortStats extends StatelessWidget {
  const _SortStats({
    required this.relaxed,
    required this.progress,
    required this.seconds,
    required this.left,
    this.countdown = false,
  });

  final bool relaxed;

  /// Time Attack: [seconds] counts down and turns red near the end.
  final bool countdown;

  final double progress;
  final int seconds;
  final int left;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final time = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Text('$left to sort', style: text.labelLarge),
                  if (!relaxed) ...[
                    const SizedBox(width: 16),
                    Icon(
                      countdown ? Icons.hourglass_bottom_rounded : Icons.timer_outlined,
                      size: 18,
                      semanticLabel: countdown ? 'Time left' : 'Time',
                      color: countdown && seconds <= 10 ? scheme.error : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: text.labelLarge?.copyWith(
                        color: countdown && seconds <= 10 ? scheme.error : null,
                        fontWeight: countdown ? FontWeight.w800 : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortTips extends StatelessWidget {
  const _SortTips({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget tip(IconData icon, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: text.bodyMedium)),
            ],
          ),
        );
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort the beads', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            tip(Icons.touch_app_outlined,
                'Tap a misplaced bead to pick it up, together with the misplaced beads of its color touching it.'),
            tip(Icons.inventory_2_outlined, 'Tap the tray to put them there. That leaves empty spots behind.'),
            tip(Icons.auto_awesome_rounded, 'Pick up the color an empty spot needs, then tap the glowing spot.'),
            tip(Icons.bolt_rounded, 'Good drops in a row build a combo for bonus points.'),
            tip(Icons.tips_and_updates_outlined, 'Stuck? The hint button shows a good next move.'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onDone, child: const Text('Got it')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live combo: a badge that pops on each good drop, with a bar that
/// drains until the combo lapses.
class _ComboMeter extends StatelessWidget {
  const _ComboMeter({required this.game, required this.bar});

  final SortController game;
  final AnimationController bar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([game, bar]),
        builder: (context, _) {
          final combo = game.comboNow();
          final show = combo >= 2 && bar.isAnimating;
          return AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(combo),
              tween: Tween(begin: 1.35, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Semantics(
                liveRegion: true,
                label: show ? 'Combo $combo' : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFFFC107)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Combo ×$combo',
                        style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 84,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: 1 - bar.value,
                            minHeight: 5,
                            color: Colors.white,
                            backgroundColor: Colors.white30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small preview of the finished picture. Hold it to see the whole
/// finished picture on the canvas.
class _PeekThumb extends StatelessWidget {
  const _PeekThumb({required this.puzzle, required this.onPeek});

  final Puzzle puzzle;
  final ValueChanged<bool> onPeek;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Preview the finished picture',
      hint: 'Press and hold',
      child: Listener(
        onPointerDown: (_) => onPeek(true),
        onPointerUp: (_) => onPeek(false),
        onPointerCancel: (_) => onPeek(false),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox.square(
                    dimension: 56,
                    child: CustomPaint(painter: PuzzleThumbPainter(puzzle, complete: true)),
                  ),
                ),
                const SizedBox(height: 2),
                Text('Hold to peek', style: text.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
