import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// ---- Extreme (Cozy Classics) ------------------------------------------------

Puzzle xHeartBalloons(String id, int n) {
  const sky = 0, skyMid = 1, skyLow = 2, cloud = 3, cloudShade = 4, hill = 5, hillDark = 6, fence = 7;
  const fenceShade = 8, red = 9, redDark = 10, pink = 11, pinkDark = 12, purple = 13, string = 14;
  const flower = 15, flowerMid = 16;
  final c = ArtCanvas(n, n, background: sky);
  c.bands(const [sky, skyMid, skyLow], bottom: 0.76);
  for (final (x, y, s) in const [(0.16, 0.14, 1.0), (0.84, 0.36, 0.8)]) {
    c.ellipse(x, y + 0.02, 0.13 * s, 0.05 * s, cloudShade);
    c.ellipse(x, y, 0.12 * s, 0.045 * s, cloud);
    c.circle(x - 0.03 * s, y - 0.03 * s, 0.05 * s, cloud);
    c.circle(x + 0.04 * s, y - 0.02 * s, 0.04 * s, cloud);
  }
  c.ellipse(0.2, 1.0, 0.7, 0.3, hillDark);
  c.ellipse(0.85, 1.02, 0.6, 0.28, hill);
  // Picket fence.
  c.rect(0, 0.8, 1, 0.825, fenceShade);
  for (var i = 0; i < 9; i++) {
    final x = 0.03 + i * 0.12;
    c.rect(x, 0.74, x + 0.06, 0.92, fence);
    c.polygon([(x, 0.74), (x + 0.03, 0.705), (x + 0.06, 0.74)], fence);
    c.rect(x + 0.045, 0.75, x + 0.06, 0.92, fenceShade);
  }
  for (final (x, col) in const [(0.1, flower), (0.33, flowerMid), (0.62, flower), (0.88, flowerMid)]) {
    c.circle(x, 0.93, 0.03, col);
    c.dot(x, 0.93, red);
  }
  // Strings gather at the fence post.
  const knot = (0.5, 0.76);
  const balloons = [
    (0.3, 0.3, 0.12, red, redDark),
    (0.52, 0.2, 0.13, pink, pinkDark),
    (0.72, 0.36, 0.11, purple, redDark),
    (0.46, 0.46, 0.1, red, redDark),
  ];
  for (final (x, y, s, _, _) in balloons) {
    c.line(knot.$1, knot.$2, x, y + s * 0.8, 0.02, string);
  }
  for (final (x, y, s, col, dark) in balloons) {
    c.fillShaded(ArtCanvas.inHeart(x, y, s), x, y, s, [dark, col, col, col]);
    c.polygon([(x - 0.02, y + s * 1.0), (x + 0.02, y + s * 1.0), (x, y + s * 0.85)], dark);
    c.ellipse(x - s * 0.45, y - s * 0.35, s * 0.18, s * 0.1, cloud, angle: -0.7);
  }
  c.ellipse(knot.$1, knot.$2, 0.035, 0.02, red);
  return c.toPuzzle(id: id, title: 'Heart Balloons', palette: const [
    0xFF4F9FE3, 0xFF86C3F0, 0xFFC0E4FA, 0xFFFFFFFF, 0xFFD8CFF0, 0xFF8BCB6E, 0xFF4F9C4A, 0xFFFFEBC2, //
    0xFFC9B48E, 0xFFE8364F, 0xFF9E1B3A, 0xFFFF8FB8, 0xFFD45A8A, 0xFF9A6BE0, 0xFF6A5546, 0xFFFFD54F,
    0xFFFF9A4D,
  ]);
}

