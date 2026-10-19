import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// Extreme blocky fan art for personal play: full scenes laid out on a 40×40
// grid, so sprites below are placed in 40ths of the canvas.

/// Fills [test] with one of [tones] per cell, picked by texture noise.
void _xTex(ArtCanvas c, ShapeTest test, List<int> tones, [int seed = 0]) {
  for (var i = 0; i < tones.length; i++) {
    c.fill((x, y) => test(x, y) && (c.noise(x, y, seed) * tones.length).floor() == i, tones[i]);
  }
}

/// Pixel art whose top left corner sits on cell ([col], [row]) of a 40 grid.
/// [scale] stretches each character over more than one cell.
void _xSprite(ArtCanvas c, List<String> rows, Map<String, int> legend, double col, double row, [double scale = 1]) {
  c.pixelArt(rows, legend,
      l: col / 40, t: row / 40, r: (col + rows.first.length * scale) / 40, b: (row + rows.length * scale) / 40);
}

/// Cell rectangle on a 40 grid, inclusive of both ends.
void _xBox(ArtCanvas c, int l, int t, int r, int b, int color) =>
    c.rect(l / 40, t / 40, (r + 0.99) / 40, (b + 0.99) / 40, color);

// ---- Extreme --------------------------------------------------------------

Puzzle xMcBeeMeadow(String id, int n) {
  const sky = 0, skyLow = 1, cloud = 2, sun = 3, grassA = 4, grassB = 5, dirt = 6, logC = 7, logDark = 8;
  const leavesA = 9, leavesB = 10, nest = 11, bee = 12, stripe = 13, poppy = 14, cornflower = 15;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.36, 1, 1, skyLow);
  _xBox(c, 31, 3, 35, 7, sun);
  _xBox(c, 18, 4, 27, 5, cloud);
  _xBox(c, 20, 3, 24, 3, cloud);
  _xBox(c, 30, 12, 37, 13, cloud);
  // Rolling meadow, a step or two of grass blocks, dirt underneath.
  double ground(double x) =>
      0.66 + const [0.0, 0.0, 0.025, 0.025, 0.0, -0.025, -0.025, 0.0][(x * 8).floor().clamp(0, 7)];
  _xTex(c, (x, y) => y > ground(x), const [grassA, grassB], 3);
  _xTex(c, (x, y) => y > 0.9, const [dirt, logDark], 4);
  // Oak tree with a bee nest.
  _xBox(c, 5, 10, 7, 26, logC);
  c.fill((x, y) => c.col(x) == 7 && c.row(y) >= 10 && c.row(y) <= 26 && c.row(y).isEven, logDark);
  _xTex(c, (x, y) => x < 0.34 && y > 0.04 && y < 0.3, const [leavesA, leavesB], 6);
  _xTex(c, (x, y) => x > 0.04 && x < 0.26 && y > 0.0 && y < 0.06, const [leavesA, leavesB], 6);
  _xSprite(
      c,
      const [
        'NNNNN',
        'NkNkN',
        'NNNNN',
        'NkNNk',
        'ddddd',
      ],
      const {
        'N': nest,
        'k': stripe,
        'd': logDark,
      },
      8,
      12);
  // Flowers across the meadow.
  for (final (col, row, petal) in const [
    (2, 30, poppy),
    (12, 33, cornflower),
    (16, 29, poppy),
    (24, 32, poppy),
    (29, 28, cornflower),
    (35, 31, poppy),
    (6, 34, cornflower),
    (38, 27, cornflower),
  ]) {
    _xSprite(
        c,
        const [
          '.p.',
          'pcp',
          '.p.',
          '.s.',
          '.s.',
        ],
        {
          'p': petal,
          'c': sun,
          's': leavesA,
        },
        col - 1.0,
        row - 2.0);
  }
  // The big bee, facing left.
  _xSprite(
      c,
      const [
        '.....ww.ww...',
        '....wwwwwww..',
        '.....ww.ww...',
        '.YYYYKKYYKKY.',
        'YkYYYKKYYKKYY',
        'YYYYYKKYYKKYS',
        'YYYYYKKYYKKYY',
        '.YYYYKKYYKKY.',
        '..k...k...k..',
      ],
      const {
        'w': cloud,
        'Y': bee,
        'K': stripe,
        'k': stripe,
        'S': stripe,
      },
      16,
      13);
  // Two small bees further away.
  for (final (col, row) in const [(31.0, 19.0), (12.0, 22.0)]) {
    _xSprite(
        c,
        const [
          '.ww.',
          'YKYK',
          'YKYK',
        ],
        const {
          'w': cloud,
          'Y': bee,
          'K': stripe,
        },
        col,
        row);
  }
  return c.toPuzzle(id: id, title: 'Buzzing Meadow', palette: const [
    0xFF7EC0EE, 0xFFB4DCF7, 0xFFFFFFFF, 0xFFFFF27A, 0xFF79C043, 0xFF9BD45A, 0xFF8B5A2B, 0xFF7A5230, //
    0xFF4A3216, 0xFF2C6E28, 0xFF4A9A3A, 0xFFC98B2E, 0xFFF7C82A, 0xFF1E1E1E, 0xFFE53935, 0xFF3F6FE0,
  ]);
}

