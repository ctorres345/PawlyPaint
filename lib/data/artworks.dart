import 'dart:math' as math;

import '../models/puzzle.dart';
import 'art_canvas.dart';

/// Every picture is drawn from simple shapes, so no image assets are needed.
/// Palette index 0 is the background; colors a drawing never uses are dropped.
typedef Artwork = Puzzle Function(String id, int size);

// ---- Beginner -------------------------------------------------------------

Puzzle heart(String id, int n) {
  const bg = 0, dots = 1, dark = 2, red = 3, light = 4, white = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 5 == 0, dots);
  c.heart(0.54, 0.55, 0.40, dark);
  c.heart(0.49, 0.50, 0.38, red);
  c.ellipse(0.33, 0.37, 0.10, 0.06, light, angle: -0.7);
  c.dot(0.30, 0.34, white);
  return c.toPuzzle(id: id, title: 'Sweetheart', palette: const [
    0xFFFCE4EC, 0xFFF8BBD0, 0xFFB0213A, 0xFFE53950, 0xFFFF8A9B, 0xFFFFFFFF, //
  ]);
}

Puzzle paw(String id, int n) {
  const bg = 0, brown = 1, pink = 2, shine = 3;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 0.67, 0.25, 0.20, brown);
  c.ellipse(0.5, 0.68, 0.17, 0.13, pink);
  for (final (x, y) in const [(0.24, 0.40), (0.40, 0.25), (0.60, 0.25), (0.76, 0.40)]) {
    c.circle(x, y, 0.105, brown);
    c.circle(x, y, 0.06, pink);
  }
  c.dot(0.42, 0.63, shine);
  return c.toPuzzle(id: id, title: 'Little Paw', palette: const [
    0xFFDFF5EE, 0xFF6D4C41, 0xFFF48FB1, 0xFFFCE4EC, //
  ]);
}

Puzzle sun(String id, int n) {
  const sky = 0, skyLight = 1, orange = 2, yellow = 3, yellowLight = 4, cheek = 5, eye = 6;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.75, 1, 1, skyLight);
  c.star(0.5, 0.5, 0.47, 0.31, 12, orange);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.5, 0.28), 0.5, 0.5, 0.28, const [yellow, yellow, yellowLight]);
  c.circle(0.40, 0.46, 0.045, eye);
  c.circle(0.60, 0.46, 0.045, eye);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.5) * (y - 0.5));
    return d >= 0.10 && d <= 0.16 && y > 0.56;
  }, eye);
  c.circle(0.35, 0.58, 0.04, cheek);
  c.circle(0.65, 0.58, 0.04, cheek);
  return c.toPuzzle(id: id, title: 'Sunny Day', palette: const [
    0xFF8FD3F7, 0xFFB9E6FB, 0xFFFF9800, 0xFFFFD54F, 0xFFFFF59D, 0xFFFF8A80, 0xFF5D4037, //
  ]);
}

Puzzle mushroom(String id, int n) {
  const bg = 0, grass = 1, grassDark = 2, stem = 3, stemShade = 4, cap = 5, capDark = 6, spot = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.82, 1, 1, grass);
  for (final x in const [0.1, 0.35, 0.65, 0.9]) {
    c.circle(x, 0.86, 0.07, grassDark);
  }
  final stemShape = ArtCanvas.inEllipse(0.5, 0.70, 0.15, 0.19);
  c.fill(stemShape, stem);
  c.fill((x, y) => stemShape(x, y) && x > 0.56, stemShade);
  final capShape = ArtCanvas.inEllipse(0.5, 0.52, 0.42, 0.34);
  bool capTest(double x, double y) => capShape(x, y) && y <= 0.56;
  c.fillShaded(capTest, 0.5, 0.40, 0.42, const [capDark, cap, cap]);
  for (final (x, y, r) in const [(0.34, 0.38, 0.07), (0.56, 0.27, 0.07), (0.70, 0.45, 0.06)]) {
    final s = ArtCanvas.inCircle(x, y, r);
    c.fill((px, py) => s(px, py) && capTest(px, py), spot);
  }
  return c.toPuzzle(id: id, title: 'Forest Friend', palette: const [
    0xFFE8F5E9, 0xFF81C784, 0xFF4CAF50, 0xFFFFF3E0, 0xFFE0C9A6, 0xFFE53935, 0xFFB71C1C, 0xFFFFFFFF, //
  ]);
}

