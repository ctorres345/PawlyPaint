import 'package:flutter/material.dart';

import '../state/achievements.dart';

IconData badgeIcon(String id) => switch (id) {
      'first' => Icons.auto_awesome_rounded,
      'hard' => Icons.grid_on_rounded,
      'extreme' => Icons.local_fire_department_rounded,
      'both' => Icons.swap_horiz_rounded,
      'sort5' => Icons.back_hand_rounded,
      'cleansort' => Icons.inventory_2_rounded,
      'stars10' => Icons.workspace_premium_rounded,
      'combo10' => Icons.bolt_rounded,
      'clock' => Icons.timer_rounded,
      'streak3' => Icons.calendar_month_rounded,
      'streak7' => Icons.whatshot_rounded,
      'course' => Icons.collections_bookmark_rounded,
      'fan' => Icons.favorite_rounded,
      'half' => Icons.hourglass_bottom_rounded,
      'all' => Icons.emoji_events_rounded,
      'gallery.bronze' => Icons.photo_library_rounded,
      'platinum' => Icons.diamond_rounded,
      'frame.it' => Icons.filter_frames_rounded,
      _ when id.startsWith('course.') => Icons.collections_bookmark_rounded,
      _ => Icons.military_tech_rounded,
    };

/// The tier's name with a capital, as the badge rows show it.
String tierName(BadgeTier tier) => '${tier.name[0].toUpperCase()}${tier.name.substring(1)}';

/// The line that announces [b], with its tier: "New gold badge: Perfectionist". A title that already ends
/// with its tier ("Perfectionist gold") drops it, so the tier is said once.
String newBadgeLabel(Achievement b) {
  final suffix = ' ${b.tier.name}';
  final title = b.title.toLowerCase().endsWith(suffix) ? b.title.substring(0, b.title.length - suffix.length) : b.title;
  return 'New ${b.tier.name} badge: $title';
}
