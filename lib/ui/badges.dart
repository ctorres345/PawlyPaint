import 'package:flutter/material.dart';

IconData badgeIcon(String id) => switch (id) {
      'first' => Icons.auto_awesome_rounded,
      'hard' => Icons.grid_on_rounded,
      'extreme' => Icons.bolt_rounded,
      'both' => Icons.swap_horiz_rounded,
      'sort5' => Icons.back_hand_rounded,
      'cleansort' => Icons.inventory_2_rounded,
      'stars10' => Icons.star_rounded,
      'combo10' => Icons.trending_up_rounded,
      'clock' => Icons.timer_rounded,
      'streak3' => Icons.local_fire_department_rounded,
      'streak7' => Icons.whatshot_rounded,
      'course' => Icons.collections_bookmark_rounded,
      'fan' => Icons.favorite_rounded,
      'half' => Icons.hourglass_bottom_rounded,
      'all' => Icons.emoji_events_rounded,
      'frame.it' => Icons.filter_frames_rounded,
      _ => Icons.military_tech_rounded,
    };