Puzzle cherries(String id, int n) {
  const bg = 0, stem = 1, leaf = 2, leafDark = 3, redDark = 4, red = 5, shine = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.line(0.32, 0.66, 0.55, 0.17, 0.08, stem);
  c.line(0.68, 0.63, 0.55, 0.17, 0.08, stem);
  c.ellipse(0.70, 0.20, 0.15, 0.065, leaf, angle: -0.4);
  c.line(0.57, 0.24, 0.80, 0.15, 0.04, leafDark);
  c.fillShaded(ArtCanvas.inCircle(0.32, 0.71, 0.18), 0.32, 0.71, 0.18, const [redDark, red, red]);
  c.fillShaded(ArtCanvas.inCircle(0.68, 0.68, 0.18), 0.68, 0.68, 0.18, const [redDark, red, red]);
  c.dot(0.26, 0.64, shine);
  c.dot(0.62, 0.61, shine);
  return c.toPuzzle(id: id, title: 'Cherry Pair', palette: const [
    0xFFFFF8E1, 0xFF795548, 0xFF66BB6A, 0xFF388E3C, 0xFFA0102A, 0xFFE0243F, 0xFFFF9EAD, //
  ]);
}

// ---- Intermediate ---------------------------------------------------------

Puzzle cat(String id, int n) {
  const bg = 0, dots = 1, fur = 2, furLight = 3, dark = 4, pink = 5, green = 6, white = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 3) % 7 == 0, dots);
  c.ellipse(0.5, 1.05, 0.42, 0.24, fur);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.polygon([(fx(0.17), 0.44), (fx(0.23), 0.11), (fx(0.45), 0.30)], fur);
    c.polygon([(fx(0.22), 0.37), (fx(0.25), 0.19), (fx(0.37), 0.31)], pink);
  }
  c.ellipse(0.5, 0.55, 0.35, 0.30, fur);
  c.ellipse(0.5, 0.69, 0.17, 0.12, furLight);
  for (final x in const [0.36, 0.64]) {
    c.ellipse(x, 0.51, 0.075, 0.09, green);
    c.ellipse(x, 0.52, 0.03, 0.075, dark);
    c.dot(x - 0.02, 0.48, white);
  }
  c.polygon(const [(0.45, 0.62), (0.55, 0.62), (0.5, 0.675)], pink);
  c.line(0.5, 0.67, 0.5, 0.72, 0.04, dark);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.line(fx(0.32), 0.66, fx(0.06), 0.61, 0.035, dark);
    c.line(fx(0.32), 0.71, fx(0.06), 0.75, 0.035, dark);
  }
  return c.toPuzzle(id: id, title: 'Curious Cat', palette: const [
    0xFFEDE7F6, 0xFFD1C4E9, 0xFF9E9E9E, 0xFFE0E0E0, 0xFF424242, 0xFFF48FB1, 0xFF8BC34A, 0xFFFFFFFF, //
  ]);
}

Puzzle daisy(String id, int n) {
  const sky = 0, skyLow = 1, stem = 2, leaf = 3, petal = 4, petalShade = 5;
  const centerDark = 6, center = 7, centerLight = 8;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.62, 1, 1, skyLow);
  c.line(0.5, 0.5, 0.5, 1.0, 0.065, stem);
  c.ellipse(0.38, 0.82, 0.13, 0.055, leaf, angle: 0.5);
  c.ellipse(0.62, 0.74, 0.13, 0.055, leaf, angle: -0.5);
  for (var i = 0; i < 10; i++) {
    final a = i * 2 * math.pi / 10;
    c.ellipse(0.5 + 0.22 * math.cos(a), 0.40 + 0.22 * math.sin(a), 0.13, 0.058,
        math.sin(a) > 0.3 ? petalShade : petal,
        angle: a);
  }
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.40, 0.12), 0.5, 0.40, 0.12, const [centerDark, center, centerLight]);
  return c.toPuzzle(id: id, title: 'Daisy', palette: const [
    0xFFB3E5FC, 0xFFE1F5FE, 0xFF43A047, 0xFF66BB6A, 0xFFFFFFFF, 0xFFE3E7F1, //
    0xFFF9A825, 0xFFFFD54F, 0xFFFFF176,
  ]);
}

