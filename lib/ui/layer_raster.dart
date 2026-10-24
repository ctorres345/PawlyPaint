import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Rect;

/// Keeps a bitmap of a recorded layer at about the screen's resolution, so a
/// frame draws one image instead of replaying thousands of shapes.
///
/// The layer is rasterized again only when its [key] changes, when the view
/// zooms in enough that the bitmap would look soft, or when it zooms far out.
/// Zoomed in past what a bitmap of [maxSide] pixels can show crisply, the
/// layer is drawn as vectors instead.
class LayerRaster {
  ui.Image? _image;
  Object? _key;
  Rect _bounds = Rect.zero;
  double _scale = 0;
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;

  /// Longest side of the bitmap, in pixels (about 26 MB of texture at most).
  static const maxSide = 2560.0;

  /// Whether the last [draw] used the bitmap (false: drew vectors).
  bool usedImage = false;

  /// Draws the layer covering [bounds] (in layer units) on [canvas], which is
  /// already transformed so one layer unit is [pixelsPerUnit] device pixels.
  /// [paintLayer] draws the layer in layer units when a new bitmap is needed.
  void draw(
    Canvas canvas, {
    required Object key,
    required Rect bounds,
    required double pixelsPerUnit,
    required void Function(Canvas canvas) paintLayer,
  }) {
    final cap = maxSide / math.max(bounds.width, bounds.height);
    if (pixelsPerUnit > cap * 1.6) {
      usedImage = false;
      paintLayer(canvas);
      return;
    }
    final want = math.min(pixelsPerUnit, cap);
    final image = _image;
    final stale = image == null || _key != key || _bounds != bounds || want > _scale * 1.25 || want < _scale / 2;
    if (stale) {
      image?.dispose();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..scale(want)
        ..translate(-bounds.left, -bounds.top);
      paintLayer(c);
      final picture = rec.endRecording();
      _image = picture.toImageSync((bounds.width * want).ceil(), (bounds.height * want).ceil());
      picture.dispose();
      _key = key;
      _bounds = bounds;
      _scale = want;
    }
    final img = _image!;
    usedImage = true;
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), bounds, _paint);
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _key = null;
  }
}
