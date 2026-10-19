import 'package:flutter/material.dart';

import '../state/progress_store.dart';

/// One step of a guided tutorial.
class CoachStep {
  const CoachStep(this.icon, this.text, {this.manual = false});

  final IconData icon;
  final String text;

  /// True when the player moves on with a button rather than by doing it.
  final bool manual;
}

/// The card that walks the player through a tutorial, one step at a time.
class CoachCard extends StatelessWidget {
  const CoachCard({
    super.key,
    required this.steps,
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

  final List<CoachStep> steps;
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = steps[step];
    final last = step == steps.length - 1;
    return Semantics(
      liveRegion: true,
      child: Card(
        elevation: 6,
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(s.icon, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.text, style: text.bodyLarge)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= step ? scheme.primary : scheme.outlineVariant,
                      ),
                    ),
                  const Spacer(),
                  if (!last) TextButton(onPressed: onSkip, child: const Text('Skip tutorial')),
                  if (s.manual || last) FilledButton(onPressed: onNext, child: Text(last ? 'Got it' : 'Next')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [open] after the mode's tutorial, the first time that mode is
/// played. The tutorial screens mark themselves as seen when they close.
Future<void> openWithTutorial(
  BuildContext context, {
  required PlayMode mode,
  required ProgressStore store,
  required Widget Function() tutorial,
  required Widget Function() open,
}) async {
  final seen = mode == PlayMode.paint ? store.seenTutorial : store.seenSortTutorial;
  final nav = Navigator.of(context);
  if (!seen) {
    await nav.push(MaterialPageRoute(builder: (_) => tutorial()));
  }
  await nav.push(MaterialPageRoute(builder: (_) => open()));
}
