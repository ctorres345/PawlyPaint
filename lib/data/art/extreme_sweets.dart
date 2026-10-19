import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// ---- Extreme --------------------------------------------------------------

Puzzle xCupcakeParty(String id, int n) {
  const wall = 0, wallDot = 1, flagA = 2, flagB = 3, string = 4, table = 5, tableDark = 6, wrap = 7, wrapDark = 8;
  const frost = 9, frostDark = 10, white = 11, cherry = 12, yellow = 13, cake = 14, flame = 15;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => (c.col(x) % 4 == 1 && c.row(y) % 4 == 1) || (c.col(x) % 4 == 3 && c.row(y) % 4 == 3), wallDot);
  // Bunting.
  c.fill((x, y) => (y - (0.06 + 0.04 * math.sin(x * math.pi))).abs() < 0.012, string);
  for (var i = 0; i < 7; i++) {
    final x = 0.07 + i * 0.143, y = 0.06 + 0.04 * math.sin(x * math.pi);
    c.polygon([(x - 0.05, y), (x + 0.05, y), (x, y + 0.1)], i.isEven ? flagA : flagB);
  }
  // Table.
  c.rect(0, 0.8, 1, 1, table);
  c.rect(0, 0.8, 1, 0.83, tableDark);
  c.fill((x, y) => y > 0.86 && (c.col(x) + c.row(y)) % 6 == 0, tableDark);
  // Wrapper.
  final wrapper = ArtCanvas.inPolygon(const [(0.26, 0.56), (0.74, 0.56), (0.66, 0.86), (0.34, 0.86)]);
  c.fill(wrapper, wrap);
  c.fill((x, y) => wrapper(x, y) && ((x - 0.5) / (1.6 - y) * 30).floor().isOdd, wrapDark);
  c.ellipse(0.5, 0.56, 0.25, 0.04, cake);
  // Frosting swirl in three tiers.
  for (final (cy, rx, ry) in const [(0.5, 0.27, 0.08), (0.4, 0.21, 0.07), (0.31, 0.14, 0.06)]) {
    final tier = ArtCanvas.inEllipse(0.5, cy, rx, ry);
    c.fillShaded(tier, 0.5, cy, rx, const [frostDark, frost, frost, white]);
  }
  c.polygon(const [(0.42, 0.28), (0.58, 0.28), (0.5, 0.2)], frost);
  // Sprinkles.
  for (final (x, y, col) in const [
    (0.34, 0.48, yellow),
    (0.46, 0.52, flagA),
    (0.62, 0.48, yellow),
    (0.7, 0.52, flagA),
    (0.4, 0.4, flagA),
    (0.58, 0.38, yellow),
    (0.5, 0.33, flagA),
    (0.28, 0.52, yellow),
  ]) {
    c.dot(x, y, col);
  }
  // Cherry with stem.
  c.line(0.53, 0.18, 0.6, 0.08, 0.02, string);
  c.circle(0.5, 0.18, 0.055, cherry);
  c.dot(0.48, 0.16, white);
  // Mini cupcake with a candle.
  final mini = ArtCanvas.inPolygon(const [(0.06, 0.72), (0.2, 0.72), (0.18, 0.86), (0.08, 0.86)]);
  c.fill(mini, flagB);
  c.fill((x, y) => mini(x, y) && c.col(x).isOdd, flagA);
  c.ellipse(0.13, 0.7, 0.085, 0.045, white);
  c.rect(0.12, 0.56, 0.145, 0.67, flagB);
  c.ellipse(0.132, 0.53, 0.018, 0.03, flame);
  // Party hat on the right.
  c.polygon(const [(0.78, 0.86), (0.96, 0.86), (0.87, 0.6)], yellow);
  c.fill(
      (x, y) => ArtCanvas.inPolygon(const [(0.78, 0.86), (0.96, 0.86), (0.87, 0.6)])(x, y) && c.row(y) % 4 == 0, flagB);
  c.circle(0.87, 0.59, 0.03, cherry);
  return c.toPuzzle(id: id, title: 'Cupcake Party', palette: const [
    0xFFFFF0D6, 0xFFFFD08A, 0xFF4FC3F7, 0xFFBA68C8, 0xFF8D6E63, 0xFFB39DDB, 0xFF7E62B8, 0xFF4DB6AC, //
    0xFF00796B, 0xFFF8BBD0, 0xFFE57399, 0xFFFFFFFF, 0xFFE53935, 0xFFFFEB3B, 0xFFC68642, 0xFFFF9800,
  ]);
}

