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
        for (var x = 0.0; x < size.width; x += 6) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = 0.0; y < size.height; y += 6) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case CanvasTheme.wood:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        for (var y = 0.0; y < size.height; y += 14) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 12) {
            path.lineTo(x, y + 3 * math.sin(x / 70 + y / 31));
          }
          canvas.drawPath(path, p);
        }
      case CanvasTheme.night:
        final rng = math.Random(7);
        for (var i = 0; i < (size.width * size.height / 2500).round(); i++) {
          canvas.drawCircle(
            Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
            rng.nextDouble() * 1.4 + 0.4,
            p,
          );
        }
    }
  }

  @override
  bool shouldRepaint(DeskPainter old) => old.theme != theme;
}
