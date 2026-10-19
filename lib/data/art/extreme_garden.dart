import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// ---- Extreme --------------------------------------------------------------

Puzzle xPumpkinPatch(String id, int n) {
  const skyTop = 0, skyMid = 1, skyLow = 2, sun = 3, cloud = 4, hill = 5, fence = 7, soil = 9, soilDark = 10;
  const vine = 11, leaf = 12, pumpkin = 13, pumpkinDark = 14, crow = 16, hay = sun, hayDark = 18;
  const hillDark = leaf, fenceDark = soilDark, pumpkinLight = sun;
  final c = ArtCanvas(n, n, background: skyTop);
  c.bands(const [skyTop, skyMid, skyLow], bottom: 0.54);
  c.circle(0.8, 0.2, 0.08, sun);
  c.ellipse(0.24, 0.15, 0.12, 0.035, cloud);
  c.circle(0.22, 0.12, 0.05, cloud);
  c.circle(0.3, 0.13, 0.035, cloud);
  c.ellipse(0.25, 0.56, 0.5, 0.13, hill);
  c.ellipse(0.85, 0.58, 0.4, 0.1, hillDark);
  c.rect(0, 0.58, 1, 1, soil);
  c.fill((x, y) => y > 0.58 && c.row(y) % 3 == 0, soilDark);
  // Fence across the back of the field.
  for (var x = 0.04; x < 1; x += 0.14) {
    c.rect(x, 0.46, x + 0.04, 0.64, fence);
    c.rect(x + 0.025, 0.46, x + 0.04, 0.64, fenceDark);
    c.polygon([(x, 0.46), (x + 0.02, 0.43), (x + 0.04, 0.46)], fence);
  }
  c.rect(0, 0.5, 1, 0.52, fence);
  c.rect(0, 0.57, 1, 0.59, fence);
  // Hay bale by the fence.
  c.rect(0.03, 0.54, 0.25, 0.7, hay);
  c.fill((x, y) => x > 0.03 && x < 0.25 && y > 0.54 && y < 0.7 && c.row(y) % 3 == 1, hayDark);
  c.rect(0.03, 0.6, 0.25, 0.62, vine);
  // Crow sitting on a post.
  c.ellipse(0.6, 0.4, 0.04, 0.03, crow);
  c.circle(0.63, 0.37, 0.02, crow);
  c.polygon(const [(0.645, 0.365), (0.68, 0.375), (0.645, 0.385)], sun);
  c.polygon(const [(0.56, 0.4), (0.52, 0.37), (0.54, 0.42)], crow);
  // Curly vines and leaves.
  c.fill((x, y) => (y - (0.7 + 0.03 * math.sin(x * 18))).abs() < 0.012, vine);
  c.fill((x, y) => (y - (0.92 + 0.025 * math.sin(x * 14 + 1))).abs() < 0.012, vine);
  for (final (x, y, a) in const [
    (0.08, 0.66, 0.4),
    (0.52, 0.66, -0.4),
    (0.94, 0.72, 0.3),
    (0.12, 0.92, -0.3),
    (0.56, 0.9, 0.5),
    (0.94, 0.94, 0.0)
  ]) {
    c.ellipse(x, y, 0.06, 0.035, leaf, angle: a);
    c.line(x - 0.04, y, x + 0.04, y, 0.01, vine);
  }
  void pump(double cx, double cy, double rx, double ry) {
    final body = ArtCanvas.inEllipse(cx, cy, rx, ry);
    c.fillShaded(body, cx, cy, rx, const [pumpkinDark, pumpkin, pumpkin, pumpkinLight]);
    for (final k in const [-0.4, 0.4]) {
      c.fill((x, y) => body(x, y) && (x - cx - k * rx * (1 - ((y - cy) / ry).abs() * 0.3)).abs() < 0.011, pumpkinDark);
    }
    c.rect(cx - 0.015, cy - ry - 0.04, cx + 0.015, cy - ry + 0.01, vine);
    c.ellipse(cx + 0.04, cy - ry - 0.01, 0.035, 0.018, leaf, angle: -0.4);
  }

  pump(0.86, 0.66, 0.08, 0.055);
  pump(0.3, 0.8, 0.19, 0.12);
  pump(0.72, 0.84, 0.13, 0.09);
  return c.toPuzzle(id: id, title: 'Pumpkin Patch', palette: const [
    0xFF81CFF0, 0xFFC3E8F0, 0xFFFFE7B3, 0xFFFFD54F, 0xFFFFFFFF, 0xFFB5D98A, 0xFF7FB65A, 0xFFD7B48A, //
    0xFFA1785A, 0xFF8D6E63, 0xFF5D4037, 0xFF33691E, 0xFF689F38, 0xFFFF9800, 0xFFD45500, 0xFFFFC266, //
    0xFF37474F, 0xFFEBCB6B, 0xFFB38B2E,
  ]);
}

