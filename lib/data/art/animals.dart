import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// ---- Easy -----------------------------------------------------------------

Puzzle fish(String id, int n) {
  const sea = 0, seaLight = 1, bubble = 2, bodyDark = 3, body = 4, bodyLight = 5, fin = 6, eye = 7;
  final c = ArtCanvas(n, n, background: sea);
  c.rect(0, 0.8, 1, 1, seaLight);
  c.polygon(const [(0.62, 0.5), (0.9, 0.3), (0.86, 0.5), (0.9, 0.7)], fin);
  c.fillShaded(ArtCanvas.inEllipse(0.42, 0.5, 0.3, 0.2), 0.42, 0.5, 0.3, const [bodyDark, body, body, bodyLight]);
  c.polygon(const [(0.36, 0.33), (0.5, 0.2), (0.52, 0.34)], fin);
  c.circle(0.26, 0.45, 0.05, eye);
  c.circle(0.2, 0.2, 0.05, bubble);
  c.circle(0.12, 0.08, 0.035, bubble);
  return c.toPuzzle(id: id, title: 'Goldie', palette: const [
    0xFF81D4FA, 0xFFB3E5FC, 0xFFFFFFFF, 0xFFE65100, 0xFFFF9800, 0xFFFFCC80, 0xFFFF7043, 0xFF263238, //
  ]);
}

Puzzle bunny(String id, int n) {
  const bg = 0, fur = 1, furShade = 2, pink = 3, eye = 4, cheek = 5;
  final c = ArtCanvas(n, n, background: bg);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.ellipse(fx(0.36), 0.25, 0.09, 0.22, fur, angle: m ? 0.15 : -0.15);
    c.ellipse(fx(0.36), 0.27, 0.04, 0.15, pink, angle: m ? 0.15 : -0.15);
  }
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.64, 0.3, 0.26), 0.5, 0.64, 0.3, const [furShade, fur, fur]);
  c.circle(0.4, 0.6, 0.04, eye);
  c.circle(0.6, 0.6, 0.04, eye);
  c.polygon(const [(0.46, 0.7), (0.54, 0.7), (0.5, 0.75)], pink);
  c.circle(0.3, 0.72, 0.045, cheek);
  c.circle(0.7, 0.72, 0.045, cheek);
  return c.toPuzzle(id: id, title: 'Bun Bun', palette: const [
    0xFFDCEDC8, 0xFFFFFFFF, 0xFFD7D7E0, 0xFFF8BBD0, 0xFF3E2723, 0xFFFFAB91, //
  ]);
}

Puzzle chick(String id, int n) {
  const sky = 0, grass = 1, body = 2, bodyShade = 3, beak = 4, eye = 5, wing = 6;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.82, 1, 1, grass);
  c.line(0.42, 0.78, 0.4, 0.88, 0.06, beak);
  c.line(0.58, 0.78, 0.6, 0.88, 0.06, beak);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.52, 0.3), 0.5, 0.52, 0.3, const [bodyShade, body, body]);
  c.ellipse(0.66, 0.6, 0.1, 0.07, wing, angle: -0.5);
  c.circle(0.42, 0.44, 0.045, eye);
  c.polygon(const [(0.24, 0.5), (0.36, 0.45), (0.36, 0.56)], beak);
  c.polygon(const [(0.48, 0.24), (0.52, 0.12), (0.56, 0.24)], body);
  return c.toPuzzle(id: id, title: 'Peep', palette: const [
    0xFFE1F5FE, 0xFFA5D6A7, 0xFFFFEB3B, 0xFFFBC02D, 0xFFFF9800, 0xFF3E2723, 0xFFFFF59D, //
  ]);
}

