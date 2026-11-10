part of '../sort_screen.dart';

/// The canvas for Sort mode: tap to send beads down, drag or pinch to move.
class _SortBoard extends StatefulWidget {
  const _SortBoard({
    super.key,
    required this.game,
    required this.view,
    required this.shimmer,
    required this.frame,
    required this.paints,
    required this.showWrong,
    required this.peek,
    required this.celebrate,
    this.sweepAt,
    required this.onTap,
  });

  final SortController game;
  final BoardView view;
  final Animation<double> shimmer;
  final Listenable frame;
  final List<GemPaints> paints;
  final bool showWrong;
  final bool peek;
  final bool celebrate;
  final DateTime? sweepAt;
  final ValueChanged<Offset> onTap;

  @override
  State<_SortBoard> createState() => _SortBoardState();
}

class _SortBoardState extends State<_SortBoard> {
  Size? _fittedFor;
  double _lastScale = 1;
  int _pointers = 0;
  Offset? _downAt;
  final _cache = _SortCache();

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final p = widget.game.puzzle;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (_fittedFor != size) {
        _fittedFor = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) view.fit(size, p.width, p.height, minCell: _SortStateBase._comfyCell);
        });
      }
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) view.zoomAt(e.localPosition, e.scrollDelta.dy > 0 ? 0.9 : 1.1);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Where the finger lands is what it aimed at; it can roll a few
          // pixels before lifting.
          onTapDown: (d) => _downAt = d.localPosition,
          onTapUp: (d) => widget.onTap(_downAt ?? d.localPosition),
          onScaleStart: (d) {
            _lastScale = 1;
            _pointers = d.pointerCount;
          },
          onScaleUpdate: (d) {
            if (d.pointerCount != _pointers) {
              _pointers = d.pointerCount;
              _lastScale = d.scale;
              return;
            }
            if (d.pointerCount > 1) view.zoomAt(d.localFocalPoint, d.scale / _lastScale);
            view.panBy(d.focalPointDelta);
            _lastScale = d.scale;
          },
          child: CustomPaint(
            size: size,
            painter: _SortBoardPainter(
              game: widget.game,
              view: view,
              shimmer: widget.shimmer,
              frame: widget.frame,
              paints: widget.paints,
              showWrong: widget.showWrong,
              peek: widget.peek,
              celebrate: widget.celebrate,
              sweepAt: widget.sweepAt,
              cache: _cache,
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        ),
      );
    });
  }
}

class _SortCache {
  ui.Picture? picture;
  Object? key;

  /// The recorded board as one bitmap at screen resolution.
  final raster = LayerRaster();

  void dispose() {
    picture?.dispose();
    picture = null;
    key = null;
    raster.dispose();
  }
}

final _socket = Paint()..color = const Color(0xFFE2D6CF);
final _socketRim = Paint()
  ..color = const Color(0x22000000)
  ..style = PaintingStyle.stroke;

/// An empty spot where a bead will go, tinted with [fill] when given.
void drawSocket(Canvas canvas, Rect cell, [Paint? fill]) {
  final r = cell.deflate(cell.width * 0.16);
  canvas.drawOval(r, fill ?? _socket);
  _socketRim.strokeWidth = math.max(0.6, cell.width * 0.05);
  canvas.drawOval(r, _socketRim);
}

class _SortBoardPainter extends CustomPainter {
  _SortBoardPainter({
    required this.game,
    required this.view,
    required this.shimmer,
    required this.frame,
    required this.paints,
    required this.showWrong,
    required this.peek,
    required this.celebrate,
    this.sweepAt,
    required this.cache,
    required this.pixelRatio,
  }) : super(repaint: Listenable.merge([game, view, shimmer, frame]));

  final SortController game;
  final BoardView view;
  final Animation<double> shimmer;
  final Listenable frame;
  final List<GemPaints> paints;
  final bool showWrong;
  final bool peek;
  final bool celebrate;
  final DateTime? sweepAt;
  final _SortCache cache;

  /// Device pixels per logical pixel, so the cached bitmap is crisp.
  final double pixelRatio;

  static final _sheet = Paint();
  static final _wrongDot = Paint()..color = const Color(0xCC3B2F36);
  // Two soft rings instead of a blur, which would cost an offscreen pass per
  // picked-up bead every frame.
  static final _glowOuter = Paint()..color = const Color(0x2EFFFFFF);
  static final _glowInner = Paint()..color = const Color(0x55FFFFFF);
  static final _spot = Paint();
  static final _ring = Paint()..style = PaintingStyle.stroke;
  static final _miss = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Rect _cell(int i) {
    final w = game.puzzle.width;
    return Rect.fromLTWH((i % w) * kCell, (i ~/ w) * kCell, kCell, kCell);
  }

