import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import 'gem_style.dart';
import 'picture_export.dart';

/// Plays back a finished picture filling in, drill by drill, in the order
/// they went down.
Future<void> showReplay(BuildContext context, {required Puzzle puzzle, required List<int> order}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: _Replay(puzzle: puzzle, order: order),
    ),
  );
}

class _Replay extends StatefulWidget {
  const _Replay({required this.puzzle, required this.order});

  final Puzzle puzzle;
  final List<int> order;

  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> with SingleTickerProviderStateMixin {
  late final paints = GemPaints.forPuzzle(widget.puzzle);
  late final _cache = _ChunkCache();

  // About 4ms a drill, kept between 3 and 8 seconds.
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.order.length * 4).clamp(3000, 8000)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How you painted it', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Flexible(
            child: AspectRatio(
              aspectRatio: p.width / p.height,
              child: Semantics(
                label: 'Replay of ${p.title} being painted',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(painter: _ReplayPainter(p, paints, widget.order, _c, _cache)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _c.forward(from: 0),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Watch again'),
              ),
              SavePictureButton(puzzle: p),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recorded pictures of the drills in blocks of [size], so each frame only
/// draws the newest few by hand.
class _ChunkCache {
  static const size = 256;
  final pictures = <ui.Picture>[];
  double? cell;

  void dispose() {
    for (final p in pictures) {
      p.dispose();
    }
    pictures.clear();
  }
}

class _ReplayPainter extends CustomPainter {
  _ReplayPainter(this.puzzle, this.paints, this.order, this.progress, this.cache) : super(repaint: progress);

  final Puzzle puzzle;
  final List<GemPaints> paints;
  final List<int> order;
  final Animation<double> progress;
  final _ChunkCache cache;

  Rect _rect(int i, double cell) => Rect.fromLTWH((i % puzzle.width) * cell, (i ~/ puzzle.width) * cell, cell, cell);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / puzzle.width;
    if (cache.cell != cell) {
      cache
        ..dispose()
        ..cell = cell;
    }
    // The empty canvas: each spot faintly shows its color.
    for (var i = 0; i < puzzle.cellCount; i++) {
      canvas.drawRect(_rect(i, cell).inflate(0.2), paints[puzzle.cells[i]].pale);
    }
    final shown = (Curves.easeInOut.transform(progress.value) * order.length).round();
    final full = shown ~/ _ChunkCache.size;
    while (cache.pictures.length < full) {
      final start = cache.pictures.length * _ChunkCache.size;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var k = start; k < start + _ChunkCache.size; k++) {
        drawGem(c, _rect(order[k], cell), paints[puzzle.cells[order[k]]]);
      }
      cache.pictures.add(rec.endRecording());
    }
    for (var k = 0; k < full; k++) {
      canvas.drawPicture(cache.pictures[k]);
    }
    for (var k = full * _ChunkCache.size; k < shown; k++) {
      // The newest few drills pop as they land.
      final pop = 0.3 * math.max(0, 1 - (shown - k) / 12);
      drawGem(canvas, _rect(order[k], cell), paints[puzzle.cells[order[k]]], pop: pop);
    }
  }

  @override
  bool shouldRepaint(_ReplayPainter old) => old.order != order || old.paints != paints;
}
