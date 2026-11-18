import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/rewards.dart';
import '../logic/unlocks.dart';
import '../state/progress_store.dart';
import 'cat_mascot.dart';
import 'unlock_ui.dart';
import 'unlocks_screen.dart';

/// Leaves a finished picture: celebrates new rewards, shows the 7-days gift
/// toast for [gifts], pops the play screen, and opens Unlocks if she asked.
Future<void> leaveFinishedPicture(BuildContext context, ProgressStore store, {required int gifts}) async {
  final seeUnlocks = await celebrateNewRewards(context, store);
  if (!context.mounted) return;
  if (gifts > 0) showDaysPlayedGift(context, gifts);
  final nav = Navigator.of(context)..pop();
  if (seeUnlocks) openUnlocks(nav);
}

/// After a finished picture: celebrates every reward that just opened, in one
/// card, and marks them celebrated so each is shown once. True when she taps
/// "See my unlocks". Does nothing when nothing new opened.
Future<bool> celebrateNewRewards(BuildContext context, ProgressStore store) async {
  final unlocks = store.currentUnlocks;
  final rewards = unlocks.newRewards;
  if (rewards.isEmpty || !context.mounted) return false;
  // Marked as the card opens (memory at once, disk meanwhile), so leaving the
  // app mid-card never shows it twice, and a card that never opens is not lost.
  final saved = store.markCelebrated([for (final r in rewards) r.id]);
  final see = await showDialog<bool>(
    context: context,
    // Shown once only, so a stray tap outside must not close it; back still does.
    barrierDismissible: false,
    builder: (_) => UnlockCelebration(rewards: rewards, unlocks: unlocks),
  );
  await saved;
  return see ?? false;
}

/// The "New unlock" card (PAP-19 board "Unlock celebration"). It scales in
/// over 300 ms and its sparkles twinkle twice; with reduced motion it just appears.
class UnlockCelebration extends StatefulWidget {
  const UnlockCelebration({super.key, required this.rewards, required this.unlocks});

  /// What just opened, in table order. Never empty.
  final List<Reward> rewards;
  final UnlockState unlocks;

  @override
  State<UnlockCelebration> createState() => _UnlockCelebrationState();
}

class _UnlockCelebrationState extends State<UnlockCelebration> with TickerProviderStateMixin {
  late final _scale = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  late final _twinkle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _scale.value = 1;
      _twinkle.value = 1;
    } else {
      _scale.forward();
      _twinkle.forward();
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rewards = widget.rewards;
    final first = rewards.first;
    final info = rewardInfo(first);
    final one = rewards.length == 1;
    final name = one ? info.name : joinAnd([for (final r in rewards) rewardInfo(r).name]);
    // Her real count, never above it: a reward kept open after the build grew
    // can have a scaled threshold higher than what she has.
    final at = math.min(widget.unlocks.threshold(rewards.last), widget.unlocks.threeStars);
    // Several at once: a gift and a general cheer instead of the first reward's.
    final art = one ? info.art : 'icons/gift.png';
    final cheer = one ? info.cheer : 'So many treats!';
    final soon = rewards.any((r) => !rewardInfo(r).ready);
    final message = [
      if (one) info.blurb,
      'You earned ${one ? 'it' : 'them'} with $at three-star ${picturesWord(at)}.',
      if (soon) one ? 'It arrives in an update soon.' : 'Some arrive in an update soon.',
    ].join(' ');
    final star = starColor(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _scale, curve: Curves.easeOutBack),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _scale, curve: Curves.easeOut),
          child: EarsCard(
            color: scheme.surface,
            radius: 28,
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                              ),
                            ),
                            Center(
                              child: Image.asset('assets/art/$art', width: 72, height: 72),
                            ),
                            Positioned(top: 2, right: 6, child: _Sparkle(_twinkle, star, 22, 0)),
                            Positioned(bottom: 10, left: 2, child: _Sparkle(_twinkle, star, 16, 0.25)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      one ? 'New unlock' : '${rewards.length} new unlocks',
                      style: TextStyle(color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: one ? 26 : 20, fontWeight: FontWeight.w800, height: 1.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: '$mascotName says: $cheer',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/art/mochi/celebrate.png', width: 72, height: 72),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '$mascotName: “$cheer”',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('See my unlocks'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      // The board's soft button: the same pink as the medallion.
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Later'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sparkle that twinkles twice as [t] runs from 0 to 1, starting [delay] in, then rests fully lit.
class _Sparkle extends StatelessWidget {
  const _Sparkle(this.t, this.color, this.size, this.delay);

  final Animation<double> t;
  final Color color;
  final double size;
  final double delay;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: t,
        builder: (context, child) {
          final p = ((t.value - delay) / (1 - delay)).clamp(0.0, 1.0);
          final s = p >= 1 ? 1.0 : 0.6 + 0.4 * math.cos(p * 4 * math.pi);
          return Transform.scale(scale: s, child: Opacity(opacity: s, child: child));
        },
        child: Icon(Icons.auto_awesome_rounded, color: color, size: size),
      );
}
