import 'package:flutter/material.dart';

import '../logic/boosters.dart';
import '../logic/unlocks.dart';
import '../models/puzzle.dart';
import '../state/progress_store.dart';
import 'cat_mascot.dart';

/// What she still has to do to open [id], in one short sentence.
String unlockCondition(String id, {int starsLeft = 0}) {
  if (id.startsWith('course.')) return 'Earn $starsLeft more ${starsLeft == 1 ? 'star' : 'stars'} to open';
  switch (id) {
    case UnlockTables.modeSort:
      return 'Finish ${UnlockTables.sortAfterPaint} Paint ${UnlockTables.sortAfterPaint == 1 ? 'picture' : 'pictures'}'
          ' to open Sort';
    case UnlockTables.modeTimeAttack:
      return 'Finish ${UnlockTables.timeAttackAfterSort} Sort pictures to open Time Attack';
    case UnlockTables.modeDaily:
      return "Finish your first picture to open today's picture";
  }
  for (final b in Booster.values) {
    if (UnlockTables.boosterId(b) == id) {
      final n = UnlockTables.boosterAfterPaint[b]!;
      return 'Finish $n Paint ${n == 1 ? 'picture' : 'pictures'} to open the ${b.label}';
    }
  }
  return 'Keep playing to open this';
}

/// A short name for an unlock, for the "New!" lines.
String unlockLabel(String id, List<Course> courses) {
  if (id.startsWith('course.')) {
    final key = id.substring('course.'.length);
    for (final c in courses) {
      if (c.id == key) return c.title;
    }
    return 'A new course';
  }
  switch (id) {
    case UnlockTables.modeSort:
      return 'Sort mode';
    case UnlockTables.modeTimeAttack:
      return 'Time Attack';
    case UnlockTables.modeDaily:
      return "Today's picture";
  }
  for (final b in Booster.values) {
    if (UnlockTables.boosterId(b) == id) return b.label;
  }
  return id;
}

/// "6 courses, Sort, Time Attack and 4 boosters", or '' when nothing is named.
String unlockPhrase(Set<String> ids) {
  final courses = ids.where((i) => i.startsWith('course.')).length;
  final boosters = ids.where((i) => i.startsWith('booster.')).length;
  final parts = <String>[
    if (courses > 0) '$courses ${courses == 1 ? 'course' : 'courses'}',
    if (ids.contains(UnlockTables.modeSort)) 'Sort',
    if (ids.contains(UnlockTables.modeTimeAttack)) 'Time Attack',
    if (ids.contains(UnlockTables.modeDaily)) "today's picture",
    if (boosters > 0) '$boosters ${boosters == 1 ? 'booster' : 'boosters'}',
  ];
  if (parts.isEmpty) return '';
  return parts.length == 1 ? parts.first : '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
}

/// What just opened, as short names for the completion sheet. Marks them
/// celebrated, so each unlock is announced once.
List<String> takeNewUnlocks(ProgressStore store, List<Course> courses) {
  final ids = store.currentUnlocks.summary;
  if (ids.isEmpty) return const [];
  store.markCelebrated(ids);
  return [for (final id in ids) unlockLabel(id, courses)];
}

/// Shows the one catch-up summary, then marks everything in it celebrated.
Future<void> showCatchUp(BuildContext context, ProgressStore store, Set<String> ids) async {
  final list = unlockPhrase(ids);
  if (list.isEmpty) return;
  await showMochiDialog(context, title: 'Welcome back!', message: "You've unlocked $list.", button: "Let's paint");
  await store.markCelebrated(ids);
}

/// A short, friendly dialog from Mochi with one button.
Future<void> showMochiDialog(
  BuildContext context, {
  required String title,
  required String message,
  String button = 'Got it',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const CatMascot(size: 72),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(button),
        ),
      ],
    ),
  );
}

/// Tells her what a locked thing needs, in a snackbar.
void showLockedHint(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// The look of a locked card: dimmed, dashed outline, readable text.
class LockedSurface extends StatelessWidget {
  const LockedSurface({super.key, required this.child, this.radius = 24});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      foregroundPainter: _DashedBorder(scheme.outline, radius),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: DefaultTextStyle.merge(style: TextStyle(color: scheme.onSurfaceVariant), child: child),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, (d + 6).clamp(0, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
