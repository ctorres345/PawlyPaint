import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// ---- Easy -----------------------------------------------------------------

Puzzle tulip(String id, int n) {
  const bg = 0, ground = 1, stem = 2, leaf = 3, petalDark = 4, petal = 5, petalLight = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.86, 1, 1, ground);
  c.line(0.5, 0.45, 0.5, 0.9, 0.08, stem);
  c.ellipse(0.36, 0.72, 0.06, 0.16, leaf, angle: -0.5);
  c.ellipse(0.64, 0.68, 0.06, 0.16, leaf, angle: 0.5);
  final cup = ArtCanvas.inEllipse(0.5, 0.38, 0.17, 0.15);
  final top = ArtCanvas.inPolygon(const [
    (0.33, 0.38), (0.33, 0.16), (0.42, 0.26), (0.5, 0.12), (0.58, 0.26), (0.67, 0.16), (0.67, 0.38), //
  ]);
  c.fillShaded((x, y) => cup(x, y) || top(x, y), 0.5, 0.32, 0.2, const [petalDark, petal, petal, petalLight]);
  return c.toPuzzle(id: id, title: 'First Tulip', palette: const [
    0xFFFFF8E1, 0xFFA1887F, 0xFF43A047, 0xFF66BB6A, 0xFFAD1457, 0xFFEC407A, 0xFFF48FB1, //
  ]);
}

Puzzle leaf(String id, int n) {
  const bg = 0, dot = 1, dark = 2, mid = 3, light = 4, vein = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y)) % 5 == 0, dot);
  final shape = ArtCanvas.inEllipse(0.5, 0.48, 0.38, 0.2, angle: -0.75);
  c.fillShaded(shape, 0.5, 0.48, 0.38, const [dark, mid, mid, light]);
  c.line(0.24, 0.76, 0.76, 0.22, 0.06, vein);
  c.line(0.16, 0.86, 0.26, 0.74, 0.06, dark);
  return c.toPuzzle(id: id, title: 'Fresh Leaf', palette: const [
    0xFFF1F8E9, 0xFFDCEDC8, 0xFF2E7D32, 0xFF43A047, 0xFF81C784, 0xFFC5E1A5, //
  ]);
}

Puzzle cactus(String id, int n) {
  const bg = 0, sun = 1, green = 2, greenDark = 3, pot = 4, potDark = 5, flower = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.circle(0.85, 0.15, 0.1, sun);
  c.ellipse(0.5, 0.42, 0.12, 0.3, green);
  c.ellipse(0.3, 0.42, 0.06, 0.12, green);
  c.line(0.3, 0.52, 0.42, 0.52, 0.08, green);
  c.ellipse(0.7, 0.34, 0.06, 0.12, green);
  c.line(0.58, 0.44, 0.7, 0.44, 0.08, green);
  c.line(0.5, 0.18, 0.5, 0.68, 0.035, greenDark);
  c.circle(0.5, 0.12, 0.06, flower);
  c.polygon(const [(0.26, 0.68), (0.74, 0.68), (0.68, 0.94), (0.32, 0.94)], pot);
  c.rect(0.24, 0.66, 0.76, 0.74, potDark);
  return c.toPuzzle(id: id, title: 'Spiky Pal', palette: const [
    0xFFFFF3E0, 0xFFFFD54F, 0xFF66BB6A, 0xFF388E3C, 0xFFE07A5F, 0xFFC0583D, 0xFFF06292, //
  ]);
}

Puzzle sprout(String id, int n) {
  const bg = 0, soil = 1, soilDark = 2, stem = 3, leafA = 4, leafB = 5, pot = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.line(0.5, 0.62, 0.5, 0.36, 0.07, stem);
  c.ellipse(0.34, 0.3, 0.16, 0.08, leafA, angle: 0.4);
  c.ellipse(0.66, 0.26, 0.16, 0.08, leafB, angle: -0.4);
  c.polygon(const [(0.2, 0.6), (0.8, 0.6), (0.7, 0.94), (0.3, 0.94)], pot);
  c.ellipse(0.5, 0.62, 0.28, 0.06, soil);
  c.dot(0.4, 0.62, soilDark);
  c.dot(0.62, 0.62, soilDark);
  return c.toPuzzle(id: id, title: 'Little Sprout', palette: const [
    0xFFE3F2FD, 0xFF6D4C41, 0xFF4E342E, 0xFF7CB342, 0xFF9CCC65, 0xFF689F38, 0xFF90A4AE, //
  ]);
}

