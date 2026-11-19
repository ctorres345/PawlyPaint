import 'package:flutter/material.dart';

import '../data/courses.dart' show unlockAfter;
import '../data/tutorial.dart';
import '../logic/unlocks.dart';
import '../models/puzzle.dart';
import '../state/progress_store.dart';
import 'game_screen.dart';
import 'coach.dart';
import 'gem_style.dart';
import 'sort_screen.dart';
import 'theme/paw_widgets.dart';
import 'theme/tokens.dart';
import 'unlock_ui.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.course});

  final Course course;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  /// Remembered while the app is open, so going back keeps the same mode.
  static PlayMode _lastMode = PlayMode.paint;
  PlayMode mode = _lastMode;

  Course get course => widget.course;

  static double? _sortProgress(Map<String, dynamic>? save, Puzzle p) {
    final board = save?['board'];
    if (save?['signature'] != p.signature || board is! String || board.length != p.cellCount) return null;
    var right = 0;
    for (var i = 0; i < p.cellCount; i++) {
      if (board.codeUnitAt(i) - 0x41 == p.cells[i]) right++;
    }
    return right / p.cellCount;
  }

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final t = context.paw;
    final sortOpen = store.currentUnlocks.isModeOpen(UnlockTables.modeSort);
    // Sort may still be locked when it was remembered from before; show Paint then.
    final shown = !sortOpen && mode == PlayMode.sort ? PlayMode.paint : mode;
    final stars = store.starsIn(course.puzzles);
    final maxStars = ProgressStore.maxStarsIn(course.puzzles);
    final sorting = shown == PlayMode.sort;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: t.courseTint(courseTintOf(course)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(PawRadius.hero)),
              ),
              padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 4, 4, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const BackButton(),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(course.title, style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: PawChip(
                          color: context.paw.surface,
                          icon: Icons.star_rounded,
                          label: '$stars / $maxStars',
                          semanticLabel: '$stars of $maxStars stars',
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: PawSegmented<PlayMode>(
                      items: [
                        (PlayMode.paint, 'Paint', Icons.brush_rounded),
                        (PlayMode.sort, 'Sort', sortOpen ? Icons.swap_horiz_rounded : Icons.lock_rounded),
                      ],
                      selected: shown,
                      onSelect: (m) {
                        if (m == PlayMode.sort && !sortOpen) {
                          showLockedHint(context, unlockCondition(UnlockTables.modeSort));
                          return;
                        }
                        setState(() => mode = _lastMode = m);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (var l = 0; l < course.levels.length; l++) ..._level(context, store, l, shown, sorting),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _level(BuildContext context, ProgressStore store, int l, PlayMode shown, bool sorting) {
    final level = course.levels[l];
    final open = store.isLevelUnlocked(course, l, shown);
    final previous = l == 0 ? null : course.levels[l - 1];
    final header = SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, l == 0 ? 18 : 24, 16, 12),
        child: _LevelHeader(
          level: level,
          open: open,
          completed: store.completedIn(level.puzzles, shown),
          stars:
              [for (final p in level.puzzles) store.record(shown.key(p.id))?.bestStars ?? 0].fold(0, (a, b) => a + b),
        ),
      ),
    );
    if (!open) {
      final have = store.completedIn(previous!.puzzles, shown).clamp(0, unlockAfter);
      return [
        header,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LockedLevel(
              message: 'Finish $unlockAfter ${previous.difficulty.label} pictures to open ${level.difficulty.label}',
              have: have,
              need: unlockAfter,
            ),
          ),
        ),
      ];
    }
    // The first open picture not finished yet is the one to play next.
    final next = [
      for (var i = 0; i < level.puzzles.length; i++)
        if (!store.isCompleted(shown.key(level.puzzles[i].id)) && store.isPuzzleUnlocked(level, i, shown)) i,
    ].firstOrNull;
    return [
      header,
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .8,
          ),
          itemCount: level.puzzles.length,
          itemBuilder: (context, i) {
            final puzzle = level.puzzles[i];
            return _PuzzleTile(
              index: i,
              puzzle: puzzle,
              // A picture already played (say, as the daily picture) stays open.
              unlocked: store.isPuzzleUnlocked(level, i, shown) || store.isCompleted(shown.key(puzzle.id)),
              next: i == next,
              lockedHint: 'Finish the picture before this one to unlock it.',
              record: store.record(shown.key(puzzle.id)),
              saved: sorting ? null : store.savedFor(puzzle),
              sortProgress: sorting ? _sortProgress(store.sortSaved(puzzle.id), puzzle) : null,
              onOpen: () => openWithTutorial(
                context,
                mode: shown,
                store: store,
                tutorial: () => sorting
                    ? SortScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true)
                    : GameScreen(puzzle: tutorialPuzzle(), store: store, tutorial: true),
                open: () =>
                    sorting ? SortScreen(puzzle: puzzle, store: store) : GameScreen(puzzle: puzzle, store: store),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// A difficulty as a colored sticker with Mochi, and how far she is in it.
class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.level, required this.open, required this.completed, required this.stars});

  final Level level;
  final bool open;
  final int completed;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final total = level.puzzles.length;
    final d = level.difficulty;
    return StickerHeader(
      title: StickerTitle(
        art: difficultyArt(d),
        text: d.label,
        artSize: 34,
        fontSize: 19,
        color: open ? difficultyColors[d] : t.tint,
        foreground: open ? fixedInk : t.muted,
        gray: !open,
      ),
      trailing: open
          ? MiniChip(
              label: stars > 0 ? '$completed/$total · $stars of ${total * 3} stars' : '$completed/$total',
              semanticLabel: '$completed of $total finished, $stars of ${total * 3} stars',
            )
          : PawChip(icon: Icons.lock_rounded, iconColor: t.ink, label: 'Locked'),
    );
  }
}

