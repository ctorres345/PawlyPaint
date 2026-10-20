import 'package:flutter/material.dart';

import '../logic/boosters.dart';
import '../models/puzzle.dart';
import '../state/achievements.dart';
import 'badges.dart';
import 'booster_bar.dart' show boosterIcon;
import 'gem_style.dart';
import 'picture_export.dart';
import 'replay.dart';

Future<void> showCompletionSheet(
  BuildContext context, {
  required Puzzle puzzle,
  required int score,
  required int stars,
  required int seconds,
  required int mistakes,
  required bool isBest,
  bool relaxed = false,
  List<Achievement> badges = const [],
  Map<Booster, int> boosters = const {},
  int? bestCombo,
  int? secondsLeft,
  List<int>? replayOrder,
  String title = 'Masterpiece complete!',
  String done = 'Back to the course',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final time = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(puzzle.title, style: text.titleMedium?.copyWith(color: scheme.primary)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 160,
                  child: CustomPaint(painter: PuzzleThumbPainter(puzzle, complete: true)),
                ),
              ),
              const SizedBox(height: 16),
              if (relaxed) Text('Painted at your own pace.', style: text.titleMedium),
              if (!relaxed && secondsLeft == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 400 + i * 250),
                        curve: Curves.elasticOut,
                        builder: (context, v, child) => Transform.scale(scale: v, child: child),
                        child: Icon(
                          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 48,
                          color: i < stars ? const Color(0xFFFFC107) : scheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
              if (isBest && !relaxed) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.emoji_events_rounded, size: 18),
                  label: const Text('New best score'),
                  backgroundColor: scheme.tertiaryContainer,
                ),
              ],
              const SizedBox(height: 16),
              if (!relaxed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(label: 'Score', value: '$score'),
                    if (secondsLeft != null)
                      _Stat(
                          label: 'Time left',
                          value: '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}')
                    else
                      _Stat(label: 'Time', value: time),
                    if (bestCombo != null && bestCombo > 1)
                      _Stat(label: 'Best combo', value: '×$bestCombo')
                    else
                      _Stat(label: 'Mistakes', value: '$mistakes'),
                  ],
                ),
              if (boosters.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final MapEntry(key: b, value: n) in boosters.entries)
                      Chip(
                        avatar: Icon(boosterIcon(b), size: 18, color: scheme.primary),
                        label: Text('+$n ${b.label}'),
                        backgroundColor: scheme.primaryContainer,
                      ),
                  ],
                ),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final b in badges)
                      Chip(
                        avatar: Icon(badgeIcon(b.id), size: 18, color: const Color(0xFFFFA000)),
                        label: Text('New badge: ${b.title}'),
                        backgroundColor: const Color(0xFFFFF3C4),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  if (replayOrder != null && replayOrder.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => showReplay(context, puzzle: puzzle, order: replayOrder),
                      icon: const Icon(Icons.slow_motion_video_rounded),
                      label: const Text('Watch replay'),
                    ),
                  SavePictureButton(puzzle: puzzle),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(done),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: text.labelMedium),
      ],
    );
  }
}