  void _record() {
    final key = (game.boardVersion, showWrong, peek, look);
    _sheet.color = canvasTheme.sheet;
    if (cache.key == key && cache.picture != null) return;
    cache.dispose();
    cache.key = key;
    final p = game.puzzle;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final board = Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell);
    final sheet = RRect.fromRectAndRadius(board.inflate(kCell * 0.6), const Radius.circular(kCell * 0.4));
    drawSheet(c, sheet, _sheet);
    // While peeking, show the finished picture instead of the board.
    final cur = peek ? game.game.target : game.game.current;
    for (var i = 0; i < cur.length; i++) {
      final rect = _cell(i);
      // Each spot shows the color that belongs there, like a printed canvas,
      // so a bead in the wrong place stands out against it.
      final spot = paints[game.game.target[i]];
      if (!peek) c.drawRect(rect, spot.pale);
      if (cur[i] < 0) {
        drawSocket(c, rect, spot.paleSelected);
        continue;
      }
      drawGem(c, peek ? rect : rect.deflate(kCell * 0.07), paints[cur[i]]);
      if (showWrong && !peek && game.game.isWrong(i)) {
        c.drawCircle(rect.center, kCell * 0.1, _wrongDot);
      }
    }
    cache.picture = rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _record();
    final p = game.puzzle;
    final now = DateTime.now();
    final t = shimmer.value;
    canvas.save();
    canvas.translate(view.offset.dx, view.offset.dy);
    canvas.scale(view.scale);
    cache.raster.draw(
      canvas,
      key: cache.key!,
      bounds: Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell).inflate(sheetMargin),
      pixelsPerUnit: view.scale * pixelRatio,
      paintLayer: (c) => c.drawPicture(cache.picture!),
    );

    // Spots whose bead is still on its way stay empty until it lands.
    for (final cell in peek ? const <int>[] : game.arriving.keys) {
      final rect = _cell(cell);
      final spot = paints[game.game.target[cell]];
      canvas.drawRect(rect, spot.pale);
      drawSocket(canvas, rect, spot.paleSelected);
    }

    // Shimmer band, brighter and with sparkles once the picture is done.
    final span = (p.width + p.height).toDouble();
    final band = t * 1.6 - 0.3;
    final width = celebrate ? 0.12 : 0.06;
    final sFrom = math.max(0, ((band - width) * span).floor());
    final sTo = math.min(p.width + p.height - 2, ((band + width) * span).ceil());
    for (var s = sFrom; s <= sTo; s++) {
      final shine = (1 - (s / span - band).abs() / width).clamp(0.0, 1.0);
      if (shine <= 0) continue;
      for (var x = math.max(0, s - p.height + 1); x <= math.min(p.width - 1, s); x++) {
        final i = (s - x) * p.width + x;
        final placed = game.game.current[i] >= 0 && !game.arriving.containsKey(i);
        if (placed) drawGemShine(canvas, _cell(i).deflate(kCell * 0.07), shine, paints.first.shape);
      }
    }
    drawSweep(canvas, sweepAt, Rect.fromLTWH(0, 0, p.width * kCell, p.height * kCell), now);
    if (celebrate) {
      for (var i = 0; i < p.cellCount; i++) {
        final hash = (i * 2654435761) & 0xFFFF;
        if (hash % 3 != 0) continue;
        final s = math.sin(2 * math.pi * (t * 6 + hash / 0xFFFF));
        if (s > 0.94) drawGemSparkle(canvas, _cell(i), (s - 0.94) / 0.06);
      }
    }

    final pulse = 0.5 + 0.5 * math.sin(now.millisecondsSinceEpoch / 140);
    final sel = peek ? null : game.selection;
    if (sel != null) {
      // Picked-up beads glow, and every empty spot that wants them breathes.
      // Picked-up beads get a dark-and-white ring that reads on any bead
      // color, white included; every empty spot that wants them breathes.
      final ringWidth = math.max(kCell * 0.09, 1.5 / view.scale);
      for (final c in sel.cells) {
        final r = _cell(c);
        canvas.drawCircle(r.center, kCell * 0.68, _glowOuter);
        canvas.drawCircle(r.center, kCell * 0.52, _glowInner);
        drawGem(canvas, r.deflate(kCell * 0.02), paints[sel.color], pop: 0.25);
        drawSelectRing(canvas, Rect.fromCircle(center: r.center, radius: kCell * 0.5), ringWidth,
            alpha: 0.8 + 0.2 * pulse);
      }
      _spot.color = paints[sel.color].color.withValues(alpha: 0.35 + 0.45 * pulse);
      final cur = game.game.current, target = game.game.target;
      for (var i = 0; i < cur.length; i++) {
        if (cur[i] >= 0 || target[i] != sel.color || game.arriving.containsKey(i)) continue;
        final r = _cell(i).deflate(kCell * (0.2 - 0.06 * pulse));
        canvas.drawOval(r, _spot);
        drawSelectRing(canvas, r, math.max(kCell * 0.07, 1.2 / view.scale), alpha: 0.6 + 0.4 * pulse);
      }
    }

    // Hint: pulsing rings on what to pick up and where it goes.
    final hint = game.hintStep, hintAt = game.hintAt;
    if (hint != null && hintAt != null && now.difference(hintAt).inMilliseconds < 3800) {
      _ring
        ..color = const Color(0xFFFFC107).withValues(alpha: 0.5 + 0.5 * pulse)
        ..strokeWidth = math.max(kCell * 0.12, 2 / view.scale);
      for (final c in [hint.fromCell, hint.toCell]) {
        if (c != null) canvas.drawCircle(_cell(c).center, kCell * (0.62 + 0.12 * pulse), _ring);
      }
    }

    // A tap on a bead that was already right shows a fading cross.
    final miss = game.mistakeCell, missAt = game.mistakeAt;
    if (miss != null && missAt != null) {
      final age = now.difference(missAt).inMilliseconds;
      if (age < 600) {
        final rect = _cell(miss).deflate(kCell * 0.22);
        _miss
          ..color = const Color(0xFFE53935).withValues(alpha: 1 - age / 600)
          ..strokeWidth = kCell * 0.12;
        canvas.drawLine(rect.topLeft, rect.bottomRight, _miss);
        canvas.drawLine(rect.topRight, rect.bottomLeft, _miss);
      }
    }
    canvas.restore();
  }

  final CanvasTheme _theme = canvasTheme;
  Object get look => (_theme, paints.first.shape);

  @override
  bool shouldRepaint(_SortBoardPainter old) =>
      old.look != look ||
      old.game != game ||
      old.showWrong != showWrong ||
      old.peek != peek ||
      old.celebrate != celebrate ||
      old.sweepAt != sweepAt ||
      old.paints != paints;
}