Puzzle strawberry(String id, int n) {
  const bg = 0, check = 1, redDark = 2, red = 3, redLight = 4, seed = 5, leaf = 6, leafDark = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) ~/ 2 + c.row(y) ~/ 2).isEven, check);
  final top = ArtCanvas.inEllipse(0.5, 0.48, 0.34, 0.22);
  final tip = ArtCanvas.inPolygon(const [(0.17, 0.50), (0.83, 0.50), (0.56, 0.88), (0.44, 0.88)]);
  final tipRound = ArtCanvas.inCircle(0.5, 0.84, 0.07);
  bool berry(double x, double y) => top(x, y) || tip(x, y) || tipRound(x, y);
  c.fillShaded(berry, 0.5, 0.55, 0.40, const [redDark, red, red, redLight]);
  c.fill((x, y) => berry(x, y) && y > 0.40 && c.row(y).isEven && (c.col(x) + c.row(y) ~/ 2) % 3 == 0, seed);
  c.star(0.5, 0.31, 0.21, 0.07, 6, leaf);
  c.line(0.5, 0.30, 0.55, 0.10, 0.05, leafDark);
  return c.toPuzzle(id: id, title: 'Berry Picnic', palette: const [
    0xFFFFF3E0, 0xFFFFE0B2, 0xFFC62828, 0xFFEF3B3B, 0xFFFF7070, 0xFFFFE082, 0xFF43A047, 0xFF2E7D32, //
  ]);
}

Puzzle rainbow(String id, int n) {
  const skyTop = 0, skyMid = 1, skyLow = 2, cloud = 9, cloudShade = 10;
  const arcs = [3, 4, 5, 6, 7, 8];
  final c = ArtCanvas(n, n, background: skyTop);
  c.bands(const [skyTop, skyMid, skyLow]);
  for (var i = 0; i < arcs.length; i++) {
    final outer = 0.46 - i * 0.056;
    c.fill((x, y) {
      final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.80) * (y - 0.80));
      return y <= 0.80 && d <= outer && d > outer - 0.056;
    }, arcs[i]);
  }
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.circle(fx(0.16), 0.82, 0.11, cloudShade);
    c.circle(fx(0.28), 0.84, 0.09, cloudShade);
    c.circle(fx(0.15), 0.79, 0.10, cloud);
    c.circle(fx(0.27), 0.81, 0.08, cloud);
    c.circle(fx(0.06), 0.84, 0.08, cloud);
  }
  c.rect(0, 0.88, 1, 1, cloud);
  return c.toPuzzle(id: id, title: 'After the Rain', palette: const [
    0xFF64B5F6, 0xFF90CAF9, 0xFFBBDEFB, 0xFFEF5350, 0xFFFFA726, 0xFFFFEE58, //
    0xFF66BB6A, 0xFF42A5F5, 0xFFAB47BC, 0xFFFFFFFF, 0xFFE3EAF2,
  ]);
}