Puzzle acorn(String id, int n) {
  const bg = 0, dot = 1, nut = 2, nutDark = 3, nutLight = 4, cap = 5, capDark = 6, stem = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 2 + c.row(y)) % 7 == 0, dot);
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.6, 0.24, 0.28), 0.5, 0.6, 0.26, const [nutDark, nut, nut, nutLight]);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.38, 0.32, 0.16)(x, y) && y < 0.46, cap);
  c.fill(
      (x, y) => ArtCanvas.inEllipse(0.5, 0.38, 0.32, 0.16)(x, y) && y < 0.46 && (c.col(x) + c.row(y)).isEven, capDark);
  c.line(0.5, 0.24, 0.56, 0.12, 0.07, stem);
  return c.toPuzzle(id: id, title: 'Acorn', palette: const [
    0xFFFFF8E1, 0xFFFFECB3, 0xFFC68642, 0xFF8D5524, 0xFFE0AC69, 0xFF8D6E63, 0xFF6D4C41, 0xFF4E342E, //
  ]);
}

// ---- Medium ---------------------------------------------------------------

Puzzle sunflower(String id, int n) {
  const sky = 0, cloud = 1, stem = 2, leaf = 3, petal = 4, petalDark = 5, seed = 6, seedLight = 7;
  final c = ArtCanvas(n, n, background: sky);
  c.circle(0.15, 0.12, 0.07, cloud);
  c.circle(0.22, 0.14, 0.06, cloud);
  c.line(0.5, 0.5, 0.5, 1, 0.06, stem);
  c.ellipse(0.36, 0.78, 0.13, 0.06, leaf, angle: 0.5);
  c.ellipse(0.64, 0.7, 0.13, 0.06, leaf, angle: -0.5);
  for (var i = 0; i < 14; i++) {
    final a = i * 2 * math.pi / 14;
    c.ellipse(0.5 + 0.22 * math.cos(a), 0.4 + 0.22 * math.sin(a), 0.11, 0.05, i.isEven ? petal : petalDark, angle: a);
  }
  final disk = ArtCanvas.inCircle(0.5, 0.4, 0.14);
  c.fill(disk, seed);
  c.fill((x, y) => disk(x, y) && (c.col(x) + c.row(y)) % 3 == 0, seedLight);
  return c.toPuzzle(id: id, title: 'Sunflower', palette: const [
    0xFF90CAF9, 0xFFFFFFFF, 0xFF388E3C, 0xFF66BB6A, 0xFFFFD600, 0xFFFFA000, 0xFF5D4037, 0xFF8D6E63, //
  ]);
}

Puzzle rose(String id, int n) {
  const bg = 0, bgDot = 1, stem = 2, leaf = 3, dark = 4, red = 5, light = 6, thorn = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 3) % 8 == 0, bgDot);
  c.line(0.5, 0.55, 0.48, 1, 0.05, stem);
  c.dot(0.52, 0.72, thorn);
  c.dot(0.46, 0.86, thorn);
  c.ellipse(0.34, 0.74, 0.12, 0.05, leaf, angle: 0.5);
  c.ellipse(0.64, 0.84, 0.12, 0.05, leaf, angle: -0.5);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.38, 0.22), 0.5, 0.38, 0.22, const [dark, red, red]);
  c.ring(0.5, 0.36, 0.12, 0.15, dark);
  c.ring(0.52, 0.34, 0.05, 0.075, dark);
  c.polygon(const [(0.3, 0.42), (0.5, 0.62), (0.7, 0.42), (0.5, 0.5)], dark);
  c.dot(0.42, 0.28, light);
  return c.toPuzzle(id: id, title: 'Garden Rose', palette: const [
    0xFFFFF0F3, 0xFFFFDDE5, 0xFF2E7D32, 0xFF4CAF50, 0xFF9B1B30, 0xFFD32F45, 0xFFFF8A9B, 0xFF1B5E20, //
  ]);
}

Puzzle wateringCan(String id, int n) {
  const bg = 0, grass = 1, can = 2, canDark = 3, canLight = 4, water = 5, handle = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.84, 1, 1, grass);
  c.ring(0.42, 0.38, 0.12, 0.17, handle);
  c.polygon(const [(0.62, 0.56), (0.88, 0.3), (0.92, 0.34), (0.68, 0.66)], canDark);
  c.polygon(const [(0.84, 0.26), (0.96, 0.26), (0.96, 0.38), (0.84, 0.38)], canDark);
  c.fillShaded(ArtCanvas.inPolygon(const [(0.2, 0.44), (0.66, 0.44), (0.7, 0.82), (0.16, 0.82)]), 0.42, 0.6, 0.3,
      const [canDark, can, can, canLight]);
  c.rect(0.18, 0.42, 0.68, 0.48, canDark);
  for (final (x, y) in const [(0.94, 0.46), (0.9, 0.56), (0.97, 0.6), (0.93, 0.7), (0.88, 0.76)]) {
    c.dot(x, y, water);
  }
  return c.toPuzzle(id: id, title: 'Watering Can', palette: const [
    0xFFE8F5E9, 0xFF81C784, 0xFF4DB6AC, 0xFF00897B, 0xFF80CBC4, 0xFF4FC3F7, 0xFF607D8B, //
  ]);
}