Puzzle xMcGhast(String id, int n) {
  const sky = 0, haze = 1, rackA = 2, rackB = 3, glowA = 4, glowB = 5, brick = 6, lavaA = 7, lavaB = 8;
  const lavaC = 9, ghast = 10, ghastShade = 11, face = 12, tear = 13, warped = 14, stem = 15;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.42, 1, 1, haze);
  // Fortress bridge in the distance, with lava-lit windows.
  _xBox(c, 22, 22, 39, 24, brick);
  for (final col in const [25, 33]) {
    _xBox(c, col, 25, col + 2, 33, brick);
  }
  for (final col in const [24, 28, 32, 36]) {
    _xBox(c, col, 23, col, 23, lavaA);
  }
  // Netherrack ceiling with hanging glowstone.
  final ceil = [3, 4, 2, 3, 5, 4, 3, 2, 3, 4];
  _xTex(c, (x, y) => c.row(y) < ceil[(x * 10).floor().clamp(0, 9)], const [rackA, rackB], 11);
  _xTex(
      c,
      (x, y) =>
          c.col(x) >= 29 && c.col(x) <= 34 && c.row(y) >= 3 && c.row(y) <= 6 && !(c.row(y) == 6 && c.col(x).isEven),
      const [glowA, glowB],
      12);
  // Left cliff topped with warped nylium and a warped fungus.
  final cliff = [16, 16, 18, 18, 22, 22, 26, 30, 34];
  bool cliffAt(double x, double y) {
    final i = c.col(x) ~/ 1;
    return i < cliff.length && c.row(y) >= cliff[i];
  }

  _xTex(c, cliffAt, const [rackA, rackB], 13);
  c.fill((x, y) => cliffAt(x, y) && !cliffAt(x, y - 1 / 40), warped);
  _xBox(c, 2, 10, 2, 15, stem);
  _xBox(c, 0, 8, 4, 9, warped);
  _xBox(c, 1, 7, 3, 7, warped);
  // Lava sea.
  _xTex(c, (x, y) => c.row(y) >= 34 && !cliffAt(x, y), const [lavaA, lavaB], 14);
  c.fill((x, y) => c.row(y) >= 34 && !cliffAt(x, y) && c.noise(x, y, 15) < 0.1, lavaC);
  // The ghast: a big crying cube with tentacles.
  for (var col = 15; col <= 27; col += 2) {
    final len = 4 + (col * 7) % 5;
    _xBox(c, col, 21, col, 20 + len, col % 4 == 1 ? ghast : ghastShade);
  }
  _xBox(c, 14, 8, 28, 21, ghast);
  _xBox(c, 27, 8, 28, 21, ghastShade);
  _xBox(c, 14, 20, 28, 21, ghastShade);
  _xBox(c, 17, 12, 19, 12, face);
  _xBox(c, 23, 12, 25, 12, face);
  _xBox(c, 18, 13, 18, 16, tear);
  _xBox(c, 24, 13, 24, 15, tear);
  _xBox(c, 20, 16, 22, 18, face);
  // A fireball on its way.
  c.circle(0.24, 0.58, 0.05, lavaA);
  c.circle(0.235, 0.575, 0.032, lavaB);
  _xBox(c, 9, 22, 9, 22, lavaC);
  for (final (col, row) in const [(13, 21), (14, 20), (12, 19)]) {
    _xBox(c, col, row, col, row, ghastShade);
  }
  return c.toPuzzle(id: id, title: 'Crying Ghast', palette: const [
    0xFF2A0A0E, 0xFF4E1414, 0xFF9A3434, 0xFF6E2626, 0xFFFFE08A, 0xFFC8903A, 0xFF22101A, 0xFFE8561A, //
    0xFFFFA53D, 0xFFFFF0A0, 0xFFF4F4F4, 0xFFC4C4C4, 0xFF3A3A3A, 0xFF8E8E8E, 0xFF1FA393, 0xFF4A2A6E,
  ]);
}

