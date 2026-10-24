import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's mascot, Mochi: a minimal cat face in the style of Japanese
/// character mascots. Wide round head, small ears, dot eyes, blush, a tiny
/// nose and no mouth.
class MascotLook {
  const MascotLook({required this.fur, required this.ear, required this.eye, required this.blush, required this.nose});

  final Color fur;
  final Color ear;
  final Color eye;
  final Color blush;
  final Color nose;

  static const cream = MascotLook(
    fur: Color(0xFFFFF8F0),
    ear: Color(0xFFFFC1D3),
    eye: Color(0xFF2E2233),
    blush: Color(0xFFFFB3C6),
    nose: Color(0xFFF2709A),
  );
  static const lilac = MascotLook(
    fur: Color(0xFFC9B6E4),
    ear: Color(0xFFFFC1D3),
    eye: Color(0xFF2E2233),
    blush: Color(0xFFFFB3C6),
    nose: Color(0xFFF2709A),
  );
}

/// The look used everywhere in the app.
const mascotLook = MascotLook.cream;

/// Mochi's name, for greetings.
const mascotName = 'Mochi';

enum MascotMood { happy, sleepy, cheer }

/// Draws the mascot face filling [size] (keeps a 200:170 aspect).
class CatMascotPainter extends CustomPainter {
  const CatMascotPainter({this.look = mascotLook, this.mood = MascotMood.happy, this.whiskers = true, this.outline});

  final MascotLook look;
  final MascotMood mood;
  final bool whiskers;

  /// A thin outline so the cream face shows on white backgrounds.
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 200, size.height / 170);
    canvas.translate((size.width - 200 * s) / 2, (size.height - 170 * s) / 2);
    canvas.scale(s);
    final fur = Paint()..color = look.fur;
    final ear = Paint()..color = look.ear;
    final eye = Paint()..color = look.eye;
    final blush = Paint()..color = look.blush;
    final nose = Paint()..color = look.nose;
    final whisker = Paint()
      ..color = look.eye.withValues(alpha: 0.7)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final head = Path()
      ..moveTo(38, 70)
      ..lineTo(46, 18)
      ..lineTo(92, 46)
      ..close()
      ..moveTo(162, 70)
      ..lineTo(154, 18)
      ..lineTo(108, 46)
      ..close()
      ..addOval(Rect.fromCenter(center: const Offset(100, 100), width: 164, height: 128));
    if (outline != null) {
      canvas.drawPath(
        head,
        Paint()
          ..color = outline!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(head, fur);
    canvas.drawPath(Path()..addPolygon(const [Offset(50, 62), Offset(54, 32), Offset(82, 50)], true), ear);
    canvas.drawPath(Path()..addPolygon(const [Offset(150, 62), Offset(146, 32), Offset(118, 50)], true), ear);
    for (final x in const [68.0, 132.0]) {
      switch (mood) {
        case MascotMood.happy:
          canvas.drawOval(Rect.fromCenter(center: Offset(x, 98), width: 13, height: 18), eye);
        case MascotMood.sleepy:
          canvas.drawLine(Offset(x - 9, 99), Offset(x + 9, 99), whisker..strokeWidth = 5);
        case MascotMood.cheer:
          final arc = Path()..addArc(Rect.fromCenter(center: Offset(x, 102), width: 20, height: 18), math.pi, math.pi);
          canvas.drawPath(arc, whisker..strokeWidth = 5);
      }
    }
    whisker.strokeWidth = 3.5;
    canvas.drawCircle(const Offset(50, 118), 9, blush);
    canvas.drawCircle(const Offset(150, 118), 9, blush);
    canvas.drawPath(Path()..addPolygon(const [Offset(94, 118), Offset(106, 118), Offset(100, 125)], true), nose);
    if (whiskers) {
      canvas.drawLine(const Offset(14, 100), const Offset(46, 106), whisker);
      canvas.drawLine(const Offset(14, 118), const Offset(46, 116), whisker);
      canvas.drawLine(const Offset(186, 100), const Offset(154, 106), whisker);
      canvas.drawLine(const Offset(186, 118), const Offset(154, 116), whisker);
    }
  }

  @override
  bool shouldRepaint(CatMascotPainter old) =>
      old.look != look || old.mood != mood || old.whiskers != whiskers || old.outline != outline;
}

