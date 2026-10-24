import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// The Cat Café course: cats, kittens and café things, drawn in the same
// flat, round style as the app's mascot.

/// A mascot-style cat head: wide round face, small ears, dot eyes, blush and
/// a tiny nose. [r] is the face half-width; the face is a bit wider than tall.
void catHead(
  ArtCanvas c,
  double cx,
  double cy,
  double r, {
  required int fur,
  required int ear,
  required int eye,
  required int nose,
  int? blush,
  int? whisker,
  int? stripe,
  bool sleepy = false,
}) {
  for (final m in const [false, true]) {
    double fx(double x) => m ? cx - (x - cx) : x;
    c.polygon([(fx(cx - r * 0.82), cy - r * 0.2), (fx(cx - r * 0.7), cy - r * 1.05), (fx(cx - r * 0.25), cy - r * 0.62)], fur);
    c.polygon([(fx(cx - r * 0.66), cy - r * 0.32), (fx(cx - r * 0.6), cy - r * 0.82), (fx(cx - r * 0.34), cy - r * 0.55)], ear);
  }
  c.ellipse(cx, cy, r, r * 0.78, fur);
  if (stripe != null) {
    c.line(cx, cy - r * 0.78, cx, cy - r * 0.45, r * 0.12, stripe);
    c.line(cx - r * 0.22, cy - r * 0.74, cx - r * 0.3, cy - r * 0.45, r * 0.1, stripe);
    c.line(cx + r * 0.22, cy - r * 0.74, cx + r * 0.3, cy - r * 0.45, r * 0.1, stripe);
  }
  final stroke = math.max(r * 0.08, 1.1 / c.width);
  final cell = 1 / c.width;
  for (final x in [cx - r * 0.38, cx + r * 0.38]) {
    if (sleepy) {
      c.line(x - r * 0.12, cy - r * 0.02, x + r * 0.12, cy - r * 0.02, stroke, eye);
    } else {
      c.ellipse(x, cy - r * 0.02, math.max(r * 0.08, 0.6 / c.width), math.max(r * 0.11, 0.8 / c.width), eye);
    }
    if (blush != null) c.circle(x + (x < cx ? -r * 0.22 : r * 0.22), cy + r * 0.2, math.max(r * 0.1, cell * 0.75), blush);
  }
  c.ellipse(cx, cy + r * 0.24, math.max(r * 0.07, cell * 0.6), math.max(r * 0.05, cell * 0.6), nose);
  if (whisker != null) {
    for (final m in const [false, true]) {
      double fx(double x) => m ? cx - (x - cx) : x;
      c.line(fx(cx - r * 0.62), cy + r * 0.04, fx(cx - r * 1.02), cy - r * 0.02, stroke * 0.7, whisker);
      c.line(fx(cx - r * 0.62), cy + r * 0.22, fx(cx - r * 1.02), cy + r * 0.26, stroke * 0.7, whisker);
    }
  }
}

// ---- Easy -----------------------------------------------------------------

Puzzle cafeCat(String id, int n) {
  const bg = 0, fur = 1, ear = 2, eye = 3, nose = 4, blush = 5, whisker = 6;
  final c = ArtCanvas(n, n, background: bg);
  catHead(c, 0.5, 0.55, 0.38, fur: fur, ear: ear, eye: eye, nose: nose, blush: blush, whisker: whisker);
  return c.toPuzzle(id: id, title: 'Café Cat', palette: const [
    0xFFFFD6E3, 0xFFFFFFFF, 0xFFFF8FAB, 0xFF2E2233, 0xFFE85A86, 0xFFFFAB91, 0xFF6D5B7B, //
  ]);
}

Puzzle yarnBall(String id, int n) {
  const bg = 0, yarnDark = 1, yarn = 2, yarnLight = 3, thread = 4, paw = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.48, 0.3), 0.5, 0.48, 0.3, const [yarnDark, yarn, yarn, yarnLight]);
  final ball = ArtCanvas.inCircle(0.5, 0.48, 0.3);
  for (final (x1, y1, x2, y2) in const [(0.2, 0.6, 0.7, 0.2), (0.3, 0.75, 0.8, 0.4), (0.22, 0.4, 0.55, 0.18)]) {
    c.fill((x, y) => ball(x, y) && ArtCanvas.inLine(x1, y1, x2, y2, 0.04)(x, y), yarnDark);
  }
  c.line(0.76, 0.6, 0.95, 0.85, 0.05, thread);
  c.line(0.08, 0.9, 0.95, 0.85, 0.05, thread);
  c.circle(0.17, 0.2, 0.06, paw);
  for (final (x, y) in const [(0.1, 0.1), (0.17, 0.08), (0.24, 0.1), (0.09, 0.17)]) {
    c.circle(x, y, 0.025, paw);
  }
  return c.toPuzzle(id: id, title: 'Yarn Ball', palette: const [
    0xFFFFF3E0, 0xFF7E57C2, 0xFFB39DDB, 0xFFD1C4E9, 0xFF9575CD, 0xFFF48FB1, //
  ]);
}