/// What a locked difficulty needs, with a bar.
class _LockedLevel extends StatelessWidget {
  const _LockedLevel({required this.message, required this.have, required this.need});

  final String message;
  final int have;
  final int need;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    return Semantics(
      label: '$message. $have of $need',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: DashedBorder(t.outline, PawRadius.tile, width: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: t.tint, borderRadius: BorderRadius.circular(PawRadius.tile)),
          child: Row(
            children: [
              Icon(Icons.lock_rounded, color: t.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: PawBar(value: have / need, track: t.surface)),
                        const SizedBox(width: 8),
                        Text('$have / $need', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.index,
    required this.puzzle,
    required this.unlocked,
    required this.next,
    required this.lockedHint,
    required this.record,
    required this.saved,
    this.sortProgress,
    required this.onOpen,
  });

  final int index;
  final Puzzle puzzle;
  final bool unlocked;

  /// The picture to play next: an accent ring and "Play next".
  final bool next;
  final String lockedHint;
  final PuzzleRecord? record;
  final SavedGame? saved;

  /// Share of beads already in place for a Sort game in progress.
  final double? sortProgress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.paw;
    final done = record != null;
    final progress = sortProgress ?? (saved == null ? 0.0 : saved!.placedCount / puzzle.cellCount);
    final started = !done && (saved != null || sortProgress != null);
    final label = done
        ? '${puzzle.title}, ${record!.bestStars} of 3 stars, best score ${record!.bestScore}'
        : !unlocked
            ? 'Picture ${index + 1}, locked'
            : started
                ? 'Picture ${index + 1}, ${(progress * 100).floor()} percent done'
                : 'Picture ${index + 1}${next ? ', play next' : ''}, ${puzzle.width} by ${puzzle.height}, ${puzzle.colorCount} colors';
    final Widget foot;
    if (done && record!.bestStars == 0) {
      foot = Icon(Icons.check_circle_rounded, size: 16, color: t.success);
    } else if (done) {
      foot = StarRow(stars: record!.bestStars);
    } else if (started) {
      foot = Text('${(progress * 100).floor()}%', style: _foot(t.ink));
    } else if (unlocked && next) {
      foot = Text('Play next', style: _foot(t.accent));
    } else if (unlocked) {
      foot = Text('Open', style: _foot(t.ink));
    } else {
      foot = Text('Mystery', style: _foot(t.muted, FontWeight.w600));
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(PawRadius.tile), boxShadow: t.shadow),
        child: Material(
          color: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PawRadius.tile),
            side: BorderSide(color: next ? t.accent : t.outline, width: next ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: unlocked ? onOpen : () => showLockedHint(context, lockedHint),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: done || started
                          ? CustomPaint(
                              painter: PuzzleThumbPainter(puzzle, placed: saved?.placed, complete: done),
                              child: const SizedBox.expand(),
                            )
                          : ColoredBox(
                              color: t.tint,
                              child: Center(child: Icon(Icons.help_rounded, size: 36, color: t.muted)),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(height: 18, child: FittedBox(fit: BoxFit.scaleDown, child: foot)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static TextStyle _foot(Color c, [FontWeight w = FontWeight.w700]) => TextStyle(fontSize: 13, fontWeight: w, color: c);
}