Puzzle xStrawberryTart(String id, int n) {
  const wall = 0, wallStripe = 1, cloth = 2, check = 3, plate = 4, plateShade = 5, crust = 6, crustDark = 7;
  const custard = 8, berry = 9, berryLight = 10, blue = 11, leaf = 12, fork = 14, white = cloth, seed = white;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => c.col(x) % 4 == 0, wallStripe);
  // Checked tablecloth.
  c.rect(0, 0.5, 1, 1, cloth);
  c.fill((x, y) => y >= 0.5 && ((c.col(x) ~/ 3).isEven || (c.row(y) ~/ 3).isEven), check);
  c.fill((x, y) => y >= 0.5 && (c.col(x) ~/ 3).isEven && (c.row(y) ~/ 3).isEven, crust);
  // Plate.
  c.ellipse(0.5, 0.74, 0.46, 0.17, plateShade);
  c.ellipse(0.5, 0.72, 0.45, 0.16, plate);
  // Tart side with fluted edge.
  final side = ArtCanvas.inEllipse(0.5, 0.64, 0.36, 0.14);
  c.fill(side, crustDark);
  c.fill((x, y) => side(x, y) && y > 0.56 && (c.col(x) % 2 == 0), crust);
  c.fill(ArtCanvas.inEllipse(0.5, 0.54, 0.36, 0.14), crust);
  c.fill(ArtCanvas.inEllipse(0.5, 0.54, 0.31, 0.11), custard);
  // Strawberry halves in a ring, blueberries in the middle.
  for (var i = 0; i < 8; i++) {
    final a = i * 2 * math.pi / 8 + 0.2;
    final x = 0.5 + 0.23 * math.cos(a), y = 0.535 + 0.08 * math.sin(a);
    c.heart(x, y, 0.05, berry);
    c.heart(x, y + 0.005, 0.025, berryLight);
  }
  for (final (x, y) in const [(0.44, 0.53), (0.54, 0.51), (0.5, 0.56), (0.58, 0.55), (0.46, 0.49)]) {
    c.circle(x, y, 0.025, blue);
  }
  c.ellipse(0.5, 0.47, 0.035, 0.018, leaf, angle: 0.5);
  c.ellipse(0.55, 0.47, 0.035, 0.018, leaf, angle: -0.5);
  // Fork and a whole strawberry on the cloth.
  c.line(0.86, 0.62, 0.95, 0.96, 0.025, fork);
  for (final dx in const [-0.02, 0.0, 0.02]) {
    c.line(0.86 + dx, 0.62, 0.84 + dx, 0.54, 0.012, fork);
  }
  c.fill(ArtCanvas.inPolygon(const [(0.06, 0.86), (0.2, 0.86), (0.13, 0.98)]), berry);
  c.circle(0.13, 0.86, 0.07, berry);
  for (final (x, y) in const [(0.1, 0.86), (0.15, 0.9), (0.12, 0.93), (0.17, 0.85)]) {
    c.dot(x, y, seed);
  }
  c.polygon(const [(0.06, 0.8), (0.13, 0.84), (0.2, 0.8), (0.13, 0.77)], leaf);
  // Window light on the wall.
  c.rect(0.08, 0.08, 0.3, 0.36, white);
  c.rect(0.1, 0.1, 0.28, 0.34, plate);
  c.rect(0.185, 0.1, 0.195, 0.34, white);
  c.rect(0.1, 0.215, 0.28, 0.225, white);
  c.circle(0.78, 0.22, 0.09, leaf);
  c.polygon(const [(0.72, 0.28), (0.84, 0.28), (0.82, 0.42), (0.74, 0.42)], crustDark);
  c.circle(0.75, 0.18, 0.025, berry);
  c.circle(0.82, 0.22, 0.025, berry);
  return c.toPuzzle(id: id, title: 'Strawberry Tart', palette: const [
    0xFFE6F4E1, 0xFFB5D8A6, 0xFFFFFFFF, 0xFFD7C4EC, 0xFFB9DDF9, 0xFF7FB3E0, 0xFFE8A84E, 0xFFAE6A28, //
    0xFFFFEB99, 0xFFD32F2F, 0xFFFF9E9E, 0xFF303F9F, 0xFF43A047, 0xFFFFE135, 0xFF9E9E9E,
  ]);
}