Puzzle cupcake(String id, int n) {
  const bg = 0, dots = 1, wrap = 2, wrapDark = 3, frost = 4, frostShade = 5;
  const cherry = 6, cherryLight = 7, sprinkleA = 8, sprinkleB = 9, stem = 10;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 2 + c.row(y)) % 6 == 0, dots);
  final cup = ArtCanvas.inPolygon(const [(0.24, 0.56), (0.76, 0.56), (0.67, 0.92), (0.33, 0.92)]);
  c.fill(cup, wrap);
  c.fill((x, y) => cup(x, y) && c.col(x).isEven, wrapDark);
  for (final (cy, rx, ry) in const [(0.55, 0.33, 0.09), (0.46, 0.28, 0.09), (0.37, 0.21, 0.08), (0.29, 0.12, 0.06)]) {
    c.fillShaded(ArtCanvas.inEllipse(0.5, cy, rx, ry), 0.5, cy, rx, const [frostShade, frost, frost]);
  }
  c.line(0.5, 0.14, 0.57, 0.04, 0.04, stem);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.19, 0.08), 0.5, 0.19, 0.08, const [cherry, cherry, cherryLight]);
  const sprinkles = [(0.37, 0.45), (0.61, 0.40), (0.46, 0.52), (0.67, 0.53), (0.53, 0.34), (0.31, 0.54), (0.44, 0.38)];
  for (var i = 0; i < sprinkles.length; i++) {
    final (x, y) = sprinkles[i];
    c.dot(x, y, i.isEven ? sprinkleA : sprinkleB);
  }
  return c.toPuzzle(id: id, title: 'Party Cupcake', palette: const [
    0xFFFCE4EC, 0xFFF8BBD0, 0xFF4DB6AC, 0xFF00897B, 0xFFFFF0F5, 0xFFF3C6D9, //
    0xFFD81B60, 0xFFFF6F9B, 0xFFFFEB3B, 0xFF4FC3F7, 0xFF6D4C41,
  ]);
}

// ---- Expert ---------------------------------------------------------------

Puzzle sunset(String id, int n) {
  const sun = 5, sunLight = 6, sea1 = 7, sea2 = 8, sea3 = 9, glint = 10, boat = 11, sail = 12;
  const birds = 13;
  final c = ArtCanvas(n, n);
  c.bands(const [0, 1, 2, 3, 4], bottom: 0.62);
  final sunShape = ArtCanvas.inCircle(0.5, 0.62, 0.19);
  c.fillShaded((x, y) => sunShape(x, y) && y < 0.62, 0.5, 0.62, 0.19, const [sun, sun, sunLight]);
  c.bands(const [sea3, sea2, sea1], top: 0.62);
  c.fill((x, y) {
    if (y < 0.62) return false;
    final spread = 0.17 * (1 - (y - 0.62) / 0.5);
    return (x - 0.5).abs() < spread && c.row(y).isEven && (c.col(x) + c.row(y)) % 3 != 0;
  }, glint);
  c.polygon(const [(0.69, 0.70), (0.87, 0.70), (0.83, 0.75), (0.73, 0.75)], boat);
  c.line(0.78, 0.70, 0.78, 0.50, 0.03, boat);
  c.polygon(const [(0.79, 0.51), (0.79, 0.69), (0.86, 0.69)], sail);
  c.polygon(const [(0.77, 0.53), (0.77, 0.69), (0.71, 0.69)], sail);
  for (final (bx, by) in const [(0.22, 0.22), (0.33, 0.16), (0.62, 0.20)]) {
    c.line(bx - 0.04, by - 0.02, bx, by + 0.01, 0.035, birds);
    c.line(bx, by + 0.01, bx + 0.04, by - 0.02, 0.035, birds);
  }
  return c.toPuzzle(id: id, title: 'Golden Hour', palette: const [
    0xFF5E35B1, 0xFF8E44AD, 0xFFD6457F, 0xFFFF7043, 0xFFFFA726, 0xFFFFEB3B, 0xFFFFF59D, //
    0xFF1A237E, 0xFF283593, 0xFF3949AB, 0xFFFFCC80, 0xFF3E2723, 0xFFFFF8E1, 0xFF4A148C,
  ]);
}