Puzzle xPicnic(String id, int n) {
  const sky = 0, cloud = 1, treeDark = 2, tree = 3, grass = 4, red = 5, pink = 6, basket = 7, basketDark = 8;
  const crust = 9, cherry = 10, sun = 11, flower = 12, lemon = 13;
  const grassDark = tree, crustDark = basket, glass = sky;
  final c = ArtCanvas(n, n, background: sky);
  c.circle(0.86, 0.1, 0.07, sun);
  c.ellipse(0.24, 0.12, 0.12, 0.04, cloud);
  c.circle(0.22, 0.09, 0.05, cloud);
  c.circle(0.29, 0.1, 0.035, cloud);
  // Tree line.
  for (var i = 0; i < 8; i++) {
    final x = i * 0.15 - 0.02;
    c.circle(x, 0.36 - (i.isEven ? 0.04 : 0), 0.11, i.isEven ? treeDark : tree);
  }
  c.rect(0, 0.36, 1, 1, grass);
  c.fill((x, y) => y > 0.36 && c.noise(x, y, 3) < 0.12, grassDark);
  // Gingham blanket in perspective.
  final blanket = ArtCanvas.inPolygon(const [(0.18, 0.46), (0.82, 0.46), (1.02, 0.96), (-0.02, 0.96)]);
  c.fill(blanket, cloud);
  c.fill((x, y) {
    if (!blanket(x, y)) return false;
    final v = (y - 0.46) / 0.5;
    final u = (x - 0.5) / (0.32 + 0.2 * v);
    return ((u + 1) * 4).floor().isEven && (v * 6).floor().isEven;
  }, red);
  c.fill((x, y) {
    if (!blanket(x, y)) return false;
    final v = (y - 0.46) / 0.5;
    final u = (x - 0.5) / (0.32 + 0.2 * v);
    final a = ((u + 1) * 4).floor().isEven, b = (v * 6).floor().isEven;
    return a != b;
  }, pink);
  // Basket.
  c.fill((x, y) {
    final d = math.sqrt((x - 0.27) * (x - 0.27) + (y - 0.58) * (y - 0.58));
    return y < 0.58 && d > 0.1 && d < 0.135;
  }, basketDark);
  final bk = ArtCanvas.inPolygon(const [(0.1, 0.58), (0.44, 0.58), (0.4, 0.8), (0.14, 0.8)]);
  c.fill(bk, basket);
  c.fill((x, y) => bk(x, y) && (c.row(y) % 3 == 0 || (c.col(x) + c.row(y) ~/ 3) % 3 == 0), basketDark);
  c.rect(0.08, 0.56, 0.46, 0.6, basketDark);
  c.polygon(const [(0.12, 0.56), (0.24, 0.48), (0.34, 0.56)], red);
  c.polygon(const [(0.24, 0.48), (0.24, 0.56), (0.34, 0.56)], pink);
  // Cherry pie.
  c.ellipse(0.66, 0.72, 0.17, 0.08, crustDark);
  c.ellipse(0.66, 0.7, 0.16, 0.07, crust);
  c.ellipse(0.66, 0.7, 0.12, 0.05, cherry);
  c.fill((x, y) => ArtCanvas.inEllipse(0.66, 0.7, 0.12, 0.05)(x, y) && (c.col(x) % 3 == 0 || c.row(y) % 2 == 0), crust);
  for (final (x, y) in const [(0.06, 0.42), (0.94, 0.44), (0.5, 0.39), (0.86, 0.98), (0.03, 0.99)]) {
    c.dot(x, y, flower);
  }
  // Lemonade glasses.
  for (final x in const [0.46, 0.88]) {
    c.rect(x - 0.035, 0.78, x + 0.035, 0.92, glass);
    c.rect(x - 0.025, 0.81, x + 0.025, 0.91, lemon);
    c.rect(x + 0.005, 0.81, x + 0.025, 0.91, sun);
    c.circle(x + 0.03, 0.78, 0.022, sun);
  }
  return c.toPuzzle(id: id, title: 'Picnic Day', palette: const [
    0xFFBDE4FF, 0xFFFFFFFF, 0xFF2F7044, 0xFF5AAE58, 0xFFB4E08A, 0xFFE0404E, 0xFFF5A3AE, 0xFFCF9550, //
    0xFF8E5528, 0xFFF7D08A, 0xFFA3203C, 0xFFFFB13D, 0xFFA77BDB, 0xFFFFF27A,
  ]);
}

