import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/settings.dart';
import 'layer_raster.dart';

/// The desk behind a play screen's canvas, drawn once into an image. Impeller
/// keeps no raster cache, so a vector desk would be drawn again with every
/// frame of the screen's effects.
class DeskLayer extends StatefulWidget {
  const DeskLayer({super.key});

  @override
  State<DeskLayer> createState() => _DeskLayerState();
}

class _DeskLayerState extends State<DeskLayer> {
  final _raster = LayerRaster();

  @override
  void dispose() {
    _raster.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: DeskPainter(
            SettingsScope.of(context).theme,
            raster: _raster,
            pixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      );
}

/// The surface behind the canvas: a linen weave, wood grain or a starry sky.
class DeskPainter extends CustomPainter {
  DeskPainter(this.theme, {this.raster, this.pixelRatio = 1});

  final CanvasTheme theme;

  /// Keeps the desk as an image at [pixelRatio], when given.
  final LayerRaster? raster;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final r = raster;
    // An empty area (a tiny split-screen window) has no image to make.
    if (r == null || size.isEmpty) return _paintDesk(canvas, size);
    r.draw(
      canvas,
      key: (theme, size),
      bounds: Offset.zero & size,
      pixelsPerUnit: pixelRatio,
      paintLayer: (c) => _paintDesk(c, size),
    );
  }

  void _paintDesk(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.desk);
    final p = Paint()
      ..color = theme.pattern
      ..strokeWidth = 1;
    switch (theme) {
      case CanvasTheme.linen:
        // Two paths instead of hundreds of lines. Warp and weft stay separate
        // draws, so the crossings still darken.
        p.style = PaintingStyle.stroke;
        final warp = Path(), weft = Path();
        for (var x = 0.0; x < size.width; x += 6) {
          warp
            ..moveTo(x, 0)
            ..lineTo(x, size.height);
        }
        for (var y = 0.0; y < size.height; y += 6) {
          weft
            ..moveTo(0, y)
            ..lineTo(size.width, y);
        }
        canvas
          ..drawPath(warp, p)
          ..drawPath(weft, p);
      case CanvasTheme.wood:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        final grain = Path();
        for (var y = 0.0; y < size.height; y += 14) {
          grain.moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 12) {
            grain.lineTo(x, y + 3 * math.sin(x / 70 + y / 31));
          }
        }
        canvas.drawPath(grain, p);
      case CanvasTheme.night:
        final rng = math.Random(7);
        final stars = Path();
        for (var i = 0; i < (size.width * size.height / 2500).round(); i++) {
          stars.addOval(Rect.fromCircle(
            center: Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
            radius: rng.nextDouble() * 1.4 + 0.4,
          ));
        }
        canvas.drawPath(stars, p);
    }
  }

  @override
  bool shouldRepaint(DeskPainter old) => old.theme != theme || old.raster != raster || old.pixelRatio != pixelRatio;
}