Puzzle milkSaucer(String id, int n) {
  const bg = 0, floor = 1, saucer = 2, saucerShade = 3, milk = 4, bottle = 5, cap = 6, label = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.7, 1, 1, floor);
  c.ellipse(0.38, 0.82, 0.3, 0.1, saucerShade);
  c.ellipse(0.38, 0.8, 0.28, 0.085, saucer);
  c.ellipse(0.38, 0.8, 0.22, 0.055, milk);
  c.rect(0.66, 0.3, 0.88, 0.75, bottle);
  c.rect(0.7, 0.18, 0.84, 0.32, bottle);
  c.rect(0.69, 0.14, 0.85, 0.2, cap);
  c.rect(0.66, 0.45, 0.88, 0.58, label);
  c.rect(0.7, 0.3, 0.74, 0.44, milk);
  return c.toPuzzle(id: id, title: 'Milk Time', palette: const [
    0xFFE1F5FE, 0xFFFFCC80, 0xFF4FC3F7, 0xFF0288D1, 0xFFFFFFFF, 0xFFECEFF1, 0xFF1565C0, 0xFFF48FB1, //
  ]);
}

Puzzle pawLatte(String id, int n) {
  const bg = 0, cup = 1, cupShade = 2, coffee = 3, foam = 4, saucer = 5, heart = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 0.86, 0.4, 0.09, saucer);
  c.ring(0.78, 0.55, 0.07, 0.13, cupShade);
  c.ellipse(0.47, 0.75, 0.3, 0.1, cupShade);
  c.rect(0.17, 0.42, 0.77, 0.75, cup);
  c.ellipse(0.47, 0.75, 0.3, 0.1, cup);
  c.fill((x, y) => x > 0.6 && x < 0.77 && y > 0.42 && y < 0.75, cupShade);
  c.ellipse(0.47, 0.42, 0.31, 0.11, cupShade);
  c.ellipse(0.47, 0.42, 0.27, 0.085, coffee);
  c.ellipse(0.47, 0.46, 0.11, 0.05, foam);
  for (final (x, y) in const [(0.33, 0.39), (0.42, 0.35), (0.52, 0.35), (0.61, 0.39)]) {
    c.ellipse(x, y, 0.045, 0.035, foam);
  }
  c.heart(0.2, 0.2, 0.07, heart);
  c.heart(0.78, 0.15, 0.05, heart);
  return c.toPuzzle(id: id, title: 'Paw Latte', palette: const [
    0xFFB3E5FC, 0xFFFFFFFF, 0xFFCFD8DC, 0xFF8D6E63, 0xFFFFF3E0, 0xFF90CAF9, 0xFFF48FB1, //
  ]);
}

Puzzle fishTreat(String id, int n) {
  const bg = 0, bone = 1, bowl = 2, bowlDark = 3, fish = 4, fishDark = 5, eye = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 0.82, 0.42, 0.14, bowlDark);
  c.ellipse(0.5, 0.78, 0.4, 0.12, bowl);
  c.ellipse(0.5, 0.78, 0.32, 0.07, bowlDark);
  c.fillShaded(ArtCanvas.inEllipse(0.45, 0.42, 0.3, 0.17), 0.45, 0.42, 0.3, const [fishDark, fish, fish]);
  c.polygon(const [(0.7, 0.42), (0.92, 0.25), (0.9, 0.42), (0.92, 0.6)], fishDark);
  c.polygon(const [(0.38, 0.27), (0.5, 0.12), (0.55, 0.28)], fishDark);
  c.circle(0.26, 0.4, 0.04, eye);
  c.line(0.14, 0.14, 0.22, 0.14, 0.03, bone);
  c.line(0.1, 0.1, 0.1, 0.18, 0.03, bone);
  c.line(0.26, 0.1, 0.26, 0.18, 0.03, bone);
  return c.toPuzzle(id: id, title: 'Fishy Treat', palette: const [
    0xFFE8F5E9, 0xFFFFFFFF, 0xFF4DD0C8, 0xFF26A69A, 0xFFFFA726, 0xFFEF6C00, 0xFF263238, //
  ]);
}

// ---- Medium ---------------------------------------------------------------

Puzzle catNap(String id, int n) {
  const bg = 0, cushion = 1, cushionDark = 2, fur = 3, furDark = 4, ear = 5, eye = 6, nose = 7, z = 8;
  const furLight = 9, blush = 10;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 0.78, 0.46, 0.17, cushionDark);
  c.ellipse(0.5, 0.74, 0.44, 0.15, cushion);
  // Curled body, tail wrapping round the front.
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.58, 0.36, 0.24), 0.5, 0.58, 0.36, const [furDark, furDark, fur, fur]);
  c.line(0.2, 0.72, 0.62, 0.8, 0.09, furDark);
  c.line(0.62, 0.8, 0.8, 0.72, 0.09, furDark);
  catHead(c, 0.6, 0.48, 0.22, fur: furLight, ear: ear, eye: eye, nose: nose, blush: blush, sleepy: true);
  for (final (x, y, s) in const [(0.82, 0.3, 0.05), (0.88, 0.2, 0.04), (0.93, 0.12, 0.03)]) {
    c.line(x - s, y - s, x + s, y - s, s * 0.6, z);
    c.line(x + s, y - s, x - s, y + s, s * 0.6, z);
    c.line(x - s, y + s, x + s, y + s, s * 0.6, z);
  }
  return c.toPuzzle(id: id, title: 'Cat Nap', palette: const [
    0xFFF3E5F5, 0xFFB39DDB, 0xFF9575CD, 0xFFFFCC80, 0xFFE09A3E, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFF7E57C2, //
    0xFFFFF3E0, 0xFFFFAB91,
  ]);
}