Puzzle ladybug(String id, int n) {
  const leaf = 0, leafVein = 1, red = 2, redDark = 3, black = 4, shine = 5;
  final c = ArtCanvas(n, n, background: leaf);
  c.line(0, 1, 1, 0, 0.05, leafVein);
  c.circle(0.5, 0.3, 0.14, black);
  c.line(0.44, 0.2, 0.36, 0.08, 0.05, black);
  c.line(0.56, 0.2, 0.64, 0.08, 0.05, black);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.58, 0.3), 0.5, 0.58, 0.3, const [redDark, red, red]);
  c.line(0.5, 0.3, 0.5, 0.88, 0.05, black);
  for (final (x, y) in const [(0.36, 0.5), (0.64, 0.5), (0.34, 0.7), (0.66, 0.7)]) {
    c.circle(x, y, 0.06, black);
  }
  c.dot(0.38, 0.38, shine);
  return c.toPuzzle(id: id, title: 'Lucky Bug', palette: const [
    0xFF81C784, 0xFF66BB6A, 0xFFE53935, 0xFFB71C1C, 0xFF212121, 0xFFFFCDD2, //
  ]);
}

Puzzle snail(String id, int n) {
  const bg = 0, ground = 1, body = 2, bodyShade = 3, shell = 4, shellDark = 5, shellLight = 6, eye = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.84, 1, 1, ground);
  c.ellipse(0.5, 0.78, 0.4, 0.07, body);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.78, 0.4, 0.07)(x, y) && y > 0.8, bodyShade);
  c.line(0.18, 0.74, 0.14, 0.52, 0.06, body);
  c.line(0.24, 0.74, 0.26, 0.54, 0.06, body);
  c.circle(0.14, 0.5, 0.04, eye);
  c.circle(0.26, 0.52, 0.04, eye);
  c.circle(0.56, 0.52, 0.27, shellDark);
  c.ring(0.56, 0.52, 0.14, 0.24, shell);
  c.ring(0.58, 0.5, 0.04, 0.1, shellLight);
  return c.toPuzzle(id: id, title: 'Slowpoke', palette: const [
    0xFFF1F8E9, 0xFF8D6E63, 0xFFFFE0B2, 0xFFE0B98C, 0xFFF4A261, 0xFF8D4F2B, 0xFFFFD199, 0xFF3E2723, //
  ]);
}

// ---- Medium ---------------------------------------------------------------

Puzzle fox(String id, int n) {
  const bg = 0, bgDot = 1, fur = 2, furDark = 3, white = 4, dark = 5, earIn = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 6 == 0, bgDot);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.polygon([(fx(0.16), 0.46), (fx(0.2), 0.1), (fx(0.44), 0.32)], furDark);
    c.polygon([(fx(0.21), 0.38), (fx(0.23), 0.19), (fx(0.36), 0.31)], earIn);
  }
  final head = ArtCanvas.inPolygon(const [(0.14, 0.4), (0.3, 0.28), (0.7, 0.28), (0.86, 0.4), (0.5, 0.86)]);
  c.fillShaded(head, 0.5, 0.45, 0.4, const [furDark, fur, fur]);
  c.fill(
      (x, y) =>
          head(x, y) &&
          (ArtCanvas.inPolygon(const [(0.14, 0.42), (0.46, 0.56), (0.5, 0.86)])(x, y) ||
              ArtCanvas.inPolygon(const [(0.86, 0.42), (0.54, 0.56), (0.5, 0.86)])(x, y)),
      white);
  c.ellipse(0.36, 0.48, 0.035, 0.05, dark);
  c.ellipse(0.64, 0.48, 0.035, 0.05, dark);
  c.ellipse(0.5, 0.82, 0.05, 0.035, dark);
  return c.toPuzzle(id: id, title: 'Clever Fox', palette: const [
    0xFFFFF8E1, 0xFFFFECB3, 0xFFFF8A3D, 0xFFD9581E, 0xFFFFFFFF, 0xFF2D2A26, 0xFFFFD0B0, //
  ]);
}

