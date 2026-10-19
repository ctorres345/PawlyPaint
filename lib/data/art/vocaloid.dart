import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// Chibi fan art for personal play, inspired by the Vocaloid singers.

/// Colors for one chibi head, as palette indices.
class _Look {
  const _Look({
    required this.hair,
    required this.hairDark,
    required this.skin,
    required this.eye,
    required this.white,
    required this.blush,
    required this.mouth,
  });

  final int hair, hairDark, skin, eye, white, blush, mouth;
}

/// A big-headed chibi face centred on ([cx], [cy]); [s] scales it (1 fills
/// most of a canvas).
void _head(ArtCanvas c, double cx, double cy, double s, _Look k) {
  c.ellipse(cx, cy, 0.34 * s, 0.34 * s, k.hair);
  c.fill((x, y) => ArtCanvas.inEllipse(cx, cy, 0.34 * s, 0.34 * s)(x, y) && y > cy + 0.16 * s, k.hairDark);
  c.ellipse(cx, cy + 0.07 * s, 0.26 * s, 0.24 * s, k.skin);
  c.fill((x, y) => ArtCanvas.inEllipse(cx, cy - 0.06 * s, 0.32 * s, 0.24 * s)(x, y) && y < cy, k.hair);
  for (final dx in const [-0.17, -0.06, 0.06, 0.17]) {
    c.polygon([
      (cx + (dx - 0.07) * s, cy - 0.02 * s),
      (cx + (dx + 0.07) * s, cy - 0.02 * s),
      (cx + dx * s, cy + 0.08 * s),
    ], k.hair);
  }
  for (final side in const [-1.0, 1.0]) {
    c.ellipse(cx + side * 0.25 * s, cy + 0.12 * s, 0.06 * s, 0.16 * s, k.hair);
    c.ellipse(cx + side * 0.1 * s, cy + 0.1 * s, 0.045 * s, 0.065 * s, k.eye);
    c.dot(cx + side * 0.1 * s - 0.015 * s, cy + 0.075 * s, k.white);
    c.circle(cx + side * 0.17 * s, cy + 0.17 * s, 0.035 * s, k.blush);
  }
  c.dot(cx, cy + 0.2 * s, k.mouth);
}

/// Long twin tails with hair ties, drawn before the head.
void _twinTails(ArtCanvas c, double cx, double cy, double s, int hair, int hairDark, int tie) {
  for (final side in const [-1.0, 1.0]) {
    final tail = ArtCanvas.inEllipse(cx + side * 0.42 * s, cy + 0.48 * s, 0.12 * s, 0.52 * s, angle: side * -0.12);
    c.fill(tail, hair);
    c.fill((x, y) => tail(x, y) && (x - (cx + side * 0.42 * s)) * side > 0.03 * s, hairDark);
    c.rect(cx + side * 0.36 * s - 0.04 * s, cy - 0.16 * s, cx + side * 0.36 * s + 0.04 * s, cy - 0.06 * s, tie);
  }
}

/// Headset ear pieces.
void _headset(ArtCanvas c, double cx, double cy, double s, int color) {
  for (final side in const [-1.0, 1.0]) {
    c.ellipse(cx + side * 0.3 * s, cy + 0.08 * s, 0.05 * s, 0.08 * s, color);
  }
}

/// A chibi body under a head of scale [s], from the neck down to [bottom].
void _body(ArtCanvas c, double cx, double neckY, double s, double bottom,
    {required int shirt, required int skirt, required int tie, required int skin, required int legs}) {
  c.polygon([
    (cx - 0.18 * s, neckY),
    (cx + 0.18 * s, neckY),
    (cx + 0.24 * s, neckY + 0.32 * s),
    (cx - 0.24 * s, neckY + 0.32 * s),
  ], shirt);
  for (final side in const [-1.0, 1.0]) {
    c.line(cx + side * 0.2 * s, neckY + 0.04 * s, cx + side * 0.32 * s, neckY + 0.3 * s, 0.09 * s, shirt);
    c.circle(cx + side * 0.33 * s, neckY + 0.33 * s, 0.05 * s, skin);
  }
  c.polygon([
    (cx - 0.04 * s, neckY),
    (cx + 0.04 * s, neckY),
    (cx + 0.02 * s, neckY + 0.2 * s),
    (cx, neckY + 0.24 * s),
    (cx - 0.02 * s, neckY + 0.2 * s),
  ], tie);
  c.polygon([
    (cx - 0.24 * s, neckY + 0.32 * s),
    (cx + 0.24 * s, neckY + 0.32 * s),
    (cx + 0.32 * s, neckY + 0.5 * s),
    (cx - 0.32 * s, neckY + 0.5 * s),
  ], skirt);
  c.rect(cx - 0.14 * s, neckY + 0.5 * s, cx - 0.04 * s, bottom, legs);
  c.rect(cx + 0.04 * s, neckY + 0.5 * s, cx + 0.14 * s, bottom, legs);
}