Puzzle tabby(String id, int n) {
  const bg = 0, bgDot = 1, fur = 2, stripe = 3, ear = 4, eye = 5, nose = 6, blush = 7, white = 8;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 6 == 0, bgDot);
  c.ellipse(0.5, 1.0, 0.4, 0.22, fur);
  c.ellipse(0.5, 0.95, 0.2, 0.12, white);
  catHead(c, 0.5, 0.5, 0.38, fur: fur, ear: ear, eye: eye, nose: nose, blush: blush, stripe: stripe);
  c.ellipse(0.5, 0.66, 0.14, 0.08, white);
  c.polygon(const [(0.47, 0.64), (0.53, 0.64), (0.5, 0.69)], nose);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.line(fx(0.14), 0.42, fx(0.26), 0.5, 0.045, stripe);
    c.line(fx(0.13), 0.55, fx(0.25), 0.58, 0.045, stripe);
  }
  return c.toPuzzle(id: id, title: 'Tabby', palette: const [
    0xFFFFF8E1, 0xFFFFECB3, 0xFFFFB74D, 0xFFE65100, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91, 0xFFFFFFFF, //
  ]);
}

Puzzle kittyCupcake(String id, int n) {
  const bg = 0, wrapper = 1, wrapperDark = 2, frosting = 3, frostingDark = 4, ear = 5, eye = 6, nose = 7, cherry = 8;
  final c = ArtCanvas(n, n, background: bg);
  c.polygon(const [(0.2, 0.6), (0.8, 0.6), (0.72, 0.95), (0.28, 0.95)], wrapper);
  for (var i = 0; i < 4; i++) {
    final x = 0.26 + i * 0.16;
    c.line(x, 0.6, x + 0.03, 0.95, 0.03, wrapperDark);
  }
  catHead(c, 0.5, 0.42, 0.34, fur: frosting, ear: ear, eye: eye, nose: nose);
  c.ellipse(0.5, 0.6, 0.34, 0.06, frostingDark);
  c.circle(0.5, 0.1, 0.06, cherry);
  c.line(0.5, 0.05, 0.56, 0.0, 0.02, wrapperDark);
  return c.toPuzzle(id: id, title: 'Kitty Cupcake', palette: const [
    0xFFE1F5FE, 0xFFF8BBD0, 0xFFEC407A, 0xFFFFF8F0, 0xFFE8D9CC, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFE53935, //
  ]);
}

Puzzle windowSeat(String id, int n) {
  const wall = 0, frame = 1, skyTop = 2, sky = 3, skyLow = 4, sun = 5, cat = 6, sill = 7, plant = 8, pot = 9;
  final c = ArtCanvas(n, n, background: wall);
  c.rect(0.1, 0.08, 0.9, 0.78, frame);
  c.bands(const [skyTop, sky, skyLow], top: 0.13, bottom: 0.73);
  c.fill((x, y) => x > 0.15 && x < 0.85 && y > 0.13 && y < 0.73, skyTop);
  c.fill((x, y) => x > 0.15 && x < 0.85 && y > 0.33 && y < 0.73, sky);
  c.fill((x, y) => x > 0.15 && x < 0.85 && y > 0.55 && y < 0.73, skyLow);
  c.circle(0.62, 0.55, 0.14, sun);
  c.fill((x, y) => x > 0.15 && x < 0.85 && y > 0.73 && y < 0.78, frame);
  c.rect(0.48, 0.13, 0.52, 0.73, frame);
  c.rect(0.15, 0.42, 0.85, 0.46, frame);
  // Cat silhouette sitting on the sill, tail curling up.
  c.ellipse(0.32, 0.62, 0.13, 0.16, cat);
  c.circle(0.32, 0.4, 0.1, cat);
  c.polygon(const [(0.24, 0.36), (0.25, 0.26), (0.32, 0.32)], cat);
  c.polygon(const [(0.4, 0.36), (0.39, 0.26), (0.32, 0.32)], cat);
  c.line(0.44, 0.72, 0.56, 0.6, 0.05, cat);
  c.line(0.56, 0.6, 0.5, 0.5, 0.05, cat);
  c.rect(0.05, 0.78, 0.95, 0.85, sill);
  c.rect(0.74, 0.86, 0.88, 0.98, pot);
  for (final (x, y) in const [(0.75, 0.82), (0.81, 0.76), (0.88, 0.8)]) {
    c.ellipse(x, y, 0.045, 0.07, plant, angle: (x - 0.81) * 3);
  }
  return c.toPuzzle(id: id, title: 'Window Seat', palette: const [
    0xFFFFF3E0, 0xFFFFFFFF, 0xFF7E57C2, 0xFFF48FB1, 0xFFFFB74D, 0xFFFFEE58, 0xFF37293E, 0xFFD7CCC8, 0xFF66BB6A, //
    0xFFE57373,
  ]);
}

