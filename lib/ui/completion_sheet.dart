import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import 'gem_style.dart';

Future<void> showCompletionSheet(
  BuildContext context, {
  required Puzzle puzzle,
  required int score,
  required int stars,
  required int seconds,
  required int mistakes,
  required bool isBest,
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
              Text('Masterpiece complete!', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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
              if (isBest) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.emoji_events_rounded, size: 18),
                  label: const Text('New best score'),
                  backgroundColor: scheme.tertiaryContainer,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(label: 'Score', value: '$score'),
                  _Stat(label: 'Time', value: time),
                  _Stat(label: 'Mistakes', value: '$mistakes'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to the course'),
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
