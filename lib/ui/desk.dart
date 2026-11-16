import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/settings.dart';

/// The surface behind the canvas: a linen weave, wood grain or a starry sky.
class DeskPainter extends CustomPainter {
  DeskPainter(this.theme);

  final CanvasTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.desk);
    final p = Paint()
      ..color = theme.pattern
      ..strokeWidth = 1;
    switch (theme) {
      case CanvasTheme.linen:
        // One path for the whole weave: this layer is redrawn with every
        // frame of the screen, so one draw beats hundreds of lines.
        p.style = PaintingStyle.stroke;
        final weave = Path();
        for (var x = 0.0; x < size.width; x += 6) {
          weave
            ..moveTo(x, 0)
            ..lineTo(x, size.height);
        }
        for (var y = 0.0; y < size.height; y += 6) {
          weave
            ..moveTo(0, y)
            ..lineTo(size.width, y);
        }
        canvas.drawPath(weave, p);
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
  bool shouldRepaint(DeskPainter old) => old.theme != theme;
}
