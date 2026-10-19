import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// Blocky fan art for personal play: everything here is drawn on purpose at
// the canvas resolution so it keeps the pixel look.

/// Fills [test] with one of [tones] per cell, picked by texture noise.
void _textured(ArtCanvas c, ShapeTest test, List<int> tones, [int seed = 0]) {
  for (var i = 0; i < tones.length; i++) {
    c.fill((x, y) => test(x, y) && (c.noise(x, y, seed) * tones.length).floor() == i, tones[i]);
  }
}

// ---- Easy -----------------------------------------------------------------

Puzzle grassBlock(String id, int n) {
  const sky = 0, grassA = 1, grassB = 2, dirtA = 3, dirtB = 4, dirtC = 5, stone = 6;
  final c = ArtCanvas(n, n, background: sky);
  bool block(double x, double y) => x > 0.12 && x < 0.88 && y > 0.12 && y < 0.88;
  _textured(c, block, const [dirtA, dirtB, dirtC], 1);
  c.fill((x, y) => block(x, y) && c.noise(x, y, 7) < 0.08, stone);
  _textured(c, (x, y) => block(x, y) && y < 0.34 + (c.noise(x, 0.5, 3) < 0.4 ? 0.07 : 0), const [grassA, grassB], 2);
  return c.toPuzzle(id: id, title: 'Grass Block', palette: const [
    0xFF9AD0F5, 0xFF5DA130, 0xFF79C043, 0xFF8B5A2B, 0xFF6F4421, 0xFFA0703F, 0xFF8A8A8A, //
  ]);
}

Puzzle creeper(String id, int n) {
  const greenA = 0, greenB = 1, greenC = 2, greenD = 3, face = 4, faceDark = 5;
  final c = ArtCanvas(n, n);
  _textured(c, (x, y) => true, const [greenA, greenB, greenC, greenD], 4);
  c.pixelArt(const [
    '........',
    '........',
    '.XX..XX.',
    '.Xx..xX.',
    '...xx...',
    '..XXXX..',
    '..XxxX..',
    '..X..X..',
  ], const {
    'X': face,
    'x': faceDark,
  });
  return c.toPuzzle(id: id, title: 'Sssurprise', palette: const [
    0xFF5BB247, 0xFF79D25E, 0xFF3F8F31, 0xFFA5E28F, 0xFF101010, 0xFF2D3A2A, //
  ]);
}

Puzzle diamond(String id, int n) {
  const bg = 0, bgDot = 1, outline = 2, white = 3, light = 4, cyan = 5, dark = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y)) % 4 == 0, bgDot);
  c.pixelArt(const [
    '................',
    '................',
    '....kkkkkkkk....',
    '...kwwlllllck...',
    '..kwllllllccdk..',
    '.kllllllcccccdk.',
    '.kkkkkkkkkkkkkk.',
    '..kcccccccdddk..',
    '...kccccccddk...',
    '....kcccccdk....',
    '.....kcccdk.....',
    '......kcdk......',
    '.......kk.......',
    '................',
    '................',
    '................',
  ], const {
    'k': outline,
    'w': white,
    'l': light,
    'c': cyan,
    'd': dark,
  }, t: 0.06, b: 1.06);
  return c.toPuzzle(id: id, title: 'Shiny Diamond', palette: const [
    0xFF2E2E3A, 0xFF3A3A48, 0xFF0E4D4A, 0xFFFFFFFF, 0xFFA8F5EC, 0xFF4AD6D0, 0xFF1C9A93, //
  ]);
}

