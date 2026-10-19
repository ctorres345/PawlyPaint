import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// ---- Easy -----------------------------------------------------------------

Puzzle lollipop(String id, int n) {
  const bg = 0, dot = 1, stick = 2, candyA = 3, candyB = 4, shine = stick;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 6 == 0, dot);
  c.line(0.5, 0.5, 0.5, 0.95, 0.07, stick);
  c.fill((x, y) {
    final dx = x - 0.5, dy = y - 0.38;
    final r = math.sqrt(dx * dx + dy * dy);
    if (r > 0.3) return false;
    return ((math.atan2(dy, dx) / (2 * math.pi) + r * 2.2) * 4).floor().isEven;
  }, candyA);
  c.fill((x, y) {
    final dx = x - 0.5, dy = y - 0.38;
    final r = math.sqrt(dx * dx + dy * dy);
    if (r > 0.3) return false;
    return ((math.atan2(dy, dx) / (2 * math.pi) + r * 2.2) * 4).floor().isOdd;
  }, candyB);
  c.dot(0.38, 0.26, shine);
  return c.toPuzzle(id: id, title: 'Swirl Pop', palette: const [
    0xFFE1F5FE, 0xFFB3E5FC, 0xFFFFFFFF, 0xFFEC407A, 0xFFFFF59D, //
  ]);
}

Puzzle iceCream(String id, int n) {
  const bg = 0, cone = 1, coneDark = 2, scoopA = 3, scoopAShade = 4, scoopB = 5, scoopBShade = 6, cherry = 7;
  final c = ArtCanvas(n, n, background: bg);
  final coneShape = ArtCanvas.inPolygon(const [(0.26, 0.58), (0.74, 0.58), (0.5, 0.97)]);
  c.fill(coneShape, cone);
  c.fill((x, y) => coneShape(x, y) && (c.col(x) + c.row(y)) % 3 == 0, coneDark);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.54, 0.24), 0.5, 0.54, 0.24, const [scoopAShade, scoopA, scoopA]);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.3, 0.21), 0.5, 0.3, 0.21, const [scoopBShade, scoopB, scoopB]);
  c.circle(0.52, 0.08, 0.06, cherry);
  return c.toPuzzle(id: id, title: 'Double Scoop', palette: const [
    0xFFE1F5FE, 0xFFE0A050, 0xFFB87333, 0xFFFFF8E1, 0xFFE8D9B5, 0xFFF8BBD0, 0xFFEC8FB0, 0xFFE53935, //
  ]);
}

Puzzle donut(String id, int n) {
  const bg = 0, dough = 1, doughDark = 2, icing = 3, icingShade = 4, sprinkleA = 5, sprinkleB = 6, sprinkleC = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.ring(0.5, 0.52, 0.1, 0.38, doughDark);
  c.ring(0.5, 0.5, 0.1, 0.37, dough);
  bool top(double x, double y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.48) * (y - 0.48));
    return d > 0.14 && d < 0.31 + 0.03 * math.sin(math.atan2(y - 0.48, x - 0.5) * 6);
  }

  c.fillShaded(top, 0.5, 0.48, 0.32, const [icingShade, icing, icing]);
  const sprinkles = [(0.3, 0.36), (0.62, 0.26), (0.72, 0.5), (0.36, 0.64), (0.6, 0.68), (0.46, 0.24), (0.28, 0.52)];
  for (var i = 0; i < sprinkles.length; i++) {
    final (x, y) = sprinkles[i];
    c.dot(x, y, const [sprinkleA, sprinkleB, sprinkleC][i % 3]);
  }
  return c.toPuzzle(id: id, title: 'Sprinkle Donut', palette: const [
    0xFFE0F7FA, 0xFFE0A96D, 0xFFB5793D, 0xFFF48FB1, 0xFFE57399, 0xFFFFFFFF, 0xFF4FC3F7, 0xFFFFEB3B, //
  ]);
}