Puzzle tuxedo(String id, int n) {
  const bg = 0, black = 1, white = 2, ear = 3, eye = 4, nose = 5, bow = 6, eyeShine = white;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 1.02, 0.4, 0.26, black);
  c.ellipse(0.5, 1.02, 0.2, 0.2, white);
  catHead(c, 0.5, 0.48, 0.38, fur: black, ear: ear, eye: eye, nose: nose);
  c.ellipse(0.5, 0.62, 0.2, 0.12, white);
  c.polygon(const [(0.42, 0.5), (0.58, 0.5), (0.5, 0.2)], white);
  for (final x in const [0.36, 0.64]) {
    c.ellipse(x, 0.47, 0.055, 0.07, bow);
    c.ellipse(x, 0.48, 0.028, 0.055, eye);
    c.dot(x - 0.015, 0.45, eyeShine);
  }
  c.polygon(const [(0.47, 0.56), (0.53, 0.56), (0.5, 0.605)], nose);
  c.polygon(const [(0.5, 0.8), (0.38, 0.73), (0.38, 0.87)], bow);
  c.polygon(const [(0.5, 0.8), (0.62, 0.73), (0.62, 0.87)], bow);
  c.circle(0.5, 0.8, 0.03, nose);
  return c.toPuzzle(id: id, title: 'Tuxedo', palette: const [
    0xFFFCE4EC, 0xFF37293E, 0xFFFFFFFF, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFF8BC34A, //
  ]);
}

// ---- Hard -----------------------------------------------------------------

Puzzle catLoaf(String id, int n) {
  const wall = 0, wallStripe = 1, cushion = 2, cushionDark = 3, cushionLight = 4, fur = 5, furDark = 6, furLight = 7;
  const ear = 8, eye = 9, nose = 10, blush = 11, paw = 12;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => c.col(x) % 6 < 2, wallStripe);
  c.ellipse(0.5, 0.8, 0.47, 0.17, cushionDark);
  c.ellipse(0.5, 0.76, 0.46, 0.16, cushion);
  c.ellipse(0.5, 0.74, 0.36, 0.09, cushionLight);
  // The loaf.
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.58, 0.36, 0.2), 0.5, 0.58, 0.36, const [furDark, fur, fur, furLight]);
  c.rect(0.14, 0.58, 0.86, 0.72, fur);
  c.ellipse(0.5, 0.72, 0.36, 0.06, furDark);
  for (final x in const [0.36, 0.64]) {
    c.ellipse(x, 0.73, 0.07, 0.04, paw);
  }
  catHead(c, 0.5, 0.42, 0.26, fur: fur, ear: ear, eye: eye, nose: nose, blush: blush, sleepy: false);
  c.line(0.5, 0.49, 0.5, 0.53, 0.03, nose);
  c.line(0.5, 0.53, 0.45, 0.55, 0.025, nose);
  c.line(0.5, 0.53, 0.55, 0.55, 0.025, nose);
  // Tail peeking out.
  c.line(0.84, 0.68, 0.95, 0.6, 0.06, furDark);
  c.line(0.95, 0.6, 0.9, 0.5, 0.06, furDark);
  return c.toPuzzle(id: id, title: 'Cat Loaf', palette: const [
    0xFFFFF3E0, 0xFFFFE6C8, 0xFF9FA8DA, 0xFF7986CB, 0xFFC5CAE9, 0xFFFFCC80, 0xFFF4A74B, 0xFFFFE0B2, //
    0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91, 0xFFFFE0B2,
  ]);
}

Puzzle boxCat(String id, int n) {
  const floor = 0, floorDark = 1, box = 2, boxDark = 3, boxLight = 4, tape = 5, inside = 6;
  const fur = 7, furDark = 8, ear = 9, eye = 10, nose = 11, blush = 12, paw = 13;
  final c = ArtCanvas(n, n, background: floor);
  c.fill((x, y) => y > 0.72 && (c.col(x) ~/ 4 + c.row(y) ~/ 4).isEven, floorDark);
  c.rect(0.14, 0.36, 0.86, 0.9, inside);
  c.polygon(const [(0.14, 0.36), (0.06, 0.2), (0.14, 0.2), (0.22, 0.36)], boxDark);
  c.polygon(const [(0.86, 0.36), (0.94, 0.2), (0.86, 0.2), (0.78, 0.36)], boxDark);
  c.polygon(const [(0.14, 0.36), (0.2, 0.08), (0.44, 0.1), (0.42, 0.36)], boxLight);
  c.polygon(const [(0.86, 0.36), (0.8, 0.08), (0.56, 0.1), (0.58, 0.36)], boxLight);
  // Cat sitting inside.
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.6, 0.26, 0.2), 0.5, 0.6, 0.26, const [furDark, fur, fur]);
  catHead(c, 0.5, 0.42, 0.24, fur: fur, ear: ear, eye: eye, nose: nose, blush: blush);
  // Front of the box, flaps and tape.
  c.rect(0.12, 0.58, 0.88, 0.92, box);
  c.rect(0.12, 0.58, 0.88, 0.63, boxDark);
  c.rect(0.46, 0.58, 0.54, 0.92, tape);
  c.rect(0.14, 0.8, 0.4, 0.86, boxDark);
  for (final x in const [0.3, 0.7]) {
    c.ellipse(x, 0.6, 0.07, 0.04, paw);
  }
  return c.toPuzzle(id: id, title: 'If I Fits', palette: const [
    0xFFEFEBE9, 0xFFD7CCC8, 0xFFD2A679, 0xFFA1744D, 0xFFE6C39A, 0xFFF5F5F5, 0xFF6D4C41, //
    0xFF90A4AE, 0xFF607D8B, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91, 0xFFCFD8DC,
  ]);
}