Puzzle mcApple(String id, int n) {
  const bg = 0, bgDot = 1, red = 2, redDark = 3, redLight = 4, stem = 5, leafC = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 3 + c.row(y)) % 7 == 0, bgDot);
  c.pixelArt(const [
    '................',
    '.......s........',
    '.......sgg......',
    '......s.gg......',
    '...RRRRsRRRR....',
    '..RrrrRRRrrRR...',
    '.RrLLrrrrrrrRR..',
    '.RrLrrrrrrrrRR..',
    '.RrrrrrrrrrrRR..',
    '.RrrrrrrrrrrRR..',
    '.RRrrrrrrrrRRR..',
    '..RRrrrrrrRRR...',
    '...RRRRRRRRR....',
    '....RRR.RRR.....',
    '................',
    '................',
  ], const {
    'R': redDark,
    'r': red,
    'L': redLight,
    's': stem,
    'g': leafC,
  }, l: 0.06, r: 1.06);
  return c.toPuzzle(id: id, title: 'Crunchy Apple', palette: const [
    0xFF3B3B3B, 0xFF4E4E4E, 0xFFE0302A, 0xFF9E1B17, 0xFFFF8A80, 0xFF5D3A1A, 0xFF3FA43A, //
  ]);
}

Puzzle torch(String id, int n) {
  const stoneA = 0, stoneB = 1, stoneC = 2, glow = 3, stick = 4, stickDark = 5, flameY = 6, flameO = 7, flameW = 8;
  final c = ArtCanvas(n, n);
  _textured(c, (x, y) => true, const [stoneA, stoneB, stoneC], 5);
  c.fill((x, y) => math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.3) * (y - 0.3)) < 0.3 && c.noise(x, y, 9) < 0.5, glow);
  c.rect(0.44, 0.34, 0.56, 0.94, stick);
  c.rect(0.5, 0.34, 0.56, 0.94, stickDark);
  c.rect(0.4, 0.22, 0.6, 0.36, flameO);
  c.rect(0.44, 0.16, 0.56, 0.32, flameY);
  c.rect(0.47, 0.22, 0.53, 0.28, flameW);
  return c.toPuzzle(id: id, title: 'Torch', palette: const [
    0xFF6E6E6E, 0xFF808080, 0xFF5A5A5A, 0xFF9C8C6A, 0xFF8B5A2B, 0xFF5D3A1A, 0xFFFFD84A, 0xFFFF8F1F, 0xFFFFFBE0, //
  ]);
}

// ---- Medium ---------------------------------------------------------------

Puzzle pickaxe(String id, int n) {
  const bg = 0, bgDot = 1, outline = 2, head = 3, headLight = 4, handle = 5, handleDark = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 6 == 0, bgDot);
  c.line(0.26, 0.82, 0.68, 0.36, 0.13, handleDark);
  c.line(0.26, 0.82, 0.68, 0.36, 0.07, handle);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.32) * (x - 0.32) + (y - 0.72) * (y - 0.72));
    return d > 0.5 && d < 0.66 && x > 0.3 && y < 0.62;
  }, outline);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.32) * (x - 0.32) + (y - 0.72) * (y - 0.72));
    return d > 0.53 && d < 0.63 && x > 0.33 && y < 0.6;
  }, head);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.32) * (x - 0.32) + (y - 0.72) * (y - 0.72));
    return d > 0.59 && d < 0.63 && x > 0.4 && y < 0.5;
  }, headLight);
  return c.toPuzzle(id: id, title: 'Diamond Pickaxe', palette: const [
    0xFFE8E4DA, 0xFFD6D0C2, 0xFF0E4D4A, 0xFF4AD6D0, 0xFFA8F5EC, 0xFFA0703F, 0xFF5D3A1A, //
  ]);
}

Puzzle mcSword(String id, int n) {
  const bg = 0, bgDot = 1, outline = 2, blade = 3, bladeLight = 4, guard = 5, grip = 6, gripDark = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 2 + c.row(y)) % 6 == 0, bgDot);
  c.line(0.38, 0.62, 0.86, 0.14, 0.17, outline);
  c.line(0.38, 0.62, 0.86, 0.14, 0.11, blade);
  c.line(0.42, 0.58, 0.84, 0.16, 0.04, bladeLight);
  c.line(0.22, 0.54, 0.46, 0.78, 0.1, guard);
  c.line(0.14, 0.86, 0.34, 0.66, 0.1, gripDark);
  c.line(0.14, 0.86, 0.34, 0.66, 0.05, grip);
  c.rect(0.08, 0.84, 0.18, 0.94, outline);
  return c.toPuzzle(id: id, title: 'Diamond Sword', palette: const [
    0xFFEDE7F6, 0xFFDDD3EE, 0xFF0E4D4A, 0xFF4AD6D0, 0xFFA8F5EC, 0xFF1C9A93, 0xFFA0703F, 0xFF5D3A1A, //
  ]);
}