Puzzle xYarnKitten(String id, int n) {
  const wall = 0, wallStripe = 1, floor = 2, floorDark = 3, rug = 4, rugEdge = 5, fur = 6, furDark = 7;
  const furLight = 8, white = 9, eye = 10, pink = 11, yarn = 12, yarnDark = 13, glass = 14, frame = white;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => c.col(x) % 4 == 0, wallStripe);
  // Window with a view of the sky.
  c.rect(0.6, 0.06, 0.92, 0.42, frame);
  c.rect(0.63, 0.09, 0.89, 0.39, glass);
  c.rect(0.75, 0.09, 0.775, 0.39, frame);
  c.rect(0.63, 0.23, 0.89, 0.25, frame);
  c.rect(0.57, 0.42, 0.95, 0.45, furDark);
  // Floorboards.
  c.rect(0, 0.62, 1, 1, floor);
  c.fill((x, y) => y > 0.62 && (c.row(y) % 3 == 0 || (c.col(x) + c.row(y) ~/ 3 * 5) % 9 == 0), floorDark);
  c.ellipse(0.5, 0.86, 0.48, 0.12, rugEdge);
  c.ellipse(0.5, 0.86, 0.43, 0.095, rug);
  c.ring(0.5, 0.86, 0, 0, rug);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.86, 0.3, 0.06)(x, y) && !ArtCanvas.inEllipse(0.5, 0.86, 0.26, 0.04)(x, y),
      rugEdge);
  // Tail.
  c.line(0.56, 0.8, 0.7, 0.72, 0.06, fur);
  c.line(0.7, 0.72, 0.72, 0.6, 0.06, fur);
  c.circle(0.72, 0.6, 0.03, furDark);
  // Body.
  final body = ArtCanvas.inEllipse(0.4, 0.7, 0.19, 0.16);
  c.fillShaded(body, 0.4, 0.7, 0.19, const [furDark, fur, fur, furLight]);
  c.fill((x, y) => body(x, y) && y > 0.6 && ((x * 40).floor() % 4 == 0) && x > 0.42, furDark);
  c.ellipse(0.36, 0.72, 0.08, 0.1, white);
  c.ellipse(0.3, 0.85, 0.06, 0.035, white);
  c.ellipse(0.44, 0.85, 0.06, 0.035, white);
  // Head.
  for (final m in const [false, true]) {
    final s = m ? 1.0 : -1.0;
    c.polygon([(0.36 + s * 0.17, 0.38), (0.36 + s * 0.14, 0.2), (0.36 + s * 0.05, 0.32)], fur);
    c.polygon([(0.36 + s * 0.145, 0.34), (0.36 + s * 0.135, 0.25), (0.36 + s * 0.08, 0.32)], pink);
  }
  final head = ArtCanvas.inEllipse(0.36, 0.44, 0.17, 0.14);
  c.fillShaded(head, 0.36, 0.44, 0.17, const [furDark, fur, fur, furLight]);
  for (final x in const [0.32, 0.36, 0.40]) {
    c.line(x, 0.31, x, 0.36, 0.025, furDark);
  }
  c.ellipse(0.36, 0.51, 0.09, 0.05, white);
  for (final x in const [0.29, 0.43]) {
    c.ellipse(x, 0.44, 0.03, 0.04, eye);
    c.dot(x - 0.01, 0.43, white);
  }
  c.polygon(const [(0.34, 0.48), (0.38, 0.48), (0.36, 0.505)], pink);
  c.circle(0.23, 0.5, 0.025, pink);
  c.circle(0.49, 0.5, 0.025, pink);
  // Yarn ball with a loose thread, and a raised paw.
  c.line(0.66, 0.86, 0.9, 0.9, 0.025, yarn);
  c.line(0.9, 0.9, 0.96, 0.8, 0.025, yarn);
  final ball = ArtCanvas.inCircle(0.74, 0.8, 0.1);
  c.fillShaded(ball, 0.74, 0.8, 0.1, const [yarnDark, yarn, yarn]);
  c.fill((x, y) => ball(x, y) && ArtCanvas.inLine(0.66, 0.74, 0.82, 0.88, 0.02)(x, y), yarnDark);
  c.fill((x, y) => ball(x, y) && ArtCanvas.inLine(0.68, 0.86, 0.8, 0.72, 0.02)(x, y), yarnDark);
  c.line(0.5, 0.66, 0.62, 0.72, 0.06, fur);
  c.circle(0.63, 0.72, 0.04, white);
  return c.toPuzzle(id: id, title: 'Yarn Kitten', palette: const [
    0xFFFCE6D6, 0xFFF4C7BE, 0xFFA87650, 0xFF7A4E30, 0xFF8ECFC4, 0xFF4F9B91, 0xFFF59E45, 0xFFC96A22, //
    0xFFFFD49C, 0xFFFFFFFF, 0xFF2E2A33, 0xFFF4889E, 0xFF7E8CEB, 0xFF4A56B5, 0xFFAEDBF6,
  ]);
}