Puzzle xMcLushCave(String id, int n) {
  const stoneA = 0, stoneB = 1, deep = 2, air = 3, mossA = 4, mossB = 5, vine = 6, berry = 7, water = 8;
  const waterDeep = 9, waterLight = 10, axo = 11, axoDark = 12, gill = 13, eye = 14, azalea = 15, drip = 16;
  final c = ArtCanvas(n, n);
  _xTex(c, (x, y) => true, const [stoneA, stoneB, deep], 21);
  bool hollow(double x, double y) =>
      ArtCanvas.inEllipse(0.5, 0.5, 0.5, 0.4)(x, y) || (y > 0.5 && y < 0.82 && x > 0.04 && x < 0.96);
  const d = 1 / 40;
  c.fill((x, y) => !hollow(x, y) && (hollow(x, y + d) || hollow(x - d, y) || hollow(x + d, y)), mossA);
  c.fill(hollow, air);
  // Dripstone hanging from the ceiling.
  for (final (col, len) in const [(9, 3), (14, 5), (27, 4), (33, 2)]) {
    final top = (0.5 - 0.4 * _xEllipseTop(col)) * 40;
    for (var i = 0; i < len; i++) {
      _xBox(c, col, top.floor() + i, col, top.floor() + i, drip);
    }
  }
  // Glow berry vines.
  for (final (col, len) in const [(5, 12), (11, 9), (18, 14), (23, 8), (30, 11), (36, 7)]) {
    final top = (0.5 - 0.4 * _xEllipseTop(col)) * 40;
    for (var i = 0; i < len; i++) {
      final row = top.floor() + i;
      _xBox(c, col, row, col, row, i % 3 == 2 ? berry : vine);
    }
  }
  // Mossy floor and a pool.
  bool floor(double x, double y) => c.row(y) >= 31 - (c.col(x) < 10 ? 2 : 0);
  _xTex(c, floor, const [mossA, mossB], 22);
  bool pool(double x, double y) => c.col(x) >= 13 && c.col(x) <= 35 && c.row(y) >= 31 && c.row(y) <= 37;
  c.fill(pool, water);
  c.fill((x, y) => pool(x, y) && c.row(y) >= 35, waterDeep);
  c.fill((x, y) => pool(x, y) && c.row(y) == 31 && c.col(x) % 3 != 0, waterLight);
  _xTex(c, (x, y) => c.row(y) >= 38, const [stoneA, deep], 23);
  // Axolotl swimming in the pool.
  _xSprite(
      c,
      const [
        'g.g.........',
        '.gPPPP......',
        'gPkPPPPPPpp.',
        '.PPPPPPPPPpp',
        '..pp..pp....',
      ],
      const {
        'g': gill,
        'P': axo,
        'p': axoDark,
        'k': eye,
      },
      19,
      32);
  // Big dripleaf on the left.
  _xBox(c, 6, 21, 6, 29, vine);
  _xBox(c, 3, 20, 10, 21, mossB);
  _xBox(c, 4, 20, 9, 20, mossA);
  // Flowering azalea on the right.
  _xTex(c, (x, y) => ArtCanvas.inEllipse(0.9, 0.7, 0.1, 0.08)(x, y), const [mossA, vine], 24);
  c.fill((x, y) => ArtCanvas.inEllipse(0.9, 0.7, 0.1, 0.08)(x, y) && c.noise(x, y, 25) < 0.3, azalea);
  return c.toPuzzle(id: id, title: 'Lush Cave', palette: const [
    0xFF7A7A7A, 0xFF959595, 0xFF4E4E58, 0xFF262B33, 0xFF4F8A2A, 0xFF7DB843, 0xFF2D5E2A, 0xFFFFB02E, //
    0xFF3F76E4, 0xFF2A4FA8, 0xFF8EB4F5, 0xFFF4A6C8, 0xFFD9779F, 0xFFC2337A, 0xFF1A1A1A, 0xFFD86ED0, 0xFF9A7B5E,
  ]);
}