Puzzle candy(String id, int n) {
  const bg = 0, dot = 1, wrap = 2, wrapDark = 3, stripe = 4, twist = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 3 + c.row(y)) % 7 == 0, dot);
  c.polygon(const [(0.3, 0.5), (0.08, 0.3), (0.12, 0.5), (0.08, 0.7)], twist);
  c.polygon(const [(0.7, 0.5), (0.92, 0.3), (0.88, 0.5), (0.92, 0.7)], twist);
  final body = ArtCanvas.inEllipse(0.5, 0.5, 0.24, 0.17);
  c.fillShaded(body, 0.5, 0.5, 0.24, const [wrapDark, wrap, wrap]);
  c.fill((x, y) => body(x, y) && ((x + y) * 8).floor() % 3 == 0, stripe);
  return c.toPuzzle(id: id, title: 'Sweetie', palette: const [
    0xFFF3E5F5, 0xFFE1BEE7, 0xFF9575CD, 0xFF7E57C2, 0xFFFFFFFF, 0xFFB39DDB, //
  ]);
}

Puzzle cookie(String id, int n) {
  const bg = 0, check = 1, cookieC = 2, cookieDark = 3, cookieLight = 4, chip = 5, milk = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) ~/ 2 + c.row(y) ~/ 2).isEven, check);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.5, 0.34), 0.5, 0.5, 0.34, const [cookieDark, cookieC, cookieC, cookieLight]);
  c.fill((x, y) => ArtCanvas.inCircle(0.86, 0.3, 0.12)(x, y), bg);
  for (final (x, y) in const [(0.36, 0.36), (0.6, 0.32), (0.44, 0.58), (0.66, 0.6), (0.3, 0.6), (0.52, 0.76)]) {
    c.circle(x, y, 0.045, chip);
  }
  c.dot(0.84, 0.84, milk);
  return c.toPuzzle(id: id, title: 'Choco Chip', palette: const [
    0xFFE3F2FD, 0xFFBBDEFB, 0xFFD9A066, 0xFFB07A3B, 0xFFEBC28E, 0xFF4E342E, 0xFFFFFFFF, //
  ]);
}

// ---- Medium ---------------------------------------------------------------

Puzzle macarons(String id, int n) {
  const bg = 0, plate = 1, plateShade = 2;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 0.86, 0.44, 0.08, plateShade);
  c.ellipse(0.5, 0.84, 0.42, 0.07, plate);
  void macaron(double x, double y, int shell, int shade, int filling) {
    c.ellipse(x, y + 0.07, 0.15, 0.06, shade);
    c.ellipse(x, y + 0.06, 0.15, 0.055, shell);
    c.rect(x - 0.14, y - 0.015, x + 0.14, y + 0.025, filling);
    c.ellipse(x, y - 0.04, 0.15, 0.06, shell);
    c.dot(x - 0.06, y - 0.06, plate);
  }

  macaron(0.3, 0.68, 3, 4, plate);
  macaron(0.7, 0.68, 6, 7, 11);
  macaron(0.5, 0.42, 9, 10, plate);
  macaron(0.5, 0.17, 3, 4, 11);
  return c.toPuzzle(id: id, title: 'Macaron Stack', palette: const [
    0xFFE0F2F1, 0xFFFFFFFF, 0xFFCFD8DC, //
    0xFFF8BBD0, 0xFFE89AB5, 0xFFFFFDE7, //
    0xFFC5E1A5, 0xFF9CCC65, 0xFFFFF3E0, //
    0xFFB39DDB, 0xFF9575CD, 0xFFFFE082,
  ]);
}