Puzzle xCarousel(String id, int n) {
  const sky = 0, skyLow = 1, pink = 2, mint = 3, gold = 4, goldDark = 5, inside = 6, base = 7;
  const baseDark = 8, horse = 9, horseShade = 10, grass = 11, grassDark = 12, light = 13, flag = 14, dark = 15;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.5, 1, 1, skyLow);
  c.rect(0, 0.86, 1, 1, grass);
  c.fill((x, y) => y > 0.86 && c.noise(x, y, 7) < 0.25, grassDark);
  // Inside of the canopy.
  c.rect(0.1, 0.3, 0.9, 0.82, inside);
  c.rect(0.48, 0.3, 0.52, 0.82, gold);
  // Base platform.
  c.ellipse(0.5, 0.84, 0.46, 0.07, baseDark);
  c.rect(0.04, 0.8, 0.96, 0.86, base);
  c.ellipse(0.5, 0.8, 0.46, 0.05, base);
  c.fill((x, y) => y > 0.82 && y < 0.86 && x > 0.04 && x < 0.96 && c.col(x) % 3 == 0, light);
  // Canopy cone with stripes fanning from the top.
  final cone = ArtCanvas.inPolygon(const [(0.5, 0.08), (0.98, 0.3), (0.02, 0.3)]);
  c.fill((x, y) => cone(x, y) && (math.atan2(x - 0.5, y - 0.08) * 4.5).floor().isEven, pink);
  c.fill((x, y) => cone(x, y) && (math.atan2(x - 0.5, y - 0.08) * 4.5).floor().isOdd, mint);
  c.rect(0.02, 0.29, 0.98, 0.32, gold);
  for (var i = 0; i < 8; i++) {
    final x = 0.08 + i * 0.12;
    c.circle(x, 0.33, 0.05, i.isEven ? pink : mint);
    c.dot(x, 0.3, light);
  }
  c.fill((x, y) => y > 0.335 && y < 0.38 && x < 0.1, sky);
  c.fill((x, y) => y > 0.335 && y < 0.38 && x > 0.9, sky);
  c.line(0.5, 0.08, 0.5, 0.02, 0.02, goldDark);
  c.polygon(const [(0.51, 0.0), (0.62, 0.03), (0.51, 0.06)], flag);
  c.circle(0.5, 0.08, 0.025, gold);
  // Two horses on their poles.
  void pony(double cx, double cy, bool left, int saddle, int mane) {
    final s = left ? -1.0 : 1.0;
    c.line(cx, 0.36, cx, 0.8, 0.02, goldDark);
    c.fillShaded(ArtCanvas.inEllipse(cx, cy, 0.12, 0.06), cx, cy, 0.12, const [horseShade, horse, horse]);
    c.polygon([(cx + s * 0.06, cy - 0.02), (cx + s * 0.13, cy - 0.13), (cx + s * 0.16, cy - 0.1), (cx + s * 0.11, cy)],
        horse);
    c.ellipse(cx + s * 0.16, cy - 0.12, 0.06, 0.03, horse, angle: s * 0.4);
    c.dot(cx + s * 0.155, cy - 0.135, dark);
    c.line(cx + s * 0.06, cy - 0.03, cx + s * 0.12, cy - 0.15, 0.03, mane);
    c.line(cx - s * 0.11, cy - 0.01, cx - s * 0.17, cy + 0.08, 0.035, mane);
    c.line(cx + s * 0.07, cy + 0.04, cx + s * 0.13, cy + 0.08, 0.03, horseShade);
    c.line(cx + s * 0.04, cy + 0.04, cx + s * 0.07, cy + 0.12, 0.03, horse);
    c.line(cx - s * 0.07, cy + 0.04, cx - s * 0.1, cy + 0.12, 0.03, horse);
    c.line(cx - s * 0.04, cy + 0.04, cx - s * 0.02, cy + 0.11, 0.03, horseShade);
    c.ellipse(cx, cy - 0.04, 0.05, 0.025, saddle);
    c.line(cx, 0.36, cx, cy - 0.05, 0.025, gold);
  }

  pony(0.27, 0.56, true, mint, pink);
  pony(0.72, 0.66, false, pink, gold);
  return c.toPuzzle(id: id, title: 'Carousel', palette: const [
    0xFF74BDEE, 0xFFC8EAFB, 0xFFF0628F, 0xFF7ED9BF, 0xFFFFC948, 0xFFC4861C, 0xFF6E3D63, 0xFF9B66CF, //
    0xFF5D3A92, 0xFFFFFFFF, 0xFFD5CDEB, 0xFF7CC66F, 0xFF4E9A4C, 0xFFFFF7A8, 0xFFE8384A, 0xFF2B2230,
  ]);
}