Puzzle butterfly(String id, int n) {
  const bg = 0, dots = 1, wingDark = 2, wing = 3, wingLight = 4, lowDark = 5, low = 6, lowLight = 7;
  const spot = 8, body = 9;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 3) % 8 == 0, dots);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    final s = m ? -1.0 : 1.0;
    c.ellipse(fx(0.30), 0.35, 0.25, 0.19, wingDark, angle: -0.5 * s);
    c.fillShaded(ArtCanvas.inEllipse(fx(0.30), 0.35, 0.21, 0.15, angle: -0.5 * s), fx(0.30), 0.35, 0.21,
        const [wingDark, wing, wing, wingLight]);
    c.ellipse(fx(0.34), 0.65, 0.18, 0.15, lowDark, angle: 0.5 * s);
    c.fillShaded(ArtCanvas.inEllipse(fx(0.34), 0.65, 0.14, 0.11, angle: 0.5 * s), fx(0.34), 0.65, 0.14,
        const [lowDark, low, low, lowLight]);
    c.circle(fx(0.24), 0.30, 0.05, spot);
    c.circle(fx(0.33), 0.67, 0.035, spot);
  }
  c.ellipse(0.5, 0.52, 0.04, 0.22, body);
  c.circle(0.5, 0.28, 0.05, body);
  c.line(0.49, 0.25, 0.40, 0.10, 0.03, body);
  c.line(0.51, 0.25, 0.60, 0.10, 0.03, body);
  c.circle(0.40, 0.10, 0.025, body);
  c.circle(0.60, 0.10, 0.025, body);
  return c.toPuzzle(id: id, title: 'Garden Flutter', palette: const [
    0xFFE0F2F1, 0xFFB2DFDB, 0xFF6A1B9A, 0xFFAB47BC, 0xFFCE93D8, //
    0xFFC2185B, 0xFFEC407A, 0xFFF48FB1, 0xFFFFF59D, 0xFF3E2723,
  ]);
}

Puzzle puppy(String id, int n) {
  const bg = 0, check = 1, tan = 2, tanLight = 3, brown = 4, brownDark = 5, cream = 6;
  const black = 7, white = 8, pink = 9, red = 10, gold = 11;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) ~/ 4 + c.row(y) ~/ 4).isEven, check);
  c.ellipse(0.5, 1.02, 0.38, 0.24, tan);
  c.ellipse(0.5, 0.81, 0.26, 0.06, red);
  c.circle(0.5, 0.87, 0.04, gold);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    final ear = ArtCanvas.inEllipse(fx(0.20), 0.50, 0.10, 0.22, angle: m ? -0.3 : 0.3);
    c.fill(ear, brown);
    c.fill((x, y) => ear(x, y) && y > 0.62, brownDark);
  }
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.50, 0.29, 0.28), 0.5, 0.50, 0.29, const [tan, tan, tanLight]);
  c.ellipse(0.38, 0.44, 0.09, 0.08, brown);
  c.ellipse(0.5, 0.63, 0.15, 0.11, cream);
  for (final x in const [0.38, 0.62]) {
    c.circle(x, 0.45, 0.045, black);
    c.dot(x - 0.015, 0.435, white);
  }
  c.ellipse(0.5, 0.57, 0.06, 0.035, black);
  c.line(0.5, 0.59, 0.5, 0.64, 0.03, black);
  c.ellipse(0.5, 0.69, 0.045, 0.045, pink);
  return c.toPuzzle(id: id, title: 'Best Buddy', palette: const [
    0xFFFFF9C4, 0xFFFFF59D, 0xFFD7A86E, 0xFFEFCB97, 0xFF8D6E63, 0xFF5D4037, //
    0xFFFFF3E0, 0xFF212121, 0xFFFFFFFF, 0xFFF06292, 0xFFE53935, 0xFFFFC107,
  ]);
}