/// Half height (0..1) of the cave ellipse at column [col] of a 40 grid.
double _xEllipseTop(int col) {
  final dx = ((col + 0.5) / 40 - 0.5) / 0.5;
  final v = 1 - dx * dx;
  return v <= 0 ? 0 : math.sqrt(v);
}

Puzzle xMcVillage(String id, int n) {
  const skyTop = 0, skyMid = 1, skyLow = 2, sun = 3, cobA = 4, cobB = 5, plank = 6, plankDark = 7, roof = 8;
  const glass = 9, grassA = 10, grassB = 11, soil = 12, wheat = 13, water = 14, skin = 15, robe = 16;
  final c = ArtCanvas(n, n, background: skyTop);
  c.bands(const [skyTop, skyMid, skyLow], top: 0.0, bottom: 0.66);
  c.fill((x, y) => c.row(y) == 8 && c.col(x).isEven, skyMid);
  c.fill((x, y) => c.row(y) == 17 && c.col(x).isOdd, skyLow);
  _xBox(c, 30, 18, 36, 24, sun);
  // Grass field.
  _xTex(c, (x, y) => c.row(y) >= 25, const [grassA, grassB], 31);
  // House: cobblestone base, plank walls, log corners, stepped roof.
  _xTex(c, (x, y) => c.col(x) >= 4 && c.col(x) <= 23 && c.row(y) >= 29 && c.row(y) <= 31, const [cobA, cobB], 32);
  _xBox(c, 5, 17, 22, 28, plank);
  c.fill((x, y) => c.col(x) >= 5 && c.col(x) <= 22 && c.row(y) >= 17 && c.row(y) <= 28 && c.row(y) % 3 == 0, plankDark);
  _xBox(c, 5, 17, 6, 28, plankDark);
  _xBox(c, 21, 17, 22, 28, plankDark);
  for (var i = 0; i < 9; i++) {
    _xBox(c, 3 + i, 16 - i, 24 - i, 16 - i, roof);
  }
  _xBox(c, 9, 10, 18, 11, plank);
  _xBox(c, 13, 11, 14, 12, glass);
  // Window and door.
  _xBox(c, 8, 20, 12, 24, plankDark);
  _xBox(c, 9, 21, 11, 23, glass);
  _xBox(c, 10, 21, 10, 23, plankDark);
  _xBox(c, 15, 21, 18, 28, roof);
  _xBox(c, 17, 25, 17, 25, sun);
  // Farm with wheat rows and a water channel.
  _xTex(c, (x, y) => c.col(x) >= 22 && c.row(y) >= 33 && c.row(y) <= 38, const [soil, cobB], 33);
  _xBox(c, 22, 33, 39, 33, soil);
  for (var col = 22; col <= 39; col++) {
    if (col == 30) {
      _xBox(c, col, 31, col, 38, water);
      continue;
    }
    final top = 29 + (col * 5) % 3;
    _xBox(c, col, top, col, 34, col.isEven ? wheat : grassB);
    _xBox(c, col, top, col, top, grassA);
  }
  _xBox(c, 0, 33, 20, 38, soil);
  _xTex(c, (x, y) => c.row(y) >= 34 && c.row(y) <= 37 && c.col(x) <= 20, const [grassA, grassB], 34);
  // Villager with arms crossed.
  _xSprite(
      c,
      const [
        '.SSSS.',
        '.RRRR.',
        '.gSSg.',
        '.SSNS.',
        '...N..',
        'RRRRRR',
        'RSSSSR',
        'RRRRRR',
        '.RRRR.',
        '.RRRR.',
        '.RRRR.',
      ],
      const {
        'S': skin,
        'N': skin,
        'R': robe,
        'g': grassA,
      },
      25,
      21);
  return c.toPuzzle(id: id, title: 'Village Sunset', palette: const [
    0xFF5B4A9E, 0xFFE8708A, 0xFFFFA65A, 0xFFFFE07A, 0xFF8A8A8A, 0xFF6A6A6A, 0xFFC49A5A, 0xFF8F6A36, //
    0xFF3E2A1A, 0xFFBFE6F5, 0xFF5DA130, 0xFF7FC043, 0xFF5C3A1C, 0xFFE8C34A, 0xFF3F76E4, 0xFFD8A27E, 0xFF6B4226,
  ]);
}