Puzzle xFireside(String id, int n) {
  const wall = 0, wallDark = 1, brick = 2, mortar = 3, hearth = 4, flameOut = 5, flameMid = 6, flameIn = 7;
  const log = 8, mantel = 9, floor = 10, rug = 11, rugLight = 12, dog = 13, dogDark = 14, mug = 15;
  const sock = 16, muzzle = 17, cocoa = log;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => c.col(x) % 5 == 0, wallDark);
  c.rect(0, 0.78, 1, 1, floor);
  c.fill((x, y) => y > 0.78 && c.row(y) % 3 == 0, mortar);
  // Brick fireplace.
  c.rect(0.14, 0.24, 0.86, 0.8, brick);
  c.fill((x, y) {
    if (x < 0.14 || x > 0.86 || y < 0.24 || y > 0.8) return false;
    final r = c.row(y), cl = c.col(x);
    return r % 3 == 0 || (cl + ((r ~/ 3).isEven ? 0 : 2)) % 4 == 0;
  }, mortar);
  final mouth = ArtCanvas.inPolygon(const [(0.3, 0.8), (0.3, 0.48), (0.4, 0.4), (0.6, 0.4), (0.7, 0.48), (0.7, 0.8)]);
  c.fill(mouth, hearth);
  // Fire.
  c.polygon(
      const [(0.34, 0.74), (0.38, 0.52), (0.44, 0.6), (0.5, 0.44), (0.56, 0.6), (0.62, 0.52), (0.66, 0.74)], flameOut);
  c.polygon(
      const [(0.39, 0.74), (0.43, 0.6), (0.47, 0.64), (0.5, 0.53), (0.53, 0.64), (0.57, 0.6), (0.61, 0.74)], flameMid);
  c.polygon(const [(0.45, 0.74), (0.5, 0.62), (0.55, 0.74)], flameIn);
  c.line(0.34, 0.76, 0.62, 0.72, 0.045, log);
  c.line(0.38, 0.72, 0.66, 0.76, 0.045, log);
  // Mantel with stockings and a candle-warm mug.
  c.rect(0.08, 0.2, 0.92, 0.26, mantel);
  c.rect(0.08, 0.25, 0.92, 0.27, log);
  for (final x in const [0.24, 0.76]) {
    c.rect(x - 0.035, 0.27, x + 0.035, 0.38, sock);
    c.ellipse(x - 0.02, 0.39, 0.055, 0.035, sock);
    c.rect(x - 0.04, 0.27, x + 0.04, 0.3, mug);
  }
  c.rect(0.43, 0.1, 0.55, 0.2, mug);
  c.rect(0.445, 0.1, 0.535, 0.125, cocoa);
  c.ring(0.565, 0.15, 0.012, 0.035, mug);
  c.heart(0.49, 0.16, 0.025, sock);
  for (final (x, y) in const [(0.47, 0.06), (0.5, 0.03), (0.52, 0.07)]) {
    c.dot(x, y, mug);
  }
  // Rug and a sleeping pup.
  c.ellipse(0.5, 0.92, 0.48, 0.08, rug);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.92, 0.48, 0.08)(x, y) && (c.col(x) + c.row(y)) % 4 == 0, rugLight);
  c.line(0.74, 0.88, 0.84, 0.8, 0.045, dog);
  c.circle(0.84, 0.8, 0.025, muzzle);
  final pup = ArtCanvas.inEllipse(0.58, 0.86, 0.21, 0.09);
  c.fillShaded(pup, 0.58, 0.86, 0.21, const [dogDark, dog, dog], lightX: 0, lightY: -1);
  c.ellipse(0.6, 0.9, 0.12, 0.03, muzzle);
  c.ellipse(0.64, 0.82, 0.06, 0.04, dogDark);
  final head = ArtCanvas.inCircle(0.35, 0.83, 0.085);
  c.fill(head, dog);
  c.ellipse(0.27, 0.87, 0.045, 0.032, muzzle);
  c.dot(0.235, 0.865, hearth);
  c.line(0.31, 0.83, 0.35, 0.835, 0.018, hearth);
  c.ellipse(0.41, 0.86, 0.03, 0.06, dogDark, angle: 0.3);
  return c.toPuzzle(id: id, title: 'Fireside Nap', palette: const [
    0xFF3F6E6E, 0xFF2A4A4C, 0xFFB8573C, 0xFF6E2E22, 0xFF241716, 0xFFF06A1E, 0xFFFF9B2E, 0xFFFFE066, //
    0xFF4A2E1C, 0xFF9A5E2E, 0xFF8E7564, 0xFF3F6FB8, 0xFF8FB8EA, 0xFFEDC27E, 0xFFC58A45, 0xFFFFFFFF,
    0xFFD62E4A, 0xFFFBE6C2,
  ]);
}