Puzzle penguin(String id, int n) {
  const sky = 0, skyLow = 1, snow = 2, snowShade = 3, black = 4, belly = snow, orange = 6, cheek = 7, white = snow;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.5, 1, 0.8, skyLow);
  c.ellipse(0.5, 1.02, 0.7, 0.2, snowShade);
  c.ellipse(0.5, 1.05, 0.7, 0.2, snow);
  c.ellipse(0.5, 0.56, 0.26, 0.34, black);
  c.ellipse(0.25, 0.6, 0.06, 0.18, black, angle: 0.3);
  c.ellipse(0.75, 0.6, 0.06, 0.18, black, angle: -0.3);
  c.ellipse(0.5, 0.64, 0.18, 0.25, belly);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.36, 0.17, 0.12)(x, y), belly);
  c.circle(0.42, 0.36, 0.035, black);
  c.circle(0.58, 0.36, 0.035, black);
  c.dot(0.415, 0.345, white);
  c.polygon(const [(0.45, 0.42), (0.55, 0.42), (0.5, 0.48)], orange);
  c.circle(0.36, 0.44, 0.03, cheek);
  c.circle(0.64, 0.44, 0.03, cheek);
  c.ellipse(0.42, 0.9, 0.07, 0.03, orange);
  c.ellipse(0.58, 0.9, 0.07, 0.03, orange);
  return c.toPuzzle(id: id, title: 'Waddles', palette: const [
    0xFFB3E5FC, 0xFFE1F5FE, 0xFFFFFFFF, 0xFFCFD8DC, 0xFF263238, 0xFFFAFAFA, 0xFFFFA000, 0xFFF8BBD0, //
  ]);
}

Puzzle owl(String id, int n) {
  const night = 0, star = 1, moon = 2, branch = 3, feather = 4, featherDark = 5, belly = 6, chevron = 7;
  const eyeWhite = 8, iris = 9, pupil = 10, beak = 11;
  final c = ArtCanvas(n, n, background: night);
  for (final (x, y) in const [(0.1, 0.1), (0.3, 0.06), (0.9, 0.3), (0.08, 0.5), (0.92, 0.6)]) {
    c.dot(x, y, star);
  }
  c.circle(0.84, 0.12, 0.08, moon);
  c.line(0, 0.86, 1, 0.82, 0.08, branch);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.polygon([(fx(0.24), 0.32), (fx(0.28), 0.14), (fx(0.4), 0.26)], featherDark);
  }
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.52, 0.28, 0.34), 0.5, 0.52, 0.3, const [featherDark, feather, feather]);
  final b = ArtCanvas.inEllipse(0.5, 0.64, 0.17, 0.2);
  c.fill(b, belly);
  c.fill((x, y) => b(x, y) && y > 0.56 && (c.row(y) % 3 == 0) && (c.col(x) + c.row(y)) % 2 == 0, chevron);
  for (final x in const [0.38, 0.62]) {
    c.circle(x, 0.4, 0.11, eyeWhite);
    c.circle(x, 0.41, 0.065, iris);
    c.circle(x, 0.41, 0.035, pupil);
  }
  c.polygon(const [(0.46, 0.5), (0.54, 0.5), (0.5, 0.58)], beak);
  c.ellipse(0.42, 0.85, 0.05, 0.025, beak);
  c.ellipse(0.58, 0.85, 0.05, 0.025, beak);
  return c.toPuzzle(id: id, title: 'Night Owl', palette: const [
    0xFF2E2A5A, 0xFFFFF59D, 0xFFFFF8E1, 0xFF5D4037, 0xFFA1887F, 0xFF6D4C41, 0xFFEFDCC6, 0xFFC7A68A, //
    0xFFFFFFFF, 0xFFFFC107, 0xFF212121, 0xFFFF9800,
  ]);
}