Puzzle cakeSlice(String id, int n) {
  const bg = 0, dot = 1, plate = 2, sponge = 3, spongeDark = 4, cream = 5, jam = 6, frosting = 7, berry = 8;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 3) % 7 == 0, dot);
  c.ellipse(0.5, 0.86, 0.42, 0.07, plate);
  final side = ArtCanvas.inPolygon(const [(0.18, 0.46), (0.82, 0.36), (0.82, 0.8), (0.18, 0.84)]);
  c.fill(side, sponge);
  c.fill((x, y) => side(x, y) && y > 0.6 - (x - 0.18) * 0.16 && y < 0.65 - (x - 0.18) * 0.16, jam);
  c.fill((x, y) => side(x, y) && y > 0.65 - (x - 0.18) * 0.16 && y < 0.69 - (x - 0.18) * 0.16, cream);
  c.fill((x, y) => side(x, y) && x > 0.74, spongeDark);
  c.polygon(const [(0.18, 0.46), (0.46, 0.24), (0.82, 0.36)], frosting);
  c.fill((x, y) => side(x, y) && y < 0.5 - (x - 0.18) * 0.16 && c.col(x).isEven, frosting);
  c.circle(0.5, 0.26, 0.06, berry);
  return c.toPuzzle(id: id, title: 'Strawberry Shortcake', palette: const [
    0xFFE8EAF6, 0xFFD1C4E9, 0xFFFFFFFF, 0xFFFFE082, 0xFFF2C14E, 0xFFFFFDE7, 0xFFE53950, 0xFFFFF0F5, //
    0xFFD32F2F,
  ]);
}

Puzzle popsicle(String id, int n) {
  const bg = 0, sun = 1, stick = 2, top = 3, mid = 4, low = sun, shade = 6, drip = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.circle(0.15, 0.15, 0.1, sun);
  c.rect(0.46, 0.72, 0.54, 0.96, stick);
  bool body(double x, double y) =>
      (x > 0.3 && x < 0.7 && y > 0.26 && y < 0.76) || ArtCanvas.inEllipse(0.5, 0.26, 0.2, 0.14)(x, y);
  c.fill((x, y) => body(x, y) && y < 0.4, top);
  c.fill((x, y) => body(x, y) && y >= 0.4 && y < 0.58, mid);
  c.fill((x, y) => body(x, y) && y >= 0.58, low);
  c.fill((x, y) => body(x, y) && x > 0.62, shade);
  c.circle(0.36, 0.8, 0.035, drip);
  c.line(0.36, 0.76, 0.36, 0.8, 0.05, drip);
  return c.toPuzzle(id: id, title: 'Sunset Pop', palette: const [
    0xFFE0F7FA, 0xFFFFEE58, 0xFFE0B97E, 0xFFFF7043, 0xFFFFA726, 0xFFFFEE58, 0xFFE64A19, 0xFFFFCA28, //
  ]);
}

Puzzle gingerbread(String id, int n) {
  const bg = 0, dot = 1, ginger = 2, gingerDark = 3, icing = 4, button = 5, eye = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y)) % 6 == 0, dot);
  bool man(double x, double y) =>
      ArtCanvas.inCircle(0.5, 0.24, 0.13)(x, y) ||
      ArtCanvas.inEllipse(0.5, 0.56, 0.16, 0.22)(x, y) ||
      ArtCanvas.inLine(0.36, 0.48, 0.16, 0.38, 0.12)(x, y) ||
      ArtCanvas.inLine(0.64, 0.48, 0.84, 0.38, 0.12)(x, y) ||
      ArtCanvas.inLine(0.42, 0.7, 0.32, 0.9, 0.13)(x, y) ||
      ArtCanvas.inLine(0.58, 0.7, 0.68, 0.9, 0.13)(x, y);
  c.fillShaded(man, 0.5, 0.5, 0.4, const [gingerDark, ginger, ginger]);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.25) * (y - 0.25));
    return d > 0.05 && d < 0.075 && y > 0.27;
  }, icing);
  c.circle(0.45, 0.2, 0.025, eye);
  c.circle(0.55, 0.2, 0.025, eye);
  for (final y in const [0.46, 0.56, 0.66]) {
    c.circle(0.5, y, 0.03, button);
  }
  for (final (x1, y1, x2, y2) in const [(0.17, 0.35, 0.21, 0.44), (0.83, 0.35, 0.79, 0.44)]) {
    c.line(x1, y1, x2, y2, 0.035, icing);
  }
  return c.toPuzzle(id: id, title: 'Ginger Friend', palette: const [
    0xFFE8F5E9, 0xFFC8E6C9, 0xFFC68642, 0xFF8D5524, 0xFFFFFFFF, 0xFFE53935, 0xFF3E2723, //
  ]);
}