// ---- Easy -----------------------------------------------------------------

Puzzle leek(String id, int n) {
  const bg = 0, bgDot = 1, stalk = 2, stalkShade = 3, light = 4, green = 5, dark = 6, root = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 5 == 0, bgDot);
  c.line(0.2, 0.86, 0.56, 0.46, 0.17, stalk);
  c.line(0.24, 0.9, 0.58, 0.52, 0.06, stalkShade);
  c.line(0.5, 0.52, 0.66, 0.36, 0.17, light);
  c.line(0.6, 0.42, 0.9, 0.08, 0.1, green);
  c.line(0.6, 0.42, 0.94, 0.3, 0.1, dark);
  c.line(0.58, 0.44, 0.72, 0.06, 0.09, green);
  for (final (x2, y2) in const [(0.04, 0.96), (0.1, 0.99), (0.02, 0.86)]) {
    c.line(0.14, 0.9, x2, y2, 0.04, root);
  }
  return c.toPuzzle(id: id, title: 'Leek Swing', palette: const [
    0xFFE0F7F5, 0xFFB2EBE6, 0xFFFFFFFF, 0xFFDDE8D0, 0xFFB5E08A, 0xFF5DBB4A, 0xFF2E8B3A, 0xFFC9B79C, //
  ]);
}

Puzzle musicNote(String id, int n) {
  const bg = 0, bgDot = 1, note = 2, noteDark = 3, sparkle = 4;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 2 + c.row(y)) % 6 == 0, bgDot);
  c.ellipse(0.36, 0.74, 0.16, 0.12, noteDark, angle: -0.4);
  c.ellipse(0.35, 0.72, 0.14, 0.1, note, angle: -0.4);
  c.rect(0.44, 0.16, 0.52, 0.72, note);
  c.polygon(const [(0.48, 0.16), (0.8, 0.32), (0.8, 0.46), (0.48, 0.3)], note);
  c.star(0.8, 0.72, 0.1, 0.035, 4, sparkle);
  c.star(0.2, 0.22, 0.07, 0.025, 4, sparkle);
  return c.toPuzzle(id: id, title: 'Melody', palette: const [
    0xFFFFF0F7, 0xFFFFD6E8, 0xFF39C5BB, 0xFF137A7F, 0xFFFFC107, //
  ]);
}

Puzzle headphones(String id, int n) {
  const bg = 0, band = 1, bandDark = 2, cup = 3, cupDark = 4, pad = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.56) * (y - 0.56));
    return d > 0.3 && d < 0.4 && y < 0.6;
  }, band);
  c.fill((x, y) {
    final d = math.sqrt((x - 0.5) * (x - 0.5) + (y - 0.56) * (y - 0.56));
    return d > 0.36 && d < 0.4 && y < 0.6;
  }, bandDark);
  for (final x in const [0.18, 0.82]) {
    c.ellipse(x, 0.66, 0.12, 0.2, cupDark);
    c.ellipse(x, 0.66, 0.08, 0.15, cup);
    c.ellipse(x + (x < 0.5 ? 0.08 : -0.08), 0.66, 0.04, 0.14, pad);
  }
  return c.toPuzzle(id: id, title: 'Headphones', palette: const [
    0xFFF3F6F9, 0xFF39C5BB, 0xFF137A7F, 0xFF8A8F99, 0xFF4A4E57, 0xFFF06292, //
  ]);
}

Puzzle microphone(String id, int n) {
  const bg = 0, glow = 1, mesh = 2, meshDark = 3, body = 4, ring = 5, stand = 6, shine = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.circle(0.5, 0.3, 0.3, glow);
  c.rect(0.47, 0.6, 0.53, 0.88, stand);
  c.ellipse(0.5, 0.9, 0.2, 0.05, stand);
  c.polygon(const [(0.38, 0.42), (0.62, 0.42), (0.56, 0.66), (0.44, 0.66)], body);
  c.rect(0.37, 0.4, 0.63, 0.45, ring);
  c.circle(0.5, 0.28, 0.15, meshDark);
  c.fill((x, y) => ArtCanvas.inCircle(0.5, 0.28, 0.15)(x, y) && (c.col(x) + c.row(y)).isEven, mesh);
  c.dot(0.44, 0.22, shine);
  return c.toPuzzle(id: id, title: 'On Stage', palette: const [
    0xFF2A2440, 0xFF3D3560, 0xFFC9CCD3, 0xFF8A8F99, 0xFF39C5BB, 0xFFF06292, 0xFF5F6470, 0xFFFFFFFF, //
  ]);
}