Puzzle xMcTheEnd(String id, int n) {
  const voidC = 0, star = 1, endA = 2, endB = 3, endC = 4, obsA = 5, obsB = 6, crystal = 7, cage = 8;
  const dragon = 9, wing = 10, eye = 11, chorus = 12, chorusFlower = 13, bedrock = 14, haze = 15;
  final c = ArtCanvas(n, n, background: voidC);
  c.fill((x, y) => y > 0.5 && c.noise(x, y, 41) < 0.3, haze);
  c.fill((x, y) => c.noise(x, y, 42) < 0.025, star);
  // Floating island of end stone.
  bool island(double x, double y) =>
      (y > 0.74 && y < 0.82) || (y >= 0.82 && ArtCanvas.inEllipse(0.5, 0.82, 0.5, 0.18)(x, y));
  _xTex(c, island, const [endA, endB, endA, endC], 43);
  // Obsidian pillars with end crystals.
  for (final (l, r, top) in const [(2, 6, 12), (33, 37, 9), (14, 16, 22)]) {
    _xTex(c, (x, y) => c.col(x) >= l && c.col(x) <= r && c.row(y) >= top && c.row(y) <= 30, const [obsA, obsB], 44);
    final mid = (l + r) / 2;
    _xSprite(
        c,
        const [
          'CCC',
          'CpC',
          'CCC',
        ],
        const {
          'C': cage,
          'p': crystal,
        },
        mid - 1,
        top - 3.0);
  }
  // Exit portal frame with the egg.
  _xBox(c, 20, 28, 28, 29, bedrock);
  _xBox(c, 22, 28, 26, 28, voidC);
  _xBox(c, 24, 25, 24, 27, bedrock);
  _xBox(c, 23, 24, 25, 24, dragon);
  _xBox(c, 24, 23, 24, 23, dragon);
  // Chorus plants.
  for (final (col, h) in const [(9, 5), (31, 4)]) {
    _xBox(c, col, 29 - h, col, 29, chorus);
    _xBox(c, col - 1, 29 - h + 2, col + 1, 29 - h + 2, chorus);
    _xBox(c, col - 1, 28 - h + 2, col - 1, 28 - h + 2, chorusFlower);
    _xBox(c, col + 1, 28 - h + 2, col + 1, 28 - h + 2, chorusFlower);
    _xBox(c, col, 28 - h, col, 28 - h, chorusFlower);
  }
  // The dragon, gliding left with its wing raised.
  _xSprite(
      c,
      const [
        '................WW........',
        '..............WWWw........',
        '............WWWWwW........',
        '..........WWWWWwWW........',
        '........WWWWWWwWW.........',
        '.D.....WWWWWWwWWW.........',
        'DDDD..WWWWWWwWWW..........',
        'DeDDDDDDDDDDDDDDDDDD......',
        'DDDD.DDDDDDDDDDDDDDDDDD...',
        'DD.....DDDDDDDDDD....DDDD.',
        'DDD......D....D.......DDDD',
        '.........D....D...........',
      ],
      const {
        'W': wing,
        'w': dragon,
        'D': dragon,
        'e': eye,
      },
      7,
      4);
  return c.toPuzzle(id: id, title: 'The End', palette: const [
    0xFF1A1230, 0xFFEDE6FF, 0xFFDCDCA0, 0xFFC2C284, 0xFFA3A066, 0xFF07050C, 0xFF4A3570, 0xFFFF7AD0, //
    0xFFB9A6F0, 0xFF4C4C5A, 0xFF9C9CB0, 0xFFCC55FF, 0xFF7A4A92, 0xFFE2C6F0, 0xFF555555, 0xFF2C2048,
  ]);
}