Puzzle xButterflyMeadow(String id, int n) {
  const sky = 0, cloud = 1, trees = 2, meadow = 3, meadowDark = trees, grassLight = 5, poppy = 7, bell = 8;
  const wingA = 9, wingADark = 10, body = 11, wingB = 12, pink = 13, sun = 14, haze = 15, daisyC = sun;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.3, 1, 0.5, haze);
  c.circle(0.12, 0.1, 0.07, sun);
  c.ellipse(0.7, 0.14, 0.12, 0.035, cloud);
  c.circle(0.68, 0.11, 0.05, cloud);
  c.circle(0.76, 0.12, 0.035, cloud);
  c.ellipse(0.2, 0.32, 0.07, 0.025, cloud);
  // Tree line on the horizon.
  c.fill((x, y) => y > 0.44 - 0.04 * math.sin(x * 25).abs() - 0.02 * math.sin(x * 7), trees);
  c.rect(0, 0.5, 1, 1, meadow);
  c.fill((x, y) => y > 0.5 && y < 0.62 && (c.col(x) + c.row(y)) % 3 == 0, grassLight);
  c.fill((x, y) => y > 0.62 && (c.col(x) * 2 + c.row(y)) % 5 == 0, meadowDark);
  // Flowers: far ones small, near ones big.
  final rnd = math.Random(7);
  for (var i = 0; i < 26; i++) {
    final x = rnd.nextDouble(), y = 0.54 + rnd.nextDouble() * 0.44;
    final kind = i % 3;
    final s = 0.012 + (y - 0.54) * 0.06;
    if (y > 0.7) c.line(x, y, x, y + 0.06, 0.02, meadowDark);
    if (kind == 0) {
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * math.pi / 5;
        c.circle(x + math.cos(a) * s * 1.4, y + math.sin(a) * s * 1.4, s, cloud);
      }
      c.circle(x, y, s * 0.9, daisyC);
    } else if (kind == 1) {
      c.circle(x, y, s * 1.8, poppy);
      c.dot(x, y, body);
    } else {
      c.ellipse(x, y, s * 1.1, s * 1.7, bell);
    }
  }
  void butterfly(double cx, double cy, double s, int wing, int edge, int spot) {
    for (final d in const [-1.0, 1.0]) {
      c.ellipse(cx + d * 0.08 * s, cy - 0.04 * s, 0.085 * s, 0.07 * s, edge, angle: d * 0.5);
      c.ellipse(cx + d * 0.08 * s, cy - 0.04 * s, 0.065 * s, 0.05 * s, wing, angle: d * 0.5);
      c.ellipse(cx + d * 0.06 * s, cy + 0.06 * s, 0.06 * s, 0.05 * s, edge, angle: -d * 0.5);
      c.ellipse(cx + d * 0.06 * s, cy + 0.06 * s, 0.042 * s, 0.032 * s, wing, angle: -d * 0.5);
      c.circle(cx + d * 0.1 * s, cy - 0.06 * s, 0.022 * s, spot);
      c.line(cx, cy - 0.08 * s, cx + d * 0.05 * s, cy - 0.16 * s, 0.012 * s + 0.004, body);
    }
    c.ellipse(cx, cy + 0.01 * s, 0.018 * s + 0.005, 0.1 * s, body);
  }

  butterfly(0.56, 0.32, 1.8, wingA, wingADark, cloud);
  butterfly(0.2, 0.62, 1.0, wingB, body, pink);
  butterfly(0.86, 0.58, 0.8, pink, body, cloud);
  return c.toPuzzle(id: id, title: 'Butterfly Meadow', palette: const [
    0xFF8FD0F5, 0xFFFFFFFF, 0xFF2E7D32, 0xFF8BC34A, 0xFF4E8F2A, 0xFFC5E1A5, 0xFFFFB300, 0xFFE53935, //
    0xFF7E57C2, 0xFFFF9800, 0xFF6A3B1E, 0xFF3E2723, 0xFF1E88E5, 0xFFF48FB1, 0xFFFFEE58, 0xFFFFF0C2,
  ]);
}

