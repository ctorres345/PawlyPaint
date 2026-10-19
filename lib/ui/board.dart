import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import 'gem_style.dart';

/// Size of one cell at zoom 1, in logical pixels.
const double kCell = 24;

/// Zoom and pan of the canvas inside its viewport.
class BoardView extends ChangeNotifier {
  double scale = 1;
  Offset offset = Offset.zero;
  Size viewport = Size.zero;
  int cols = 1;
  int rows = 1;
  double minScale = 0.2;
  double maxScale = 3;

  double get cellSize => kCell * scale;

  void fit(Size size, int cols, int rows) {
    viewport = size;
    this.cols = cols;
    this.rows = rows;
    final fitScale = math.min(size.width / (cols * kCell), size.height / (rows * kCell)) * 0.9;
    minScale = fitScale * 0.8;
    maxScale = math.max(fitScale * 1.2, 72 / kCell);
    scale = fitScale;
    offset = Offset((size.width - cols * cellSize) / 2, (size.height - rows * cellSize) / 2);
    notifyListeners();
  }

  void zoomAt(Offset focal, double factor) {
    final next = (scale * factor).clamp(minScale, maxScale);
    if (next == scale) return;
    offset = focal - (focal - offset) * (next / scale);
    scale = next;
    _clamp();
    notifyListeners();
  }

  void panBy(Offset delta) {
    offset += delta;
    _clamp();
    notifyListeners();
  }

  /// Centers the view on a cell and zooms in enough to tap it comfortably.
  void focusCell(int x, int y) {
    scale = math.max(scale, math.min(maxScale, 40 / kCell));
    final cs = cellSize;
    offset = Offset(viewport.width / 2 - (x + 0.5) * cs, viewport.height / 2 - (y + 0.5) * cs);
    _clamp();
    notifyListeners();
  }

  /// Board coordinates (in cells) of the viewport center.
  Offset get centerCell => (viewport.center(Offset.zero) - offset) / cellSize;

  void _clamp() {
    final bw = cols * cellSize, bh = rows * cellSize;
    offset = Offset(
      offset.dx.clamp(viewport.width / 2 - bw, viewport.width / 2),
      offset.dy.clamp(viewport.height / 2 - bh, viewport.height / 2),
    );
  }
}

/// The canvas: one finger places drills (tap or drag), two fingers zoom and pan.
class Board extends StatefulWidget {
  const Board({
    super.key,
    required this.game,
    required this.view,
    required this.shimmer,
    required this.paints,
    required this.highlight,
    required this.onResult,
  });

