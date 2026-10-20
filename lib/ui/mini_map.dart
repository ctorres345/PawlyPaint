import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import 'board.dart';
import 'gem_style.dart';

/// A small copy of the whole canvas with a box around the part on screen.
/// Shown only while zoomed in; tap or drag it to move around.
class MiniMap extends StatefulWidget {
  const MiniMap({super.key, required this.game, required this.view, required this.paints, this.maxSide = 96});

  final GameController game;
  final BoardView view;
  final List<GemPaints> paints;
  final double maxSide;

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> {
  final _cache = _MapCache();

  BoardView get view => widget.view;

  /// Whether some of the canvas is off screen.
  bool get _zoomedIn {
    if (view.viewport.isEmpty) return false;
    final r = view.visibleCells;
    return r.left > 0.5 || r.top > 0.5 || r.right < view.cols - 0.5 || r.bottom < view.rows - 0.5;
  }

  void _jump(Offset local, Size size) {
    final p = widget.game.puzzle;
    view.centerOn(local.dx / size.width * p.width, local.dy / size.height * p.height);
  }

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.game.puzzle;
    final cell = widget.maxSide / math.max(p.width, p.height);
    final size = Size(p.width * cell, p.height * cell);
    return ListenableBuilder(
      listenable: view,
      builder: (context, _) => IgnorePointer(
        ignoring: !_zoomedIn,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _zoomedIn ? 1 : 0,
          child: Semantics(
            label: 'Map of the whole canvas',
            hint: 'Tap to move there',
            child: GestureDetector(
              onTapDown: (d) => _jump(d.localPosition, size),
              onPanUpdate: (d) => _jump(d.localPosition, size),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: _MiniMapPainter(widget.game, view, widget.paints, _cache),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCache {
  ui.Picture? picture;
  int? version;

  void dispose() {
    picture?.dispose();
    picture = null;
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.game, this.view, this.paints, this.cache) : super(repaint: Listenable.merge([game, view]));

  final GameController game;
  final BoardView view;
  final List<GemPaints> paints;
  final _MapCache cache;

  static final _frame = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFFE91E63);
  static final _fill = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final p = game.puzzle;
    final cell = size.width / p.width;
    if (cache.version != game.boardVersion || cache.picture == null) {
      cache.dispose();
      cache.version = game.boardVersion;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < p.cellCount; i++) {
        final g = paints[p.cells[i]];
        final rect = Rect.fromLTWH((i % p.width) * cell, (i ~/ p.width) * cell, cell + 0.3, cell + 0.3);
        c.drawRect(rect, game.placed[i] == 1 ? (_fill..color = g.color) : g.pale);
      }
      cache.picture = rec.endRecording();
    }
    canvas.drawPicture(cache.picture!);
    final r = view.visibleCells;
    final frame = Rect.fromLTRB(r.left * cell, r.top * cell, r.right * cell, r.bottom * cell)
        .intersect(Offset.zero & size)
        .deflate(1);
    if (!frame.isEmpty) canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(2)), _frame);
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => old.game != game || old.paints != paints;
}