Puzzle frog(String id, int n) {
  const pond = 0, ripple = 1, pad = 2, padDark = 3, green = 4, greenDark = padDark, greenLight = 6;
  const eyeWhite = 7, pupil = 8, mouth = 9, cheek = 10;
  final c = ArtCanvas(n, n, background: pond);
  c.ring(0.15, 0.2, 0.06, 0.08, ripple);
  c.ring(0.85, 0.25, 0.05, 0.07, ripple);
  final lily = ArtCanvas.inEllipse(0.5, 0.82, 0.44, 0.16);
  c.fill((x, y) => lily(x, y) && !ArtCanvas.inPolygon(const [(0.5, 0.82), (0.9, 0.7), (0.95, 0.78)])(x, y), pad);
  c.line(0.5, 0.82, 0.2, 0.86, 0.03, padDark);
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.58, 0.3, 0.22), 0.5, 0.58, 0.3, const [greenDark, green, green, greenLight]);
  for (final x in const [0.34, 0.66]) {
    c.circle(x, 0.38, 0.11, green);
    c.circle(x, 0.37, 0.075, eyeWhite);
    c.circle(x, 0.38, 0.04, pupil);
  }
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.52) * (y - 0.52));
    return d > 0.13 && d < 0.17 && y > 0.6;
  }, mouth);
  c.circle(0.3, 0.62, 0.04, cheek);
  c.circle(0.7, 0.62, 0.04, cheek);
  c.ellipse(0.3, 0.78, 0.09, 0.04, greenDark);
  c.ellipse(0.7, 0.78, 0.09, 0.04, greenDark);
  return c.toPuzzle(id: id, title: 'Lily Hopper', palette: const [
    0xFF4FC3F7, 0xFF81D4FA, 0xFF7CB342, 0xFF558B2F, 0xFF8BC34A, 0xFF5B8C2A, 0xFFC5E1A5, //
    0xFFFFFFFF, 0xFF212121, 0xFF33691E, 0xFFF48FB1,
  ]);
}

Puzzle whale(String id, int n) {
  const sky = 0, sea1 = 1, sea2 = 2, sea3 = 3, body = 4, bodyDark = 5, spout = 7, belly = spout, eye = 8, cheek = 9;
  final c = ArtCanvas(n, n, background: sky);
  c.bands(const [sea1, sea2, sea3], top: 0.55);
  for (final (x, r) in const [(0.3, 0.06), (0.36, 0.08), (0.42, 0.06)]) {
    c.circle(x, 0.18, r, spout);
  }
  c.line(0.36, 0.38, 0.36, 0.22, 0.05, spout);
  c.polygon(const [(0.78, 0.55), (0.96, 0.36), (0.9, 0.52), (0.98, 0.66)], bodyDark);
  final whaleBody = ArtCanvas.inEllipse(0.46, 0.58, 0.36, 0.2);
  c.fillShaded(whaleBody, 0.46, 0.55, 0.36, const [bodyDark, body, body]);
  c.fill((x, y) => whaleBody(x, y) && y > 0.66, belly);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.24) * (x - 0.24) + (y - 0.56) * (y - 0.56));
    return d > 0.07 && d < 0.1 && y > 0.6 && x > 0.18;
  }, bodyDark);
  c.circle(0.3, 0.54, 0.035, eye);
  c.circle(0.26, 0.62, 0.035, cheek);
  return c.toPuzzle(id: id, title: 'Big Blue', palette: const [
    0xFFE3F2FD, 0xFF4FC3F7, 0xFF29B6F6, 0xFF0288D1, 0xFF5C6BC0, 0xFF3949AB, 0xFFE8EAF6, 0xFFFFFFFF, 0xFF1A237E, //
    0xFFF48FB1,
  ]);
}

// ---- Hard -----------------------------------------------------------------

