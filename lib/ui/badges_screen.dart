import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import 'badges.dart';
import 'theme/paw_widgets.dart';
import 'theme/tokens.dart';

/// Badges on their own screen (PAP-19 "Badges" board). PAP-20 builds the shell:
/// the overall hero, the nameplate with name editing and the badge list. Tier
/// frames with progress bars, the title picker and the rainbow slot come with PAP-48.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key, required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final settings = SettingsScope.maybeOf(context);
    final t = context.paw;
    final earned = earnedAchievements(courses, store);
    final shown = achievementsShown(courses, store);
    final pct = completionPercent(courses, store);
    final counted = shown.where((a) => a.tier != BadgeTier.rainbow && !a.retired).toList();
    final done = counted.where((a) => earned.contains(a.id)).length;
    final name = settings?.playerName ?? AppSettings.defaultPlayerName;
    final title = currentTitle(courses, store, earned: earned, shown: shown);
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _OverallHero(percent: pct, done: done, total: counted.length),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(PawRadius.tile),
              border: Border.all(color: t.outline),
              boxShadow: t.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your nameplate. It shows on Home.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                // Wraps the button under the nameplate on narrow phones and big text.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Nameplate(name: name, title: title),
                    if (settings != null)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
                        onPressed: () => editPlayerName(context, settings),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Name'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const StickerTitle(art: 'icons/badge.png', text: 'Series', artSize: 30),
          const SizedBox(height: 14),
          for (final a in shown) ...[
            _BadgeRow(badge: a, earned: earned.contains(a.id)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Asks for her name and saves it (at most [AppSettings.maxNameLength] letters).
Future<void> editPlayerName(BuildContext context, AppSettings settings) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(initial: settings.playerName),
  );
  if (name != null) await settings.setPlayerName(name);
}

/// Owns its text controller, so the controller lives until the dialog has
/// finished closing.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: AppSettings.maxNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: AppSettings.defaultPlayerName),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
        ],
      );
}

/// The one eared card on this screen: how much of the collection is earned.
class _OverallHero extends StatelessWidget {
  const _OverallHero({required this.percent, required this.done, required this.total});

  final int percent;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Semantics(
      label: 'Overall: $percent percent. $done of $total badges',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 30, top: -7, child: _Ear(color: t.soft)),
            Positioned(right: 30, top: -7, child: _Ear(color: t.soft)),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(PawRadius.hero)),
              child: Row(
                children: [
                  const Art('mochi/waving.png', size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Overall', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.onSoft)),
                        Text('$percent%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: t.onSoft)),
                        Row(
                          children: [
                            Expanded(child: PawBar(value: percent / 100, track: t.surface, height: 8)),
                            const SizedBox(width: 8),
                            Text(
                              '$done / $total',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.onSoft),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ear extends StatelessWidget {
  const _Ear({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: 0.785,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        ),
      );
}

/// One badge: its tier colors once earned, gray until then.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge, required this.earned});

  final Achievement badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final tier = t.tiers[badge.tier]!;
    final tierName = '${badge.tier.name[0].toUpperCase()}${badge.tier.name.substring(1)}';
    return Semantics(
      label: '${badge.title}, $tierName. ${badge.description}. ${earned ? 'Earned' : 'Not earned yet'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(PawRadius.tile),
          border: Border.all(color: t.outline),
          boxShadow: t.shadow,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: earned ? tier.fill : t.tint,
                borderRadius: BorderRadius.circular(PawRadius.tile),
                border: Border.all(color: earned ? tier.frame : t.outline, width: 3),
              ),
              child: Icon(badgeIcon(badge.id), size: 30, color: earned ? tier.frame : t.muted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.title,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.ink),
                        ),
                      ),
                      Text(
                        earned ? tierName : 'Locked',
                        style:
                            TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: earned ? tier.text : t.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(badge.description, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
