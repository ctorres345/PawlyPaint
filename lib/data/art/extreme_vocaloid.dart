import '../../models/puzzle.dart';
import '../art_canvas.dart';

// Extreme chibi fan art for personal play, inspired by the Vocaloid singers.
// Drawn for a 40×40 grid.

/// Colors for one chibi head, as palette indices.
class _XLook {
  const _XLook({
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

/// A big-headed chibi face centred on ([cx], [cy]); [s] scales it.
void _xHead(ArtCanvas c, double cx, double cy, double s, _XLook k) {
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
void _xTwinTails(ArtCanvas c, double cx, double cy, double s, int hair, int hairDark, int tie) {
  for (final side in const [-1.0, 1.0]) {
    final tail = ArtCanvas.inEllipse(cx + side * 0.42 * s, cy + 0.48 * s, 0.12 * s, 0.52 * s, angle: side * -0.12);
    c.fill(tail, hair);
    c.fill((x, y) => tail(x, y) && (x - (cx + side * 0.42 * s)) * side > 0.03 * s, hairDark);
    c.rect(cx + side * 0.36 * s - 0.04 * s, cy - 0.16 * s, cx + side * 0.36 * s + 0.04 * s, cy - 0.06 * s, tie);
  }
}

/// Headset ear pieces.
void _xHeadset(ArtCanvas c, double cx, double cy, double s, int color) {
  for (final side in const [-1.0, 1.0]) {
    c.ellipse(cx + side * 0.3 * s, cy + 0.08 * s, 0.05 * s, 0.08 * s, color);
  }
}

/// A chibi body under a head of scale [s], from the neck down to [bottom].
void _xBody(ArtCanvas c, double cx, double neckY, double s, double bottom,
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

/// An eighth note whose top left corner sits on cell ([col], [row]) of a 40 grid.
void _xNote(ArtCanvas c, double col, double row, int color) {
  c.pixelArt(const [
    '.XX',
    '.XX',
    '.X.',
    'XX.',
    'XX.',
  ], {
    'X': color,
  }, l: col / 40, t: row / 40, r: (col + 3) / 40, b: (row + 5) / 40);
}

const _xSkin = 0xFFFFE3D0;

// ---- Extreme --------------------------------------------------------------

Puzzle xVocKaitoIceCream(String id, int n) {
  const sky = 0, sun = 1, sea = 2, sand = 3, hair = 4, hairDark = 5, skin = 6, white = 7, blush = 8, mouth = 9;
  const coatShade = 10, scarf = 11, pants = 12, cone = 13, coneDark = 14, pink = 15, mint = 16;
  final c = ArtCanvas(n, n, background: sky);
  c.circle(0.12, 0.1, 0.07, sun);
  c.ellipse(0.82, 0.12, 0.12, 0.04, white);
  c.ellipse(0.88, 0.09, 0.06, 0.035, white);
  c.rect(0, 0.52, 1, 0.68, sea);
  c.fill((x, y) => y > 0.52 && y < 0.68 && (c.col(x) + c.row(y) * 3) % 7 == 0, white);
  c.fill((x, y) => y >= 0.68, sand);
  c.fill((x, y) => y >= 0.7 && c.noise(x, y, 5) < 0.08, coneDark);
  const s = 0.62, cx = 0.42, cy = 0.28, neck = 0.48;
  _xBody(c, cx, neck, s, 0.94, shirt: white, skirt: coatShade, tie: scarf, skin: skin, legs: pants);
  c.rect(cx - 0.16, 0.92, cx - 0.02, 0.97, hairDark);
  c.rect(cx + 0.02, 0.92, cx + 0.16, 0.97, hairDark);
  _xHead(
      c,
      cx,
      cy,
      s,
      const _XLook(
          hair: hair, hairDark: hairDark, skin: skin, eye: hairDark, white: white, blush: blush, mouth: mouth));
  // Scarf wrapped around the neck, one end blowing out.
  c.ellipse(cx, neck + 0.01, 0.15, 0.04, scarf);
  c.polygon(const [(0.34, 0.5), (0.4, 0.5), (0.3, 0.68), (0.24, 0.66)], scarf);
  // A triple ice cream cone in the left hand.
  c.polygon(const [(0.56, 0.6), (0.76, 0.6), (0.66, 0.84)], cone);
  c.fill(
      (x, y) =>
          ArtCanvas.inPolygon(const [(0.56, 0.6), (0.76, 0.6), (0.66, 0.84)])(x, y) && (c.col(x) + c.row(y)) % 3 == 0,
      coneDark);
  c.circle(0.62, 0.7, 0.035, skin);
  c.circle(0.66, 0.56, 0.08, pink);
  c.circle(0.66, 0.43, 0.075, mint);
  c.circle(0.66, 0.31, 0.065, white);
  c.dot(0.63, 0.53, white);
  c.dot(0.63, 0.41, white);
  c.circle(0.67, 0.22, 0.03, mouth);
  return c.toPuzzle(id: id, title: 'Ice Cream Break', palette: const [
    0xFF8FD3F5, 0xFFFFE066, 0xFF2E86C9, 0xFFF2DCA6, 0xFF3B6FD9, 0xFF1E3A8A, _xSkin, 0xFFFFFFFF, 0xFFFFA8B8, //
    0xFFD83A4A, 0xFFC9D1DE, 0xFF5FA8F5, 0xFF2B2E45, 0xFFE0A85A, 0xFFA8702E, 0xFFFF9EC4, 0xFF9DE8C8,
  ]);
}

Puzzle xVocLukaTuna(String id, int n) {
  const sky = 0, white = 1, sea = 2, seaDark = 3, plank = 4, plankDark = 5, hair = 6, hairDark = 7, skin = 8;
  const blush = 9, mouth = 10, shirt = 11, skirt = 12, gold = 13, tuna = 14, belly = 15, fin = 16;
  final c = ArtCanvas(n, n, background: sky);
  c.ellipse(0.16, 0.14, 0.12, 0.04, white);
  c.ellipse(0.86, 0.22, 0.1, 0.035, white);
  c.rect(0, 0.42, 1, 0.8, sea);
  c.fill((x, y) => y > 0.42 && y < 0.8 && c.row(y).isEven && (c.col(x) + c.row(y) * 2) % 9 < 2, seaDark);
  c.fill((x, y) => y > 0.42 && y < 0.44, white);
  c.fill((x, y) => y >= 0.8, plank);
  c.fill((x, y) => y >= 0.8 && (c.row(y) % 3 == 2 || (c.col(x) + (c.row(y) ~/ 3) * 5) % 10 == 0), plankDark);
  const s = 0.62, cx = 0.46, cy = 0.27, neck = 0.47;
  // Long straight hair behind her.
  c.rect(cx - 0.21, cy + 0.04, cx - 0.1, 0.84, hair);
  c.rect(cx + 0.1, cy + 0.04, cx + 0.21, 0.84, hair);
  c.rect(cx - 0.21, 0.6, cx - 0.17, 0.84, hairDark);
  c.rect(cx + 0.17, 0.6, cx + 0.21, 0.84, hairDark);
  _xBody(c, cx, neck, s, 0.94, shirt: shirt, skirt: skirt, tie: gold, skin: skin, legs: skirt);
  c.rect(cx - 0.11, 0.62, cx + 0.11, 0.65, gold);
  _xHead(c, cx, cy, s,
      const _XLook(hair: hair, hairDark: hairDark, skin: skin, eye: sea, white: white, blush: blush, mouth: mouth));
  _xHeadset(c, cx, cy, s, gold);
  // A big tuna held in both arms.
  c.polygon(const [(0.82, 0.66), (0.96, 0.56), (0.92, 0.66), (0.96, 0.76)], tuna);
  c.ellipse(0.5, 0.66, 0.34, 0.085, tuna);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.66, 0.34, 0.085)(x, y) && y > 0.675, belly);
  for (final x in const [0.62, 0.68, 0.74]) {
    c.dot(x, 0.58, fin);
    c.dot(x, 0.74, fin);
  }
  c.dot(0.24, 0.64, white);
  c.dot(0.25, 0.64, seaDark);
  c.circle(cx - 0.2, 0.7, 0.035, skin);
  c.circle(cx + 0.2, 0.7, 0.035, skin);
  return c.toPuzzle(id: id, title: 'Catch of the Day', palette: const [
    0xFFBFE6FA, 0xFFFFFFFF, 0xFF2E7FC9, 0xFF1A4F8A, 0xFFC49A62, 0xFF8A643A, 0xFFF6A1B6, 0xFFD06A88, _xSkin, //
    0xFFFF8FA3, 0xFFB5545F, 0xFF5A5E6B, 0xFF26272E, 0xFFE8B730, 0xFF4F6487, 0xFFD3DBE5, 0xFFFFD43B,
  ]);
}

Puzzle xVocMeikoStage(String id, int n) {
  const bg = 0, beam = 1, floor = 2, floorEdge = 3, speaker = 4, cone = 5, hair = 6, hairDark = 7, skin = 8;
  const eye = 9, white = 10, blush = 11, mouth = 12, red = 13, redDark = 14, mic = 15, note = 16, lamp = 17;
  final c = ArtCanvas(n, n, background: bg);
  c.polygon(const [(0.2, 0), (0.3, 0), (0.6, 0.82), (0.34, 0.82)], beam);
  c.polygon(const [(0.7, 0), (0.8, 0), (0.66, 0.82), (0.4, 0.82)], beam);
  for (final (x, col) in const [(0.12, lamp), (0.25, note), (0.5, lamp), (0.75, note), (0.88, lamp)]) {
    c.rect(x - 0.04, 0.0, x + 0.04, 0.04, speaker);
    c.rect(x - 0.025, 0.04, x + 0.025, 0.065, col);
  }
  c.rect(0, 0.82, 1, 1, floor);
  c.fill((x, y) => y >= 0.82 && c.col(x) % 6 == 0, floorEdge);
  c.rect(0, 0.82, 1, 0.845, floorEdge);
  // Speaker stacks.
  for (final x in const [0.1, 0.9]) {
    c.rect(x - 0.1, 0.5, x + 0.1, 0.84, speaker);
    c.circle(x, 0.6, 0.06, cone);
    c.circle(x, 0.6, 0.025, speaker);
    c.circle(x, 0.75, 0.04, cone);
  }
  const s = 0.62, cx = 0.5, cy = 0.28, neck = 0.48;
  _xBody(c, cx, neck, s, 0.9, shirt: red, skirt: redDark, tie: white, skin: skin, legs: skin);
  c.rect(cx - 0.16, 0.6, cx + 0.16, 0.66, skin);
  c.rect(cx - 0.1, 0.84, cx - 0.02, 0.92, redDark);
  c.rect(cx + 0.02, 0.84, cx + 0.1, 0.92, redDark);
  _xHead(c, cx, cy, s,
      const _XLook(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  // Short bob: trim the hair below the chin.
  c.fill((x, y) => y > cy + 0.17 && y < cy + 0.24 && (x - cx).abs() > 0.13 && (x - cx).abs() < 0.24, bg);
  // Hand-held mic near her mouth.
  c.line(cx + 0.2, 0.68, cx + 0.13, 0.5, 0.035, mic);
  c.circle(cx + 0.12, 0.47, 0.035, mic);
  c.circle(cx + 0.2, 0.69, 0.035, skin);
  _xNote(c, 4, 13, note);
  _xNote(c, 33, 10, lamp);
  _xNote(c, 30, 22, note);
  return c.toPuzzle(id: id, title: 'Encore', palette: const [
    0xFF1E1633, 0xFF3D3366, 0xFF7A4E2E, 0xFF4E2F1A, 0xFF16161C, 0xFF6A6E7A, 0xFF8A4A2A, 0xFF5E2F18, _xSkin, //
    0xFF6E3A1E, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, 0xFFE0302A, 0xFF9E1B1B, 0xFFC9CCD3, 0xFF39C5BB, 0xFFFFE066,
  ]);
}

Puzzle xVocRoadRoller(String id, int n) {
  const sky = 0, skyLow = 1, city = 2, road = 3, white = 4, roller = 5, rollerDark = 6, drum = 7, drumLight = 8;
  const hair = 9, hairDark = 10, skin = 11, eye = 12, blush = 13, mouth = 14, navy = 15;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.4, 1, 1, skyLow);
  // City skyline.
  for (final (l, r, t) in const [
    (0.0, 0.1, 0.48),
    (0.1, 0.2, 0.4),
    (0.22, 0.3, 0.52),
    (0.3, 0.42, 0.44),
    (0.62, 0.72, 0.42),
    (0.72, 0.8, 0.5),
    (0.8, 0.92, 0.36),
    (0.92, 1.0, 0.46)
  ]) {
    c.rect(l, t, r, 0.72, city);
  }
  c.fill((x, y) => y > 0.38 && y < 0.7 && c.row(y).isEven && c.col(x) % 3 == 1 && c.at(c.col(x), c.row(y)) == city,
      skyLow);
  c.rect(0, 0.72, 1, 1, road);
  c.fill((x, y) => y > 0.9 && y < 0.93 && (c.col(x) ~/ 3).isEven, white);
  // The road roller: a big front drum under a yellow fork, engine body behind.
  c.rect(0.36, 0.52, 0.94, 0.8, roller);
  c.rect(0.36, 0.74, 0.94, 0.8, rollerDark);
  c.rect(0.88, 0.52, 0.94, 0.8, rollerDark);
  c.rect(0.42, 0.58, 0.84, 0.64, white);
  c.rect(0.06, 0.52, 0.4, 0.6, roller);
  c.rect(0.06, 0.52, 0.1, 0.72, rollerDark);
  c.circle(0.24, 0.8, 0.17, drum);
  c.ring(0.24, 0.8, 0.1, 0.12, drumLight);
  c.circle(0.24, 0.8, 0.04, roller);
  c.rect(0.22, 0.6, 0.26, 0.8, rollerDark);
  c.circle(0.8, 0.86, 0.1, drum);
  c.circle(0.8, 0.86, 0.04, drumLight);
  // Rin riding on top, arm raised.
  const s = 0.48, cx = 0.62, cy = 0.2, neck = 0.355;
  _xBody(c, cx, neck, s, 0.5, shirt: white, skirt: navy, tie: hair, skin: skin, legs: navy);
  c.line(cx + 0.1, neck + 0.02, cx + 0.22, neck - 0.1, 0.045, white);
  c.circle(cx + 0.23, neck - 0.12, 0.025, skin);
  _xHead(c, cx, cy, s,
      const _XLook(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  c.polygon(const [(cx, cy - 0.15), (cx - 0.13, cy - 0.24), (cx - 0.1, cy - 0.11)], white);
  c.polygon(const [(cx, cy - 0.15), (cx + 0.13, cy - 0.24), (cx + 0.1, cy - 0.11)], white);
  return c.toPuzzle(id: id, title: 'Road Roller', palette: const [
    0xFFFF9E6B, 0xFFFFC98A, 0xFF7A5A86, 0xFF55575E, 0xFFFFFFFF, 0xFFF5B21B, 0xFFB57A0E, 0xFF2A2A30, 0xFF8A8C94, //
    0xFFFFEA80, 0xFFE0B83A, _xSkin, 0xFF3A7BD5, 0xFFFFA8B8, 0xFFB5545F, 0xFF2F3550,
  ]);
}

Puzzle xVocMoonlit(String id, int n) {
  const skyA = 0, skyB = 1, skyC = 2, star = 3, moon = 4, moonShade = 5, hair = 6, hairDark = 7, skin = 8;
  const eye = 9, white = 10, blush = 11, mouth = 12, tie = 13, headset = 14, shirt = 15, skirt = 16;
  final c = ArtCanvas(n, n, background: skyA);
  c.bands(const [skyA, skyB, skyC]);
  c.fill((x, y) => (c.row(y) == 13 && c.col(x).isEven) || (c.row(y) == 26 && c.col(x).isOdd), skyB);
  c.fill((x, y) => c.row(y) == 27 && c.col(x).isEven, skyC);
  c.fill((x, y) => c.noise(x, y, 71) < 0.03, star);
  for (final (x, y) in const [(0.1, 0.12), (0.88, 0.1), (0.9, 0.42), (0.08, 0.5)]) {
    c.star(x, y, 0.045, 0.015, 4, star);
  }
  // A crescent moon cradling her.
  bool crescent(double x, double y) =>
      ArtCanvas.inCircle(0.5, 0.66, 0.34)(x, y) && !ArtCanvas.inCircle(0.5, 0.56, 0.32)(x, y);
  c.fill(crescent, moon);
  c.fill((x, y) => crescent(x, y) && (y > 0.94 || c.noise(x, y, 72) < 0.12), moonShade);
  const s = 0.56, cx = 0.5, cy = 0.24, neck = 0.42;
  _xTwinTails(c, cx, cy, s, hair, hairDark, tie);
  _xBody(c, cx, neck, s, 0.86, shirt: shirt, skirt: skirt, tie: tie, skin: skin, legs: skirt);
  _xHead(c, cx, cy, s,
      const _XLook(hair: hair, hairDark: hairDark, skin: skin, eye: eye, white: white, blush: blush, mouth: mouth));
  _xHeadset(c, cx, cy, s, headset);
  _xNote(c, 4, 26, hair);
  _xNote(c, 34, 22, tie);
  _xNote(c, 33, 2, hair);
  return c.toPuzzle(id: id, title: 'Moonlit Melody', palette: const [
    0xFF0F1640, 0xFF1F2A66, 0xFF3A3F8A, 0xFFFFF59D, 0xFFFFE9A8, 0xFFE0BE6A, 0xFF39C5BB, 0xFF1E8F88, _xSkin, //
    0xFF137A7F, 0xFFFFFFFF, 0xFFFFA8B8, 0xFFB5545F, 0xFFE6457A, 0xFF4A4E57, 0xFF9AA0AA, 0xFF2B2E36,
  ]);
}