Puzzle carrot(String id, int n) {
  const bg = 0, soil = 1, soilDark = 2, orange = 3, orangeDark = 4, orangeLight = 5, green = 6, greenDark = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.6, 1, 1, soil);
  c.fill((x, y) => y > 0.6 && (c.col(x) * 3 + c.row(y)) % 7 == 0, soilDark);
  for (final (x2, y2, col) in const [(0.36, 0.08, green), (0.5, 0.04, greenDark), (0.64, 0.1, green)]) {
    c.line(0.5, 0.3, x2, y2, 0.07, col);
  }
  final body = ArtCanvas.inPolygon(const [(0.32, 0.3), (0.68, 0.3), (0.52, 0.94), (0.48, 0.94)]);
  c.fillShaded(body, 0.5, 0.45, 0.3, const [orangeDark, orange, orange, orangeLight]);
  for (final y in const [0.42, 0.56, 0.7]) {
    c.fill((x, py) => body(x, py) && (py - y).abs() < 0.015 && x < 0.5, orangeDark);
  }
  return c.toPuzzle(id: id, title: 'Crunchy Carrot', palette: const [
    0xFFE1F5FE, 0xFF8D6E63, 0xFF6D4C41, 0xFFFF9800, 0xFFE65100, 0xFFFFB74D, 0xFF66BB6A, 0xFF388E3C, //
  ]);
}

Puzzle birdhouse(String id, int n) {
  const sky = 0, tree = 1, leafA = 2, leafB = 3, wall = 4, wallShade = 5, roof = 6, roofDark = 7, hole = 8, perch = 9;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0.44, 0.7, 0.56, 1, tree);
  for (final (x, y, r, col) in const [(0.12, 0.2, 0.14, leafA), (0.9, 0.3, 0.16, leafB), (0.1, 0.8, 0.12, leafB)]) {
    c.circle(x, y, r, col);
  }
  final house = ArtCanvas.inPolygon(const [(0.26, 0.42), (0.74, 0.42), (0.74, 0.76), (0.26, 0.76)]);
  c.fill(house, wall);
  c.fill((x, y) => house(x, y) && x > 0.6, wallShade);
  c.polygon(const [(0.18, 0.46), (0.5, 0.14), (0.82, 0.46)], roof);
  c.fill((x, y) => ArtCanvas.inPolygon(const [(0.18, 0.46), (0.5, 0.14), (0.82, 0.46)])(x, y) && y > 0.4, roofDark);
  c.circle(0.5, 0.56, 0.07, hole);
  c.line(0.5, 0.68, 0.5, 0.72, 0.04, perch);
  return c.toPuzzle(id: id, title: 'Birdhouse', palette: const [
    0xFFB3E5FC, 0xFF6D4C41, 0xFF81C784, 0xFF66BB6A, 0xFFFFCC80, 0xFFF0B060, 0xFFE57373, 0xFFC62828, 0xFF4E342E, //
    0xFF8D6E63,
  ]);
}

// ---- Hard -----------------------------------------------------------------

Puzzle cherryBlossom(String id, int n) {
  const sky = 0, skyLow = 1, branch = 2, branchDark = 3, petal = 4, petalDark = 5, petalLight = 6, center = 7;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.6, 1, 1, skyLow);
  c.line(0, 0.86, 0.5, 0.56, 0.06, branchDark);
  c.line(0.5, 0.56, 1, 0.42, 0.045, branch);
  c.line(0.4, 0.62, 0.36, 0.3, 0.035, branch);
  c.line(0.7, 0.5, 0.78, 0.2, 0.03, branch);
  void blossom(double x, double y, double r) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      c.circle(x + r * 0.6 * math.cos(a), y + r * 0.6 * math.sin(a), r * 0.55, i.isEven ? petal : petalLight);
    }
    c.circle(x, y, r * 0.3, petalDark);
    c.dot(x, y, center);
  }

  for (final (x, y, r) in const [
    (0.36, 0.26, 0.11), (0.78, 0.18, 0.1), (0.56, 0.5, 0.1), (0.2, 0.72, 0.09), (0.9, 0.42, 0.08), //
    (0.62, 0.3, 0.07),
  ]) {
    blossom(x, y, r);
  }
  for (final (x, y) in const [(0.14, 0.3), (0.86, 0.66), (0.52, 0.84), (0.3, 0.92)]) {
    c.dot(x, y, petal);
  }
  return c.toPuzzle(id: id, title: 'Sakura', palette: const [
    0xFFE3F2FD, 0xFFF3E5F5, 0xFF6D4C41, 0xFF4E342E, 0xFFF8BBD0, 0xFFEC407A, 0xFFFFFFFF, 0xFFFFD54F, //
  ]);
}