Puzzle xHotCocoa(String id, int n) {
  const wall = 0, frame = 1, frameDark = 2, night = 3, star = 4, snow = 5, hill = 6, table = 7, tableDark = 8;
  const mug = 9, mugDark = 10, cocoa = 11, marsh = 12, steam = 13, cookie = 14, plate = 15, tree = 16;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => (c.col(x) + c.row(y)) % 8 == 0, marsh);
  // Window with a snowy night.
  c.rect(0.08, 0.04, 0.92, 0.6, frame);
  c.rect(0.12, 0.08, 0.88, 0.56, night);
  bool inWin(double x, double y) => x > 0.12 && x < 0.88 && y > 0.08 && y < 0.56;
  c.fill((x, y) => inWin(x, y) && ArtCanvas.inEllipse(0.3, 0.6, 0.4, 0.14)(x, y), hill);
  c.fill((x, y) => inWin(x, y) && ArtCanvas.inEllipse(0.8, 0.62, 0.36, 0.16)(x, y), snow);
  for (final (x, y) in const [(0.22, 0.4), (0.7, 0.36)]) {
    c.polygon([(x - 0.06, y + 0.1), (x + 0.06, y + 0.1), (x, y - 0.06)], tree);
    c.polygon([(x - 0.05, y + 0.02), (x + 0.05, y + 0.02), (x, y - 0.1)], tree);
  }
  c.circle(0.78, 0.16, 0.05, star);
  c.circle(0.8, 0.15, 0.045, night);
  for (var i = 0; i < 26; i++) {
    final x = 0.14 + (i * 0.37 % 0.72), y = 0.1 + (i * 0.23 % 0.42);
    c.dot(x, y, i % 4 == 0 ? star : snow);
  }
  c.rect(0.48, 0.08, 0.52, 0.56, frame);
  c.rect(0.12, 0.3, 0.88, 0.33, frame);
  c.rect(0.06, 0.58, 0.94, 0.63, frameDark);
  // Table.
  c.rect(0, 0.72, 1, 1, table);
  c.fill((x, y) => y > 0.72 && c.row(y) % 4 == 0, tableDark);
  // Plate of cookies.
  c.ellipse(0.2, 0.88, 0.17, 0.05, plate);
  for (final (x, y) in const [(0.12, 0.84), (0.27, 0.84), (0.2, 0.78)]) {
    c.ellipse(x, y, 0.075, 0.045, cookie);
    c.dot(x - 0.025, y, cocoa);
    c.dot(x + 0.02, y - 0.015, cocoa);
    c.dot(x + 0.01, y + 0.02, cocoa);
  }
  // Mug.
  final body = ArtCanvas.inPolygon(const [(0.4, 0.52), (0.8, 0.52), (0.78, 0.94), (0.42, 0.94)]);
  c.ring(0.81, 0.72, 0.05, 0.1, mugDark);
  c.fillShaded(body, 0.6, 0.72, 0.3, const [mugDark, mug, mug]);
  c.heart(0.58, 0.75, 0.07, snow);
  c.ellipse(0.6, 0.52, 0.2, 0.04, cocoa);
  // Whipped cream with marshmallows.
  c.ellipse(0.58, 0.49, 0.15, 0.05, snow);
  c.ellipse(0.58, 0.44, 0.1, 0.04, snow);
  c.ellipse(0.58, 0.4, 0.05, 0.03, snow);
  for (final (x, y) in const [(0.46, 0.5), (0.7, 0.5), (0.53, 0.45)]) {
    c.rect(x - 0.022, y - 0.022, x + 0.022, y + 0.022, marsh);
  }
  // Candy cane hooked on the rim.
  c.line(0.74, 0.5, 0.74, 0.34, 0.03, mug);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.78) * (x - 0.78) + (y - 0.34) * (y - 0.34));
    return d > 0.025 && d < 0.055 && y < 0.34;
  }, mug);
  c.fill((x, y) => ArtCanvas.inLine(0.74, 0.5, 0.74, 0.34, 0.03)(x, y) && c.row(y) % 2 == 0, snow);
  // Steam swirls.
  for (final x in const [0.5, 0.62]) {
    c.fill((px, py) => py > 0.14 && py < 0.34 && (px - x - 0.025 * math.sin(py * 28)).abs() < 0.014, steam);
  }
  return c.toPuzzle(id: id, title: 'Hot Cocoa', palette: const [
    0xFFFFE3C2, 0xFF7FA88A, 0xFF4F7A62, 0xFF283593, 0xFFFFE066, 0xFFFFFFFF, 0xFF9FB6E0, 0xFFC98550, //
    0xFF8A5228, 0xFFE53935, 0xFF9E1C1C, 0xFF5D3A24, 0xFFF8BBD0, 0xFFE0D8E8, 0xFFEAB46A, 0xFF80CBC4, //
    0xFF0F4D2A,
  ]);
}

