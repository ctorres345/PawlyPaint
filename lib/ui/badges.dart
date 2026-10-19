import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/progress_store.dart';

IconData badgeIcon(String id) => switch (id) {
      'first' => Icons.auto_awesome_rounded,
      'hard' => Icons.grid_on_rounded,
      'both' => Icons.swap_horiz_rounded,
      'sort5' => Icons.back_hand_rounded,
      'cleansort' => Icons.inventory_2_rounded,
      'stars10' => Icons.star_rounded,
      'streak3' => Icons.local_fire_department_rounded,
      'streak7' => Icons.whatshot_rounded,
      'course' => Icons.collections_bookmark_rounded,
      'fan' => Icons.favorite_rounded,
      'half' => Icons.hourglass_bottom_rounded,
      'all' => Icons.emoji_events_rounded,
      _ => Icons.military_tech_rounded,
    };

/// A grid of every badge, earned ones in gold.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.courses, required this.store});

  final List<Course> courses;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final earned = earnedAchievements(courses, store);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in achievements)
          Semantics(
            label: '${a.title}: ${a.description}. ${earned.contains(a.id) ? 'Earned' : 'Not earned yet'}',
            excludeSemantics: true,
            child: Tooltip(
              message: a.description,
              triggerMode: TooltipTriggerMode.tap,
              child: Container(
                width: 104,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: earned.contains(a.id) ? const Color(0xFFFFF3C4) : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      badgeIcon(a.id),
                      size: 30,
                      color: earned.contains(a.id) ? const Color(0xFFFFA000) : scheme.outline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.title,
                      style: text.labelMedium,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