Puzzle pudding(String id, int n) {
  const bg = 0, plate = 1, plateShade = 2, custard = 3, custardShade = 4, caramel = 5, cream = 6, cherry = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.ellipse(0.5, 0.84, 0.42, 0.08, plateShade);
  c.ellipse(0.5, 0.82, 0.4, 0.07, plate);
  final body = ArtCanvas.inPolygon(const [(0.3, 0.38), (0.7, 0.38), (0.78, 0.8), (0.22, 0.8)]);
  c.fill(body, custard);
  c.fill((x, y) => body(x, y) && x > 0.64, custardShade);
  c.ellipse(0.5, 0.38, 0.2, 0.06, caramel);
  c.fill((x, y) => body(x, y) && y < 0.48 && (c.col(x) % 4 == 1), caramel);
  c.circle(0.5, 0.3, 0.07, cream);
  c.circle(0.5, 0.2, 0.045, cherry);
  return c.toPuzzle(id: id, title: 'Caramel Pudding', palette: const [
    0xFFFCE4EC, 0xFFFFFFFF, 0xFFE0E0E0, 0xFFFFE082, 0xFFF9C74F, 0xFF8D4F1D, 0xFFFFFDE7, 0xFFE53935, //
  ]);
}

// ---- Hard -----------------------------------------------------------------

Puzzle layerCake(String id, int n) {
  const bg = 0, bunting = 1, stand = 2, standShade = 3, cakeA = 4, cakeB = 5, cream = stand, creamShade = 7;
  const candle = 8, flame = 9, berry = 10, side = 11;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => y < 0.12 && (c.col(x) % 4 < 2) && y < 0.12 - (c.col(x) % 4) * 0.02, bunting);
  c.rect(0.44, 0.8, 0.56, 0.9, standShade);
  c.ellipse(0.5, 0.92, 0.22, 0.04, stand);
  c.ellipse(0.5, 0.8, 0.42, 0.05, stand);
  final tiers = [(0.18, 0.82, 0.54, 0.78, cakeA), (0.26, 0.74, 0.34, 0.54, cakeB)];
  for (final (l, r, t, b, col) in tiers) {
    c.rect(l, t, r, b, col);
    c.rect(r - 0.06, t, r, b, side);
    c.rect(l, t - 0.02, r, t + 0.03, cream);
    for (var x = l + 0.03; x < r; x += 0.08) {
      c.circle(x, t + 0.05, 0.025, cream);
    }
    c.rect(l, (t + b) / 2, r, (t + b) / 2 + 0.03, creamShade);
  }
  c.ellipse(0.5, 0.34, 0.24, 0.04, cream);
  for (final (x, y) in const [(0.34, 0.31), (0.66, 0.31), (0.5, 0.3)]) {
    c.circle(x, y, 0.035, berry);
  }
  for (final x in const [0.42, 0.58]) {
    c.rect(x - 0.015, 0.16, x + 0.015, 0.29, candle);
    c.ellipse(x, 0.13, 0.02, 0.035, flame);
  }
  return c.toPuzzle(id: id, title: 'Party Cake', palette: const [
    0xFFFFF8E1, 0xFF80DEEA, 0xFFFFFFFF, 0xFFCFD8DC, 0xFFF8BBD0, 0xFFE1BEE7, 0xFFFFFDF5, 0xFFF3E5F5, //
    0xFF4FC3F7, 0xFFFFB300, 0xFFE53935, 0xFFE0A0C0,
  ]);
}

