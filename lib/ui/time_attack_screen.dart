import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/tutorial.dart';
import '../logic/time_attack.dart';
import '../models/puzzle.dart';
import '../state/progress_store.dart';
import 'coach.dart';
import 'sort_screen.dart';

/// Time Attack: pick a difficulty, then sort a random picture of that size
/// before the clock runs out.
class TimeAttackScreen extends StatelessWidget {
  const TimeAttackScreen({super.key, required this.courses});

  final List<Course> courses;

  static final _rng = math.Random();

  void _play(BuildContext context, ProgressStore store, Difficulty d) {
    final pool = [
      for (final c in courses)
        for (final l in c.levels)
          if (l.difficulty == d) ...l.puzzles
    ];
    if (pool.isEmpty) return;
    final puzzle = pool[_rng.nextInt(pool.length)];
    _open(context, store, () => SortScreen(puzzle: puzzle, store: store, timeAttack: d, seed: _rng.nextInt(1 << 30)));
  }

  void _playDaily(BuildContext context, ProgressStore store) {
    final today = TimeAttack.daily(DateTime.now(), courses);
    _open(
      context,
      store,
      () => SortScreen(
        puzzle: today.puzzle,
        store: store,
        timeAttack: today.difficulty,
        seed: today.seed,
        dailyChallenge: true,
      ),
    );
  }

  void _open(BuildContext context, ProgressStore store, Widget Function() open) => openWithTutorial(
        context,
        mode: PlayMode.sort,
        store: store,
        tutorial: () => SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true),
        open: open,
      );

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Time Attack')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Sort a surprise picture before the clock runs out. Every good drop adds a second, '
            'big combos add two. Hints and shakes cost ${TimeAttack.helpCost} seconds.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          _DailyChallengeCard(
            difficulty: TimeAttack.daily(DateTime.now(), courses).difficulty,
            record: store.dailyTimeAttack(DateTime.now()),
            onPlay: () => _playDaily(context, store),
          ),
          const SizedBox(height: 20),
          Text('Free play', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final d in Difficulty.values) ...[
            _DifficultyCard(
              difficulty: d,
              record: store.timeAttack(d),
              unlocked: store.isTimeAttackUnlocked(d),
              onPlay: () => _play(context, store, d),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({required this.difficulty, required this.record, required this.unlocked, required this.onPlay});

  final Difficulty difficulty;
  final TimeAttackRecord record;
  final bool unlocked;
  final VoidCallback onPlay;

  static const _colors = {
    Difficulty.easy: Color(0xFF81C784),
    Difficulty.medium: Color(0xFF64B5F6),
    Difficulty.hard: Color(0xFFBA68C8),
    Difficulty.extreme: Color(0xFFFF8A65),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = _colors[difficulty]!;
    final previous = difficulty.index > 0 ? Difficulty.values[difficulty.index - 1] : null;
    final left = record.bestLeft;
    return Semantics(
      button: true,
      label: unlocked
          ? '${difficulty.label}, best score ${record.bestScore}, ${record.wins} wins'
          : '${difficulty.label}, locked',
      excludeSemantics: true,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color.lerp(accent, Colors.white, 0.6)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: unlocked
                ? onPlay
                : () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text('Win a ${previous!.label} round to unlock ${difficulty.label}.'),
                    behavior: SnackBarBehavior.floating,
                  )),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(unlocked ? Icons.timer_rounded : Icons.lock_rounded, size: 36, color: scheme.onSurface),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(difficulty.label, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          unlocked
                              ? record.plays == 0
                                  ? 'Not played yet'
                                  : '${record.wins > 0 ? 'Best ${record.bestScore} · ' : ''}${record.wins}/${record.plays} won'
                                      '${record.bestCombo > 1 ? ' · combo ×${record.bestCombo}' : ''}'
                              : 'Win a ${previous!.label} round to unlock',
                          style: text.bodyMedium,
                        ),
                        if (unlocked && record.wins > 0)
                          Text(
                            'Most time left: ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                            style: text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (unlocked) const Icon(Icons.play_arrow_rounded, size: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's challenge: the same surprise board all day, so every try is a
/// shot at a better score.
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({required this.difficulty, required this.record, required this.onPlay});

  final Difficulty difficulty;
  final TimeAttackRecord record;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = record.plays == 0
        ? 'A new board every day. Same picture on every try.'
        : record.wins == 0
            ? 'Not beaten yet · ${record.plays} ${record.plays == 1 ? 'try' : 'tries'}'
            : 'Best today ${record.bestScore} · ${record.plays} ${record.plays == 1 ? 'try' : 'tries'}';
    return Semantics(
      button: true,
      label: "Today's challenge, ${difficulty.label}. $status",
      excludeSemantics: true,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  record.wins > 0 ? Icons.emoji_events_rounded : Icons.today_rounded,
                  size: 36,
                  color: record.wins > 0 ? const Color(0xFFFFB300) : scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's challenge · ${difficulty.label}",
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(status, style: text.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow_rounded, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
