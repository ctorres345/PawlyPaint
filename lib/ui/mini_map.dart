import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import 'board.dart';
import 'gem_style.dart';

/// A small copy of the whole canvas with a box around the part on screen.
/// Shown only while zoomed in; tap or drag it to move around.
class MiniMap extends StatefulWidget {
  const MiniMap({
    super.key,
    required this.width,
    required this.height,
    required this.board,
    required this.version,
    required this.cellPaint,
    required this.view,
    this.maxSide = 96,
  });

  /// The Paint canvas: painted drills in color, the rest pale.
  MiniMap.paint({Key? key, required GameController game, required BoardView view, required List<GemPaints> paints})
      : this(
          key: key,
          width: game.puzzle.width,
          height: game.puzzle.height,
          board: game,
          version: () => game.boardVersion,
          cellPaint: (i) => game.placed[i] == 1 ? paints[game.puzzle.cells[i]].base : paints[game.puzzle.cells[i]].pale,
          view: view,
        );

  final int width;
  final int height;

  /// Notifies when the board changes; [version] says whether it did.
  final Listenable board;
  final int Function() version;

  /// How cell i looks on the map, or null to leave it empty.
  final Paint? Function(int i) cellPaint;
  final BoardView view;
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

  void _jump(Offset local, Size size) =>
      view.centerOn(local.dx / size.width * widget.width, local.dy / size.height * widget.height);

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.maxSide / math.max(widget.width, widget.height);
    final size = Size(widget.width * cell, widget.height * cell);
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
                    painter: _MiniMapPainter(widget, _cache),
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
  _MiniMapPainter(this.map, this.cache) : super(repaint: Listenable.merge([map.board, map.view]));

  final MiniMap map;
  final _MapCache cache;

  static final _frame = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFFE91E63);
  @override
  void paint(Canvas canvas, Size size) {
    final w = map.width;
    final cell = size.width / w;
    final version = map.version();
    if (cache.version != version || cache.picture == null) {
      cache.dispose();
      cache.version = version;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < w * map.height; i++) {
        final paint = map.cellPaint(i);
        if (paint == null) continue;
        c.drawRect(Rect.fromLTWH((i % w) * cell, (i ~/ w) * cell, cell + 0.3, cell + 0.3), paint);
      }
      cache.picture = rec.endRecording();
    }
    canvas.drawPicture(cache.picture!);
    final r = map.view.visibleCells;
    final frame = Rect.fromLTRB(r.left * cell, r.top * cell, r.right * cell, r.bottom * cell)
        .intersect(Offset.zero & size)
        .deflate(1);
    if (!frame.isEmpty) canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(2)), _frame);
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) {
    // A new board (a restart) means the cached picture is stale too.
    if (old.map.board != map.board) cache.version = null;
    return old.map != map;
  }
}