Puzzle xMushroomCottage(String id, int n) {
  const sky = 0, cloud = 1, hill = 2, grass = 3, grassDark = 4, cap = 5, capDark = 6, capLight = 7, spot = cloud;
  const stem = 9, stemShade = 10, door = 11, doorDark = 12, glow = 13, stone = 14, flower = 15, smoke = cloud;
  final c = ArtCanvas(n, n, background: sky);
  c.ellipse(0.16, 0.12, 0.1, 0.035, cloud);
  c.circle(0.15, 0.09, 0.045, cloud);
  c.ellipse(0.86, 0.2, 0.09, 0.03, cloud);
  c.ellipse(0.2, 0.7, 0.5, 0.18, hill);
  c.ellipse(0.9, 0.68, 0.4, 0.16, hill);
  c.rect(0, 0.76, 1, 1, grass);
  c.fill((x, y) => y > 0.76 && (c.col(x) + c.row(y) * 2) % 5 == 0, grassDark);
  // Chimney with a puff of smoke.
  c.rect(0.66, 0.1, 0.74, 0.3, stone);
  c.rect(0.64, 0.08, 0.76, 0.12, doorDark);
  for (final (x, y, r) in const [(0.72, 0.04, 0.03), (0.8, 0.03, 0.025), (0.87, 0.05, 0.02)]) {
    c.circle(x, y, r, smoke);
  }
  // Stem house.
  final house = ArtCanvas.inPolygon(const [(0.32, 0.42), (0.68, 0.42), (0.74, 0.86), (0.26, 0.86)]);
  c.fill(house, stem);
  c.fill((x, y) => house(x, y) && x > 0.62, stemShade);
  c.fill((x, y) => house(x, y) && y > 0.6 && (c.row(y) % 4 == 0), stemShade);
  // Cap.
  bool capShape(double x, double y) => ArtCanvas.inEllipse(0.5, 0.42, 0.42, 0.3)(x, y) && y < 0.46;
  c.fillShaded(capShape, 0.5, 0.36, 0.42, const [capDark, cap, cap, capLight]);
  c.fill((x, y) => capShape(x, y) && y > 0.42, capDark);
  for (final (x, y, r) in const [
    (0.32, 0.26, 0.05),
    (0.52, 0.2, 0.06),
    (0.7, 0.3, 0.045),
    (0.2, 0.37, 0.035),
    (0.82, 0.39, 0.03),
    (0.44, 0.36, 0.035),
    (0.62, 0.16, 0.025)
  ]) {
    c.circle(x, y, r, spot);
  }
  // Round door and windows.
  bool doorShape(double x, double y) =>
      (x > 0.42 && x < 0.58 && y > 0.66 && y < 0.86) || ArtCanvas.inCircle(0.5, 0.66, 0.08)(x, y);
  c.fill(doorShape, door);
  c.fill((x, y) => doorShape(x, y) && (c.col(x) % 2 == 0), doorDark);
  c.dot(0.555, 0.76, glow);
  for (final (x, y) in const [(0.36, 0.56), (0.64, 0.56)]) {
    c.circle(x, y, 0.055, doorDark);
    c.circle(x, y, 0.035, glow);
    c.rect(x - 0.005, y - 0.04, x + 0.005, y + 0.04, doorDark);
  }
  // Stepping stones.
  for (final (x, y, rx) in const [(0.48, 0.9, 0.06), (0.4, 0.96, 0.07), (0.56, 0.98, 0.05)]) {
    c.ellipse(x, y, rx, 0.025, stone);
  }
  // Little mushrooms and flowers.
  for (final (x, y) in const [(0.12, 0.84), (0.2, 0.88), (0.86, 0.86)]) {
    c.rect(x - 0.012, y - 0.02, x + 0.012, y + 0.02, stem);
    c.ellipse(x, y - 0.025, 0.04, 0.025, cap);
    c.dot(x - 0.01, y - 0.03, spot);
  }
  for (final (x, y) in const [(0.06, 0.94), (0.28, 0.92), (0.76, 0.92), (0.94, 0.95), (0.68, 0.98)]) {
    c.circle(x, y, 0.022, flower);
    c.dot(x, y, glow);
  }
  return c.toPuzzle(id: id, title: 'Mushroom Cottage', palette: const [
    0xFFB2EBF2, 0xFFFFFFFF, 0xFFA5D6A7, 0xFF66BB6A, 0xFF2E7D32, 0xFFE53935, 0xFFA31515, 0xFFFF8A75, //
    0xFFFFFFFF, 0xFFFFF0CF, 0xFFE2C08F, 0xFF9A6240, 0xFF5D3A26, 0xFFFFD54F, 0xFF9EAAB4, 0xFFBA68C8,
  ]);
}