Puzzle sundae(String id, int n) {
  const bg = 0, bgDot = 1, glass = 2, glassShade = 3, scoopA = 4, scoopB = 5, scoopC = 6, sauce = 7;
  const cream = 8, cherry = 9, wafer = 10, spoon = 11;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 7 == 0, bgDot);
  c.rect(0.46, 0.7, 0.54, 0.88, glass);
  c.ellipse(0.5, 0.9, 0.16, 0.04, glass);
  final cup = ArtCanvas.inPolygon(const [(0.22, 0.44), (0.78, 0.44), (0.62, 0.72), (0.38, 0.72)]);
  c.fill(cup, glass);
  c.fill((x, y) => cup(x, y) && x > 0.6, glassShade);
  c.circle(0.36, 0.42, 0.11, scoopA);
  c.circle(0.64, 0.42, 0.11, scoopB);
  c.circle(0.5, 0.32, 0.11, scoopC);
  c.fill((x, y) => ArtCanvas.inCircle(0.5, 0.3, 0.12)(x, y) && y < 0.3 + 0.04 * math.sin(x * 40), sauce);
  c.circle(0.5, 0.18, 0.07, cream);
  c.circle(0.52, 0.1, 0.04, cherry);
  c.polygon(const [(0.68, 0.34), (0.76, 0.14), (0.8, 0.16), (0.72, 0.36)], wafer);
  c.line(0.26, 0.36, 0.14, 0.12, 0.03, spoon);
  return c.toPuzzle(id: id, title: 'Grand Sundae', palette: const [
    0xFFE8F5E9, 0xFFC8E6C9, 0xFFE3F2FD, 0xFFBBDEFB, 0xFFF8BBD0, 0xFFC5E1A5, 0xFFFFF8E1, 0xFF6D3B1F, //
    0xFFFFFFFF, 0xFFE53935, 0xFFE0B97E, 0xFF9E9E9E,
  ]);
}

Puzzle bobaTea(String id, int n) {
  const bg = 0, bgDot = 1, cup = 2, cupShade = 3, tea = 4, teaShade = 5, pearl = 6, pearlShine = 7, lid = cupShade;
  const straw = 9, strawStripe = 10, face = 11, cheek = 12;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 2 + c.row(y)) % 7 == 0, bgDot);
  c.line(0.58, 0.3, 0.7, 0.02, 0.07, straw);
  c.fill((x, y) => ArtCanvas.inLine(0.58, 0.3, 0.7, 0.02, 0.07)(x, y) && c.row(y) % 3 == 0, strawStripe);
  final body = ArtCanvas.inPolygon(const [(0.24, 0.3), (0.76, 0.3), (0.68, 0.94), (0.32, 0.94)]);
  c.fill(body, cup);
  c.fill((x, y) => body(x, y) && y > 0.38, tea);
  c.fill((x, y) => body(x, y) && y > 0.38 && x > 0.62, teaShade);
  c.fill((x, y) => body(x, y) && x > 0.7, cupShade);
  for (var i = 0; i < 9; i++) {
    final x = 0.38 + (i % 5) * 0.06 + (i ~/ 5) * 0.03, y = 0.86 - (i ~/ 5) * 0.06;
    c.circle(x, y, 0.03, pearl);
    if (i.isEven) c.dot(x - 0.01, y - 0.01, pearlShine);
  }
  c.ellipse(0.5, 0.3, 0.28, 0.05, lid);
  c.circle(0.43, 0.56, 0.02, face);
  c.circle(0.57, 0.56, 0.02, face);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.58) * (y - 0.58));
    return d > 0.03 && d < 0.05 && y > 0.6;
  }, face);
  c.circle(0.38, 0.62, 0.025, cheek);
  c.circle(0.62, 0.62, 0.025, cheek);
  return c.toPuzzle(id: id, title: 'Boba Buddy', palette: const [
    0xFFFFF3E0, 0xFFFFE0B2, 0xFFFAFAFA, 0xFFE0E0E0, 0xFFD7B899, 0xFFC19A6B, 0xFF3E2723, 0xFF8D6E63, //
    0xFFFFFFFF, 0xFF4FC3F7, 0xFF0288D1, 0xFF4E342E, 0xFFF48FB1,
  ]);
}