Puzzle orange(String id, int n) {
  const bg = 0, bgDot = 1, orangeC = 2, orangeDark = 3, orangeLight = 4, leafC = 5, stem = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y)) % 4 == 0, bgDot);
  c.fillShaded(ArtCanvas.inCircle(0.5, 0.56, 0.32), 0.5, 0.56, 0.32, const [orangeDark, orangeC, orangeC, orangeLight]);
  c.fill((x, y) => ArtCanvas.inCircle(0.5, 0.56, 0.32)(x, y) && c.noise(x, y, 3) < 0.06, orangeDark);
  c.rect(0.48, 0.2, 0.53, 0.28, stem);
  c.ellipse(0.64, 0.2, 0.12, 0.05, leafC, angle: -0.3);
  return c.toPuzzle(id: id, title: 'Sunny Orange', palette: const [
    0xFFFFFDE7, 0xFFFFF59D, 0xFFFF9800, 0xFFE65100, 0xFFFFCC80, 0xFF43A047, 0xFF5D4037, //
  ]);
}

// ---- Medium ---------------------------------------------------------------

const _skin = 0xFFFFE3D0;

Puzzle mikuFace(String id, int n) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, white = 6, blush = 7, mouth = 8, tie = 9;
  const headset = 10;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 7 == 0, bgDot);
  _twinTails(c, 0.5, 0.44, 1, hair, hairDark, tie);
  _head(c, 0.5, 0.44, 1,
      const _Look(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  _headset(c, 0.5, 0.44, 1, headset);
  return c.toPuzzle(id: id, title: 'Miku', palette: const [
    0xFFE3EEFA, 0xFFC9DDF2, 0xFF39C5BB, 0xFF1E8F88, _skin, 0xFF137A7F, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, //
    0xFFE6457A, 0xFF4A4E57,
  ]);
}

Puzzle rinFace(String id, int n) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, white = 6, blush = 7, mouth = 8, bow = white;
  const bowShade = 9;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 2 + c.row(y)) % 7 == 0, bgDot);
  _head(c, 0.5, 0.5, 1,
      const _Look(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  c.polygon(const [(0.5, 0.18), (0.24, 0.04), (0.28, 0.24)], bow);
  c.polygon(const [(0.5, 0.18), (0.76, 0.04), (0.72, 0.24)], bow);
  c.fill((x, y) => ArtCanvas.inPolygon(const [(0.5, 0.18), (0.24, 0.04), (0.28, 0.24)])(x, y) && y > 0.17, bowShade);
  c.fill((x, y) => ArtCanvas.inPolygon(const [(0.5, 0.18), (0.76, 0.04), (0.72, 0.24)])(x, y) && y > 0.17, bowShade);
  c.circle(0.5, 0.18, 0.04, bow);
  c.rect(0.33, 0.44, 0.39, 0.47, bow);
  c.rect(0.61, 0.44, 0.67, 0.47, bow);
  return c.toPuzzle(id: id, title: 'Rin', palette: const [
    0xFFFFF8E1, 0xFFFFECB3, 0xFFFFE066, 0xFFE8B730, _skin, 0xFF3A7BD5, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, //
    0xFFD9DDE3,
  ]);
}

Puzzle lenFace(String id, int n) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, white = 6, blush = 7, mouth = 8;
  const collar = 10;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 3) % 8 == 0, bgDot);
  c.polygon(const [(0.5, 0.1), (0.62, 0.04), (0.58, 0.18)], hair);
  c.polygon(const [(0.5, 0.1), (0.4, 0.02), (0.44, 0.16)], hair);
  c.polygon(const [(0.3, 0.86), (0.7, 0.86), (0.82, 1), (0.18, 1)], collar);
  c.polygon(const [(0.42, 0.86), (0.58, 0.86), (0.5, 0.98)], white);
  _head(c, 0.5, 0.5, 1,
      const _Look(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  return c.toPuzzle(id: id, title: 'Len', palette: const [
    0xFFE8F5E9, 0xFFC8E6C9, 0xFFFFE066, 0xFFE8B730, _skin, 0xFF3A7BD5, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, //
    0xFF4A4E57, 0xFF2F3550,
  ]);
}

Puzzle lukaFace(String id, int n) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, white = 6, blush = 7, mouth = 8, gold = 9;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) * 3 + c.row(y)) % 8 == 0, bgDot);
  c.rect(0.18, 0.4, 0.34, 1, hair);
  c.rect(0.66, 0.4, 0.82, 1, hair);
  c.rect(0.18, 0.6, 0.24, 1, hairDark);
  c.rect(0.76, 0.6, 0.82, 1, hairDark);
  _head(c, 0.5, 0.42, 1,
      const _Look(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  _headset(c, 0.5, 0.42, 1, gold);
  return c.toPuzzle(id: id, title: 'Luka', palette: const [
    0xFFFCE4EC, 0xFFF8CCDA, 0xFFF6A1B6, 0xFFD9738F, _skin, 0xFF3A7BD5, 0xFFFFFFFF, 0xFFFF8FA3, 0xFFB5545F, //
    0xFFE8B730,
  ]);
}

Puzzle kaitoFace(String id, int n) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, white = 6, blush = 7, mouth = 8, scarf = 9;
  const scarfDark = 10, coat = 11;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y)) % 6 == 0, bgDot);
  c.polygon(const [(0.24, 0.8), (0.76, 0.8), (0.86, 1), (0.14, 1)], coat);
  _head(c, 0.5, 0.46, 1,
      const _Look(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  c.ellipse(0.5, 0.78, 0.24, 0.06, scarf);
  c.rect(0.56, 0.78, 0.64, 1, scarf);
  c.rect(0.6, 0.78, 0.64, 1, scarfDark);
  return c.toPuzzle(id: id, title: 'Kaito', palette: const [
    0xFFE3F2FD, 0xFFBBDEFB, 0xFF3B6FD9, 0xFF27499A, _skin, 0xFF16306E, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, //
    0xFF4A8BF0, 0xFF2D5FB8, 0xFFE0E0E0,
  ]);
}

// ---- Hard -----------------------------------------------------------------

/// Full chibi Miku in a given colour scheme, with a little scenery.
Puzzle _mikuFull(String id, int n, String title, List<int> palette, {required bool snow, required bool sakura}) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, white = 6, blush = 7, mouth = 8, tie = 9;
  const headset = 10, shirt = 11, skirt = 12, legs = 13, extra = 14;
  final c = ArtCanvas(n, n, background: bg);
  if (snow) {
    c.fill((x, y) => c.noise(x, y, 51) < 0.05, bgDot);
  } else if (sakura) {
    c.fill((x, y) => c.noise(x, y, 52) < 0.06, bgDot);
  } else {
    c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 9 == 0, bgDot);
  }
  _twinTails(c, 0.5, 0.28, 0.62, hair, hairDark, tie);
  _body(c, 0.5, 0.48, 0.62, 0.96, shirt: shirt, skirt: skirt, tie: tie, skin: skin, legs: legs);
  _head(c, 0.5, 0.28, 0.62,
      const _Look(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  _headset(c, 0.5, 0.28, 0.62, headset);
  if (snow) {
    for (final (x, y) in const [(0.12, 0.2), (0.86, 0.3), (0.16, 0.7), (0.88, 0.78)]) {
      c.star(x, y, 0.05, 0.015, 6, white);
    }
  } else if (sakura) {
    for (final (x, y) in const [(0.12, 0.24), (0.88, 0.2), (0.1, 0.74), (0.9, 0.66)]) {
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5;
        c.circle(x + 0.03 * math.cos(a), y + 0.03 * math.sin(a), 0.022, extra);
      }
    }
  } else {
    // A leek held up in her right hand.
    c.line(0.7, 0.68, 0.86, 0.36, 0.05, white);
    c.line(0.86, 0.36, 0.92, 0.2, 0.05, extra);
  }
  return c.toPuzzle(id: id, title: title, palette: palette);
}