Puzzle tulips(String id, int n) {
  const bg = 0, bgLow = 1, stem = 2, leaf = 3, redDark = 4, red = 5, pinkDark = 6, pink = 7;
  const yellowDark = 8, yellow = 9, ribbon = 10, ribbonLight = 11, paper = 12, paperShade = 13;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.85, 1, 1, bgLow);
  for (final (x, y) in const [(0.30, 0.38), (0.5, 0.30), (0.70, 0.38)]) {
    c.line(0.5, 0.80, x, y, 0.035, stem);
  }
  c.ellipse(0.36, 0.60, 0.05, 0.15, leaf, angle: -0.5);
  c.ellipse(0.64, 0.60, 0.05, 0.15, leaf, angle: 0.5);
  void tulip(double cx, double cy, int dark, int light) {
    final cup = ArtCanvas.inEllipse(cx, cy, 0.09, 0.08);
    final petals = ArtCanvas.inPolygon([
      (cx - 0.09, cy), (cx - 0.09, cy - 0.11), (cx - 0.045, cy - 0.05), (cx, cy - 0.13), //
      (cx + 0.045, cy - 0.05), (cx + 0.09, cy - 0.11), (cx + 0.09, cy),
    ]);
    c.fillShaded((x, y) => cup(x, y) || petals(x, y), cx, cy - 0.03, 0.10, [dark, light, light]);
  }
  tulip(0.30, 0.36, redDark, red);
  tulip(0.70, 0.36, yellowDark, yellow);
  tulip(0.5, 0.28, pinkDark, pink);
  final wrap = ArtCanvas.inPolygon(const [(0.29, 0.58), (0.71, 0.58), (0.58, 0.96), (0.42, 0.96)]);
  c.fill(wrap, paper);
  c.fill((x, y) => wrap(x, y) && x > 0.5, paperShade);
  c.rect(0.39, 0.72, 0.61, 0.77, ribbon);
  c.ellipse(0.43, 0.745, 0.07, 0.035, ribbonLight, angle: 0.4);
  c.ellipse(0.57, 0.745, 0.07, 0.035, ribbonLight, angle: -0.4);
  return c.toPuzzle(id: id, title: 'Tulip Bouquet', palette: const [
    0xFFF3E5F5, 0xFFE1BEE7, 0xFF388E3C, 0xFF66BB6A, 0xFFC62828, 0xFFEF5350, 0xFFD81B60, //
    0xFFF48FB1, 0xFFF9A825, 0xFFFFEE58, 0xFF5C6BC0, 0xFF9FA8DA, 0xFFFFF8E1, 0xFFFFE0B2,
  ]);
}

Puzzle moonlight(String id, int n) {
  const moon = 3, moonShade = 4, star = 5, starWarm = 6, hill = 7, hillFar = 8;
  const house = 9, roof = 10, window = 11, kitty = 12;
  final c = ArtCanvas(n, n);
  c.bands(const [0, 1, 2], bottom: 0.80);
  final disc = ArtCanvas.inCircle(0.70, 0.25, 0.16);
  final bite = ArtCanvas.inCircle(0.77, 0.20, 0.135);
  c.fillShaded((x, y) => disc(x, y) && !bite(x, y), 0.70, 0.25, 0.16, const [moonShade, moon, moon]);
  const stars = [(0.10, 0.10), (0.25, 0.18), (0.40, 0.08), (0.15, 0.35), (0.52, 0.30), (0.88, 0.45), (0.35, 0.45), (0.92, 0.08)];
  for (var i = 0; i < stars.length; i++) {
    final (x, y) = stars[i];
    c.dot(x, y, i % 3 == 0 ? starWarm : star);
  }
  c.star(0.30, 0.28, 0.05, 0.018, 4, star);
  c.ellipse(0.25, 1.05, 0.58, 0.33, hillFar);
  c.ellipse(0.82, 1.10, 0.55, 0.30, hill);
  c.rect(0.18, 0.66, 0.36, 0.80, house);
  c.rect(0.31, 0.55, 0.34, 0.63, roof);
  c.polygon(const [(0.14, 0.675), (0.27, 0.55), (0.40, 0.675)], roof);
  c.rect(0.21, 0.70, 0.26, 0.75, window);
  c.rect(0.29, 0.70, 0.34, 0.75, window);
  c.ellipse(0.72, 0.785, 0.055, 0.04, kitty);
  c.circle(0.765, 0.735, 0.03, kitty);
  c.polygon(const [(0.745, 0.73), (0.75, 0.69), (0.765, 0.715)], kitty);
  c.polygon(const [(0.765, 0.715), (0.78, 0.69), (0.787, 0.73)], kitty);
  c.line(0.67, 0.79, 0.63, 0.71, 0.03, kitty);
  return c.toPuzzle(id: id, title: 'Moonlit Watch', palette: const [
    0xFF0D1B3E, 0xFF1A2A5C, 0xFF283C7A, 0xFFFFF59D, 0xFFFFE082, 0xFFFFFFFF, 0xFFFFF176, //
    0xFF1B3A2F, 0xFF2E5E4E, 0xFF6D4C41, 0xFF8E2C2C, 0xFFFFD54F, 0xFF000000,
  ]);
}