Puzzle calico(String id, int n) {
  const bg = 0, bgDot = 1, white = 2, orange = 3, black = 4, ear = 5, eye = 6, nose = 7, blush = 8, collar = 9, bell = 10;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 3 + c.row(y) * 5) % 11 == 0, bgDot);
  c.ellipse(0.5, 1.0, 0.4, 0.26, white);
  c.ellipse(0.26, 0.98, 0.14, 0.14, orange);
  catHead(c, 0.5, 0.46, 0.38, fur: white, ear: ear, eye: eye, nose: nose, blush: blush);
  final head = ArtCanvas.inEllipse(0.5, 0.46, 0.38, 0.3);
  c.fill((x, y) => head(x, y) && ArtCanvas.inEllipse(0.3, 0.3, 0.2, 0.16, angle: 0.5)(x, y), orange);
  c.fill((x, y) => head(x, y) && ArtCanvas.inEllipse(0.7, 0.28, 0.16, 0.14, angle: -0.4)(x, y), black);
  c.fill((x, y) => head(x, y) && ArtCanvas.inEllipse(0.78, 0.58, 0.12, 0.1)(x, y), orange);
  c.polygon(const [(0.18, 0.26), (0.2, 0.06), (0.37, 0.2)], orange);
  c.polygon(const [(0.82, 0.26), (0.8, 0.06), (0.63, 0.2)], black);
  for (final x in const [0.36, 0.64]) {
    c.ellipse(x, 0.45, 0.03, 0.045, eye);
  }
  c.polygon(const [(0.47, 0.54), (0.53, 0.54), (0.5, 0.58)], nose);
  c.rect(0.3, 0.74, 0.7, 0.8, collar);
  c.circle(0.5, 0.83, 0.05, bell);
  return c.toPuzzle(id: id, title: 'Calico', palette: const [
    0xFFE8F5E9, 0xFFC8E6C9, 0xFFFFFFFF, 0xFFFF9800, 0xFF37293E, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91, //
    0xFFE53935, 0xFFFFD54F,
  ]);
}

Puzzle barista(String id, int n) {
  const wall = 0, shelf = 1, jar = 2, jarDark = 3, counter = 4, counterDark = 5, apron = 6, apronDark = 7;
  const fur = 8, furDark = 9, ear = 10, eye = 11, nose = 12, blush = 13, cup = 14, coffee = 15, steam = 16;
  final c = ArtCanvas(n, n, background: wall);
  c.rect(0, 0.12, 1, 0.15, shelf);
  for (final (x, h) in const [(0.12, 0.08), (0.28, 0.06), (0.72, 0.07), (0.88, 0.09)]) {
    c.rect(x - 0.05, 0.12 - h, x + 0.05, 0.12, jar);
    c.rect(x - 0.05, 0.12 - h, x + 0.05, 0.12 - h + 0.02, jarDark);
  }
  c.rect(0, 0.78, 1, 1, counter);
  c.rect(0, 0.78, 1, 0.82, counterDark);
  // Body with apron.
  c.ellipse(0.5, 0.78, 0.3, 0.26, fur);
  c.polygon(const [(0.3, 0.62), (0.7, 0.62), (0.74, 0.8), (0.26, 0.8)], apron);
  c.rect(0.4, 0.55, 0.6, 0.63, apronDark);
  c.rect(0.44, 0.68, 0.56, 0.76, apronDark);
  catHead(c, 0.5, 0.42, 0.28, fur: fur, ear: ear, eye: eye, nose: nose, blush: blush, whisker: furDark);
  // Paws holding a cup.
  c.ellipse(0.74, 0.72, 0.07, 0.04, fur);
  c.rect(0.7, 0.62, 0.84, 0.74, cup);
  c.ellipse(0.77, 0.62, 0.07, 0.025, coffee);
  c.ring(0.87, 0.67, 0.025, 0.045, cup);
  c.line(0.74, 0.56, 0.76, 0.48, 0.02, steam);
  c.line(0.8, 0.56, 0.82, 0.48, 0.02, steam);
  c.ellipse(0.26, 0.74, 0.07, 0.04, fur);
  return c.toPuzzle(id: id, title: 'Barista', palette: const [
    0xFFFFF3E0, 0xFFA1887F, 0xFFFFCC80, 0xFFFF8A65, 0xFF8D6E63, 0xFF5D4037, 0xFF8BC34A, 0xFF558B2F, //
    0xFFBCAAA4, 0xFF8D6E63, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91, 0xFFFFFFFF, 0xFF6D4C41, 0xFFE0E0E0,
  ]);
}

Puzzle cuddlePuddle(String id, int n) {
  const bg = 0, blanket = 1, blanketDark = 2, fur1 = 3, fur1Dark = 4, fur2 = 5, fur2Dark = 6, ear = 7, eye = 8;
  const nose = 9, blush = 10, heart = 11;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 0.78, 0.48, 0.22, blanketDark);
  c.ellipse(0.5, 0.74, 0.46, 0.2, blanket);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.74, 0.46, 0.2)(x, y) && (c.col(x) + c.row(y)) % 5 == 0, blanketDark);
  c.fillShaded(ArtCanvas.inEllipse(0.32, 0.62, 0.26, 0.18), 0.32, 0.62, 0.26, const [fur1Dark, fur1, fur1]);
  c.fillShaded(ArtCanvas.inEllipse(0.68, 0.64, 0.26, 0.18), 0.68, 0.64, 0.26, const [fur2Dark, fur2, fur2]);
  catHead(c, 0.3, 0.44, 0.22, fur: fur1, ear: ear, eye: eye, nose: nose, blush: blush, sleepy: true);
  catHead(c, 0.68, 0.46, 0.22, fur: fur2, ear: ear, eye: eye, nose: nose, blush: blush);
  c.line(0.52, 0.72, 0.62, 0.8, 0.06, fur1Dark);
  c.heart(0.5, 0.18, 0.08, heart);
  c.heart(0.68, 0.1, 0.05, heart);
  return c.toPuzzle(id: id, title: 'Cuddle Puddle', palette: const [
    0xFFE3F2FD, 0xFFB39DDB, 0xFF9575CD, 0xFFFFF8F0, 0xFFE8D9CC, 0xFFFFCC80, 0xFFF4A74B, 0xFFFFC1D3, 0xFF2E2233, //
    0xFFF2709A, 0xFFFFAB91, 0xFFF48FB1,
  ]);
}