Puzzle xCandyHouse(String id, int n) {
  const sky = 0, skyDot = 1, snow = 2, snowShade = 3, ginger = 4, gingerDark = 5, choco = 6, red = 7, green = 8;
  const yellow = 9, window = yellow, pink = 11, blue = 12, stick = snow, purple = 14, mint = 15;
  final c = ArtCanvas(n, n, background: sky);
  c.fill((x, y) => (c.col(x) * 3 + c.row(y) * 2) % 9 == 0, skyDot);
  // Snowy ground.
  c.ellipse(0.5, 0.98, 0.8, 0.2, snowShade);
  c.ellipse(0.5, 1.0, 0.78, 0.18, snow);
  c.rect(0, 0.86, 1, 1, snow);
  // House walls.
  c.rect(0.22, 0.48, 0.78, 0.88, ginger);
  c.rect(0.7, 0.48, 0.78, 0.88, gingerDark);
  c.fill((x, y) => x > 0.22 && x < 0.7 && y > 0.48 && y < 0.88 && (c.row(y) % 5 == 0), gingerDark);
  // Roof: chocolate bars with dripping icing.
  final roof = ArtCanvas.inPolygon(const [(0.12, 0.52), (0.5, 0.16), (0.88, 0.52)]);
  c.fill(roof, choco);
  c.fill((x, y) => roof(x, y) && ((c.col(x) + c.row(y)) % 4 == 0), gingerDark);
  c.line(0.12, 0.52, 0.5, 0.16, 0.05, snow);
  c.line(0.88, 0.52, 0.5, 0.16, 0.05, snow);
  for (final x in const [0.18, 0.28, 0.72, 0.82]) {
    final y = 0.52 - (0.5 - (x - 0.5).abs()) * 0.0 - ((0.38 - (x - 0.5).abs()) * 0.95);
    c.circle(x, y + 0.05, 0.02, snow);
  }
  c.rect(0.12, 0.5, 0.88, 0.54, snow);
  for (var x = 0.14; x < 0.88; x += 0.08) {
    c.circle(x, 0.555, 0.02, snow);
  }
  // Gumdrops on the roof.
  for (final (x, y, col) in const [
    (0.5, 0.26, red),
    (0.4, 0.36, green),
    (0.6, 0.36, yellow),
    (0.3, 0.45, purple),
    (0.5, 0.42, mint),
    (0.7, 0.45, red)
  ]) {
    c.ellipse(x, y, 0.035, 0.025, col);
  }
  // Chimney.
  c.rect(0.66, 0.18, 0.74, 0.32, red);
  c.rect(0.64, 0.16, 0.76, 0.2, snow);
  // Door and windows.
  c.fill((x, y) => (x > 0.43 && x < 0.57 && y > 0.7 && y < 0.88) || ArtCanvas.inCircle(0.5, 0.7, 0.07)(x, y), pink);
  c.rect(0.495, 0.66, 0.505, 0.88, mint);
  c.dot(0.54, 0.78, yellow);
  for (final x in const [0.32, 0.68]) {
    c.rect(x - 0.06, 0.6, x + 0.06, 0.72, snow);
    c.rect(x - 0.045, 0.615, x + 0.045, 0.705, window);
    c.rect(x - 0.005, 0.615, x + 0.005, 0.705, snow);
  }
  // Candy buttons along the wall base.
  for (var x = 0.26; x < 0.78; x += 0.06) {
    if ((x - 0.5).abs() < 0.08) continue;
    c.circle(x, 0.84, 0.018, ((x * 100).round() ~/ 6).isEven ? green : red);
  }
  // Candy canes and lollipop trees.
  for (final x in const [0.06, 0.94]) {
    c.rect(x - 0.012, 0.6, x + 0.012, 0.9, stick);
    c.fill((px, py) {
      final dx = px - x, dy = py - 0.5;
      final r = math.sqrt(dx * dx + dy * dy);
      return r < 0.09 && ((math.atan2(dy, dx) * 2 + r * 50).floor() % 3 == 0);
    }, blue);
    c.fill((px, py) {
      final dx = px - x, dy = py - 0.5;
      final r = math.sqrt(dx * dx + dy * dy);
      return r < 0.09 && ((math.atan2(dy, dx) * 2 + r * 50).floor() % 3 != 0);
    }, pink);
  }
  for (final x in const [0.16, 0.84]) {
    c.line(x, 0.9, x, 0.72, 0.03, snow);
    c.fill((px, py) => ArtCanvas.inLine(x, 0.9, x, 0.72, 0.03)(px, py) && c.row(py) % 2 == 0, red);
    c.fill((px, py) {
      final d = math.sqrt((px - x - 0.03) * (px - x - 0.03) + (py - 0.72) * (py - 0.72));
      return d > 0.018 && d < 0.045 && py < 0.72;
    }, red);
  }
  return c.toPuzzle(id: id, title: 'Candy House', palette: const [
    0xFFF0D9F2, 0xFFD7AEE3, 0xFFFFFFFF, 0xFFC9D3E0, 0xFFD08A48, 0xFF8D5524, 0xFF4E2C1C, 0xFFE53935, //
    0xFF4CAF50, 0xFFFFD54F, 0xFFFFA94D, 0xFFF48FB1, 0xFF4FC3F7, 0xFFFFFFFF, 0xFF8E5CC4, 0xFF6EDBC0,
  ]);
}

