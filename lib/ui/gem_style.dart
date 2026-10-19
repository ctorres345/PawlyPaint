import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/puzzle.dart';

/// Pre-built paints for one drill color, so painting a frame allocates nothing.
class GemPaints {
  GemPaints(this.color)
      : base = Paint()..color = color,
        light = Paint()..color = _shift(color, 0.16),
        dark = Paint()..color = _shift(color, -0.18),
        pale = Paint()..color = Color.lerp(color, Colors.white, 0.72)!,
        paleSelected = Paint()..color = Color.lerp(color, Colors.white, 0.45)!,
        onColor = color.computeLuminance() > 0.5 ? const Color(0xFF3B2F36) : Colors.white;

  final Color color;
  final Paint base;
  final Paint light;
  final Paint dark;
  final Paint pale;
  final Paint paleSelected;
  final Color onColor;

  static Color _shift(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static List<GemPaints> forPuzzle(Puzzle p) => [for (final c in p.palette) GemPaints(c)];
}

final _facetPaint = Paint()
  ..color = const Color(0x22000000)
  ..strokeWidth = 0.8;
final _glossPaint = Paint()..color = const Color(0x99FFFFFF);
final _shinePaint = Paint();
final _sparklePaint = Paint()
  ..color = Colors.white
  ..strokeCap = StrokeCap.round;

/// Draws one faceted square drill filling [cell].
///
/// [shine] (0..1) brightens it as the shimmer band passes, [pop] (0..0.3)
/// enlarges it right after it lands, and [sparkle] (0..1) adds a twinkle.
void drawGem(Canvas canvas, Rect cell, GemPaints g, {double shine = 0, double pop = 0, double sparkle = 0}) {
  final w = cell.width;
  var r = cell.deflate(w * 0.05);
  if (pop > 0) r = Rect.fromCenter(center: r.center, width: r.width * (1 + pop), height: r.height * (1 + pop));
  final rw = r.width;
  final radius = Radius.circular(rw * 0.2);

  canvas.drawRRect(RRect.fromRectAndRadius(r, radius), g.dark);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTRB(r.left, r.top, r.right - rw * 0.12, r.bottom - rw * 0.12), radius),
    g.light,
  );
  final table = Rect.fromLTRB(r.left + rw * 0.24, r.top + rw * 0.24, r.right - rw * 0.2, r.bottom - rw * 0.2);
  if (w >= 16) {
    canvas.drawLine(r.topLeft, table.topLeft, _facetPaint);
    canvas.drawLine(r.topRight, table.topRight, _facetPaint);
    canvas.drawLine(r.bottomLeft, table.bottomLeft, _facetPaint);
    canvas.drawLine(r.bottomRight, table.bottomRight, _facetPaint);
  }
  canvas.drawRRect(RRect.fromRectAndRadius(table, Radius.circular(rw * 0.08)), g.base);
  if (w >= 8) {
    canvas.drawOval(
      Rect.fromLTWH(table.left + rw * 0.04, table.top + rw * 0.04, rw * 0.2, rw * 0.11),
      _glossPaint,
    );
  }
  if (shine > 0) {
    _shinePaint.color = Colors.white.withValues(alpha: 0.5 * shine);
    canvas.drawRRect(RRect.fromRectAndRadius(r, radius), _shinePaint);
  }
  if (sparkle > 0 && w >= 10) {
    final c = Offset(r.left + rw * 0.32, r.top + rw * 0.3);
    final len = rw * 0.45 * sparkle;
    _sparklePaint.strokeWidth = math.max(1, rw * 0.06);
    canvas.drawLine(c.translate(-len, 0), c.translate(len, 0), _sparklePaint);
    canvas.drawLine(c.translate(0, -len), c.translate(0, len), _sparklePaint);
  }
}

/// Small preview of a picture. Unfinished pictures stay a mystery, picross
/// style: only the drills already placed show their color.
class PuzzleThumbPainter extends CustomPainter {
  PuzzleThumbPainter(this.puzzle, {this.placed, this.complete = false});

  final Puzzle puzzle;

  /// '1'/'0' per cell from a saved game, or null when not started.
  final String? placed;
  final bool complete;

  static const _hidden = Color(0xFFEDE6EA);
  static const _hiddenAlt = Color(0xFFE4DCE1);

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / puzzle.width;
    final ch = size.height / puzzle.height;
    final paint = Paint();
    final cells = puzzle.cells;
    final saved = placed;
    final Uint8List? mask = saved == null ? null : Uint8List.fromList(saved.codeUnits);
    for (var y = 0; y < puzzle.height; y++) {
      for (var x = 0; x < puzzle.width; x++) {
        final i = y * puzzle.width + x;
        final show = complete || (mask != null && mask[i] == 0x31);
        paint.color = show ? puzzle.palette[cells[i]] : ((x + y).isEven ? _hidden : _hiddenAlt);
        final rect = Rect.fromLTWH(x * cw, y * ch, cw + 0.5, ch + 0.5);
        canvas.drawRect(complete && cw > 4 ? rect.deflate(cw * 0.08) : rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(PuzzleThumbPainter old) =>
      old.puzzle != puzzle || old.placed != placed || old.complete != complete;
}