// ---- Extreme --------------------------------------------------------------

Puzzle xCafeCounter(String id, int n) {
  const wall = 0, wallDot = 1, board = 2, chalk = 3, counter = 4, counterDark = 5, counterLight = 6;
  const cup = 7, coffee = 8, cake = 9, cakeTop = 10, plate = 11;
  const fur1 = 12, fur1Dark = 13, fur2 = 14, ear = 15, eye = 16, nose = 17, blush = 18;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => c.col(x) % 5 == 2 && c.row(y) % 5 == 2 && y < 0.5, wallDot);
  c.rect(0.08, 0.06, 0.92, 0.3, board);
  for (final (x1, x2, y) in const [(0.14, 0.4, 0.12), (0.14, 0.55, 0.18), (0.14, 0.34, 0.24), (0.6, 0.86, 0.12), (0.66, 0.86, 0.18), (0.6, 0.8, 0.24)]) {
    c.line(x1, y, x2, y, 0.025, chalk);
  }
  c.rect(0, 0.6, 1, 1, counter);
  c.rect(0, 0.6, 1, 0.65, counterLight);
  c.fill((x, y) => y > 0.68 && c.col(x) % 7 == 3, counterDark);
  // Two cats behind the counter.
  c.ellipse(0.26, 0.66, 0.2, 0.14, fur1);
  catHead(c, 0.26, 0.47, 0.17, fur: fur1, ear: ear, eye: eye, nose: nose, blush: blush, whisker: fur1Dark);
  c.ellipse(0.68, 0.66, 0.2, 0.14, fur2);
  catHead(c, 0.68, 0.45, 0.19, fur: fur2, ear: ear, eye: eye, nose: nose, blush: blush, sleepy: true);
  // Cups and a cake on the counter.
  for (final x in const [0.1, 0.5]) {
    c.rect(x - 0.05, 0.56, x + 0.05, 0.64, cup);
    c.ellipse(x, 0.56, 0.05, 0.018, coffee);
    c.ring(x + 0.07, 0.6, 0.015, 0.03, cup);
  }
  c.ellipse(0.87, 0.64, 0.12, 0.035, plate);
  c.rect(0.79, 0.52, 0.95, 0.63, cake);
  c.rect(0.79, 0.5, 0.95, 0.54, cakeTop);
  c.circle(0.87, 0.48, 0.02, nose);
  return c.toPuzzle(id: id, title: 'Café Counter', palette: const [
    0xFFFFF3E0, 0xFFFFE0B2, 0xFF3E4A3B, 0xFFE8F0E6, 0xFFA1724B, 0xFF7A5234, 0xFFC99A6E, //
    0xFFFFFFFF, 0xFF6D4C41, 0xFFF8BBD0, 0xFFFFFFFF, 0xFFCFD8DC, 0xFFFFCC80, 0xFFE09A3E, 0xFF90A4AE, //
    0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91,
  ]);
}

Puzzle xRainyDay(String id, int n) {
  const wall = 0, frame = 1, sky = 2, skyDark = 3, rain = 4, cloud = 5, sill = 6;
  const fur = 7, furDark = 8, ear = 9, eye = 10, nose = 11, blush = 12, mug = 13, cocoa = 14, steam = 15, plant = 16, pot = 17;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => (c.col(x) + c.row(y)) % 8 == 0, frame);
  c.rect(0.06, 0.04, 0.94, 0.7, frame);
  c.rect(0.1, 0.08, 0.9, 0.66, sky);
  c.fill((x, y) => x > 0.1 && x < 0.9 && y > 0.08 && y < 0.3, skyDark);
  for (final (x, y) in const [(0.3, 0.2), (0.7, 0.14)]) {
    c.ellipse(x, y, 0.14, 0.05, cloud);
    c.circle(x - 0.05, y - 0.03, 0.05, cloud);
    c.circle(x + 0.04, y - 0.04, 0.06, cloud);
  }
  c.fill((x, y) => x > 0.1 && x < 0.9 && y > 0.3 && y < 0.66 && (c.col(x) * 2 + c.row(y)) % 9 == 0, rain);
  c.rect(0.48, 0.08, 0.52, 0.66, frame);
  c.rect(0.1, 0.36, 0.9, 0.4, frame);
  // Cat on the sill with a mug of cocoa.
  c.rect(0.02, 0.7, 0.98, 0.78, sill);
  c.fillShaded(ArtCanvas.inEllipse(0.4, 0.66, 0.26, 0.16), 0.4, 0.66, 0.26, const [furDark, fur, fur]);
  catHead(c, 0.4, 0.48, 0.2, fur: fur, ear: ear, eye: eye, nose: nose, blush: blush, whisker: furDark);
  c.line(0.62, 0.74, 0.8, 0.68, 0.06, furDark);
  c.line(0.8, 0.68, 0.76, 0.58, 0.06, furDark);
  c.rect(0.56, 0.6, 0.68, 0.72, mug);
  c.ellipse(0.62, 0.6, 0.06, 0.02, cocoa);
  c.ring(0.7, 0.66, 0.018, 0.035, mug);
  c.line(0.6, 0.55, 0.61, 0.47, 0.02, steam);
  c.line(0.65, 0.55, 0.66, 0.47, 0.02, steam);
  // Plant on the floor.
  c.rect(0.8, 0.86, 0.92, 0.98, pot);
  for (final (x, y, a) in const [(0.8, 0.8, 0.6), (0.86, 0.76, 0.0), (0.92, 0.8, -0.6)]) {
    c.ellipse(x, y, 0.035, 0.07, plant, angle: a);
  }
  return c.toPuzzle(id: id, title: 'Rainy Day', palette: const [
    0xFFFFF8E1, 0xFFFFFFFF, 0xFF90A4AE, 0xFF607D8B, 0xFFB3E5FC, 0xFFCFD8DC, 0xFFD7CCC8, //
    0xFFFFCC80, 0xFFE09A3E, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91, 0xFFF48FB1, 0xFF6D4C41, 0xFFECEFF1, //
    0xFF66BB6A, 0xFFE57373,
  ]);
}