Puzzle pancakes(String id, int n) {
  const bg = 0, check = 1, plate = 2, plateShade = 3, cake = 4, cakeDark = 5, butter = 6, syrup = 7;
  const berry = 8, berryLight = 9;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) ~/ 4 + c.row(y) ~/ 4).isEven, check);
  c.ellipse(0.5, 0.86, 0.44, 0.08, plateShade);
  c.ellipse(0.5, 0.84, 0.42, 0.07, plate);
  for (var i = 0; i < 5; i++) {
    final y = 0.78 - i * 0.08;
    c.ellipse(0.5, y + 0.015, 0.3, 0.05, cakeDark);
    c.ellipse(0.5, y, 0.3, 0.045, cake);
  }
  c.ellipse(0.5, 0.44, 0.28, 0.05, syrup);
  for (final (x, len) in const [(0.26, 0.14), (0.4, 0.22), (0.66, 0.1), (0.76, 0.18)]) {
    c.rect(x - 0.015, 0.44, x + 0.015, 0.44 + len, syrup);
  }
  c.rect(0.44, 0.36, 0.56, 0.42, butter);
  for (final (x, y) in const [(0.2, 0.84), (0.28, 0.88), (0.8, 0.86)]) {
    c.circle(x, y, 0.03, berry);
    c.dot(x - 0.01, y - 0.01, berryLight);
  }
  return c.toPuzzle(id: id, title: 'Pancake Stack', palette: const [
    0xFFFFFDE7, 0xFFFFF59D, 0xFFFFFFFF, 0xFFE0E0E0, 0xFFF2C27B, 0xFFC98B3D, 0xFFFFF176, 0xFF8D4A1D, //
    0xFF3949AB, 0xFF7986CB,
  ]);
}

Puzzle teaTime(String id, int n) {
  const bg = 0, cloth = 1, clothCheck = 2, saucer = clothCheck, saucerShade = 4, cup = 5, cupShade = 6, tea = 7;
  const steam = 8, flower = 9, cookieC = 10, cookieDark = 11;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0, 0.62, 1, 1, cloth);
  c.fill((x, y) => y >= 0.62 && (c.col(x) ~/ 3 + c.row(y) ~/ 3).isEven, clothCheck);
  c.ellipse(0.44, 0.8, 0.32, 0.07, saucerShade);
  c.ellipse(0.44, 0.78, 0.3, 0.06, saucer);
  c.ring(0.68, 0.56, 0.05, 0.09, cup);
  bool body(double x, double y) => ArtCanvas.inEllipse(0.44, 0.56, 0.22, 0.2)(x, y) && y > 0.46;
  c.fill(body, cup);
  c.fill((x, y) => body(x, y) && x > 0.56, cupShade);
  c.ellipse(0.44, 0.46, 0.22, 0.05, tea);
  c.circle(0.38, 0.6, 0.04, flower);
  c.circle(0.48, 0.64, 0.03, flower);
  for (final x in const [0.38, 0.5]) {
    c.fill((px, py) => py > 0.18 && py < 0.4 && (px - x - 0.03 * math.sin(py * 30)).abs() < 0.02, steam);
  }
  for (final (x, y) in const [(0.84, 0.86), (0.9, 0.76)]) {
    c.circle(x, y, 0.07, cookieC);
    c.dot(x, y, cookieDark);
    c.dot(x + 0.03, y - 0.02, cookieDark);
  }
  return c.toPuzzle(id: id, title: 'Tea Time', palette: const [
    0xFFFFF8E1, 0xFFF8BBD0, 0xFFFFFFFF, 0xFFFAFAFA, 0xFFE0E0E0, 0xFFE3F2FD, 0xFFBBDEFB, 0xFFB5651D, //
    0xFFCFD8DC, 0xFFF06292, 0xFFE0A96D, 0xFF6D4C41,
  ]);
}