  final GameController game;
  final BoardView view;
  final Animation<double> shimmer;
  final List<GemPaints> paints;
  final bool highlight;
  final ValueChanged<PlaceResult> onResult;

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> {
  Size? _fittedFor;
  int _pointers = 0;
  bool _wasMulti = false;
  double _lastScale = 1;
  (int, int)? _lastCell;

  GameController get game => widget.game;
  BoardView get view => widget.view;

  (int, int)? _cellAt(Offset local) {
    final p = (local - view.offset) / view.cellSize;
    final x = p.dx.floor(), y = p.dy.floor();
    if (x < 0 || y < 0 || x >= game.puzzle.width || y >= game.puzzle.height) return null;
    return (x, y);
  }

  void _placeAt((int, int) cell, {required bool dragging}) {
    final (x, y) = cell;
    final result = game.place(y * game.puzzle.width + x, dragging: dragging);
    if (result != PlaceResult.ignored) widget.onResult(result);
  }

  /// Fills every cell on the line from the last drag point, so fast swipes
  /// don't skip cells.
  void _dragTo(Offset local) {
    final cell = _cellAt(local);
    if (cell == null) {
      _lastCell = null;
      return;
    }
    final from = _lastCell ?? cell;
    var (x0, y0) = from;
    final (x1, y1) = cell;
    final dx = (x1 - x0).abs(), dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      _placeAt((x0, y0), dragging: true);
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
    _lastCell = cell;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (_fittedFor != size) {
        _fittedFor = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) view.fit(size, game.puzzle.width, game.puzzle.height);
        });
      }
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) view.zoomAt(e.localPosition, e.scrollDelta.dy > 0 ? 0.9 : 1.1);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final cell = _cellAt(d.localPosition);
            if (cell != null) _placeAt(cell, dragging: false);
          },
          onScaleStart: (d) {
            _pointers = d.pointerCount;
            _wasMulti = d.pointerCount > 1;
            _lastScale = 1;
            _lastCell = null;
            if (!_wasMulti) _dragTo(d.localFocalPoint);
          },
          onScaleUpdate: (d) {
            if (d.pointerCount != _pointers) {
              _pointers = d.pointerCount;
              _lastScale = d.scale;
              if (d.pointerCount > 1) _wasMulti = true;
              return;
            }
            if (!_wasMulti) {
              _dragTo(d.localFocalPoint);
            } else {
              view.zoomAt(d.localFocalPoint, d.scale / _lastScale);
              view.panBy(d.focalPointDelta);
              _lastScale = d.scale;
            }
          },
          onScaleEnd: (_) {
            _wasMulti = false;
            _lastCell = null;
          },
          child: CustomPaint(
            size: size,
            painter: BoardPainter(
              game: game,
              view: view,
              shimmer: widget.shimmer,
              paints: widget.paints,
              highlight: widget.highlight,
            ),
          ),
        ),
      );
    });
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.game,
    required this.view,
    required this.shimmer,
    required this.paints,
    required this.highlight,
  }) : super(repaint: Listenable.merge([game, view, shimmer]));

  final GameController game;
  final BoardView view;
  final Animation<double> shimmer;
  final List<GemPaints> paints;
  final bool highlight;

  static final _sheet = Paint()..color = const Color(0xFFFBF8F3);
  static final _sheetShadow = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  static final _dim = Paint()..color = const Color(0xFFEDEAE6);
  static final _gridFine = Paint()
    ..color = const Color(0x14000000)
    ..strokeWidth = 0.6;
  static final _gridMajor = Paint()
    ..color = const Color(0x2E000000)
    ..strokeWidth = 1;
  static final _ring = Paint()..style = PaintingStyle.stroke;

  final Map<String, TextPainter> _labels = {};
  double _labelSize = 0;

  TextPainter _label(int color, bool selected, bool dimmed, double fontSize) {
    if (fontSize != _labelSize) {
      _labels.clear();
      _labelSize = fontSize;
    }
    final key = '$color-$selected-$dimmed';
    return _labels.putIfAbsent(key, () {
      final ink = selected
          ? HSLColor.fromColor(paints[color].color).withLightness(0.25).toColor()
          : (dimmed ? const Color(0xFFB9B1B5) : const Color(0xFF6D5F66));
      return TextPainter(
        text: TextSpan(
          text: game.puzzle.symbolFor(color),
          style: TextStyle(
            fontSize: fontSize,
            color: ink,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = game.puzzle;
    final cs = view.cellSize;
    final o = view.offset;
    final board = Rect.fromLTWH(o.dx, o.dy, p.width * cs, p.height * cs);
    final sheet = RRect.fromRectAndRadius(board.inflate(math.max(8, cs * 0.6)), const Radius.circular(10));
    canvas.drawRRect(sheet.shift(const Offset(0, 4)), _sheetShadow);
    canvas.drawRRect(sheet, _sheet);

    final x0 = math.max(0, (-o.dx / cs).floor());
    final y0 = math.max(0, (-o.dy / cs).floor());
    final x1 = math.min(p.width - 1, ((size.width - o.dx) / cs).floor());
    final y1 = math.min(p.height - 1, ((size.height - o.dy) / cs).floor());
    if (x1 < x0 || y1 < y0) return;

    final sel = game.selected;
    final smart = highlight && !game.isColorDone(sel);
    final t = shimmer.value;
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 8);
    final showLabels = cs >= 13;
    final fontSize = (cs * 0.42).roundToDouble();

    // Empty cells: a printed, color-tinted canvas with numbers.
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * p.width + x;
        if (game.placed[i] == 1) continue;
        final color = p.cells[i];
        final rect = Rect.fromLTWH(o.dx + x * cs, o.dy + y * cs, cs, cs);
        final isSel = smart && color == sel;
        final dimmed = smart && !isSel;
        canvas.drawRect(rect, isSel ? paints[color].paleSelected : (dimmed ? _dim : paints[color].pale));
        if (isSel) {
          _ring
            ..color = paints[color].color.withValues(alpha: 0.35 + 0.45 * pulse)
            ..strokeWidth = math.max(1, cs * 0.08);
          canvas.drawRect(rect.deflate(cs * 0.08), _ring);
        }
        if (showLabels) {
          final label = _label(color, isSel, dimmed, fontSize);
          label.paint(canvas, rect.center - Offset(label.width / 2, label.height / 2));
        }
      }
    }

    // Grid lines, with a stronger line every 10 cells like a real kit.
    if (cs >= 6) {
      for (var x = x0; x <= x1 + 1; x++) {
        final dx = o.dx + x * cs;
        canvas.drawLine(Offset(dx, o.dy + y0 * cs), Offset(dx, o.dy + (y1 + 1) * cs), x % 10 == 0 ? _gridMajor : _gridFine);
      }
      for (var y = y0; y <= y1 + 1; y++) {
        final dy = o.dy + y * cs;
        canvas.drawLine(Offset(o.dx + x0 * cs, dy), Offset(o.dx + (x1 + 1) * cs, dy), y % 10 == 0 ? _gridMajor : _gridFine);
      }
    }

    // Placed drills, with a light sweep and the odd twinkle.
    final now = DateTime.now();
    final band = t * 1.6 - 0.3;
    final span = (p.width + p.height).toDouble();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * p.width + x;
        if (game.placed[i] == 0) continue;
        final rect = Rect.fromLTWH(o.dx + x * cs, o.dy + y * cs, cs, cs);
        final shine = (1 - ((x + y) / span - band).abs() / 0.06).clamp(0.0, 1.0);
        var pop = 0.0;
        final at = game.recentPlacements[i];
        if (at != null) {
          final age = now.difference(at).inMilliseconds;
          if (age < 220) pop = 0.3 * (1 - age / 220);
        }
        var sparkle = 0.0;
        final hash = (i * 2654435761) & 0xFFFF;
        if (hash % 9 == 0) {
          final s = math.sin(2 * math.pi * (t * 2 + hash / 0xFFFF));
          if (s > 0.94) sparkle = (s - 0.94) / 0.06;
        }
        drawGem(canvas, rect, paints[p.cells[i]], shine: shine, pop: pop, sparkle: sparkle);
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter old) => old.game != game || old.highlight != highlight || old.paints != paints;
}
