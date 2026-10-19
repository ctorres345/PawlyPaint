import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../state/progress_store.dart';
import 'gem_style.dart';

/// Every finished picture, to admire.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key, required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final text = Theme.of(context).textTheme;
    final done = [
      for (final c in courses)
        for (final p in c.puzzles)
          if (store.isCompleted(PlayMode.paint.key(p.id)) || store.isCompleted(PlayMode.sort.key(p.id))) (c, p),
    ];
    final total = courses.fold(0, (s, c) => s + c.puzzles.length);
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: done.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.collections_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Finished pictures will hang here.', style: text.titleMedium, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text('${done.length} of $total pictures finished', style: text.titleSmall),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: done.length,
                    itemBuilder: (context, i) {
                      final (course, puzzle) = done[i];
                      return Semantics(
                        button: true,
                        label: '${puzzle.title}, from ${course.title}',
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PictureViewer(puzzle: puzzle, course: course)),
                          ),
                          child: Hero(
                            tag: 'gallery-${puzzle.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(painter: PuzzleThumbPainter(puzzle, complete: true)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// One finished picture, full size, with its shimmer.
class PictureViewer extends StatefulWidget {
  const PictureViewer({super.key, required this.puzzle, required this.course});

  final Puzzle puzzle;
  final Course course;

  @override
  State<PictureViewer> createState() => _PictureViewerState();
}

class _PictureViewerState extends State<PictureViewer> with SingleTickerProviderStateMixin {
  late final AnimationController shimmer;
  late final paints = GemPaints.forPuzzle(widget.puzzle);

  @override
  void initState() {
    super.initState();
    shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) shimmer.stop();
  }

  @override
  void dispose() {
    shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final text = Theme.of(context).textTheme;
    Widget stars(PlayMode mode) {
      final r = store.record(mode.key(widget.puzzle.id));
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${mode.label} ', style: text.labelLarge),
          for (var s = 0; s < 3; s++)
            Icon(
              r != null && s < r.bestStars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: r != null && s < r.bestStars ? const Color(0xFFFFC107) : Theme.of(context).colorScheme.outline,
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1E7E1),
      appBar: AppBar(title: Text(widget.puzzle.title), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: widget.puzzle.width / widget.puzzle.height,
                    child: Hero(
                      tag: 'gallery-${widget.puzzle.id}',
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFFBF8F3),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CustomPaint(
                            painter: _FinishedPainter(widget.puzzle, paints, shimmer),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(widget.course.title, style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 24, children: [stars(PlayMode.paint), stars(PlayMode.sort)]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FinishedPainter extends CustomPainter {
  _FinishedPainter(this.puzzle, this.paints, this.shimmer) : super(repaint: shimmer);

  final Puzzle puzzle;
  final List<GemPaints> paints;
  final Animation<double> shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = math.min(size.width / puzzle.width, size.height / puzzle.height);
    final t = shimmer.value;
    final span = (puzzle.width + puzzle.height).toDouble();
    final band = t * 1.6 - 0.3;
    for (var i = 0; i < puzzle.cellCount; i++) {
      final x = i % puzzle.width, y = i ~/ puzzle.width;
      final rect = Rect.fromLTWH(x * cs, y * cs, cs, cs);
      drawGem(canvas, rect, paints[puzzle.cells[i]]);
      final shine = (1 - ((x + y) / span - band).abs() / 0.07).clamp(0.0, 1.0);
      if (shine > 0) drawGemShine(canvas, rect, shine);
      final hash = (i * 2654435761) & 0xFFFF;
      if (hash % 5 == 0) {
        final s = math.sin(2 * math.pi * (t * 3 + hash / 0xFFFF));
        if (s > 0.94) drawGemSparkle(canvas, rect, (s - 0.94) / 0.06);
      }
    }
  }

  @override
  bool shouldRepaint(_FinishedPainter old) => old.puzzle != puzzle;
}