Puzzle panda(String id, int n) {
  const bg = 0, stalk = 1, stalkDark = 2, leaf = 3, white = 4, shade = 5, black = 6, eye = white, pink = 8;
  final c = ArtCanvas(n, n, background: bg);
  for (final x in const [0.08, 0.92]) {
    c.rect(x - 0.035, 0, x + 0.035, 1, stalk);
    for (final y in const [0.2, 0.45, 0.7]) {
      c.rect(x - 0.035, y, x + 0.035, y + 0.02, stalkDark);
    }
  }
  c.ellipse(0.5, 1.04, 0.38, 0.22, white);
  for (final m in const [false, true]) {
    double fx(double x) => m ? 1 - x : x;
    c.circle(fx(0.27), 0.26, 0.1, black);
  }
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.5, 0.31, 0.28), 0.5, 0.5, 0.31, const [shade, white, white, white]);
  c.ellipse(0.38, 0.48, 0.07, 0.09, black, angle: 0.5);
  c.ellipse(0.62, 0.48, 0.07, 0.09, black, angle: -0.5);
  c.circle(0.39, 0.47, 0.025, eye);
  c.circle(0.61, 0.47, 0.025, eye);
  c.ellipse(0.5, 0.6, 0.05, 0.03, black);
  c.line(0.5, 0.62, 0.5, 0.66, 0.025, black);
  c.circle(0.3, 0.62, 0.035, pink);
  c.circle(0.7, 0.62, 0.035, pink);
  c.line(0.16, 0.98, 0.3, 0.8, 0.04, stalk);
  c.ellipse(0.34, 0.78, 0.07, 0.03, leaf, angle: -0.6);
  c.ellipse(0.22, 0.78, 0.06, 0.025, leaf, angle: 0.5);
  c.ellipse(0.24, 0.86, 0.07, 0.07, black);
  c.ellipse(0.76, 0.86, 0.07, 0.07, black);
  return c.toPuzzle(id: id, title: 'Bamboo Bear', palette: const [
    0xFFE8F5E9, 0xFF9CCC65, 0xFF689F38, 0xFF43A047, 0xFFFFFFFF, 0xFFE0E0E0, 0xFF263238, 0xFFFFFFFE, //
    0xFFF8BBD0,
  ]);
}

Puzzle turtle(String id, int n) {
  const sea = 0, seaLight = 1, sand = 2, sandDark = 3, skin = 4, skinDark = 5, shell = 6, shellDark = 7;
  const shellLight = 8, eye = 9, bubble = 10;
  final c = ArtCanvas(n, n, background: sea);
  c.rect(0, 0, 1, 0.2, seaLight);
  c.ellipse(0.5, 1.05, 0.8, 0.18, sand);
  c.fill((x, y) => y > 0.9 && (c.col(x) + c.row(y)) % 5 == 0, sandDark);
  for (final (x, y, a) in const [(0.28, 0.66, 0.6), (0.72, 0.66, -0.6), (0.3, 0.36, -0.6), (0.7, 0.36, 0.6)]) {
    c.ellipse(x, y, 0.1, 0.05, skin, angle: a);
  }
  c.circle(0.5, 0.2, 0.09, skin);
  c.circle(0.46, 0.18, 0.02, eye);
  c.circle(0.54, 0.18, 0.02, eye);
  c.polygon(const [(0.47, 0.75), (0.53, 0.75), (0.5, 0.84)], skinDark);
  final sh = ArtCanvas.inEllipse(0.5, 0.52, 0.24, 0.26);
  c.fillShaded(sh, 0.5, 0.52, 0.24, const [shellDark, shell, shell, shellLight]);
  // Plate seams: a centre plate and lines out to the rim.
  c.fill((x, y) => sh(x, y) && ArtCanvas.inEllipse(0.5, 0.52, 0.12, 0.13)(x, y), shellLight);
  c.ring(0.5, 0.52, 0.12, 0.15, shellDark);
  for (final (x2, y2) in const [(0.5, 0.24), (0.5, 0.8), (0.26, 0.42), (0.74, 0.42), (0.28, 0.66), (0.72, 0.66)]) {
    c.fill(
        (x, y) =>
            sh(x, y) && !ArtCanvas.inCircle(0.5, 0.52, 0.13)(x, y) && ArtCanvas.inLine(0.5, 0.52, x2, y2, 0.03)(x, y),
        shellDark);
  }
  for (final (x, y, r) in const [(0.82, 0.14, 0.03), (0.86, 0.06, 0.02), (0.14, 0.3, 0.025)]) {
    c.circle(x, y, r, bubble);
  }
  return c.toPuzzle(id: id, title: 'Sea Wanderer', palette: const [
    0xFF26C6DA, 0xFF80DEEA, 0xFFFFE0B2, 0xFFE6BE8A, 0xFFAED581, 0xFF7CB342, 0xFF8D6E63, 0xFF5D4037, //
    0xFFBCAAA4, 0xFF212121, 0xFFE0F7FA,
  ]);
}

