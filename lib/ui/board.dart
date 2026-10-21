import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../logic/line.dart';
import '../models/puzzle.dart';
import '../state/game_controller.dart';
import '../state/settings.dart';
import 'gem_style.dart';

/// Size of one cell at zoom 1, in logical pixels.
const double kCell = 24;

/// Below this on-screen cell size a tap zooms in instead of placing a drill,
/// since the numbers are too small to read.
const double kMinTapCell = 18;

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

  /// Keeps the canvas clear of the screen edges, where a swipe would trigger
  /// the system back gesture.
  static const edge = 36.0;

  /// Room kept free for buttons floating over the canvas when it is fitted.
  EdgeInsets reserve = EdgeInsets.zero;

  /// Scale and offset that show the whole canvas centered.
  (double, Offset) fitTransform() {
    final w = viewport.width - reserve.horizontal, h = viewport.height - reserve.vertical;
    final s = math.min((w - 2 * edge) / (cols * kCell), (h - 2 * edge) / (rows * kCell));
    return (s, Offset(reserve.left + (w - cols * kCell * s) / 2, reserve.top + (h - rows * kCell * s) / 2));
  }

  /// Shows the whole canvas, or, when that would make cells smaller than
  /// [minCell] on screen, its middle at that size.
  void fit(Size size, int cols, int rows, {double minCell = 0}) {
    viewport = size;
    this.cols = cols;
    this.rows = rows;
    final (s, o) = fitTransform();
    minScale = s * 0.8;
    maxScale = math.max(s * 1.2, 72 / kCell);
    if (kCell * s >= minCell) {
      scale = s;
      offset = o;
    } else {
      scale = math.min(minCell / kCell, maxScale);
      final area = reserve.deflateRect(Offset.zero & size);
      offset = area.center - Offset(cols.toDouble(), rows.toDouble()) * cellSize / 2;
      _clamp();
    }
    notifyListeners();
  }

  void setTransform(double scale, Offset offset) {
    this.scale = scale;
    this.offset = offset;
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

  /// The part of the board on screen, in cells.
  Rect get visibleCells => Rect.fromPoints(-offset / cellSize, (viewport.bottomRight(Offset.zero) - offset) / cellSize);

  /// Moves the view, at the same zoom, so board point ([cx], [cy]) is centered.
  void centerOn(double cx, double cy) {
    offset = viewport.center(Offset.zero) - Offset(cx, cy) * cellSize;
    _clamp();
    notifyListeners();
  }

  /// The cell under a point in the viewport, or null outside the canvas.
  (int, int)? cellAt(Offset local) {
    final p = (local - offset) / cellSize;
    final x = p.dx.floor(), y = p.dy.floor();
    if (x < 0 || y < 0 || x >= cols || y >= rows) return null;
    return (x, y);
  }

  /// Cells whose middle is within [radius] of a point in the viewport, the
  /// one under the point first and the rest nearest first.
  List<(int, int)> cellsNear(Offset local, double radius) {
    final under = cellAt(local);
    final p = (local - offset) / cellSize;
    final r = radius / cellSize;
    final near = <((int, int), double)>[];
    for (var y = math.max(0, (p.dy - r).floor()); y <= math.min(rows - 1, (p.dy + r).floor()); y++) {
      for (var x = math.max(0, (p.dx - r).floor()); x <= math.min(cols - 1, (p.dx + r).floor()); x++) {
        if ((x, y) == under) continue;
        final d = (Offset(x + 0.5, y + 0.5) - p).distance;
        if (d <= r) near.add(((x, y), d));
      }
    }
    near.sort((a, b) => a.$2.compareTo(b.$2));
    return [if (under != null) under, for (final n in near) n.$1];
  }

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
    required this.celebrate,
    this.sweepAt,
    required this.onResult,
    this.onBomb,
  });

  final GameController game;
  final BoardView view;
  final Animation<double> shimmer;
  final List<GemPaints> paints;
  final bool highlight;

  /// Extra sparkle while the finished picture is revealed.
  final bool celebrate;

  /// When the finished picture's shine sweep started, if it has.
  final DateTime? sweepAt;
  final void Function(PlaceResult result, {required bool dragging}) onResult;

  /// Set while a bomb is armed: the next tap drops it on that cell instead
  /// of placing a drill.
  final ValueChanged<int>? onBomb;

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> {
  Size? _fittedFor;
  int _pointers = 0;
  bool _wasMulti = false;
  double _lastScale = 1;
  (int, int)? _lastCell;
  Offset? _downAt;
  final _cache = BoardCache();

  GameController get game => widget.game;
  BoardView get view => widget.view;

  void _placeAt((int, int) cell, {required bool dragging}) {
    final (x, y) = cell;
    final result = game.place(y * game.puzzle.width + x, dragging: dragging);
    if (result != PlaceResult.ignored) widget.onResult(result, dragging: dragging);
  }

  void _tap(Offset local) {
    final cell = view.cellAt(local);
    if (cell == null) return;
    final onBomb = widget.onBomb;
    if (onBomb != null) {
      onBomb(cell.$2 * game.puzzle.width + cell.$1);
      return;
    }
    if (view.cellSize < kMinTapCell) {
      view.zoomAt(local, 40 / view.cellSize);
      return;
    }
    _placeAt(cell, dragging: false);
  }

  /// Fills every cell on the line from the last drag point, so fast swipes
  /// don't skip cells.
  void _dragTo(Offset local) {
    final cell = view.cellAt(local);
    if (cell == null) {
      _lastCell = null;
      return;
    }
    for (final c in cellsOnLine(_lastCell ?? cell, cell)) {
      _placeAt(c, dragging: true);
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
        onPointerDown: (e) => _downAt = e.localPosition,
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) view.zoomAt(e.localPosition, e.scrollDelta.dy > 0 ? 0.9 : 1.1);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(d.localPosition),
          onScaleStart: (d) {
            _pointers = d.pointerCount;
            _wasMulti = d.pointerCount > 1;
            _lastScale = 1;
            _lastCell = null;
            if (!_wasMulti) {
              // The recognizer starts after the finger moved a little; begin
              // from where it went down so the first cell isn't skipped.
              if (_downAt != null) _dragTo(_downAt!);
              _dragTo(d.localFocalPoint);
            }
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
              celebrate: widget.celebrate,
              sweepAt: widget.sweepAt,
              cache: _cache,
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }
}

/// The canvas, recorded in layers so a frame mostly replays pictures:
/// the sheet with every spot and the grid, the numbers, and the placed
/// drills in chunks that only grow. Placing a drill re-records nothing big,
/// which keeps fast drags smooth on the largest canvases.
class BoardCache {
  ui.Picture? base;
  ui.Picture? labels;
  Object? key;

  /// Placed drills in the order they went down, [chunk] cells a picture.
  final List<ui.Picture> gems = [];
  int committed = 0;
  Object? gemsLook;
  static const chunk = 64;

  void dispose() {
    base?.dispose();
    labels?.dispose();
    base = labels = null;
    key = null;
    clearGems();
  }

  void clearGems() {
    for (final g in gems) {
      g.dispose();
    }
    gems.clear();
    committed = 0;
    gemsLook = null;
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.game,
    required this.view,
    required this.shimmer,
    required this.paints,
    required this.highlight,
    required this.celebrate,
    this.sweepAt,
    required this.cache,
  }) : super(repaint: Listenable.merge([game, view, shimmer]));

  final GameController game;
  final BoardView view;
  final Animation<double> shimmer;
  final List<GemPaints> paints;
  final bool highlight;
  final bool celebrate;
  final DateTime? sweepAt;
  final BoardCache cache;

  static final _sheet = Paint();
  static final _sheetShadow = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  static final _gridFine = Paint()
    ..color = const Color(0x14000000)
    ..strokeWidth = 0.6;
  static final _gridMajor = Paint()
    ..color = const Color(0x2E000000)
    ..strokeWidth = 1;
  static final _ring = Paint()..style = PaintingStyle.stroke;
  static final _blast = Paint()..style = PaintingStyle.stroke;
  static final _beacon = Paint()..style = PaintingStyle.stroke;
  static final _miss = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  bool get _smart => highlight && !game.isColorDone(game.selected) && !game.isComplete;

  static Rect _cellRect(Puzzle p, int i) => Rect.fromLTWH((i % p.width) * kCell, (i ~/ p.width) * kCell, kCell, kCell);

  /// The sheet with every spot tinted, the grid, and the numbers. Placed
  /// drills cover their spot later, so this only changes with the selection.
  void _rebuildBase() {
    final smart = _smart;
    final sel = game.selected;
    final key = (smart, sel, game.isComplete, currentLook());
    _sheet.color = canvasTheme.sheet;
    if (cache.key == key && cache.base != null) return;
    cache.base?.dispose();
    cache.labels?.dispose();
    cache.key = key;
    final p = game.puzzle;

    var rec = ui.PictureRecorder();
    var c = Canvas(rec);
    final board = Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell);
    final sheet = RRect.fromRectAndRadius(board.inflate(kCell * 0.6), const Radius.circular(kCell * 0.4));
    c.drawRRect(sheet.shift(const Offset(0, 4)), _sheetShadow);
    c.drawRRect(sheet, _sheet);
    if (!game.isComplete) {
      for (var i = 0; i < p.cellCount; i++) {
        final color = p.cells[i];
        final g = paints[color];
        c.drawRect(_cellRect(p, i), !smart ? g.pale : (color == sel ? g.paleSelected : g.dim));
      }
      for (var x = 0; x <= p.width; x++) {
        c.drawLine(Offset(x * kCell, 0), Offset(x * kCell, board.bottom), x % 10 == 0 ? _gridMajor : _gridFine);
      }
      for (var y = 0; y <= p.height; y++) {
        c.drawLine(Offset(0, y * kCell), Offset(board.right, y * kCell), y % 10 == 0 ? _gridMajor : _gridFine);
      }
    }
    cache.base = rec.endRecording();

    // Numbers on the spots, drawn only when zoomed in enough to read.
    rec = ui.PictureRecorder();
    c = Canvas(rec);
    if (!game.isComplete) {
      final labels = <(int, bool, bool), TextPainter>{};
      for (var i = 0; i < p.cellCount; i++) {
        final color = p.cells[i];
        final isSel = smart && color == sel;
        final dimmed = smart && !isSel;
        final label = labels.putIfAbsent((color, isSel, dimmed), () {
          final g = paints[color];
          final ink = GemPaints.inkOn(isSel ? g.paleSelected : (dimmed ? g.dim : g.pale));
          return TextPainter(
            text: TextSpan(
              text: p.symbolFor(color),
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: kCell * 0.42,
                // Dimmed numbers stay readable but quieter.
                color: dimmed ? ink.withValues(alpha: 0.55) : ink,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
        });
        final center = Offset((i % p.width + 0.5) * kCell, (i ~/ p.width + 0.5) * kCell);
        label.paint(c, center - Offset(label.width / 2, label.height / 2));
      }
      for (final l in labels.values) {
        l.dispose();
      }
    }
    cache.labels = rec.endRecording();
  }

  /// One placed drill: clears its spot back to the sheet (inside the grid
  /// lines) and draws the drill.
  void _drawPlaced(Canvas c, Puzzle p, int i) {
    final rect = _cellRect(p, i);
    c.drawRect(rect.deflate(0.5), _sheet);
    drawGem(c, rect, paints[p.cells[i]]);
  }

  /// Draws every placed drill: the recorded chunks, then the newest few by
  /// hand. A chunk is recorded once enough new drills have gone down.
  void _drawGems(Canvas canvas) {
    final p = game.puzzle;
    final order = game.order;
    final look = currentLook();
    if (cache.gemsLook != look || order.length < cache.committed) {
      cache.clearGems();
      cache.gemsLook = look;
    }
    while (order.length - cache.committed >= BoardCache.chunk) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var k = cache.committed; k < cache.committed + BoardCache.chunk; k++) {
        _drawPlaced(c, p, order[k]);
      }
      cache.gems.add(rec.endRecording());
      cache.committed += BoardCache.chunk;
    }
    for (final g in cache.gems) {
      canvas.drawPicture(g);
    }
    for (var k = cache.committed; k < order.length; k++) {
      _drawPlaced(canvas, p, order[k]);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _rebuildBase();
    final p = game.puzzle;
    canvas.save();
    canvas.translate(view.offset.dx, view.offset.dy);
    canvas.scale(view.scale);
    canvas.drawPicture(cache.base!);
    if (view.cellSize >= 13) canvas.drawPicture(cache.labels!);
    _drawGems(canvas);

    final t = shimmer.value;
    final now = DateTime.now();
    Rect cellRect(int i) => _cellRect(p, i);

    // Pulsing outline on the cells still waiting for the selected color.
    if (_smart) {
      final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 8);
      // Light colors (white, cream) would vanish against their pale spot, so
      // they get the dark ring ink instead.
      final selColor = paints[game.selected].color;
      _ring
        ..color = (selColor.computeLuminance() > 0.55 ? ringInk : selColor).withValues(alpha: 0.35 + 0.45 * pulse)
        ..strokeWidth = math.max(kCell * 0.08, 1.5 / view.scale);
      for (final i in p.cellsByColor[game.selected]) {
        if (game.placed[i] == 0) canvas.drawRect(cellRect(i).deflate(kCell * 0.08), _ring);
      }
    }

    // A band of light sweeping diagonally across the placed drills.
    final span = (p.width + p.height).toDouble();
    final band = t * 1.6 - 0.3;
    final sFrom = math.max(0, ((band - 0.06) * span).floor());
    final sTo = math.min(p.width + p.height - 2, ((band + 0.06) * span).ceil());
    for (var s = sFrom; s <= sTo; s++) {
      final shine = (1 - (s / span - band).abs() / 0.06).clamp(0.0, 1.0);
      if (shine <= 0) continue;
      for (var x = math.max(0, s - p.height + 1); x <= math.min(p.width - 1, s); x++) {
        final i = (s - x) * p.width + x;
        if (game.placed[i] == 1) drawGemShine(canvas, cellRect(i), shine);
      }
    }

    drawSweep(canvas, sweepAt, Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell), now);

    // The odd twinkle, and lots of them while the finished picture is revealed.
    for (var i = 0; i < p.cellCount; i++) {
      final hash = (i * 2654435761) & 0xFFFF;
      if (hash % (celebrate ? 3 : 9) != 0 || game.placed[i] == 0) continue;
      final s = math.sin(2 * math.pi * (t * (celebrate ? 6 : 2) + hash / 0xFFFF));
      if (s > 0.94) drawGemSparkle(canvas, cellRect(i), (s - 0.94) / 0.06);
    }

    // A finished color glints all over for a moment.
    final doneColor = game.lastColorDone, doneAt = game.lastColorDoneAt;
    if (doneColor != null && doneAt != null && !celebrate) {
      final age = now.difference(doneAt).inMilliseconds;
      if (age >= 0 && age < 1100) {
        final fade = 1 - age / 1100;
        for (final i in p.cellsByColor[doneColor]) {
          final hash = (i * 2654435761) & 0xFFFF;
          final s = 0.5 + 0.5 * math.sin(age / 90 + hash / 0xFFFF * 2 * math.pi);
          drawGemShine(canvas, cellRect(i), fade * s);
          if (hash % 4 == 0 && s > 0.8) drawGemSparkle(canvas, cellRect(i), fade * (s - 0.8) / 0.2);
        }
      }
    }

    // Drills that just landed pop above their neighbours. Booster drills land
    // in a wave, so the ones still waiting show their empty cell.
    for (final MapEntry(key: i, value: at) in game.recentPlacements.entries) {
      final age = now.difference(at).inMilliseconds;
      if (game.placed[i] == 0) continue;
      if (age < 0) {
        canvas.drawRect(cellRect(i), paints[p.cells[i]].pale);
      } else if (age < 220) {
        drawGem(canvas, cellRect(i), paints[p.cells[i]], pop: 0.3 * (1 - age / 220));
      }
    }

    // A golden ring spreads from where a bomb or wand went off.
    final blastCell = game.lastBlastCell, blastAt = game.lastBlastAt;
    if (blastCell != null && blastAt != null) {
      final age = now.difference(blastAt).inMilliseconds;
      if (age < 700) {
        final k = age / 700;
        _blast
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.9 * (1 - k))
          ..strokeWidth = kCell * (0.5 - 0.35 * k);
        canvas.drawCircle(cellRect(blastCell).center, kCell * (0.5 + 5 * Curves.easeOutCubic.transform(k)), _blast);
      }
    }

    // The last few spots of a color pulse so they're easy to spot, even
    // zoomed out: the rings keep a minimum size on screen.
    final sel = game.selected;
    if (_smart && game.remaining[sel] <= 5) {
      final k = (now.millisecondsSinceEpoch % 1200) / 1200;
      final minR = 16 / view.scale;
      for (final i in p.cellsByColor[sel]) {
        if (game.placed[i] == 1) continue;
        final r = math.max(kCell * 0.7, minR) * (1 + 0.6 * k);
        _beacon
          ..color = const Color(0xFFEC407A).withValues(alpha: 0.85 * (1 - k))
          ..strokeWidth = math.max(kCell * 0.12, 2.5 / view.scale);
        canvas.drawCircle(cellRect(i).center, r, _beacon);
      }
    }

    // A wrong tap shows a fading red cross.
    final missCell = game.lastMistakeCell, missAt = game.lastMistakeAt;
    if (missCell != null && missAt != null && game.placed[missCell] == 0) {
      final age = now.difference(missAt).inMilliseconds;
      if (age < 600) {
        final rect = cellRect(missCell).deflate(kCell * 0.22);
        _miss
          ..color = const Color(0xFFE53935).withValues(alpha: 1 - age / 600)
          ..strokeWidth = kCell * 0.12;
        canvas.drawLine(rect.topLeft, rect.bottomRight, _miss);
        canvas.drawLine(rect.topRight, rect.bottomLeft, _miss);
      }
    }
    canvas.restore();
  }

  final Object look = currentLook();

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.look != look ||
      old.game != game ||
      old.highlight != highlight ||
      old.paints != paints ||
      old.celebrate != celebrate ||
      old.sweepAt != sweepAt;
}