Puzzle xRoseArbor(String id, int n) {
  const sky = 0, cloud = 1, hedge = 2, hedgeLight = 3, lawn = 4, lawnStripe = hedgeLight, arch = cloud, archShade = 7;
  const rose = 8, roseLight = 9, roseDark = 10, vine = 11, bench = 12, benchDark = 13, path = 14, pathEdge = 15;
  const bird = benchDark, can = 16;
  final c = ArtCanvas(n, n, background: sky);
  c.ellipse(0.16, 0.1, 0.1, 0.035, cloud);
  c.circle(0.18, 0.07, 0.045, cloud);
  c.ellipse(0.86, 0.16, 0.1, 0.03, cloud);
  // Hedge wall.
  c.rect(0, 0.42, 1, 0.68, hedge);
  for (var x = 0.0; x <= 1.0; x += 0.1) {
    c.circle(x, 0.44, 0.06, hedge);
  }
  c.fill((x, y) => y > 0.38 && y < 0.68 && (c.col(x) * 3 + c.row(y) * 2) % 7 == 0, hedgeLight);
  // Lawn with mower stripes and a path.
  c.rect(0, 0.66, 1, 1, lawn);
  c.fill((x, y) => y > 0.66 && (c.col(x) ~/ 3).isEven, lawnStripe);
  final pathShape = ArtCanvas.inPolygon(const [(0.38, 0.66), (0.62, 0.66), (0.8, 1.01), (0.2, 1.01)]);
  c.fill(pathShape, pathEdge);
  c.fill((x, y) => pathShape(x, y) && (x - 0.5).abs() < 0.1 + (y - 0.66) * 0.45, path);
  c.fill((x, y) => pathShape(x, y) && c.row(y) % 4 == 0 && (x - 0.5).abs() < 0.1 + (y - 0.66) * 0.45, pathEdge);
  // Bench under the arch.
  c.rect(0.34, 0.5, 0.66, 0.53, bench);
  c.rect(0.34, 0.55, 0.66, 0.58, bench);
  c.rect(0.32, 0.62, 0.68, 0.66, bench);
  c.rect(0.32, 0.655, 0.68, 0.67, benchDark);
  for (final x in const [0.35, 0.63]) {
    c.rect(x, 0.5, x + 0.025, 0.74, benchDark);
  }
  // Arch posts with lattice and the curved top.
  for (final x in const [0.2, 0.74]) {
    c.rect(x, 0.3, x + 0.06, 0.86, arch);
    c.fill((px, py) => px > x && px < x + 0.06 && py > 0.3 && py < 0.86 && c.row(py) % 3 == 0, archShade);
  }
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.32) * (y - 0.32));
    return y < 0.32 && d > 0.24 && d < 0.3;
  }, arch);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.32) * (y - 0.32));
    return y < 0.32 && d > 0.24 && d < 0.255;
  }, archShade);
  // Climbing roses along the arch.
  final rnd = math.Random(3);
  final spots = <(double, double)>[];
  for (var i = 0; i <= 10; i++) {
    final a = math.pi + i * math.pi / 10;
    spots.add((0.5 + 0.27 * math.cos(a), 0.32 + 0.27 * math.sin(a)));
  }
  for (var y = 0.38; y < 0.84; y += 0.08) {
    spots.add((0.23 + rnd.nextDouble() * 0.02, y));
    spots.add((0.77 - rnd.nextDouble() * 0.02, y + 0.04));
  }
  for (final (x, y) in spots) {
    c.ellipse(x + 0.03, y + 0.02, 0.03, 0.018, vine, angle: 0.6);
  }
  for (var i = 0; i < spots.length; i++) {
    final (x, y) = spots[i];
    final r = i.isEven ? 0.032 : 0.026;
    c.circle(x, y, r, i % 3 == 0 ? roseLight : rose);
    c.dot(x, y, roseDark);
  }
  // Watering can beside the bench.
  c.rect(0.56, 0.74, 0.66, 0.82, can);
  c.ring(0.61, 0.74, 0.02, 0.035, can);
  c.line(0.56, 0.78, 0.5, 0.72, 0.02, can);
  c.rect(0.48, 0.7, 0.51, 0.73, can);
  // Robin on the arch.
  c.ellipse(0.62, 0.035, 0.035, 0.022, bird);
  c.circle(0.64, 0.02, 0.018, bird);
  c.ellipse(0.62, 0.045, 0.02, 0.014, rose);
  // Pots of roses at the path's edge.
  for (final x in const [0.1, 0.9]) {
    c.polygon([(x - 0.06, 0.84), (x + 0.06, 0.84), (x + 0.045, 0.96), (x - 0.045, 0.96)], benchDark);
    c.circle(x, 0.8, 0.06, hedge);
    c.circle(x - 0.025, 0.78, 0.022, rose);
    c.circle(x + 0.03, 0.81, 0.02, roseLight);
  }
  return c.toPuzzle(id: id, title: 'Rose Arbor', palette: const [
    0xFFBBDEFB, 0xFFFFFFFF, 0xFF2E7D32, 0xFF66BB6A, 0xFFAED581, 0xFF85B94A, 0xFFFFFFFF, 0xFFA7B4BE, //
    0xFFE91E63, 0xFFF8A5C2, 0xFF880E4F, 0xFF1B4D1F, 0xFFB07A50, 0xFF6D4C41, 0xFFF0DEB8, 0xFFC8A87A, //
    0xFF4FA3D9,
  ]);
}

