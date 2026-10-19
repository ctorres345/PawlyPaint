import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import '../models/puzzle.dart';

typedef ShapeTest = bool Function(double x, double y);

/// A tiny raster used to draw puzzle pictures from shapes.
///
/// Coordinates are normalized to 0..1 on both axes, so the same drawing
/// works at any grid size. Each cell is sampled at its center.
class ArtCanvas {
  ArtCanvas(this.width, this.height, {int background = 0})
      : _px = Uint8List(width * height)..fillRange(0, width * height, background);

  final int width;
  final int height;
  final Uint8List _px;

  int at(int x, int y) => _px[y * width + x];

  /// Column and row of the cell containing a normalized point.
  int col(double x) => (x * width).floor().clamp(0, width - 1);
  int row(double y) => (y * height).floor().clamp(0, height - 1);

  /// Paints the single cell containing (x, y).
  void dot(double x, double y, int c) => _px[row(y) * width + col(x)] = c;

  /// Paints every cell whose center passes [test] with color [c].
  void fill(ShapeTest test, int c) {
    for (var y = 0; y < height; y++) {
      final ny = (y + 0.5) / height;
      for (var x = 0; x < width; x++) {
        final nx = (x + 0.5) / width;
        if (test(nx, ny)) _px[y * width + x] = c;
      }
    }
  }

  /// Like [fill], but picks a tone from [tones] (darkest first) depending on
  /// how much the point faces a light coming from the top left.
  void fillShaded(
    ShapeTest test,
    double cx,
    double cy,
    double r,
    List<int> tones, {
    double lightX = -0.65,
    double lightY = -0.75,
  }) {
    final len = math.sqrt(lightX * lightX + lightY * lightY);
    final lx = lightX / len, ly = lightY / len;
    for (var y = 0; y < height; y++) {
      final ny = (y + 0.5) / height;
      for (var x = 0; x < width; x++) {
        final nx = (x + 0.5) / width;
        if (!test(nx, ny)) continue;
        final dx = (nx - cx) / r, dy = (ny - cy) / r;
        final d = (dx * lx + dy * ly).clamp(-1.0, 1.0);
        final t = (d + 1) / 2;
        final i = (t * tones.length).floor().clamp(0, tones.length - 1);
        _px[y * width + x] = tones[i];
      }
    }
  }

  /// Horizontal bands from [top] to [bottom], one per color.
  void bands(List<int> colors, {double top = 0, double bottom = 1}) {
    final step = (bottom - top) / colors.length;
    for (var i = 0; i < colors.length; i++) {
      final t = top + step * i, b = t + step;
      fill((x, y) => y >= t && y < b, colors[i]);
    }
  }

  void rect(double l, double t, double r, double b, int c) => fill((x, y) => x >= l && x <= r && y >= t && y <= b, c);

  void circle(double cx, double cy, double r, int c) => fill(inCircle(cx, cy, r), c);

  void ellipse(double cx, double cy, double rx, double ry, int c, {double angle = 0}) =>
      fill(inEllipse(cx, cy, rx, ry, angle: angle), c);

  void ring(double cx, double cy, double inner, double outer, int c) => fill((x, y) {
        final d = _dist(x, y, cx, cy);
        return d >= inner && d <= outer;
      }, c);

  void polygon(List<(double, double)> pts, int c) => fill(inPolygon(pts), c);

  void line(double x1, double y1, double x2, double y2, double thickness, int c) =>
      fill(inLine(x1, y1, x2, y2, thickness), c);

  void heart(double cx, double cy, double size, int c) => fill(inHeart(cx, cy, size), c);

  void star(double cx, double cy, double outer, double inner, int points, int c, {double rotation = -math.pi / 2}) =>
      polygon(starPoints(cx, cy, outer, inner, points, rotation: rotation), c);

  /// Turns the drawing into a [Puzzle], dropping palette colors it never used.
  Puzzle toPuzzle({required String id, required String title, required List<int> palette}) {
    final used = List<bool>.filled(palette.length, false);
    for (final p in _px) {
      used[p] = true;
    }
    final remap = List<int>.filled(palette.length, -1);
    final colors = <Color>[];
    for (var i = 0; i < palette.length; i++) {
      if (!used[i]) continue;
      remap[i] = colors.length;
      colors.add(Color(palette[i]));
    }
    final cells = Uint8List(_px.length);
    for (var i = 0; i < _px.length; i++) {
      cells[i] = remap[_px[i]];
    }
    return Puzzle(
      id: id,
      title: title,
      width: width,
      height: height,
      cells: cells,
      palette: colors,
    );
  }

  // ---- Shape tests --------------------------------------------------------

  static double _dist(double x, double y, double cx, double cy) {
    final dx = x - cx, dy = y - cy;
    return math.sqrt(dx * dx + dy * dy);
  }

  static ShapeTest inCircle(double cx, double cy, double r) =>
      (x, y) => (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;

  static ShapeTest inEllipse(double cx, double cy, double rx, double ry, {double angle = 0}) {
    final cosA = math.cos(angle), sinA = math.sin(angle);
    return (x, y) {
      final dx = x - cx, dy = y - cy;
      final u = dx * cosA + dy * sinA;
      final v = -dx * sinA + dy * cosA;
      return (u * u) / (rx * rx) + (v * v) / (ry * ry) <= 1;
    };
  }

  static ShapeTest inPolygon(List<(double, double)> pts) => (x, y) {
        var inside = false;
        for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
          final (xi, yi) = pts[i];
          final (xj, yj) = pts[j];
          if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
            inside = !inside;
          }
        }
        return inside;
      };

  static ShapeTest inLine(double x1, double y1, double x2, double y2, double thickness) => (x, y) {
        final vx = x2 - x1, vy = y2 - y1;
        final len2 = vx * vx + vy * vy;
        final t = len2 == 0 ? 0.0 : (((x - x1) * vx + (y - y1) * vy) / len2).clamp(0.0, 1.0);
        final px = x1 + vx * t, py = y1 + vy * t;
        return _dist(x, y, px, py) <= thickness / 2;
      };

  /// Classic implicit heart, [size] is roughly its half width.
  static ShapeTest inHeart(double cx, double cy, double size) => (x, y) {
        final u = (x - cx) / size * 1.14;
        final v = -(y - cy) / size * 1.14 + 0.12;
        final a = u * u + v * v - 1;
        return a * a * a - u * u * v * v * v <= 0;
      };

  static List<(double, double)> starPoints(double cx, double cy, double outer, double inner, int points,
      {double rotation = -math.pi / 2}) {
    final pts = <(double, double)>[];
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = rotation + i * math.pi / points;
      pts.add((cx + r * math.cos(a), cy + r * math.sin(a)));
    }
    return pts;
  }
}