/// The mascot as a widget.
class CatMascot extends StatelessWidget {
  const CatMascot({super.key, this.size = 48, this.mood = MascotMood.happy, this.outline});

  final double size;
  final MascotMood mood;
  final Color? outline;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size * 0.85,
          child: CustomPaint(painter: CatMascotPainter(mood: mood, outline: outline)),
        ),
      );
}

/// A paw print filling [size].
class PawPainter extends CustomPainter {
  const PawPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    final paint = Paint()..color = color;
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 66), width: 48, height: 38), paint);
    canvas.drawCircle(const Offset(20, 42), 11, paint);
    canvas.drawCircle(const Offset(40, 26), 12, paint);
    canvas.drawCircle(const Offset(60, 26), 12, paint);
    canvas.drawCircle(const Offset(80, 42), 11, paint);
  }

  @override
  bool shouldRepaint(PawPainter old) => old.color != color;
}

/// A paw print icon.
class PawIcon extends StatelessWidget {
  const PawIcon({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: PawPainter(color ?? IconTheme.of(context).color ?? Colors.black)),
        ),
      );
}

/// A faint, tilted pattern of paw prints behind a screen.
class PawPattern extends StatelessWidget {
  const PawPattern({super.key, this.opacity = 0.06});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: opacity);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _PawPatternPainter(color), size: Size.infinite),
      ),
    );
  }
}

class _PawPatternPainter extends CustomPainter {
  const _PawPatternPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 92.0, paw = 30.0;
    final painter = PawPainter(color);
    for (var row = -1; row * step < size.height + step; row++) {
      for (var col = -1; col * step < size.width + step; col++) {
        final x = col * step + (row.isOdd ? step / 2 : 0), y = row * step;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.35 + (col + row) % 3 * 0.25);
        painter.paint(canvas, const Size.square(paw));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PawPatternPainter old) => old.color != color;
}

/// Wraps a rounded card so a pair of cat ears peeks over its top edge.
class EarsCard extends StatelessWidget {
  const EarsCard({super.key, required this.color, required this.child, this.radius = 24});

  final Color color;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 22, top: -10, child: _Ear(color: color, flip: false)),
            Positioned(right: 22, top: -10, child: _Ear(color: color, flip: true)),
            child,
          ],
        ),
      );
}

class _Ear extends StatelessWidget {
  const _Ear({required this.color, required this.flip});

  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.rotationZ(flip ? 0.2 : -0.2),
          child: SizedBox(
            width: 32,
            height: 22,
            child: CustomPaint(painter: _EarPainter(color)),
          ),
        ),
      );
}

class _EarPainter extends CustomPainter {
  const _EarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.1, size.width * 0.5, 0)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.1, size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_EarPainter old) => old.color != color;
}

/// A speech bubble from the mascot.
class MascotBubble extends StatelessWidget {
  const MascotBubble({super.key, required this.text, this.mood = MascotMood.happy});

  final String text;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$mascotName says: $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CatMascot(size: 56, mood: mood, outline: theme.colorScheme.primary.withValues(alpha: 0.25)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))
                ],
              ),
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cat puns for finished pictures, picked by a stable hash so each picture
/// keeps its own.
String completionPun(String seed) {
  const puns = ['Purr-fect!', 'Meow-velous!', 'Claw-some!', 'Paw-some work!', 'Feline fine!', 'Simply purr-fection!'];
  return puns[seed.hashCode.abs() % puns.length];
}
