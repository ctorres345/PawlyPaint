import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/rewards.dart';
import '../logic/unlocks.dart';
import '../state/progress_store.dart';
import 'cat_mascot.dart';
import 'unlock_ui.dart';

/// The star color of the PAP-19 tokens, light and dark.
Color starColor(BuildContext context) =>
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
    final next = UnlockTables.rewardById(unlocks.nextReward?.id);
    final earned = <Reward>[], hidden = <Reward>[];
    for (final r in UnlockTables.rewards) {
      if (unlocks.isUnlocked(r.id)) {
        earned.add(r);
      } else if (r != next) {
        hidden.add(r);
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlocks'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              label: '${unlocks.threeStars} three-star ${picturesWord(unlocks.threeStars)}',
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration:
                    BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: starColor(context)),
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
            constraints: const BoxConstraints(minHeight: 38),
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

/// Art from `assets/art/` in a rounded tile.
class ArtTile extends StatelessWidget {
  const ArtTile({super.key, required this.art, this.size = 48, this.color});

  /// Path under `assets/art/`.
  final String art;
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
        child: Image.asset('assets/art/$art', fit: BoxFit.contain, excludeFromSemantics: true),
      );
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.reward, required this.unlocks});

  final Reward reward;
  final UnlockState unlocks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = rewardInfo(reward);
    final need = unlocks.threshold(reward);
    final left = unlocks.nextReward!.remaining;
    final have = need - left;
    return Semantics(
      container: true,
      label: 'Next unlock: ${info.name}. $left more three-star ${picturesWord(left)}. $have of $need.',
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
                    ArtTile(art: info.art, color: scheme.surface),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          Text('$left more three-star ${picturesWord(left)}', style: const TextStyle(fontSize: 14)),
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
    final ready = info.ready;
    return Semantics(
      container: true,
      label: '${info.name}, ${info.kind}, earned at $at three-star ${picturesWord(at)}${ready ? '' : ', coming soon'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ArtTile(art: info.art),
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
              // A status, not a button: an icon and muted text, no fill or border.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Coming soon',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                  ),
                ],
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
      label: 'Mystery reward, locked. At $at three-star ${picturesWord(at)}.',
      excludeSemantics: true,
      child: LockedSurface(
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ArtTile(art: 'icons/mystery.png', color: scheme.surface),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mystery reward', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('At $at three-star ${picturesWord(at)}',
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