Puzzle lotus(String id, int n) {
  const water = 0, waterLight = 1, waterDark = 2, pad = 3, padDark = 4, petal = 5, petalDark = 6, petalTip = 7;
  const center = 8;
  final c = ArtCanvas(n, n, background: water);
  c.fill((x, y) => c.row(y) % 4 == 0 && (c.col(x) + c.row(y) ~/ 4 * 3) % 6 < 2, waterLight);
  c.fill((x, y) => y > 0.85, waterDark);
  for (final (x, y, r) in const [(0.2, 0.78, 0.16), (0.82, 0.3, 0.14), (0.78, 0.82, 0.12)]) {
    final p = ArtCanvas.inCircle(x, y, r);
    c.fill((px, py) => p(px, py) && !ArtCanvas.inPolygon([(x, y), (x + r, y - r * 0.4), (x + r, y + r * 0.1)])(px, py),
        pad);
    c.line(x, y, x - r * 0.8, y + r * 0.2, 0.02, padDark);
  }
  for (final (a, col) in const [(-1.2, petalDark), (1.2, petalDark), (-0.6, petal), (0.6, petal), (0.0, petal)]) {
    c.ellipse(0.46 + 0.16 * math.sin(a), 0.5 - 0.1 * math.cos(a), 0.07, 0.17, col, angle: a);
  }
  for (final a in const [-0.6, 0.6, 0.0]) {
    c.fill(
        (x, y) =>
            ArtCanvas.inEllipse(0.46 + 0.16 * math.sin(a), 0.5 - 0.1 * math.cos(a), 0.07, 0.17, angle: a)(x, y) &&
            y < 0.38 - 0.1 * math.cos(a) + 0.08,
        petalTip);
  }
  c.ellipse(0.46, 0.58, 0.14, 0.04, center);
  return c.toPuzzle(id: id, title: 'Lotus Pond', palette: const [
    0xFF4DB6AC, 0xFF80CBC4, 0xFF00897B, 0xFF7CB342, 0xFF558B2F, 0xFFF8BBD0, 0xFFF06292, 0xFFFCE4EC, //
    0xFFFFD54F,
  ]);
}

Puzzle gnome(String id, int n) {
  const bg = 0, grass = 1, grassDark = 2, hat = 3, hatDark = 4, face = 5, nose = 6, beard = 7, beardShade = 8;
  const coat = 9, coatDark = 10, boot = 11, mushroomCap = 12, spot = 13;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.84, 1, 1, grass);
  c.fill((x, y) => y > 0.84 && (c.col(x) + c.row(y)) % 4 == 0, grassDark);
  c.ellipse(0.4, 0.88, 0.08, 0.04, boot);
  c.ellipse(0.6, 0.88, 0.08, 0.04, boot);
  c.fillShaded(ArtCanvas.inPolygon(const [(0.3, 0.56), (0.7, 0.56), (0.76, 0.86), (0.24, 0.86)]), 0.5, 0.7, 0.3,
      const [coatDark, coat, coat]);
  c.polygon(const [(0.34, 0.4), (0.66, 0.4), (0.62, 0.72), (0.5, 0.82), (0.38, 0.72)], beard);
  c.fill(
      (x, y) =>
          ArtCanvas.inPolygon(const [(0.34, 0.4), (0.66, 0.4), (0.62, 0.72), (0.5, 0.82), (0.38, 0.72)])(x, y) &&
          x > 0.56,
      beardShade);
  c.ellipse(0.5, 0.4, 0.13, 0.06, face);
  c.circle(0.5, 0.45, 0.05, nose);
  c.fillShaded(
      ArtCanvas.inPolygon(const [(0.3, 0.38), (0.54, 0.06), (0.7, 0.38)]), 0.5, 0.25, 0.25, const [hatDark, hat, hat]);
  c.ellipse(0.84, 0.78, 0.1, 0.06, mushroomCap);
  c.rect(0.82, 0.8, 0.86, 0.86, beard);
  c.dot(0.82, 0.76, spot);
  c.dot(0.88, 0.77, spot);
  return c.toPuzzle(id: id, title: 'Garden Gnome', palette: const [
    0xFFE1F5FE, 0xFF7CB342, 0xFF558B2F, 0xFFE53935, 0xFFB71C1C, 0xFFFFDAB9, 0xFFFF8A80, 0xFFFFFFFF, //
    0xFFE0E0E0, 0xFF1E88E5, 0xFF1565C0, 0xFF5D4037, 0xFFFF7043, 0xFFFFF3E0,
  ]);
}