Puzzle mikuFull(String id, int n) => _mikuFull(
    id,
    n,
    'Miku Live',
    const [
      0xFFE3EEFA, 0xFFC9DDF2, 0xFF39C5BB, 0xFF1E8F88, _skin, 0xFF137A7F, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, //
      0xFFE6457A, 0xFF4A4E57, 0xFF9AA0AA, 0xFF2B2E36, 0xFF3A3D45, 0xFF5DBB4A,
    ],
    snow: false,
    sakura: false);

Puzzle snowMiku(String id, int n) => _mikuFull(
    id,
    n,
    'Snow Miku',
    const [
      0xFF9EC9F0, 0xFFC2DDF5, 0xFFE8F4FF, 0xFF8FB0DC, _skin, 0xFF3A7BD5, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, //
      0xFF5C8FD6, 0xFF7FA6D9, 0xFFD3DCEB, 0xFF3A6FB8, 0xFF2B4D80, 0xFFFFFFFF,
    ],
    snow: true,
    sakura: false);

Puzzle sakuraMiku(String id, int n) => _mikuFull(
    id,
    n,
    'Sakura Miku',
    const [
      0xFFFDE0EA, 0xFFF9C5D5, 0xFFF7A8C2, 0xFFD9738F, _skin, 0xFFB5545F, 0xFFFFFFFF, 0xFFFF8FA3, 0xFF8E3A4A, //
      0xFF9B1B4A, 0xFF8A6E78, 0xFFE8D5DD, 0xFFC2506E, 0xFF5E3442, 0xFFFF7AA2,
    ],
    snow: false,
    sakura: true);