Puzzle xGreenhouse(String id, int n) {
  const sky = 0, frame = 1, glass = 2, roofGlass = 3, plant = 4, plantDark = 5, pot = 6, potDark = 7, red = 8;
  const yellow = 9, shelf = 10, grass = 11, soil = 12, stone = 13, sprout = plant, cloud = frame, pink = 16;
  final c = ArtCanvas(n, n, background: sky);
  c.ellipse(0.14, 0.1, 0.1, 0.035, cloud);
  c.circle(0.12, 0.07, 0.04, cloud);
  c.ellipse(0.84, 0.08, 0.09, 0.03, cloud);
  c.rect(0, 0.78, 1, 1, grass);
  // Glass house.
  c.polygon(const [(0.1, 0.4), (0.5, 0.14), (0.9, 0.4)], roofGlass);
  c.rect(0.12, 0.4, 0.88, 0.8, glass);
  c.fill(
      (x, y) =>
          ((x > 0.12 && x < 0.88 && y > 0.4 && y < 0.8) ||
              ArtCanvas.inPolygon(const [(0.1, 0.4), (0.5, 0.14), (0.9, 0.4)])(x, y)) &&
          ((x - y) * 40).floor() % 9 == 0,
      frame);
  // Inside: shelf with pots, tall plant and hanging basket.
  c.rect(0.14, 0.6, 0.86, 0.63, shelf);
  c.rect(0.16, 0.63, 0.19, 0.74, shelf);
  c.rect(0.81, 0.63, 0.84, 0.74, shelf);
  for (final (x, kind) in const [(0.22, 0), (0.33, 1), (0.67, 2), (0.78, 0)]) {
    c.polygon([(x - 0.045, 0.53), (x + 0.045, 0.53), (x + 0.035, 0.6), (x - 0.035, 0.6)], pot);
    c.rect(x - 0.05, 0.52, x + 0.05, 0.545, potDark);
    if (kind == 0) {
      c.circle(x, 0.46, 0.055, plant);
      c.circle(x - 0.02, 0.44, 0.02, red);
      c.circle(x + 0.025, 0.47, 0.018, red);
    } else if (kind == 1) {
      c.ellipse(x - 0.03, 0.45, 0.018, 0.06, plantDark, angle: -0.3);
      c.ellipse(x + 0.03, 0.45, 0.018, 0.06, plantDark, angle: 0.3);
      c.ellipse(x, 0.43, 0.018, 0.08, plant);
    } else {
      c.circle(x, 0.47, 0.05, plantDark);
      c.circle(x - 0.02, 0.45, 0.018, yellow);
      c.circle(x + 0.02, 0.48, 0.018, pink);
      c.circle(x + 0.01, 0.43, 0.015, yellow);
    }
  }
  // Frame drawn over everything inside.
  for (var x = 0.12; x < 0.9; x += 0.152) {
    c.rect(x, 0.4, x + 0.022, 0.8, frame);
  }
  c.rect(0.12, 0.395, 0.88, 0.42, frame);
  c.rect(0.12, 0.6, 0.44, 0.615, frame);
  c.rect(0.56, 0.6, 0.88, 0.615, frame);
  c.line(0.1, 0.4, 0.5, 0.14, 0.03, frame);
  c.line(0.9, 0.4, 0.5, 0.14, 0.03, frame);
  for (final x in const [0.3, 0.5, 0.7]) {
    c.line(x, 0.4, 0.5, 0.15, 0.015, frame);
  }
  c.circle(0.5, 0.13, 0.025, frame);
  // Door.
  c.rect(0.43, 0.5, 0.57, 0.8, frame);
  c.rect(0.455, 0.53, 0.545, 0.78, glass);
  c.rect(0.455, 0.64, 0.545, 0.655, frame);
  c.dot(0.53, 0.67, yellow);
  // Stone base.
  c.rect(0.1, 0.76, 0.9, 0.82, stone);
  c.fill((x, y) => x > 0.1 && x < 0.9 && y > 0.76 && y < 0.82 && (c.col(x) + (c.row(y) % 2) * 2) % 4 == 0, frame);
  c.rect(0.43, 0.76, 0.57, 0.82, frame);
  // Garden beds in front.
  for (final (l, r) in const [(0.04, 0.38), (0.62, 0.96)]) {
    c.rect(l, 0.88, r, 0.98, shelf);
    c.rect(l + 0.02, 0.88, r - 0.02, 0.93, soil);
    for (var x = l + 0.05; x < r - 0.02; x += 0.075) {
      c.line(x, 0.88, x - 0.02, 0.84, 0.018, sprout);
      c.line(x, 0.88, x + 0.02, 0.84, 0.018, sprout);
    }
  }
  c.rect(0.44, 0.82, 0.56, 1, stone);
  return c.toPuzzle(id: id, title: 'Greenhouse', palette: const [
    0xFF7EC3F2, 0xFFFFFFFF, 0xFFB7E4DA, 0xFF5DB8AA, 0xFF43A047, 0xFF1B5E20, 0xFFD8743C, 0xFF9C4A22, //
    0xFFEF5350, 0xFFFFD54F, 0xFFC49A6C, 0xFF9CCC65, 0xFF5D4037, 0xFFA0AAB4, 0xFF689F38, 0xFFFFFFFF, //
    0xFFF48FB1,
  ]);
}
