import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/puzzle.dart';

/// Pre-built paints for one drill color, so painting a frame allocates nothing.
class GemPaints {
  GemPaints(this.color)
      : base = Paint()..color = color,
        light = Paint()..color = Color.lerp(color, Colors.white, 0.38)!,
        dark = Paint()..color = Color.lerp(color, Colors.black, 0.28)!,
        table = Paint()..color = Color.lerp(color, Colors.white, 0.16)!,
        pale = Paint()..color = Color.lerp(color, Colors.white, 0.5)!,
        paleSelected = Paint()..color = Color.lerp(color, Colors.white, 0.3)!,
        dim = Paint()..color = Color.lerp(color, const Color(0xFFEDEAE6), 0.72)!,
        onColor = color.computeLuminance() > 0.5 ? const Color(0xFF3B2F36) : Colors.white;

  final Color color;
  final Paint base;
  final Paint light;
  final Paint dark;
  final Paint table;

  /// The spot's own color, lightened: an empty spot shows which color
  /// belongs there, so a wrong bead stands out against it.
  final Paint pale;
  final Paint paleSelected;

  /// Cells of other colors while one color is highlighted: grayed but
  /// keeping a hint of their tint, like a printed canvas.
  final Paint dim;
  final Color onColor;

  /// Ink that reads on top of [fill] (one of this color's spot paints).
  static Color inkOn(Paint fill) => fill.color.computeLuminance() > 0.4 ? const Color(0xFF3B2F36) : Colors.white;

  static List<GemPaints> forPuzzle(Puzzle p) => [for (final c in p.palette) GemPaints(c)];
}

final _facetPaint = Paint()
  ..color = const Color(0x1F000000)
  ..strokeWidth = 0.8;
final _glossPaint = Paint()..color = const Color(0x99FFFFFF);
final _shinePaint = Paint();
final _sparklePaint = Paint()
  ..color = Colors.white
  ..strokeCap = StrokeCap.round;

/// Square diamond-painting drills, or round ones.
enum GemShape {
  square('Square'),
  round('Round');

  const GemShape(this.label);

  final String label;
}

/// The drill shape everything is drawn with; set from the player's settings.
GemShape gemShape = GemShape.square;

/// Outer rect and corner radius of a drill inside [cell].
(Rect, Radius) _gemBounds(Rect cell, double pop) {
  var r = cell.deflate(cell.width * 0.05);
  if (pop > 0) r = Rect.fromCenter(center: r.center, width: r.width * (1 + pop), height: r.height * (1 + pop));
  return (r, Radius.circular(r.width * (gemShape == GemShape.round ? 0.5 : 0.2)));
}

/// A round, domed bead: dark rim, lit upper-left, body, and a soft gloss.
void _drawRound(Canvas canvas, Rect r, GemPaints g, double w) {
  final rw = r.width;
  canvas.drawOval(r, g.dark);
  canvas.drawOval(Rect.fromLTRB(r.left, r.top, r.right - rw * 0.08, r.bottom - rw * 0.08), g.light);
  final body = Rect.fromLTRB(r.left + rw * 0.07, r.top + rw * 0.07, r.right - rw * 0.1, r.bottom - rw * 0.1);
  canvas.drawOval(body, g.base);
  canvas.drawOval(body.deflate(rw * 0.16).translate(-rw * 0.03, -rw * 0.03), g.table);
  if (w >= 8) {
    canvas.drawOval(Rect.fromLTWH(body.left + rw * 0.1, body.top + rw * 0.08, rw * 0.24, rw * 0.13), _glossPaint);
  }
}

/// Draws one faceted square drill filling [cell]. [pop] (0..0.3) enlarges it
/// right after it lands.
void drawGem(Canvas canvas, Rect cell, GemPaints g, {double pop = 0}) {
  final w = cell.width;
  final (r, radius) = _gemBounds(cell, pop);
  final rw = r.width;
  if (gemShape == GemShape.round) {
    _drawRound(canvas, r, g, w);
    return;
  }

  // Dark rim, a lit top-left bevel, the crown, then a brighter table facet.
  canvas.drawRRect(RRect.fromRectAndRadius(r, radius), g.dark);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTRB(r.left, r.top, r.right - rw * 0.08, r.bottom - rw * 0.08), radius),
    g.light,
  );
  final crown = Rect.fromLTRB(r.left + rw * 0.08, r.top + rw * 0.08, r.right - rw * 0.12, r.bottom - rw * 0.12);
  canvas.drawRRect(RRect.fromRectAndRadius(crown, Radius.circular(rw * 0.14)), g.base);
  final table = crown.deflate(rw * 0.2);
  if (w >= 16) {
    final k = rw * 0.05;
    canvas.drawLine(crown.topLeft.translate(k, k), table.topLeft, _facetPaint);
    canvas.drawLine(crown.topRight.translate(-k, k), table.topRight, _facetPaint);
    canvas.drawLine(crown.bottomLeft.translate(k, -k), table.bottomLeft, _facetPaint);
    canvas.drawLine(crown.bottomRight.translate(-k, -k), table.bottomRight, _facetPaint);
  }
  canvas.drawRRect(RRect.fromRectAndRadius(table, Radius.circular(rw * 0.06)), g.table);
  if (w >= 8) {
    canvas.drawOval(
      Rect.fromLTWH(crown.left + rw * 0.06, crown.top + rw * 0.05, rw * 0.22, rw * 0.12),
      _glossPaint,
    );
  }
}