Puzzle rinLen(String id, int n) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, white = 6, blush = 7, mouth = 8, bow = white;
  const shirt = 9, collar = 10, shorts = 11, legs = 12, note = 13;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 9 == 0, bgDot);
  const look = _Look(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth);
  for (final (cx, isRin) in const [(0.28, true), (0.72, false)]) {
    _body(c, cx, 0.54, 0.5, 0.96, shirt: shirt, skirt: shorts, tie: collar, skin: skin, legs: legs);
    _head(c, cx, 0.38, 0.5, look);
    if (isRin) {
      c.polygon([(cx, 0.22), (cx - 0.13, 0.13), (cx - 0.11, 0.25)], bow);
      c.polygon([(cx, 0.22), (cx + 0.13, 0.13), (cx + 0.11, 0.25)], bow);
    } else {
      c.polygon([(cx, 0.22), (cx + 0.08, 0.17), (cx + 0.06, 0.25)], hair);
    }
  }
  c.pixelArt(const [
    '.XX',
    '.X.',
    'XX.',
  ], const {
    'X': note,
  }, l: 0.44, t: 0.08, r: 0.56, b: 0.2);
  return c.toPuzzle(id: id, title: 'Twin Mirror', palette: const [
    0xFFFFFDE7, 0xFFFFF59D, 0xFFFFE066, 0xFFE8B730, _skin, 0xFF3A7BD5, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, //
    0xFFDDE3EA, 0xFF2F3550, 0xFF5A5F6B, 0xFF2B2E36, 0xFF39C5BB,
  ]);
}

Puzzle concert(String id, int n) {
  const dark = 0, spot = 1, stage = 2, stageEdge = 3, singer = 4, singerDark = 5, crowd = 6, glow = 7;
  const glowPink = 8, star = 9;
  final c = ArtCanvas(n, n, background: dark);
  c.fill((x, y) => y < 0.4 && c.noise(x, y, 61) < 0.03, star);
  c.polygon(const [(0.18, 0), (0.28, 0), (0.56, 0.66), (0.36, 0.66)], spot);
  c.polygon(const [(0.72, 0), (0.82, 0), (0.64, 0.66), (0.44, 0.66)], spot);
  c.rect(0, 0.62, 1, 0.72, stage);
  c.rect(0, 0.7, 1, 0.73, stageEdge);
  // The singer: twin-tailed silhouette in teal.
  c.circle(0.5, 0.36, 0.06, singer);
  for (final side in const [-1.0, 1.0]) {
    c.ellipse(0.5 + side * 0.08, 0.46, 0.03, 0.12, singer, angle: side * -0.15);
  }
  c.polygon(const [(0.46, 0.42), (0.54, 0.42), (0.58, 0.56), (0.42, 0.56)], singerDark);
  c.rect(0.465, 0.56, 0.485, 0.63, singerDark);
  c.rect(0.515, 0.56, 0.535, 0.63, singerDark);
  // Crowd with glowsticks.
  for (var i = 0; i < 9; i++) {
    final x = 0.06 + i * 0.11, y = 0.86 + (i.isEven ? 0.0 : 0.03);
    c.circle(x, y, 0.06, crowd);
    c.rect(x - 0.06, y, x + 0.06, 1, crowd);
    c.line(x + 0.04, y - 0.04, x + 0.08, y - 0.14, 0.03, i % 3 == 0 ? glowPink : glow);
  }
  return c.toPuzzle(id: id, title: 'Concert Night', palette: const [
    0xFF15122A, 0xFF3A3360, 0xFF5A4E8A, 0xFF8A7FC0, 0xFF39C5BB, 0xFF1E8F88, 0xFF0A0814, 0xFF6FF0E4, //
    0xFFFF7AC6, 0xFFFFF59D,
  ]);
}
