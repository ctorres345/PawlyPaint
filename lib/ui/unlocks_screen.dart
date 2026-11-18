import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/rewards.dart';
import '../logic/unlocks.dart';
import '../state/progress_store.dart';
import 'cat_mascot.dart';
import 'unlock_ui.dart';

/// The star color of the PAP-19 tokens, light and dark.
Color _star(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF2C14E) : const Color(0xFFE0A21B);

/// Opens the Unlocks screen.
Future<void> openUnlocks(NavigatorState nav) =>
    nav.push(MaterialPageRoute<void>(builder: (_) => const UnlocksScreen()));

/// The 3-star rewards: what she has earned, the next one and how far it is,
/// and the rest as mystery boxes (PAP-38, PAP-19 board "Unlocks screen").
class UnlocksScreen extends StatelessWidget {
  const UnlocksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocks = ProgressScope.of(context).currentUnlocks;
    final scheme = Theme.of(context).colorScheme;
    final earned = [
      for (final r in UnlockTables.rewards)
        if (unlocks.isUnlocked(r.id)) r,
    ];
    final next = unlocks.nextReward == null ? null : rewardById(unlocks.nextReward!.id);
    final hidden = [
      for (final r in UnlockTables.rewards)
        if (!unlocks.isUnlocked(r.id) && r != next) r,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlocks'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              label: '${unlocks.threeStars} three-star ${unlocks.threeStars == 1 ? 'picture' : 'pictures'}',
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration:
                    BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: _star(context)),
                    const SizedBox(width: 4),
                    Text('${unlocks.threeStars} three-star',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (next != null) _NextCard(reward: next, unlocks: unlocks) else const _AllEarnedCard(),
            const SizedBox(height: 16),
            const StickerTitle(art: 'icons/gift.png', text: 'Earned'),
            const SizedBox(height: 12),
            _EarnedList(rewards: earned, unlocks: unlocks, firstAt: next == null ? null : unlocks.threshold(next)),
            if (hidden.isNotEmpty) ...[
              const SizedBox(height: 16),
              const StickerTitle(art: 'icons/lock.png', text: 'Still hidden'),
              const SizedBox(height: 12),
              for (final r in hidden) ...[
                _MysteryRow(at: unlocks.threshold(r)),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A section heading in the sticker style of the redesign: a tilted pill with
/// an illustration.
class StickerTitle extends StatelessWidget {
  const StickerTitle({super.key, required this.art, required this.text});

  /// Path under `assets/art/`.
  final String art;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.rotate(
          angle: -2 * math.pi / 180,
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(left: 6, right: 16),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: scheme.outlineVariant, width: 3),
              boxShadow: [BoxShadow(color: scheme.outlineVariant, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/art/$art', width: 30, height: 30, excludeFromSemantics: true),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(color: scheme.onPrimary, fontSize: 18, fontWeight: FontWeight.w800, height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A reward's art in a rounded tile.
class RewardArt extends StatelessWidget {
  const RewardArt({super.key, required this.reward, this.size = 48, this.color});

  final Reward reward;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size / 12),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Image.asset('assets/art/${rewardInfo(reward).art}', fit: BoxFit.contain, excludeFromSemantics: true),
      );
}

String _pictures(int n) => n == 1 ? 'picture' : 'pictures';

class _NextCard extends StatelessWidget {
  const _NextCard({required this.reward, required this.unlocks});

  final Reward reward;
  final UnlockState unlocks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = rewardInfo(reward);
    final need = unlocks.threshold(reward);
    final have = unlocks.threeStars.clamp(0, need);
    final left = need - have;
    return Semantics(
      container: true,
      label: 'Next unlock: ${info.name}. $left more three-star ${_pictures(left)}. $have of $need.',
      excludeSemantics: true,
      child: EarsCard(
        color: scheme.primaryContainer,
        radius: 28,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(28)),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: scheme.onPrimaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Next unlock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RewardArt(reward: reward, color: scheme.surface),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          Text('$left more three-star ${_pictures(left)}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: need == 0 ? 1 : have / need,
                          minHeight: 8,
                          backgroundColor: scheme.surface,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$have / $need', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllEarnedCard extends StatelessWidget {
  const _AllEarnedCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return EarsCard(
      color: scheme.primaryContainer,
      radius: 28,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            Image.asset('assets/art/mochi/celebrate.png', width: 64, height: 64, excludeFromSemantics: true),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Every reward is yours. You found them all!',
                style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarnedList extends StatelessWidget {
  const _EarnedList({required this.rewards, required this.unlocks, required this.firstAt});

  final List<Reward> rewards;
  final UnlockState unlocks;

  /// 3-star pictures the first reward needs, for the empty state.
  final int? firstAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: rewards.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nothing yet. Finish pictures with 3 stars to earn your first reward'
                '${firstAt == null ? '' : ' at $firstAt'}.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          : Column(
              children: [
                for (final (i, r) in rewards.indexed) ...[
                  if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                  _EarnedRow(reward: r, at: unlocks.threshold(r)),
                ],
              ],
            ),
    );
  }
}

class _EarnedRow extends StatelessWidget {
  const _EarnedRow({required this.reward, required this.at});

  final Reward reward;
  final int at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = rewardInfo(reward);
    final ready = rewardReady(reward);
    return Semantics(
      container: true,
      label: '${info.name}, ${info.kind}, earned at $at three-star ${_pictures(at)}${ready ? '' : ', coming soon'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            RewardArt(reward: reward),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    '${info.kind} · at $at three-star',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!ready)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Coming soon',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MysteryRow extends StatelessWidget {
  const _MysteryRow({required this.at});

  final int at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Mystery reward, locked. At $at three-star ${_pictures(at)}.',
      excludeSemantics: true,
      child: LockedSurface(
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16)),
                child: Image.asset('assets/art/icons/mystery.png', excludeFromSemantics: true),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mystery reward', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('At $at three-star ${_pictures(at)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.lock_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Celebration ------------------------------------------------------------

/// After a finished picture: celebrates every reward that just opened, in one
/// card, and marks them celebrated so each is shown once. True when she taps
/// "See my unlocks". Does nothing when nothing new opened.
Future<bool> celebrateNewRewards(BuildContext context, ProgressStore store) async {
  final unlocks = store.currentUnlocks;
  final rewards = unlocks.newRewards;
  if (rewards.isEmpty) return false;
  // Marked first, so leaving the app mid-card never shows it twice.
  await store.markCelebrated([for (final r in rewards) r.id]);
  if (!context.mounted) return false;
  final see = await showDialog<bool>(
    context: context,
    builder: (_) => UnlockCelebration(rewards: rewards, unlocks: unlocks),
  );
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
    final name = one ? info.name : _list([for (final r in rewards) rewardInfo(r).name]);
    final at = widget.unlocks.threshold(rewards.last);
    final soon = rewards.any((r) => !rewardReady(r));
    final message = [
      if (one) info.blurb,
      'You earned ${one ? 'it' : 'them'} with $at three-star ${_pictures(at)}.',
      if (soon) one ? 'It arrives in an update soon.' : 'Some arrive in an update soon.',
    ].join(' ');
    final star = _star(context);
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
                              child: Image.asset('assets/art/${info.art}', width: 72, height: 72),
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
                      label: '$mascotName says: ${info.cheer}',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/art/mochi/celebrate.png', width: 72, height: 72),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '$mascotName: “${info.cheer}”',
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
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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

/// "A, B and C".
String _list(List<String> names) =>
    names.length == 1 ? names.first : '${names.take(names.length - 1).join(', ')} and ${names.last}';

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