/// Brightens a placed drill as the shimmer band passes; [amount] is 0..1.
void drawGemShine(Canvas canvas, Rect cell, double amount) {
  final (r, radius) = _gemBounds(cell, 0);
  _shinePaint.color = Colors.white.withValues(alpha: 0.5 * amount);
  canvas.drawRRect(RRect.fromRectAndRadius(r, radius), _shinePaint);
}

/// A four-point twinkle on a placed drill; [amount] is 0..1.
void drawGemSparkle(Canvas canvas, Rect cell, double amount) {
  final (r, _) = _gemBounds(cell, 0);
  final rw = r.width;
  final c = Offset(r.left + rw * 0.32, r.top + rw * 0.3);
  final len = rw * 0.45 * amount;
  _sparklePaint.strokeWidth = rw * 0.06;
  canvas.drawLine(c.translate(-len, 0), c.translate(len, 0), _sparklePaint);
  canvas.drawLine(c.translate(0, -len), c.translate(0, len), _sparklePaint);
}

/// A brilliant-cut bead for the tray: an octagon with a flat table and eight
/// crown facets, lit from the top left.
void drawCutGem(Canvas canvas, Rect cell, GemPaints g) {
  final c = cell.center;
  final rad = cell.width * 0.47;
  List<Offset> ring(double k) => [
        for (var i = 0; i < 8; i++) c + Offset.fromDirection(math.pi / 8 + i * math.pi / 4, rad * k),
      ];
  final outer = ring(1), crown = ring(0.88), table = ring(0.5);
  canvas.drawPath(Path()..addPolygon(outer, true), g.dark);
  canvas.drawPath(Path()..addPolygon(crown, true), g.base);
  for (var i = 0; i < 8; i++) {
    final j = (i + 1) % 8;
    // Facets facing the light (up and left) are bright, the rest stay plain.
    final mid = (crown[i] + crown[j]) / 2 - c;
    final lit = (mid.dx + mid.dy) / mid.distance;
    if (lit > 0.3) continue;
    canvas.drawPath(
      Path()..addPolygon([table[i], crown[i], crown[j], table[j]], true),
      lit < -0.5 ? g.light : g.table,
    );
  }
  canvas.drawPath(Path()..addPolygon(table, true), g.table);
  if (cell.width >= 12) {
    for (var i = 0; i < 8; i++) {
      canvas.drawLine(table[i], crown[i], _facetPaint);
    }
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-rad * 0.22, -rad * 0.24), width: rad * 0.4, height: rad * 0.22),
      _glossPaint,
    );
  }
}

final _sheetShade = Paint();

/// The canvas sheet with a soft shadow under it. The shadow is a few nested
/// translucent shapes rather than a blur filter, which would cost the GPU an
/// offscreen pass every time the layer is drawn.
void drawSheet(Canvas canvas, RRect sheet, Paint sheetPaint) {
  for (var i = 3; i >= 0; i--) {
    _sheetShade.color = Color.fromARGB(0x0C + 0x06 * i, 0, 0, 0);
    canvas.drawRRect(sheet.shift(Offset(0, 2.0 + i * 1.5)).inflate(1.5 + i * 2.5), _sheetShade);
  }
  canvas.drawRRect(sheet, sheetPaint);
}

/// How far the sheet (0.6 of a 24-unit cell) and its shadow reach beyond the
/// board's cells.
const sheetMargin = 24 * 0.6 + 14.0;

final _ringOutline = Paint()..style = PaintingStyle.stroke;
final _ringCore = Paint()..style = PaintingStyle.stroke;

/// Ink for the dark half of a selection ring.
const ringInk = Color(0xFF2E2233);

/// A selection ring that reads on every bead color: a dark outline around a
/// bright core, so it stands out on white beads as well as on dark ones.
/// [width] is the core's stroke width and [alpha] fades the whole ring.
void drawSelectRing(Canvas canvas, Rect r, double width, {double alpha = 1, Color core = Colors.white}) {
  _ringOutline
    ..color = ringInk.withValues(alpha: 0.85 * alpha)
    ..strokeWidth = width * 2.2;
  _ringCore
    ..color = core.withValues(alpha: alpha)
    ..strokeWidth = width;
  canvas.drawOval(r, _ringOutline);
  canvas.drawOval(r, _ringCore);
}

/// How long the finish sweep takes to cross the picture.
const sweepDuration = Duration(milliseconds: 1300);

/// Draws the finish sweep over [board] if one started at [at] and is still
/// running at [now].
void drawSweep(Canvas canvas, DateTime? at, Rect board, DateTime now) {
  if (at == null) return;
  final progress = now.difference(at).inMilliseconds / sweepDuration.inMilliseconds;
  if (progress < 1) drawFinishSweep(canvas, board, progress);
}

final _sweepPaint = Paint();

/// One wide band of light sweeping diagonally across a finished picture
/// covering [board]; [progress] runs 0..1.
void drawFinishSweep(Canvas canvas, Rect board, double progress) {
  final length = (board.width + board.height) / math.sqrt2;
  const dir = Offset(math.sqrt1_2, math.sqrt1_2);
  final center = (-0.25 + 1.5 * progress) * length;
  final half = length * 0.16;
  _sweepPaint.shader = ui.Gradient.linear(
    board.topLeft + dir * (center - half),
    board.topLeft + dir * (center + half),
    const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
    const [0, 0.5, 1],
  );
  canvas.drawRect(board, _sweepPaint);
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