Puzzle xBakery(String id, int n) {
  const sky = 0, cloud = 1, wall = 2, brick = 3, awning = 4, awningDark = 5, glass = 6, frame = 7, door = 8;
  const bread = 9, breadDark = 10, cake = 11, walk = 12, walkDark = 13, plant = 14, pot = 15, lamp = 16, white = cloud;
  final c = ArtCanvas(n, n, background: sky);
  c.ellipse(0.82, 0.06, 0.1, 0.03, cloud);
  c.circle(0.8, 0.04, 0.04, cloud);
  // Building.
  c.rect(0.02, 0.08, 0.98, 0.86, wall);
  c.fill((x, y) => x > 0.02 && x < 0.98 && y > 0.08 && y < 0.86 && c.row(y) % 3 == 0 && (c.col(x) + c.row(y)) % 4 < 2,
      brick);
  c.rect(0.02, 0.06, 0.98, 0.1, frame);
  // Sign board with a croissant.
  c.rect(0.26, 0.12, 0.74, 0.26, frame);
  c.rect(0.28, 0.14, 0.72, 0.24, white);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.24) * (y - 0.24) * 2.2);
    return d > 0.05 && d < 0.1 && y < 0.225;
  }, bread);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.24) * (y - 0.24) * 2.2);
    return d > 0.05 && d < 0.1 && y < 0.225 && c.col(x) % 2 == 0;
  }, breadDark);
  // Striped scalloped awning.
  c.rect(0.04, 0.3, 0.96, 0.38, awning);
  c.fill((x, y) => x > 0.04 && x < 0.96 && y > 0.29 && y < 0.38 && (c.col(x) ~/ 3).isOdd, white);
  for (var x = 0.08; x < 0.96; x += 0.075) {
    c.circle(x, 0.385, 0.035, ((x - 0.08) / 0.075).round().isEven ? awning : white);
  }
  c.rect(0.04, 0.28, 0.96, 0.3, awningDark);
  // Display window.
  c.rect(0.06, 0.46, 0.6, 0.78, frame);
  c.rect(0.08, 0.48, 0.58, 0.76, glass);
  c.rect(0.08, 0.66, 0.58, 0.68, frame);
  // Cake on a stand.
  c.rect(0.14, 0.6, 0.28, 0.66, cake);
  c.rect(0.14, 0.6, 0.28, 0.615, white);
  c.rect(0.18, 0.55, 0.24, 0.6, cake);
  c.dot(0.21, 0.53, awning);
  // Bread loaves.
  for (final (x, y) in const [(0.4, 0.62), (0.5, 0.63)]) {
    c.ellipse(x, y, 0.06, 0.035, bread);
    c.line(x - 0.03, y - 0.01, x - 0.01, y + 0.01, 0.012, breadDark);
    c.line(x + 0.0, y - 0.015, x + 0.02, y + 0.01, 0.012, breadDark);
  }
  // Lower shelf: cupcakes and cookies.
  for (final x in const [0.14, 0.26, 0.38, 0.5]) {
    c.rect(x - 0.03, 0.72, x + 0.03, 0.76, x < 0.3 ? awning : breadDark);
    c.circle(x, 0.71, 0.032, x < 0.3 ? white : cake);
  }
  // Door with a round window and a little bell.
  c.rect(0.66, 0.44, 0.92, 0.86, frame);
  c.rect(0.69, 0.47, 0.89, 0.86, door);
  c.circle(0.79, 0.56, 0.06, glass);
  c.rect(0.72, 0.68, 0.86, 0.8, frame);
  c.rect(0.74, 0.7, 0.84, 0.78, door);
  c.dot(0.71, 0.66, lamp);
  // Lantern by the door.
  c.rect(0.63, 0.44, 0.64, 0.5, frame);
  c.rect(0.615, 0.5, 0.655, 0.56, lamp);
  // Sidewalk.
  c.rect(0, 0.86, 1, 1, walk);
  c.fill((x, y) => y > 0.86 && (c.col(x) % 6 == 0 || c.row(y) == c.row(0.93)), walkDark);
  // Flower pots and a sandwich board.
  for (final x in const [0.06, 0.6]) {
    c.polygon([(x - 0.04, 0.8), (x + 0.04, 0.8), (x + 0.03, 0.9), (x - 0.03, 0.9)], pot);
    c.circle(x, 0.77, 0.045, plant);
    c.dot(x - 0.015, 0.75, awning);
    c.dot(x + 0.02, 0.78, lamp);
  }
  c.polygon(const [(0.88, 0.98), (0.92, 0.82), (0.96, 0.98)], frame);
  c.rect(0.9, 0.86, 0.94, 0.92, white);
  return c.toPuzzle(id: id, title: 'Corner Bakery', palette: const [
    0xFFA9DDF5, 0xFFFFFFFF, 0xFFFFE6C7, 0xFFE9B99A, 0xFFEC5F8C, 0xFFAD1F55, 0xFF4DD0E1, 0xFF5D4037, //
    0xFF7E9C8A, 0xFFE3A452, 0xFFAD6B2A, 0xFFF8C5DA, 0xFFC4C4C4, 0xFF8F8F8F, 0xFF43A047, 0xFFD8743C, //
    0xFFFFD54F,
  ]);
}