Puzzle xCatTower(String id, int n) {
  const wall = 0, wallStripe = 1, floor = 2, post = 3, postDark = 4, shelf = 5, shelfDark = 6;
  const fur1 = 7, fur2 = 8, fur3 = 9, furDark = 10, ear = 11, eye = 12, nose = 13, blush = 14, toy = 15;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => c.row(y) % 6 < 2 && y < 0.88, wallStripe);
  c.rect(0, 0.88, 1, 1, floor);
  c.rect(0.46, 0.22, 0.54, 0.9, post);
  c.fill((x, y) => x > 0.46 && x < 0.54 && y > 0.22 && y < 0.9 && c.row(y) % 3 == 0, postDark);
  for (final (y, l, r) in const [(0.9, 0.16, 0.84), (0.64, 0.3, 0.8), (0.42, 0.2, 0.7), (0.22, 0.34, 0.66)]) {
    c.rect(l, y - 0.02, r, y + 0.04, shelfDark);
    c.rect(l, y - 0.04, r, y, shelf);
  }
  // Three cats on three shelves.
  c.ellipse(0.66, 0.62, 0.14, 0.1, fur1);
  catHead(c, 0.66, 0.5, 0.12, fur: fur1, ear: ear, eye: eye, nose: nose, blush: blush, sleepy: true);
  c.ellipse(0.34, 0.4, 0.14, 0.1, fur2);
  catHead(c, 0.34, 0.29, 0.12, fur: fur2, ear: ear, eye: eye, nose: nose, blush: blush);
  c.ellipse(0.5, 0.19, 0.12, 0.08, fur3);
  catHead(c, 0.5, 0.1, 0.11, fur: fur3, ear: ear, eye: eye, nose: nose, blush: blush);
  c.ellipse(0.26, 0.86, 0.14, 0.1, fur3);
  catHead(c, 0.26, 0.75, 0.12, fur: fur3, ear: ear, eye: eye, nose: nose, blush: blush);
  c.line(0.38, 0.9, 0.44, 0.78, 0.04, furDark);
  // A dangling toy mouse.
  c.line(0.8, 0.44, 0.8, 0.56, 0.015, toy);
  c.ellipse(0.8, 0.59, 0.04, 0.03, toy);
  return c.toPuzzle(id: id, title: 'Cat Tower', palette: const [
    0xFFFFF3E0, 0xFFFFE6C8, 0xFFBCAAA4, 0xFFD7B899, 0xFFB08F6B, 0xFF9FA8DA, 0xFF7986CB, //
    0xFFFFCC80, 0xFF90A4AE, 0xFFFFF8F0, 0xFF8D6E63, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91, 0xFFE57373,
  ]);
}