Puzzle lavender(String id, int n) {
  const sky1 = 0, sky2 = 1, sun = 2, hill = 3, row1 = 4, row2 = 5, row3 = 6, stemC = 7, tree = 8, treeLeaf = 9;
  final c = ArtCanvas(n, n, background: sky1);
  c.bands(const [sky1, sky2], bottom: 0.5);
  c.circle(0.75, 0.3, 0.1, sun);
  c.ellipse(0.5, 0.56, 0.8, 0.1, hill);
  c.rect(0.16, 0.38, 0.19, 0.5, tree);
  c.circle(0.175, 0.36, 0.07, treeLeaf);
  for (var r = 0; r < 6; r++) {
    final y = 0.56 + r * 0.075;
    c.fill((x, py) => py >= y && py < y + 0.075, r.isEven ? stemC : hill);
    c.fill((x, py) => py >= y && py < y + 0.05 && (c.col(x) + r) % 2 == 0, const [row1, row2, row3][r % 3]);
  }
  return c.toPuzzle(id: id, title: 'Lavender Fields', palette: const [
    0xFFFFE0B2, 0xFFFFCCBC, 0xFFFFF176, 0xFF9CCC65, 0xFF7E57C2, 0xFF9575CD, 0xFFB39DDB, 0xFF558B2F, //
    0xFF6D4C41, 0xFF689F38,
  ]);
}

Puzzle appleTree(String id, int n) {
  const sky = 0, cloud = 1, grass = 2, grassDark = 3, trunk = 4, trunkDark = 5, leafDark = 6, leaf = 7;
  const leafLight = 8, apple = 9, appleLight = 10, basket = 11;
  final c = ArtCanvas(n, n, background: sky);
  c.circle(0.15, 0.12, 0.06, cloud);
  c.circle(0.22, 0.1, 0.07, cloud);
  c.circle(0.88, 0.16, 0.05, cloud);
  c.rect(0, 0.82, 1, 1, grass);
  c.fill((x, y) => y > 0.82 && (c.col(x) * 2 + c.row(y)) % 6 == 0, grassDark);
  c.polygon(const [(0.44, 0.86), (0.56, 0.86), (0.54, 0.5), (0.46, 0.5)], trunk);
  c.fill((x, y) => ArtCanvas.inPolygon(const [(0.44, 0.86), (0.56, 0.86), (0.54, 0.5), (0.46, 0.5)])(x, y) && x > 0.52,
      trunkDark);
  bool crown(double x, double y) =>
      ArtCanvas.inCircle(0.5, 0.36, 0.26)(x, y) ||
      ArtCanvas.inCircle(0.3, 0.44, 0.16)(x, y) ||
      ArtCanvas.inCircle(0.7, 0.44, 0.16)(x, y);
  c.fillShaded(crown, 0.5, 0.38, 0.36, const [leafDark, leaf, leaf, leafLight]);
  for (final (x, y) in const [(0.36, 0.3), (0.6, 0.24), (0.7, 0.44), (0.3, 0.5), (0.5, 0.46), (0.44, 0.18)]) {
    c.circle(x, y, 0.04, apple);
    c.dot(x - 0.015, y - 0.015, appleLight);
  }
  c.polygon(const [(0.7, 0.8), (0.88, 0.8), (0.85, 0.92), (0.73, 0.92)], basket);
  c.circle(0.75, 0.79, 0.03, apple);
  c.circle(0.82, 0.79, 0.03, apple);
  return c.toPuzzle(id: id, title: 'Apple Tree', palette: const [
    0xFFB3E5FC, 0xFFFFFFFF, 0xFF8BC34A, 0xFF689F38, 0xFF8D6E63, 0xFF5D4037, 0xFF2E7D32, 0xFF43A047, //
    0xFF81C784, 0xFFE53935, 0xFFFF8A80, 0xFFD7A86E,
  ]);
}
