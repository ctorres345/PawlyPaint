import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import 'badges.dart';
import 'theme/paw_widgets.dart';
import 'theme/tokens.dart';

/// Badges on their own screen (PAP-19 "Badges" board): the overall hero, the
/// nameplate with name editing and the title picker, the rainbow slot when a
/// rainbow badge is registered, platinum, then each series with its tier frame
/// and a bar toward its next step (PAP-48).
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key, required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final settings = SettingsScope.maybeOf(context);
    final t = context.paw;
    final (:facts, :earned) = badgeSnapshot(courses, store);
    final shown = achievementsShown(courses, store);
    final pct = completionPercent(courses, store, earned: earned);
    final counted = shown.where(countsTowardCompletion).toList();
    final done = counted.where((a) => earned.contains(a.id)).length;
    final name = settings?.playerName ?? AppSettings.defaultPlayerName;
    final best = currentTitleChoice(courses, store, earned: earned, shown: shown);
    final title = currentTitleChoice(courses, store, chosen: settings?.playerTitle, earned: earned, shown: shown);
    final rows = badgeRows(shown, earned);
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _OverallHero(percent: pct, done: done, total: counted.length),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                    Nameplate(name: name, title: title.title, tier: title.tier),
                    if (settings != null)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
                        onPressed: () => editPlayerName(context, settings),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Name'),
                      ),
                  ],
                ),
                if (settings != null) ...[
                  const SizedBox(height: 14),
                  Text('Pick a title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
                  const SizedBox(height: 4),
                  for (final c in titleChoices(shown, earned))
                    _TitleRow(
                      choice: c,
                      selected: c.title == title.title,
                      // Picking her best title clears the choice, so a better one she earns later is worn.
                      onPick: () => settings.setPlayerTitle(c.title == best.title ? null : c.title),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final a in shown)
            if (a.tier == BadgeTier.rainbow) ...[
              _RainbowRow(badge: a, earned: earned.contains(a.id)),
              const SizedBox(height: 10),
            ],
          for (final a in shown)
            if (a.tier == BadgeTier.platinum) ...[
              _BadgeRow(row: BadgeRowView([a], earned), facts: facts, courses: courses),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 10),
          const StickerTitle(art: 'icons/badge.png', text: 'Series', artSize: 30),
          const SizedBox(height: 14),
          for (final r in rows)
            if (r.isSeries) ...[
              _BadgeRow(row: r, facts: facts, courses: courses),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 10),
          const StickerTitle(icon: Icons.military_tech_rounded, text: 'Milestones'),
          const SizedBox(height: 14),
          for (final r in rows)
            if (!r.isSeries) ...[
              _BadgeRow(row: r, facts: facts, courses: courses),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// One note for badges she had already earned when they reached the app, such as after an update.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showEarnedBadgesSummary(
  BuildContext context,
  List<Achievement> badges, {
  required VoidCallback onOpen,
}) {
  final text = badges.length == 1
      ? '${newBadgeLabel(badges.single)}. You had already earned it!'
      : '${badges.length} badges you had already earned are in your collection!';
  return ScaffoldMessenger.of(context).showSnackBar(
    // Leaves by itself: a note with a button would otherwise stay until tapped.
    SnackBar(
      content: Text(text),
      // Floats above Home's dock and unlock strip, like the app's other notes, instead of covering them.
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 164),
      persist: false,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: 'See badges', onPressed: onOpen),
    ),
  );
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

/// One title in the picker: checked when she wears it, a lock until its badge is earned.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.choice, required this.selected, required this.onPick});

  final TitleChoice choice;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final badge = choice.badge;
    final from = switch (badge) {
      null => 'Starter title',
      // Course Champ comes from any course's gold, not only the first one listed.
      _ when courseMasterOf(badge.series) != null => 'Course master ${badge.tier.name}, any course',
      // Series badges name the series and tier, as the rows below do: "Perfectionist gold".
      Achievement(:final series?, retired: false) => '$series ${badge.tier.name}',
      _ => badge.title,
    };
    final color = selected ? t.onSoft : (choice.earned ? t.ink : t.muted);
    return Semantics(
      label: '${choice.title}, from $from${choice.earned ? '' : '. Locked'}',
      selected: selected,
      checked: selected,
      button: choice.earned && !selected,
      enabled: choice.earned,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      // The InkWell's own tap is excluded with its semantics, so screen readers get it here.
      onTap: choice.earned && !selected ? onPick : null,
      child: Material(
        color: selected ? t.soft : Colors.transparent,
        borderRadius: BorderRadius.circular(PawRadius.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(PawRadius.tile),
          onTap: choice.earned && !selected ? onPick : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : choice.earned
                            ? Icons.radio_button_unchecked_rounded
                            : Icons.lock_rounded,
                    size: 20,
                    color: selected ? t.onSoft : t.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      choice.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      from,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 12, color: selected ? t.onSoft : t.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The square frame a badge row leads with: its tier's colors, or gray while locked.
class _TierFrame extends StatelessWidget {
  const _TierFrame({required this.icon, this.tier});

  final IconData icon;

  /// Null while locked.
  final BadgeTier? tier;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final c = tier == null ? null : t.tiers[tier]!;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: c?.fill ?? t.tint,
        borderRadius: BorderRadius.circular(PawRadius.tile),
        border: Border.all(color: c?.frame ?? t.outline, width: 3),
      ),
      child: Icon(icon, size: 30, color: c?.frame ?? t.muted),
    );
  }
}

/// One row: a series framed in its highest earned tier with a bar toward its next step,
/// or a single badge.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.row, required this.facts, required this.courses});

  final BadgeRowView row;
  final ProgressFacts facts;
  final List<Course> courses;

  String get _name {
    final first = row.steps.first;
    final series = first.series;
    if (!row.isSeries || series == null) return first.title;
    final id = courseMasterOf(series);
    if (id == null) return series;
    final course = courses.where((c) => c.id == id).firstOrNull;
    return '${course?.title ?? id} master';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final top = row.top;
    final next = row.next;
    final tier = top == null ? null : t.tiers[top.tier]!;
    final status = top == null ? 'Locked' : tierName(top.tier);
    // Toward the next step, or the last one once the row is complete. A one-step goal has no bar.
    final p = badgeProgress(next ?? row.steps.last, facts);
    final caption = switch ((row.isSeries, next)) {
      // "Gold at 40 finished pictures"; a goal of one reads better as its description.
      (true, Achievement(:final tier, :final unit?)) when p != null && p.target > 1 =>
        '${tierName(tier)} at ${p.target} $unit',
      (true, final Achievement n) => '${tierName(n.tier)} next: ${n.description}',
      (true, null) => 'Top tier reached',
      (false, _) => row.steps.first.description,
    };
    // Every series row shows its count, even while its first step needs only one.
    final bar = p != null && (row.isSeries || p.target > 1) ? p : null;
    return Semantics(
      label: '$_name, $status. $caption.${bar == null ? '' : ' ${bar.current} of ${bar.target}'}',
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
            _TierFrame(icon: badgeIcon(row.steps.first.id), tier: top?.tier),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.ink)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tier?.text ?? t.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                  if (bar != null) ...[const SizedBox(height: 6), _CountBar(progress: bar)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar with its count beside it ("37 / 50"), or under it when big text leaves the bar no room.
class _CountBar extends StatelessWidget {
  const _CountBar({required this.progress});

  final BadgeProgress progress;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final text = '${progress.current} / ${progress.target}';
    final style = DefaultTextStyle.of(context).style.merge(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink),
        );
    final label = Text(text, style: style);
    final bar = PawBar(value: progress.current / progress.target, height: 8);
    return LayoutBuilder(builder: (context, box) {
      // The count's width at this text size, plus room for a bar worth reading.
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final countWidth = painter.width;
      painter.dispose();
      if (box.maxWidth >= countWidth + 8 + 48) {
        return Row(children: [Expanded(child: bar), const SizedBox(width: 8), label]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [bar, const SizedBox(height: 4), label],
      );
    });
  }
}

/// The rainbow slot: a private badge (PAP-27) above platinum, in a frame that slowly turns
/// through the rainbow. Still when the phone asks for reduced motion. Its name stays hidden
/// until it is earned.
class _RainbowRow extends StatefulWidget {
  const _RainbowRow({required this.badge, required this.earned});

  final Achievement badge;
  final bool earned;

  @override
  State<_RainbowRow> createState() => _RainbowRowState();
}

class _RainbowRowState extends State<_RainbowRow> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final name = widget.earned ? widget.badge.title : 'Rainbow';
    final caption = widget.earned ? widget.badge.description : 'A secret badge. Keep playing!';
    return Semantics(
      label: '$name, rainbow tier. $caption',
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
            AnimatedBuilder(
              animation: _spin,
              builder: (context, child) => Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PawRadius.tile),
                  gradient: SweepGradient(
                    colors: rainbowColors,
                    transform: GradientRotation(_spin.value * 2 * math.pi),
                  ),
                ),
                child: child,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(PawRadius.tile - 3),
                ),
                child: Icon(
                  widget.earned ? Icons.auto_awesome_rounded : Icons.question_mark_rounded,
                  size: 30,
                  color: widget.earned ? t.ink : t.muted,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: widget.earned ? t.ink : t.muted)),
                  const SizedBox(height: 2),
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