Puzzle hedgehog(String id, int n) {
  const bg = 0, ground = 1, leafA = 2, leafB = 3, spine = 4, spineDark = 5, face = 6, faceShade = 7;
  const nose = 8, eye = 9, cheek = 10, apple = 11, appleLeaf = 12;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.82, 1, 1, ground);
  for (final (x, y, a, col) in const [(0.12, 0.88, 0.5, leafA), (0.85, 0.9, -0.4, leafB), (0.6, 0.94, 0.2, leafA)]) {
    c.ellipse(x, y, 0.07, 0.03, col, angle: a);
  }
  c.polygon(ArtCanvas.starPoints(0.56, 0.58, 0.36, 0.26, 14), spineDark);
  c.fill((x, y) => ArtCanvas.inPolygon(ArtCanvas.starPoints(0.56, 0.58, 0.36, 0.26, 14))(x, y) && y > 0.78, bg);
  c.fillShaded(ArtCanvas.inEllipse(0.56, 0.6, 0.27, 0.2), 0.56, 0.6, 0.27, const [spineDark, spine, spine]);
  c.rect(0.2, 0.78, 0.92, 0.82, ground);
  final faceShape = ArtCanvas.inPolygon(const [(0.38, 0.46), (0.12, 0.66), (0.36, 0.78)]);
  c.fill(faceShape, face);
  c.fill((x, y) => faceShape(x, y) && y > 0.72, faceShade);
  c.circle(0.13, 0.66, 0.035, nose);
  c.circle(0.28, 0.6, 0.025, eye);
  c.circle(0.3, 0.7, 0.025, cheek);
  c.circle(0.6, 0.36, 0.08, apple);
  c.line(0.6, 0.29, 0.62, 0.24, 0.025, appleLeaf);
  c.ellipse(0.66, 0.26, 0.04, 0.02, appleLeaf, angle: -0.4);
  return c.toPuzzle(id: id, title: 'Prickles', palette: const [
    0xFFFFF3E0, 0xFFBCAAA4, 0xFFFF8A65, 0xFFFFB74D, 0xFF8D6E63, 0xFF5D4037, 0xFFFFE0B2, 0xFFE9C79B, //
    0xFF3E2723, 0xFF212121, 0xFFF48FB1, 0xFFE53935, 0xFF43A047,
  ]);
}

