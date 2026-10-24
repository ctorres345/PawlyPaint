import 'package:flutter/material.dart';

/// The app logo: a paw made of jewels, four round gem toes over a faceted
/// pink jewel. Same geometry as the launcher icon drawn by tool/make_icon.py,
/// in a 1024-unit square without the background tile.
class JewelPawPainter extends CustomPainter {
  const JewelPawPainter();

  static const _facets = <(List<Offset>, Color)>[
    ([Offset(361, 492.8), Offset(663, 492.8), Offset(602.6, 595.2), Offset(421.4, 595.2)], Color(0xFFFFB3C6)),
    ([Offset(255.2, 595.2), Offset(361, 492.8), Offset(421.4, 595.2)], Color(0xFFFF8FAB)),
    ([Offset(663, 492.8), Offset(768.8, 595.2), Offset(602.6, 595.2)], Color(0xFFE85A86)),
    ([Offset(255.2, 595.2), Offset(421.4, 595.2), Offset(512, 844.8)], Color(0xFFF2709A)),
    ([Offset(421.4, 595.2), Offset(602.6, 595.2), Offset(512, 844.8)], Color(0xFFE04A7A)),
    ([Offset(602.6, 595.2), Offset(768.8, 595.2), Offset(512, 844.8)], Color(0xFFB8285A)),
  ];

  // Centre, radius and (rim, body, light) colours of each gem toe.
  static const _gems = <(Offset, double, Color, Color, Color)>[
    (Offset(262, 452), 92, Color(0xFF7E57C2), Color(0xFFD1C4E9), Color(0xFFB39DDB)),
    (Offset(418, 356), 98, Color(0xFF26A69A), Color(0xFFB2DFDB), Color(0xFF80CBC4)),
    (Offset(606, 356), 98, Color(0xFFFB8C00), Color(0xFFFFE0B2), Color(0xFFFFCC80)),
    (Offset(762, 452), 92, Color(0xFFD81B60), Color(0xFFF8BBD0), Color(0xFFF48FB1)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // The artwork spans x 164..860 and y 258..845; centre that span in the box.
    final s = size.shortestSide / 700;
    canvas.translate(size.width / 2 - 512 * s, size.height / 2 - 551 * s);
    canvas.scale(s);
    final paint = Paint();
    for (final (pts, color) in _facets) {
      canvas.drawPath(Path()..addPolygon(pts, true), paint..color = color);
    }
    canvas.drawLine(
      const Offset(255.2, 595.2),
      const Offset(768.8, 595.2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 5,
    );
    for (final (c, r, rim, body, light) in _gems) {
      canvas.drawCircle(c, r, paint..color = rim);
      canvas.drawCircle(c - Offset(0.04 * r, 0.04 * r), 0.92 * r, paint..color = body);
      canvas.drawCircle(c + Offset(0.03 * r, 0.03 * r), 0.78 * r, paint..color = light);
      canvas.drawOval(
        Rect.fromCenter(center: c - Offset(0.3 * r, 0.35 * r), width: 0.56 * r, height: 0.32 * r),
        paint..color = Colors.white.withValues(alpha: 0.7),
      );
    }
    paint.color = Colors.white;
    for (final (c, arm, hw) in const [(Offset(430, 560), 42.0, 5.5), (Offset(690, 540), 30.0, 4.5)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 2 * hw, height: 2 * arm), Radius.circular(hw)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 2 * arm, height: 2 * hw), Radius.circular(hw)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(JewelPawPainter old) => false;
}

/// The paw-of-jewels logo at [size].
class JewelPawLogo extends StatelessWidget {
  const JewelPawLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(dimension: size, child: const CustomPaint(painter: JewelPawPainter())),
      );
}
