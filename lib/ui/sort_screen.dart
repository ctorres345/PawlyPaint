import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/courses.dart' show allCourses;
import '../logic/scoring.dart';
import '../logic/time_attack.dart';
import '../models/puzzle.dart';
import '../state/achievements.dart';
import '../state/display_rate.dart';
import '../state/music.dart';
import '../state/progress_store.dart';
import '../state/settings.dart';
import '../state/sort_controller.dart';
import 'board.dart' show BoardView, kCell;
import 'coach.dart';
import 'completion_sheet.dart';
import 'desk.dart';
import 'effect_clock.dart';
import 'gem_style.dart';
import 'layer_raster.dart';
import 'mini_map.dart';
import 'music_sheet.dart';
import 'star_meter.dart';
import 'unlock_ui.dart';
import 'unlock_celebration.dart';
import 'theme/paw_widgets.dart' show LightPlayTheme;

part 'sort/sort_state.dart';
part 'sort/sort_flow.dart';
part 'sort/sort_layout.dart';
part 'sort/sort_board.dart';
part 'sort/sort_tray.dart';
part 'sort/sort_hud.dart';

/// Sort mode: the picture starts scrambled. Tap misplaced beads to pick them
/// up, then tap the tray or an empty spot that wants their color.
class SortScreen extends StatelessWidget {
  const SortScreen({
    super.key,
    required this.puzzle,
    required this.store,
    this.daily = false,
    this.tutorial = false,
    this.timeAttack,
    this.seed = 0,
    this.dailyChallenge = false,
  });

  final Puzzle puzzle;
  final ProgressStore store;

  /// Opened from today's daily picture, so finishing it counts for the streak.
  final bool daily;

  /// The guided first picture: nothing is saved or scored.
  final bool tutorial;

  /// Set for a Time Attack run at this difficulty: a fresh board scrambled
  /// by [seed], against the clock, never saved.
  final Difficulty? timeAttack;

  /// Today's Time Attack challenge: the same board on every try, with its
  /// own best score.
  final bool dailyChallenge;
  final int seed;

  // The page sits under the light theme, so the dialogs and sheets it opens
  // from its own context are light too.
  @override
  Widget build(BuildContext context) => LightPlayTheme(builder: (_) => _SortPage(this));
}

class _SortPage extends StatefulWidget {
  const _SortPage(this.screen);

  final SortScreen screen;
  Puzzle get puzzle => screen.puzzle;
  ProgressStore get store => screen.store;
  bool get daily => screen.daily;
  bool get tutorial => screen.tutorial;
  Difficulty? get timeAttack => screen.timeAttack;
  bool get dailyChallenge => screen.dailyChallenge;
  int get seed => screen.seed;

  @override
  State<_SortPage> createState() => _SortScreenState();
}

class _SortScreenState extends _SortStateBase with _SortFlow, _SortLayout {}