Puzzle parrot(String id, int n) {
  const jungle = 0, jungleLeaf = 1, jungleLeafDark = 2, branch = 3, red = 4, redDark = 5, blue = 6, yellow = 7;
  const green = 8, face = 9, beak = 10, beakDark = 11, eye = 12;
  final c = ArtCanvas(n, n, background: jungle);
  for (final (x, y, a, col) in const [
    (0.1, 0.15, 0.6, jungleLeaf),
    (0.88, 0.2, -0.6, jungleLeafDark),
    (0.08, 0.6, -0.3, jungleLeafDark),
    (0.92, 0.7, 0.4, jungleLeaf),
  ]) {
    c.ellipse(x, y, 0.16, 0.06, col, angle: a);
  }
  c.line(0, 0.78, 1, 0.74, 0.07, branch);
  c.polygon(const [(0.44, 0.7), (0.56, 0.7), (0.58, 0.98), (0.5, 0.92), (0.42, 0.98)], blue);
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.5, 0.17, 0.26), 0.5, 0.5, 0.2, const [redDark, red, red]);
  c.ellipse(0.62, 0.56, 0.08, 0.18, green, angle: -0.2);
  c.fill((x, y) => ArtCanvas.inEllipse(0.62, 0.56, 0.08, 0.18, angle: -0.2)(x, y) && y > 0.58, blue);
  c.fill((x, y) => ArtCanvas.inEllipse(0.62, 0.56, 0.08, 0.18, angle: -0.2)(x, y) && y < 0.48, yellow);
  c.circle(0.46, 0.3, 0.12, red);
  c.ellipse(0.42, 0.3, 0.06, 0.05, face);
  c.circle(0.43, 0.29, 0.022, eye);
  c.polygon(const [(0.32, 0.3), (0.38, 0.26), (0.38, 0.4), (0.3, 0.38)], beak);
  c.polygon(const [(0.32, 0.36), (0.38, 0.36), (0.36, 0.42)], beakDark);
  c.ellipse(0.46, 0.76, 0.04, 0.02, beakDark);
  c.ellipse(0.56, 0.76, 0.04, 0.02, beakDark);
  return c.toPuzzle(id: id, title: 'Polly', palette: const [
    0xFFE0F2F1, 0xFF66BB6A, 0xFF2E7D32, 0xFF795548, 0xFFE53935, 0xFFB71C1C, 0xFF1E88E5, 0xFFFFD600, //
    0xFF43A047, 0xFFFFFFFF, 0xFFFFE082, 0xFF424242, 0xFF212121,
  ]);
}

Puzzle bee(String id, int n) {
  const bg = 0, petal = 1, petalShade = 2, center = 3, centerDark = 4, yellow = 5, black = 6;
  const wing = 7, wingEdge = 8, cheek = 9, trail = 10;
  final c = ArtCanvas(n, n, background: bg);
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    c.ellipse(0.26 + 0.14 * math.cos(a), 0.74 + 0.14 * math.sin(a), 0.1, 0.07, i.isEven ? petal : petalShade, angle: a);
  }
  c.fillShaded(ArtCanvas.inCircle(0.26, 0.74, 0.08), 0.26, 0.74, 0.08, const [centerDark, center, center]);
  for (final (x, y) in const [(0.5, 0.62), (0.44, 0.66), (0.38, 0.62), (0.56, 0.56)]) {
    c.dot(x, y, trail);
  }
  c.ellipse(0.56, 0.24, 0.12, 0.09, wingEdge, angle: -0.4);
  c.ellipse(0.56, 0.24, 0.1, 0.07, wing, angle: -0.4);
  c.ellipse(0.74, 0.26, 0.11, 0.08, wingEdge, angle: 0.4);
  c.ellipse(0.74, 0.26, 0.09, 0.06, wing, angle: 0.4);
  final body = ArtCanvas.inEllipse(0.66, 0.44, 0.2, 0.14);
  c.fill(body, yellow);
  c.fill((x, y) => body(x, y) && ((x - 0.6) * 10).floor().isOdd && x > 0.6, black);
  c.polygon(const [(0.85, 0.44), (0.92, 0.42), (0.86, 0.48)], black);
  c.circle(0.5, 0.42, 0.1, yellow);
  c.circle(0.47, 0.4, 0.025, black);
  c.circle(0.46, 0.47, 0.025, cheek);
  c.line(0.48, 0.33, 0.42, 0.2, 0.025, black);
  c.line(0.53, 0.33, 0.55, 0.19, 0.025, black);
  return c.toPuzzle(id: id, title: 'Busy Bee', palette: const [
    0xFFFCE4EC, 0xFFFFFFFF, 0xFFF8BBD0, 0xFFFFCA28, 0xFFF57F17, 0xFFFFD54F, 0xFF212121, //
    0xFFE3F2FD, 0xFF90CAF9, 0xFFFF8A80, 0xFFBDBDBD,
  ]);
}