Puzzle xTeaParty(String id, int n) {
  const bg = 0, bgDot = 1, cloth = 2, clothDark = 3, table = 4, teapot = 5, teapotDark = 6, lid = 7;
  const cup = 8, tea = 9, cake = 10, cakeTop = 11, plate = 12;
  const fur1 = 13, fur2 = 14, ear = 15, eye = 16, nose = 17, blush = 18;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 3) % 9 == 0, bgDot);
  c.ellipse(0.5, 0.72, 0.46, 0.12, table);
  c.ellipse(0.5, 0.68, 0.46, 0.12, cloth);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.68, 0.46, 0.12)(x, y) && (c.col(x) ~/ 3 + c.row(y) ~/ 3).isEven, clothDark);
  c.rect(0.12, 0.72, 0.18, 0.95, table);
  c.rect(0.82, 0.72, 0.88, 0.95, table);
  // Two cats seated at the table.
  c.ellipse(0.2, 0.62, 0.17, 0.14, fur1);
  catHead(c, 0.2, 0.44, 0.16, fur: fur1, ear: ear, eye: eye, nose: nose, blush: blush);
  c.ellipse(0.8, 0.62, 0.17, 0.14, fur2);
  catHead(c, 0.8, 0.44, 0.16, fur: fur2, ear: ear, eye: eye, nose: nose, blush: blush, sleepy: true);
  // Teapot in the middle, cups, cake.
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.56, 0.14, 0.11), 0.5, 0.56, 0.14, const [teapotDark, teapot, teapot]);
  c.ellipse(0.5, 0.45, 0.07, 0.025, lid);
  c.circle(0.5, 0.42, 0.02, teapotDark);
  c.line(0.36, 0.55, 0.3, 0.45, 0.03, teapot);
  c.ring(0.66, 0.55, 0.03, 0.055, teapot);
  for (final x in const [0.3, 0.7]) {
    c.ellipse(x, 0.7, 0.07, 0.02, plate);
    c.rect(x - 0.045, 0.63, x + 0.045, 0.69, cup);
    c.ellipse(x, 0.63, 0.045, 0.015, tea);
  }
  c.ellipse(0.5, 0.74, 0.1, 0.03, plate);
  c.rect(0.44, 0.65, 0.56, 0.73, cake);
  c.rect(0.44, 0.64, 0.56, 0.67, cakeTop);
  return c.toPuzzle(id: id, title: 'Tea Party', palette: const [
    0xFFFCE4EC, 0xFFF8BBD0, 0xFFFFFFFF, 0xFFF48FB1, 0xFFA1887F, 0xFF80CBC4, 0xFF4DB6AC, 0xFF26A69A, //
    0xFFFFFFFF, 0xFFD7A86E, 0xFFFFE0B2, 0xFFF48FB1, 0xFFE0E0E0, //
    0xFFFFF8F0, 0xFF90A4AE, 0xFFFFC1D3, 0xFF2E2233, 0xFFF2709A, 0xFFFFAB91,
  ]);
}

Puzzle xNightCafe(String id, int n) {
  const sky = 0, star = 1, moon = 2, wall = 3, wallDark = 4, roof = 5, roofDark = 6, window = 7, windowDark = 8;
  const door = 9, sign = 10, signText = 11, lamp = 12, path = 13, fur = 14, ear = 15, eye = 16, nose = 17, plant = 18;
  final c = ArtCanvas(n, n, background: sky);
  c.fill((x, y) => y < 0.3 && (c.col(x) * 7 + c.row(y) * 13) % 17 == 0, star);
  c.circle(0.84, 0.12, 0.07, moon);
  c.circle(0.87, 0.1, 0.05, sky);
  c.rect(0.08, 0.36, 0.92, 0.84, wall);
  c.fill((x, y) => x > 0.08 && x < 0.92 && y > 0.36 && y < 0.84 && c.row(y) % 4 == 0 && (c.col(x) + c.row(y) ~/ 4 * 2) % 5 == 0, wallDark);
  c.polygon(const [(0.04, 0.38), (0.5, 0.18), (0.96, 0.38)], roof);
  c.polygon(const [(0.04, 0.38), (0.96, 0.38), (0.96, 0.42), (0.04, 0.42)], roofDark);
  // Awning stripes.
  for (var i = 0; i < 7; i++) {
    c.rect(0.08 + i * 0.12, 0.42, 0.14 + i * 0.12, 0.48, i.isEven ? roofDark : roof);
  }
  // Sign with the cat face.
  c.rect(0.3, 0.26, 0.7, 0.36, sign);
  c.line(0.36, 0.31, 0.44, 0.31, 0.02, signText);
  c.line(0.56, 0.31, 0.64, 0.31, 0.02, signText);
  catHead(c, 0.5, 0.32, 0.05, fur: fur, ear: ear, eye: eye, nose: nose);
  // Windows glowing, a cat in one.
  for (final x in const [0.24, 0.76]) {
    c.rect(x - 0.12, 0.52, x + 0.12, 0.72, windowDark);
    c.rect(x - 0.1, 0.54, x + 0.1, 0.7, window);
  }
  c.ellipse(0.24, 0.7, 0.07, 0.05, eye);
  catHead(c, 0.24, 0.62, 0.06, fur: eye, ear: eye, eye: window, nose: eye);
  c.rect(0.42, 0.56, 0.58, 0.84, door);
  c.rect(0.45, 0.59, 0.55, 0.68, window);
  c.circle(0.55, 0.74, 0.012, lamp);
  // Lamps and path.
  for (final x in const [0.14, 0.86]) {
    c.rect(x - 0.012, 0.78, x + 0.012, 0.95, windowDark);
    c.circle(x, 0.76, 0.035, lamp);
  }
  c.rect(0, 0.84, 1, 1, path);
  c.fill((x, y) => y > 0.84 && (c.col(x) ~/ 3 + c.row(y) ~/ 2).isEven, wallDark);
  for (final (x, y) in const [(0.3, 0.82), (0.7, 0.82)]) {
    c.ellipse(x, y, 0.05, 0.04, plant);
    c.rect(x - 0.03, 0.85, x + 0.03, 0.9, roof);
  }
  return c.toPuzzle(id: id, title: 'Night Café', palette: const [
    0xFF2B2A4C, 0xFFFFF59D, 0xFFFFF9C4, 0xFFF3DDC3, 0xFFC9A27F, 0xFFE57373, 0xFFB94A4A, 0xFFFFE082, 0xFF6D4C41, //
    0xFF8D6E63, 0xFFFFFFFF, 0xFFE91E63, 0xFFFFC107, 0xFF8D8F94, 0xFFFFF8F0, 0xFFFFC1D3, 0xFF37293E, 0xFFF2709A, 0xFF66BB6A,
  ]);
}