Puzzle tnt(String id, int n) {
  const bg = 0, red = 1, redDark = 2, white = 3, ink = 4, shade = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.pixelArt(const [
    'rRrRrRrRrRrR',
    'rRrRrRrRrRrR',
    'rRrRrRrRrRrR',
    'wwwwwwwwwwww',
    'TTTwTwwTwTTT',
    'wTwwTTwTwwTw',
    'wTwwTwTTwwTw',
    'wTwwTwwTwwTw',
    'wwwwwwwwwwww',
    'rRrRrRrRrRrR',
    'rRrRrRrRrRrR',
    'ssssssssssss',
  ], const {
    'r': red,
    'R': redDark,
    'w': white,
    'T': ink,
    's': shade,
  }, l: 0.1, t: 0.1, r: 0.9, b: 0.9);
  return c.toPuzzle(id: id, title: 'Handle With Care', palette: const [
    0xFF9AD0F5, 0xFFDB3B2B, 0xFFA82418, 0xFFF2F2F2, 0xFF1A1A1A, 0xFF7A1A10, //
  ]);
}

Puzzle pig(String id, int n) {
  const pinkA = 0, pinkB = 1, pinkC = 2, eyeW = 3, eyeB = 4, snout = 5, nostril = 6;
  final c = ArtCanvas(n, n);
  _textured(c, (x, y) => true, const [pinkA, pinkB, pinkC], 11);
  c.pixelArt(const [
    '........',
    '........',
    '........',
    'wb....bw',
    '..SSSS..',
    '..nSSn..',
    '..SSSS..',
    '........',
  ], const {
    'w': eyeW,
    'b': eyeB,
    'S': snout,
    'n': nostril,
  });
  return c.toPuzzle(id: id, title: 'Oink', palette: const [
    0xFFF2A7A7, 0xFFEB9696, 0xFFF7BDBD, 0xFFFFFFFF, 0xFF2B1B1B, 0xFFE07B86, 0xFF8A3A46, //
  ]);
}

Puzzle mcCake(String id, int n) {
  const bg = 0, bgDot = 1, frost = 2, frostShade = 3, berry = 4, sponge = 5, spongeDark = 6, jam = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) ~/ 2 + c.row(y) ~/ 2).isEven, bgDot);
  c.rect(0.12, 0.5, 0.88, 0.86, sponge);
  c.rect(0.12, 0.66, 0.88, 0.72, jam);
  c.rect(0.66, 0.5, 0.88, 0.86, spongeDark);
  c.rect(0.66, 0.66, 0.88, 0.72, berry);
  c.rect(0.12, 0.3, 0.88, 0.5, frost);
  c.fill((x, y) => x > 0.12 && x < 0.88 && y >= 0.5 && y < 0.58 && c.noise(x, 0.5, 2) < 0.5, frost);
  c.rect(0.66, 0.3, 0.88, 0.5, frostShade);
  for (final (x, y) in const [(0.24, 0.36), (0.44, 0.42), (0.56, 0.34), (0.32, 0.46), (0.76, 0.38)]) {
    c.dot(x, y, berry);
  }
  return c.toPuzzle(id: id, title: 'Block Cake', palette: const [
    0xFF9AD0F5, 0xFF8CC4EB, 0xFFF7F7F7, 0xFFD9D9D9, 0xFFD62828, 0xFFE3B577, 0xFFB98A4C, 0xFFE8604C, //
  ]);
}

// ---- Hard -----------------------------------------------------------------

Puzzle overworld(String id, int n) {
  const sky = 0, skyLow = 1, sun = 2, cloud = 3, grassA = 4, grassB = 5, dirtA = 6, dirtB = 7;
  const log = 8, leavesA = 9, leavesB = 10, water = 11, waterLight = 12;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.3, 1, 1, skyLow);
  c.rect(0.72, 0.08, 0.84, 0.2, sun);
  c.rect(0.08, 0.12, 0.34, 0.18, cloud);
  c.rect(0.14, 0.09, 0.26, 0.12, cloud);
  double ground(double x) {
    final step = (x * 8).floor();
    return 0.58 + const [0.0, -0.06, -0.06, -0.12, -0.06, 0.03, 0.06, 0.06][step.clamp(0, 7)];
  }

  const waterLine = 0.64;
  _textured(c, (x, y) => y > ground(x) + 0.08, const [dirtA, dirtB], 3);
  _textured(c, (x, y) => y > ground(x) && y <= ground(x) + 0.08, const [grassA, grassB], 4);
  c.fill((x, y) => x > 0.62 && y > waterLine && y <= ground(x) + 0.12, water);
  c.fill((x, y) => x > 0.62 && y > waterLine && y < waterLine + 0.03 && c.col(x).isEven, waterLight);
  c.rect(0.3, 0.3, 0.36, ground(0.33), log);
  _textured(c, (x, y) => x > 0.2 && x < 0.46 && y > 0.16 && y < 0.34, const [leavesA, leavesB], 6);
  _textured(c, (x, y) => x > 0.25 && x < 0.41 && y > 0.1 && y < 0.18, const [leavesA, leavesB], 6);
  return c.toPuzzle(id: id, title: 'Overworld', palette: const [
    0xFF7EC0EE, 0xFFA9D6F5, 0xFFFFF27A, 0xFFFFFFFF, 0xFF5DA130, 0xFF79C043, 0xFF8B5A2B, 0xFF6F4421, //
    0xFF4A3216, 0xFF2F7A2A, 0xFF3F9A35, 0xFF3F76E4, 0xFF7FA6F0,
  ]);
}

Puzzle enderman(String id, int n) {
  const night = 0, star = 1, ground = 2, groundDark = 3, body = 4, bodyLight = 5, eyeOuter = 6, eyeInner = 7;
  const particle = 8;
  final c = ArtCanvas(n, n, background: night);
  c.fill((x, y) => y < 0.7 && c.noise(x, y, 12) < 0.03, star);
  _textured(c, (x, y) => y > 0.86, const [ground, groundDark], 13);
  c.rect(0.4, 0.14, 0.6, 0.34, body);
  c.rect(0.43, 0.34, 0.57, 0.6, body);
  c.rect(0.36, 0.34, 0.4, 0.74, body);
  c.rect(0.6, 0.34, 0.64, 0.74, body);
  c.rect(0.44, 0.6, 0.48, 0.88, body);
  c.rect(0.52, 0.6, 0.56, 0.88, body);
  c.rect(0.4, 0.14, 0.43, 0.34, bodyLight);
  c.rect(0.41, 0.25, 0.48, 0.28, eyeOuter);
  c.rect(0.52, 0.25, 0.59, 0.28, eyeOuter);
  c.rect(0.44, 0.25, 0.47, 0.28, eyeInner);
  c.rect(0.53, 0.25, 0.56, 0.28, eyeInner);
  for (final (x, y) in const [(0.28, 0.3), (0.72, 0.22), (0.3, 0.6), (0.7, 0.52), (0.24, 0.44), (0.76, 0.7)]) {
    c.dot(x, y, particle);
  }
  return c.toPuzzle(id: id, title: "Don't Look", palette: const [
    0xFF14112A, 0xFFE6E0FF, 0xFF3A2F4A, 0xFF4A3D5E, 0xFF101010, 0xFF303030, 0xFFE07BFF, 0xFFB72EE6, 0xFF9B4DCA, //
  ]);
}

Puzzle netherPortal(String id, int n) {
  const rackA = 0, rackB = 1, rackC = 2, obsA = 3, obsB = 4, portalA = 5, portalB = 6, portalC = 7, lava = 8;
  final c = ArtCanvas(n, n);
  _textured(c, (x, y) => true, const [rackA, rackB, rackC], 21);
  c.fill((x, y) => y > 0.9 && c.noise(x, y, 22) < 0.6, lava);
  bool frame(double x, double y) => x > 0.22 && x < 0.78 && y > 0.1 && y < 0.92;
  bool inner(double x, double y) => x > 0.32 && x < 0.68 && y > 0.2 && y < 0.82;
  _textured(c, (x, y) => frame(x, y) && !inner(x, y), const [obsA, obsB], 23);
  c.fill((x, y) => inner(x, y), portalA);
  c.fill((x, y) => inner(x, y) && math.sin((x * 3 + y * 7) * 6 + c.noise(x, y, 24) * 2) > 0.3, portalB);
  c.fill((x, y) => inner(x, y) && c.noise(x, y, 25) < 0.08, portalC);
  return c.toPuzzle(id: id, title: 'Nether Portal', palette: const [
    0xFF7A2626, 0xFF6A1F1F, 0xFF8E3434, 0xFF140F1F, 0xFF2B1F3D, 0xFF6B1FB8, 0xFF9C46E8, 0xFFE2B8FF, 0xFFFF8C1A, //
  ]);
}

Puzzle sheep(String id, int n) {
  const sky = 0, sun = 1, grassA = 2, grassB = 3, woolA = 4, woolB = 5, face = 6, faceDark = 7, eye = 8;
  const flower = 9, cloud = woolA;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0.74, 0.08, 0.86, 0.2, sun);
  c.rect(0.1, 0.14, 0.32, 0.2, cloud);
  _textured(c, (x, y) => y > 0.66, const [grassA, grassB], 31);
  for (final (x, y) in const [(0.1, 0.78), (0.86, 0.84), (0.66, 0.94), (0.2, 0.92)]) {
    c.dot(x, y, flower);
  }
  for (final x in const [0.3, 0.42, 0.6, 0.72]) {
    c.rect(x - 0.03, 0.66, x + 0.03, 0.82, faceDark);
  }
  _textured(c, (x, y) => x > 0.24 && x < 0.78 && y > 0.4 && y < 0.68, const [woolA, woolB], 32);
  c.rect(0.12, 0.34, 0.3, 0.56, woolA);
  c.rect(0.14, 0.4, 0.28, 0.56, face);
  c.rect(0.15, 0.44, 0.19, 0.48, eye);
  c.rect(0.23, 0.44, 0.27, 0.48, eye);
  c.rect(0.18, 0.5, 0.24, 0.54, faceDark);
  return c.toPuzzle(id: id, title: 'Woolly', palette: const [
    0xFF7EC0EE, 0xFFFFF27A, 0xFF5DA130, 0xFF79C043, 0xFFF2F2F2, 0xFFD9D9D9, 0xFFD8B79A, 0xFF8C6E58, //
    0xFF1A1A1A, 0xFFE84A5F,
  ]);
}

Puzzle cave(String id, int n) {
  const stoneA = 0, stoneB = 1, stoneC = 2, diamondC = 3, gold = 4, coal = 5, lavaA = 6, lavaB = 7;
  const torchStick = 8, torchFlame = 9, iron = 10;
  final c = ArtCanvas(n, n);
  _textured(c, (x, y) => true, const [stoneA, stoneB, stoneC], 41);
  void ore(double x, double y, int col, int seed) {
    c.fill((px, py) => (px - x).abs() < 0.07 && (py - y).abs() < 0.07 && c.noise(px, py, seed) < 0.45, col);
  }

  ore(0.24, 0.3, diamondC, 42);
  ore(0.72, 0.24, gold, 43);
  ore(0.56, 0.52, coal, 44);
  ore(0.18, 0.62, iron, 45);
  ore(0.84, 0.6, coal, 46);
  _textured(c, (x, y) => y > 0.82 && x > 0.3 && x < 0.9, const [lavaA, lavaB], 47);
  c.rect(0.46, 0.18, 0.5, 0.32, torchStick);
  c.rect(0.45, 0.14, 0.51, 0.19, torchFlame);
  return c.toPuzzle(id: id, title: 'Lucky Mine', palette: const [
    0xFF7A7A7A, 0xFF8C8C8C, 0xFF656565, 0xFF4AD6D0, 0xFFF5D547, 0xFF1F1F1F, 0xFFFF7A1A, 0xFFFFB33D, //
    0xFF8B5A2B, 0xFFFFE680, 0xFFD8AF93,
  ]);
}
