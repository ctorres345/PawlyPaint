import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// The K-Pop Stage course: fandom things and stages with generic cartoon
// idols. No real group's logo, colours or lightstick shape.

const _skin = 0xFFFFE0C8;

/// Colours of a chibi idol.
class _Idol {
  const _Idol({required this.hair, required this.hairDark, required this.eye, required this.blush, required this.outfit});

  final int hair, hairDark, eye, blush, outfit;
}

/// A chibi idol head centred on ([cx], [cy]) with half-width [r]. [style]
/// picks the hair: 0 bangs, 1 bob, 2 long with buns, 3 cap.
void _idolHead(ArtCanvas c, double cx, double cy, double r, _Idol k, {int style = 0, int skin = -1, int? cap}) {
  final sk = skin < 0 ? 1 : skin;
  final cell = 1 / c.width;
  if (style == 2) {
    for (final side in const [-1.0, 1.0]) {
      c.circle(cx + side * r * 0.85, cy - r * 0.75, r * 0.3, k.hair);
      c.ellipse(cx + side * r * 0.95, cy + r * 0.5, r * 0.22, r * 0.75, k.hairDark);
    }
  }
  if (style == 1) {
    c.ellipse(cx, cy + r * 0.15, r * 1.1, r * 1.05, k.hairDark);
  }
  c.ellipse(cx, cy, r, r * 0.95, k.hair);
  c.ellipse(cx, cy + r * 0.12, r * 0.84, r * 0.78, sk);
  // Bangs.
  c.fill((x, y) => ArtCanvas.inEllipse(cx, cy - r * 0.25, r * 0.95, r * 0.6)(x, y) && y < cy - r * 0.1, k.hair);
  for (final dx in const [-0.5, -0.17, 0.17, 0.5]) {
    c.polygon([(cx + (dx - 0.2) * r, cy - r * 0.15), (cx + (dx + 0.2) * r, cy - r * 0.15), (cx + dx * r, cy + r * 0.12)], k.hair);
  }
  if (style == 3 && cap != null) {
    c.ellipse(cx, cy - r * 0.45, r * 0.95, r * 0.5, cap);
    c.rect(cx - r * 0.95, cy - r * 0.42, cx + r * 1.25, cy - r * 0.3, cap);
  }
  for (final side in const [-1.0, 1.0]) {
    c.ellipse(cx + side * r * 0.32, cy + r * 0.22, math.max(r * 0.12, cell * 0.7), math.max(r * 0.17, cell), k.eye);
    c.circle(cx + side * r * 0.52, cy + r * 0.42, math.max(r * 0.1, cell * 0.75), k.blush);
  }
  c.ellipse(cx, cy + r * 0.5, math.max(r * 0.09, cell * 0.6), math.max(r * 0.06, cell * 0.6), k.blush);
}

/// A simple body under a head: shoulders to [bottom] in the outfit colour.
void _idolBody(ArtCanvas c, double cx, double neckY, double r, double bottom, int outfit, {int? trim}) {
  c.polygon([(cx - r * 0.55, neckY), (cx + r * 0.55, neckY), (cx + r * 0.8, bottom), (cx - r * 0.8, bottom)], outfit);
  if (trim != null) c.rect(cx - r * 0.12, neckY, cx + r * 0.12, bottom, trim);
}

/// A glowing lightstick: handle, grip and a round head with a halo.
void _lightstick(ArtCanvas c, double cx, double cy, double s, {required int handle, required int grip, required int glow, required int core, int? halo}) {
  if (halo != null) c.circle(cx, cy - s * 0.35, s * 0.4, halo);
  c.rect(cx - s * 0.07, cy - s * 0.2, cx + s * 0.07, cy + s * 0.55, handle);
  c.rect(cx - s * 0.1, cy + 0.15 * s, cx + s * 0.1, cy + s * 0.3, grip);
  c.circle(cx, cy - s * 0.35, s * 0.28, glow);
  c.circle(cx, cy - s * 0.35, s * 0.16, core);
}

/// Four-point sparkle.
void _sparkle(ArtCanvas c, double cx, double cy, double s, int color) {
  c.polygon([(cx, cy - s), (cx + s * 0.25, cy), (cx, cy + s), (cx - s * 0.25, cy)], color);
  c.polygon([(cx - s, cy), (cx, cy - s * 0.25), (cx + s, cy), (cx, cy + s * 0.25)], color);
}

/// A row of fans seen from behind, each holding a lightstick.
void _crowd(ArtCanvas c, double top, int count, {required int head, required List<int> glows, int seed = 0}) {
  for (var i = 0; i < count; i++) {
    final x = (i + 0.5) / count, y = top + (i.isEven ? 0.0 : 0.03);
    final w = 0.5 / count;
    c.circle(x, y, w * 0.9, head);
    c.rect(x - w, y, x + w, 1, head);
    final g = glows[(i * 7 + seed) % glows.length];
    c.line(x + w * 0.6, y - w, x + w * 1.1, y - w * 3.2, w * 0.5, g);
    c.circle(x + w * 1.1, y - w * 3.2, w * 0.7, g);
  }
}

// ---- Easy -----------------------------------------------------------------

Puzzle lightstick(String id, int n) {
  const bg = 0, halo = 1, glow = 2, core = 3, handle = 4, grip = 5, spark = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.ring(0.5, 0.36, 0.3, 0.38, halo);
  _lightstick(c, 0.5, 0.56, 0.62, handle: handle, grip: grip, glow: glow, core: core, halo: halo);
  _sparkle(c, 0.18, 0.2, 0.07, spark);
  _sparkle(c, 0.82, 0.15, 0.06, spark);
  _sparkle(c, 0.85, 0.72, 0.05, spark);
  return c.toPuzzle(id: id, title: 'Lightstick', palette: const [
    0xFF2B1B4D, 0xFF6A4FB0, 0xFFF48FB1, 0xFFFFFFFF, 0xFFECEFF1, 0xFF9575CD, 0xFFFFF176, //
  ]);
}

Puzzle fingerHeart(String id, int n) {
  const bg = 0, skin = 1, shade = 2, sleeve = 3, heart = 4, heartLight = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0.3, 0.72, 0.72, 1, sleeve);
  c.ellipse(0.5, 0.62, 0.22, 0.2, skin);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.62, 0.22, 0.2)(x, y) && x > 0.62, shade);
  c.line(0.4, 0.5, 0.33, 0.3, 0.1, skin); // index finger
  c.line(0.56, 0.5, 0.62, 0.32, 0.1, skin); // thumb
  c.line(0.33, 0.3, 0.42, 0.3, 0.06, shade);
  c.heart(0.68, 0.2, 0.1, heart);
  c.heart(0.22, 0.14, 0.06, heartLight);
  c.heart(0.86, 0.42, 0.05, heartLight);
  return c.toPuzzle(id: id, title: 'Finger Heart', palette: const [
    0xFFFFF0F5, _skin, 0xFFE8B89A, 0xFF7E57C2, 0xFFE91E63, 0xFFF8BBD0, //
  ]);
}

Puzzle photocard(String id, int n) {
  const bg = 0, card = 1, border = 2, hair = 3, skin = 4, eye = 5, blush = 6, spark = 7;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0.16, 0.04, 0.84, 0.96, border);
  c.rect(0.22, 0.1, 0.78, 0.9, card);
  _idolBody(c, 0.5, 0.66, 0.24, 0.9, border);
  _idolHead(c, 0.5, 0.46, 0.24, const _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: border), skin: skin);
  _sparkle(c, 0.08, 0.2, 0.06, spark);
  _sparkle(c, 0.92, 0.7, 0.06, spark);
  c.heart(0.7, 0.2, 0.04, blush);
  return c.toPuzzle(id: id, title: 'Photocard', palette: const [
    0xFFE1BEE7, 0xFFFFFFFF, 0xFFF48FB1, 0xFF4A3B8C, _skin, 0xFF2E2233, 0xFFFF8A80, 0xFFFFF176, //
  ]);
}

Puzzle album(String id, int n) {
  const bg = 0, sleeve = 1, sleeveDark = 2, disc = 3, discLight = 4, label = 5, hole = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0.08, 0.2, 0.62, 0.9, sleeveDark);
  c.rect(0.08, 0.2, 0.58, 0.86, sleeve);
  c.heart(0.33, 0.5, 0.13, sleeveDark);
  c.fillShaded(ArtCanvas.inCircle(0.68, 0.54, 0.26), 0.68, 0.54, 0.26, const [disc, disc, discLight]);
  c.circle(0.68, 0.54, 0.1, label);
  c.circle(0.68, 0.54, 0.035, hole);
  return c.toPuzzle(id: id, title: 'New Album', palette: const [
    0xFFFFF8E1, 0xFFCE93D8, 0xFF8E24AA, 0xFF37474F, 0xFF90A4AE, 0xFFF48FB1, 0xFFFFF8E1, //
  ]);
}

Puzzle sloganBanner(String id, int n) {
  const bg = 0, banner = 1, bannerDark = 2, text = 3, heart = 4, stick = 5;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0.1, 0.32, 0.9, 0.68, bannerDark);
  c.rect(0.1, 0.3, 0.88, 0.64, banner);
  c.rect(0.18, 0.4, 0.5, 0.46, text);
  c.rect(0.18, 0.5, 0.62, 0.56, text);
  c.heart(0.76, 0.47, 0.08, heart);
  c.rect(0.04, 0.26, 0.09, 0.9, stick);
  c.rect(0.91, 0.26, 0.96, 0.9, stick);
  return c.toPuzzle(id: id, title: 'Fan Banner', palette: const [
    0xFFE3F2FD, 0xFFF8BBD0, 0xFFC2185B, 0xFF4A148C, 0xFFE91E63, 0xFF90A4AE, //
  ]);
}

// ---- Medium ---------------------------------------------------------------

Puzzle mainVocal(String id, int n) {
  const bg = 0, bgDot = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, blush = 6, outfit = 7, mic = 8, spark = 9;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => (c.col(x) + c.row(y) * 2) % 7 == 0, bgDot);
  _idolBody(c, 0.5, 0.66, 0.3, 1, outfit, trim: blush);
  _idolHead(c, 0.5, 0.42, 0.3, const _Idol(hair: hair, hairDark: hairDark, eye: eye, blush: blush, outfit: outfit), style: 2, skin: skin);
  c.line(0.78, 0.56, 0.84, 0.78, 0.05, mic);
  c.circle(0.77, 0.54, 0.06, hairDark);
  _sparkle(c, 0.12, 0.2, 0.05, spark);
  _sparkle(c, 0.88, 0.22, 0.04, spark);
  return c.toPuzzle(id: id, title: 'Main Vocal', palette: const [
    0xFFFCE4EC, 0xFFF8BBD0, 0xFFB388FF, 0xFF7C4DFF, _skin, 0xFF2E2233, 0xFFFF8A80, 0xFFFFFFFF, 0xFF546E7A, //
    0xFFFFF176,
  ]);
}

Puzzle rapper(String id, int n) {
  const bg = 0, bgStripe = 1, hair = 2, hairDark = 3, skin = 4, eye = 5, blush = 6, outfit = 7, cap = 8, chain = 9;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => ((x + y) * 6).floor().isEven, bgStripe);
  _idolBody(c, 0.5, 0.66, 0.3, 1, outfit);
  c.line(0.38, 0.7, 0.5, 0.82, 0.03, chain);
  c.line(0.62, 0.7, 0.5, 0.82, 0.03, chain);
  _idolHead(c, 0.5, 0.42, 0.3, const _Idol(hair: hair, hairDark: hairDark, eye: eye, blush: blush, outfit: outfit), style: 3, skin: skin, cap: cap);
  return c.toPuzzle(id: id, title: 'Main Rapper', palette: const [
    0xFFE8EAF6, 0xFFC5CAE9, 0xFF37474F, 0xFF263238, _skin, 0xFF1A1A2E, 0xFFFF8A80, 0xFF212121, 0xFFE53935, //
    0xFFFFD54F,
  ]);
}

Puzzle photocardBinder(String id, int n) {
  const bg = 0, page = 1, pocket = 2, card = 3, skin = 4, eye = 5, blush = 6, ring = 7, hairA = 8, hairB = 9;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0.1, 0.06, 0.94, 0.94, page);
  for (final y in const [0.2, 0.5, 0.8]) {
    c.circle(0.1, y, 0.035, ring);
  }
  for (final (cx, hair, style) in const [(0.33, hairA, 1), (0.71, hairB, 0)]) {
    c.rect(cx - 0.17, 0.2, cx + 0.17, 0.8, pocket);
    c.rect(cx - 0.15, 0.22, cx + 0.15, 0.78, card);
    _idolBody(c, cx, 0.58, 0.14, 0.78, pocket);
    _idolHead(c, cx, 0.45, 0.14, _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: pocket), style: style, skin: skin);
  }
  return c.toPuzzle(id: id, title: 'Photocard Binder', palette: const [
    0xFFB39DDB, 0xFFFFFFFF, 0xFFCE93D8, 0xFFB3E5FC, _skin, 0xFF2E2233, 0xFFFF8A80, 0xFF90A4AE, //
    0xFF7C4DFF, 0xFFFF80AB,
  ]);
}

Puzzle concertTicket(String id, int n) {
  const bg = 0, ticket = 1, stub = 2, text = 3, star = 4, perf = 5, glow = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => c.noise(x, y, 3) < 0.05, glow);
  c.fill(ArtCanvas.inPolygon(const [(0.06, 0.34), (0.94, 0.26), (0.94, 0.66), (0.06, 0.74)]), ticket);
  c.fill((x, y) => ArtCanvas.inPolygon(const [(0.66, 0.29), (0.94, 0.26), (0.94, 0.66), (0.66, 0.69)])(x, y), stub);
  c.fill((x, y) => ArtCanvas.inLine(0.66, 0.29, 0.66, 0.69, 0.025)(x, y) && (c.row(y) % 2 == 0), perf);
  c.rect(0.12, 0.4, 0.5, 0.46, text);
  c.rect(0.12, 0.5, 0.42, 0.55, text);
  c.rect(0.12, 0.59, 0.58, 0.63, text);
  c.star(0.8, 0.48, 0.1, 0.045, 5, star);
  return c.toPuzzle(id: id, title: 'Concert Ticket', palette: const [
    0xFF1A1040, 0xFFFFF8E1, 0xFFF48FB1, 0xFF4A148C, 0xFFFFD54F, 0xFF1A1040, 0xFF4A3B8C, //
  ]);
}

Puzzle fanLetter(String id, int n) {
  const bg = 0, env = 1, envDark = 2, flap = 3, seal = 4, paper = 5, spark = 6;
  final c = ArtCanvas(n, n, background: bg);
  c.rect(0.12, 0.3, 0.88, 0.84, envDark);
  c.rect(0.2, 0.2, 0.8, 0.5, paper);
  c.rect(0.28, 0.27, 0.6, 0.3, envDark);
  c.rect(0.28, 0.34, 0.7, 0.37, envDark);
  c.polygon(const [(0.12, 0.84), (0.5, 0.52), (0.88, 0.84)], env);
  c.polygon(const [(0.12, 0.3), (0.5, 0.62), (0.88, 0.3), (0.88, 0.34), (0.5, 0.66), (0.12, 0.34)], flap);
  c.polygon(const [(0.12, 0.3), (0.5, 0.62), (0.88, 0.3)], flap);
  c.heart(0.5, 0.62, 0.08, seal);
  _sparkle(c, 0.14, 0.14, 0.05, spark);
  _sparkle(c, 0.86, 0.12, 0.04, spark);
  return c.toPuzzle(id: id, title: 'Fan Letter', palette: const [
    0xFFE0F7FA, 0xFFF8BBD0, 0xFFF06292, 0xFFFCE4EC, 0xFFC2185B, 0xFFFFFFFF, 0xFFFFD54F, //
  ]);
}

// ---- Hard -----------------------------------------------------------------

Puzzle dancePractice(String id, int n) {
  const wall = 0, mirror = 1, mirrorLight = 2, floor = 3, floorLine = 4, skin = 5, eye = 6, blush = 7;
  const hairA = 8, hairB = 9, outfitA = 10, outfitB = 11, bar = 12;
  final c = ArtCanvas(n, n, background: wall);
  c.rect(0.05, 0.05, 0.95, 0.62, mirrorLight);
  c.fill((x, y) => x > 0.05 && x < 0.95 && y > 0.05 && y < 0.62 && (x - y) > 0.2, mirror);
  c.rect(0, 0.62, 1, 1, floor);
  for (var i = 0; i < 6; i++) {
    c.rect(0, 0.62 + i * 0.07, 1, 0.625 + i * 0.07, floorLine);
  }
  c.rect(0.05, 0.4, 0.95, 0.43, bar);
  for (final (cx, hair, outfit, style) in [(0.32, hairA, outfitA, 1), (0.68, hairB, outfitB, 0)]) {
    _idolBody(c, cx, 0.62, 0.16, 0.9, outfit);
    c.line(cx - 0.12, 0.66, cx - 0.24, 0.5, 0.06, outfit);
    c.line(cx + 0.12, 0.66, cx + 0.24, 0.5, 0.06, outfit);
    c.circle(cx - 0.24, 0.5, 0.035, skin);
    c.circle(cx + 0.24, 0.5, 0.035, skin);
    _idolHead(c, cx, 0.5, 0.16, _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: outfit), style: style, skin: skin);
  }
  return c.toPuzzle(id: id, title: 'Dance Practice', palette: const [
    0xFFEDE7F6, 0xFFB3E5FC, 0xFFE1F5FE, 0xFFD7CCC8, 0xFFBCAAA4, _skin, 0xFF2E2233, 0xFFFF8A80, //
    0xFF7C4DFF, 0xFFFF80AB, 0xFF212121, 0xFFFFFFFF, 0xFF8D6E63,
  ]);
}

Puzzle lightOcean(String id, int n) {
  const dark = 0, beam = 1, stage = 2, stageEdge = 3, head = 4, glowA = 5, glowB = 6, glowC = 7, star = 8;
  final c = ArtCanvas(n, n, background: dark);
  c.fill((x, y) => y < 0.5 && c.noise(x, y, 11) < 0.04, star);
  for (final x0 in const [0.15, 0.5, 0.85]) {
    c.polygon([(x0 - 0.04, 0), (x0 + 0.04, 0), (x0 + 0.2, 0.6), (x0 - 0.2, 0.6)], beam);
  }
  c.rect(0, 0.55, 1, 0.64, stage);
  c.rect(0, 0.63, 1, 0.66, stageEdge);
  _crowd(c, 0.92, 8, head: head, glows: const [glowA, glowB, glowC], seed: 2);
  _crowd(c, 0.82, 10, head: head, glows: const [glowA, glowB, glowC], seed: 1);
  _crowd(c, 0.74, 12, head: head, glows: const [glowA, glowB, glowC]);
  return c.toPuzzle(id: id, title: 'Lightstick Ocean', palette: const [
    0xFF12102A, 0xFF2B2550, 0xFF4A3B8C, 0xFF7E57C2, 0xFF08070F, 0xFFF48FB1, 0xFF80DEEA, 0xFFFFF176, //
    0xFFFFFFFF,
  ]);
}

Puzzle comebackStage(String id, int n) {
  const dark = 0, spot = 1, stage = 2, stageEdge = 3, skin = 4, eye = 5, blush = 6, hair = 7, outfit = 8;
  const confA = 9, confB = 10, mic = 11;
  final c = ArtCanvas(n, n, background: dark);
  c.polygon(const [(0.4, 0), (0.6, 0), (0.78, 0.7), (0.22, 0.7)], spot);
  c.fill((x, y) => c.noise(x, y, 5) < 0.04, confA);
  c.fill((x, y) => c.noise(x, y, 9) < 0.03, confB);
  c.rect(0, 0.68, 1, 1, stage);
  c.rect(0, 0.68, 1, 0.71, stageEdge);
  _idolBody(c, 0.5, 0.5, 0.17, 0.7, outfit, trim: blush);
  c.line(0.38, 0.54, 0.26, 0.42, 0.06, outfit);
  c.circle(0.25, 0.41, 0.035, skin);
  c.line(0.62, 0.54, 0.7, 0.46, 0.06, outfit);
  c.circle(0.71, 0.45, 0.035, skin);
  c.line(0.71, 0.45, 0.74, 0.38, 0.03, mic);
  c.circle(0.75, 0.36, 0.035, eye);
  _idolHead(c, 0.5, 0.36, 0.17, const _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: outfit), style: 2, skin: skin);
  return c.toPuzzle(id: id, title: 'Comeback Stage', palette: const [
    0xFF1A0F33, 0xFF3D2A6E, 0xFF5E4A9E, 0xFF9C8CD0, _skin, 0xFF2E2233, 0xFFFF8A80, 0xFFFF80AB, 0xFFFFFFFF, //
    0xFFFFD54F, 0xFF80DEEA, 0xFF90A4AE,
  ]);
}

Puzzle photoBooth(String id, int n) {
  const bg = 0, strip = 1, frame = 2, skin = 3, eye = 4, blush = 5, hairA = 6, hairB = 7, outfit = 8, heart = 9, spark = 10;
  final c = ArtCanvas(n, n, background: bg);
  c.fill((x, y) => c.noise(x, y, 7) < 0.04, spark);
  c.rect(0.28, 0.02, 0.72, 0.98, strip);
  for (var i = 0; i < 3; i++) {
    final top = 0.05 + i * 0.31, cy = top + 0.16;
    c.rect(0.31, top, 0.69, top + 0.28, frame);
    for (final (cx, hair, style) in [(0.42, hairA, 1), (0.58, hairB, 0)]) {
      _idolBody(c, cx, cy + 0.07, 0.08, top + 0.28, outfit);
      _idolHead(c, cx, cy, 0.08, _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: outfit), style: style, skin: skin);
    }
    c.heart(i == 1 ? 0.36 : 0.64, top + 0.05, 0.025, heart);
  }
  return c.toPuzzle(id: id, title: 'Photo Booth', palette: const [
    0xFFFCE4EC, 0xFFFFFFFF, 0xFFE1F5FE, _skin, 0xFF2E2233, 0xFFFF8A80, 0xFF7C4DFF, 0xFFFF80AB, 0xFFB39DDB, //
    0xFFE91E63, 0xFFFFF176,
  ]);
}

Puzzle idolGroup(String id, int n) {
  const bg = 0, bgLight = 1, floor = 2, skin = 3, eye = 4, blush = 5, outfit = 6, trim = 7;
  const hairs = [8, 9, 10, 11];
  final c = ArtCanvas(n, n, background: bg);
  c.circle(0.5, 0.45, 0.42, bgLight);
  c.rect(0, 0.86, 1, 1, floor);
  for (var i = 0; i < 4; i++) {
    final cx = 0.17 + i * 0.22, cy = 0.5 + (i == 1 || i == 2 ? -0.04 : 0.0);
    _idolBody(c, cx, cy + 0.12, 0.11, 0.88, outfit, trim: trim);
    _idolHead(c, cx, cy, 0.11, _Idol(hair: hairs[i], hairDark: hairs[i], eye: eye, blush: blush, outfit: outfit), style: i % 3, skin: skin);
  }
  return c.toPuzzle(id: id, title: 'The Group', palette: const [
    0xFFE1BEE7, 0xFFF3E5F5, 0xFFCE93D8, _skin, 0xFF2E2233, 0xFFFF8A80, 0xFFFFFFFF, 0xFFF48FB1, //
    0xFF7C4DFF, 0xFFFF80AB, 0xFF4FC3F7, 0xFF212121,
  ]);
}

// ---- Extreme --------------------------------------------------------------

Puzzle xStadiumNight(String id, int n) {
  const sky = 0, star = 1, screen = 2, screenGlow = 3, stand = 4, standDark = 5, stage = 6, beam = 7;
  const head = 8, glowA = 9, glowB = 10, glowC = 11, idol = 12;
  final c = ArtCanvas(n, n, background: sky);
  c.fill((x, y) => y < 0.35 && c.noise(x, y, 21) < 0.03, star);
  c.polygon(const [(0, 0.3), (1, 0.3), (1, 0.62), (0, 0.62)], standDark);
  c.fill((x, y) => y > 0.3 && y < 0.62 && c.noise(x, y, 4) < 0.25, stand);
  for (final x0 in const [0.3, 0.5, 0.7]) {
    c.polygon([(x0 - 0.03, 0.12), (x0 + 0.03, 0.12), (x0 + 0.16, 0.62), (x0 - 0.16, 0.62)], beam);
  }
  c.rect(0.3, 0.12, 0.7, 0.4, screenGlow);
  c.rect(0.32, 0.14, 0.68, 0.38, screen);
  c.circle(0.5, 0.24, 0.05, idol);
  c.polygon(const [(0.46, 0.28), (0.54, 0.28), (0.57, 0.38), (0.43, 0.38)], idol);
  c.rect(0.2, 0.58, 0.8, 0.66, stage);
  c.circle(0.5, 0.56, 0.025, idol);
  c.rect(0.485, 0.58, 0.515, 0.63, idol);
  _crowd(c, 0.94, 12, head: head, glows: const [glowA, glowB, glowC], seed: 3);
  _crowd(c, 0.86, 16, head: head, glows: const [glowA, glowB, glowC], seed: 1);
  _crowd(c, 0.78, 20, head: head, glows: const [glowA, glowB, glowC]);
  return c.toPuzzle(id: id, title: 'Stadium Night', palette: const [
    0xFF0B0A1F, 0xFFFFFFFF, 0xFFB388FF, 0xFF7C4DFF, 0xFF2E2A55, 0xFF1C1A3A, 0xFF4A3B8C, 0xFF3A3070, //
    0xFF050410, 0xFFF48FB1, 0xFF80DEEA, 0xFFFFF176, 0xFFFFFFFF,
  ]);
}

Puzzle xMusicShow(String id, int n) {
  const dark = 0, led = 1, ledLight = 2, stage = 3, stageEdge = 4, skin = 5, eye = 6, blush = 7, outfit = 8, trim = 9;
  const hairA = 10, hairB = 11, hairC = 12, spot = 13, spark = 14;
  final c = ArtCanvas(n, n, background: dark);
  c.rect(0.04, 0.04, 0.96, 0.6, led);
  c.fill((x, y) => x > 0.04 && x < 0.96 && y > 0.04 && y < 0.6 && c.noise(x, y, 8) < 0.2, ledLight);
  c.fill((x, y) => x > 0.04 && x < 0.96 && y > 0.04 && y < 0.6 && (c.col(x) % 4 == 0 || c.row(y) % 4 == 0), dark);
  for (final x0 in const [0.25, 0.5, 0.75]) {
    c.polygon([(x0 - 0.03, 0), (x0 + 0.03, 0), (x0 + 0.14, 0.72), (x0 - 0.14, 0.72)], spot);
  }
  c.rect(0, 0.7, 1, 1, stage);
  c.rect(0, 0.7, 1, 0.73, stageEdge);
  c.fill((x, y) => y > 0.73 && c.noise(x, y, 2) < 0.05, spark);
  for (final (cx, hair, style, dy) in [(0.25, hairA, 1, 0.0), (0.5, hairB, 2, -0.05), (0.75, hairC, 0, 0.0)]) {
    _idolBody(c, cx, 0.55 + dy, 0.12, 0.74, outfit, trim: trim);
    _idolHead(c, cx, 0.42 + dy, 0.12, _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: outfit), style: style, skin: skin);
  }
  return c.toPuzzle(id: id, title: 'Music Show', palette: const [
    0xFF120C2E, 0xFF5E35B1, 0xFFB388FF, 0xFF26203F, 0xFF7E57C2, _skin, 0xFF2E2233, 0xFFFF8A80, 0xFFFFFFFF, //
    0xFFF48FB1, 0xFF7C4DFF, 0xFFFF80AB, 0xFF4FC3F7, 0xFF2E2560, 0xFFFFF176,
  ]);
}

Puzzle xFanCafe(String id, int n) {
  const wall = 0, table = 1, tableEdge = 2, album = 3, albumDark = 4, card = 5, skin = 6, eye = 7, blush = 8;
  const hair = 9, cup = 10, tea = 11, pearl = 12, handle = 13, glow = 14, core = 15, spark = 16;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => c.noise(x, y, 13) < 0.03, spark);
  c.rect(0, 0.55, 1, 1, table);
  c.rect(0, 0.55, 1, 0.58, tableEdge);
  // Albums leaning on the wall.
  c.rect(0.06, 0.26, 0.34, 0.56, albumDark);
  c.rect(0.06, 0.26, 0.31, 0.53, album);
  c.heart(0.18, 0.4, 0.07, albumDark);
  c.rect(0.4, 0.3, 0.64, 0.56, albumDark);
  c.rect(0.4, 0.3, 0.61, 0.53, card);
  _idolHead(c, 0.5, 0.42, 0.07, const _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: album), skin: skin);
  // Lightstick lying on the table.
  _lightstick(c, 0.76, 0.42, 0.34, handle: handle, grip: albumDark, glow: glow, core: core, halo: null);
  // Photocards fanned on the table.
  for (var i = 0; i < 3; i++) {
    final x = 0.12 + i * 0.1;
    c.rect(x, 0.66, x + 0.12, 0.84, albumDark);
    c.rect(x + 0.01, 0.67, x + 0.11, 0.83, card);
    _idolHead(c, x + 0.06, 0.74, 0.035, const _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: album), skin: skin, style: i);
  }
  // Boba tea.
  c.polygon(const [(0.62, 0.62), (0.84, 0.62), (0.81, 0.92), (0.65, 0.92)], cup);
  c.polygon(const [(0.63, 0.68), (0.83, 0.68), (0.81, 0.92), (0.65, 0.92)], tea);
  for (final (x, y) in const [(0.68, 0.88), (0.73, 0.89), (0.78, 0.88), (0.7, 0.84), (0.76, 0.84)]) {
    c.circle(x, y, 0.018, pearl);
  }
  c.rect(0.74, 0.5, 0.76, 0.75, pearl);
  return c.toPuzzle(id: id, title: 'Fan Café', palette: const [
    0xFFFFF3F7, 0xFFD7B899, 0xFFB08968, 0xFFCE93D8, 0xFF8E24AA, 0xFFFFFFFF, _skin, 0xFF2E2233, 0xFFFF8A80, //
    0xFF7C4DFF, 0xFFE1F5FE, 0xFFD7B899, 0xFF3E2723, 0xFFECEFF1, 0xFFF48FB1, 0xFFFFFFFF, 0xFFFFD54F,
  ]);
}

Puzzle xAwardNight(String id, int n) {
  const bg = 0, carpet = 1, carpetEdge = 2, trophy = 3, trophyDark = 4, base = 5, skin = 6, eye = 7, blush = 8;
  const hairA = 9, hairB = 10, outfit = 11, trim = 12, confA = 13, confB = 14, spot = 15;
  final c = ArtCanvas(n, n, background: bg);
  c.polygon(const [(0.5, 0), (0.5, 0), (0.95, 0.75), (0.05, 0.75)], spot);
  c.fill((x, y) => c.noise(x, y, 17) < 0.04, confA);
  c.fill((x, y) => c.noise(x, y, 19) < 0.03, confB);
  c.polygon(const [(0.3, 0.72), (0.7, 0.72), (1, 1), (0, 1)], carpet);
  c.polygon(const [(0.3, 0.72), (0.7, 0.72), (0.72, 0.75), (0.28, 0.75)], carpetEdge);
  // Trophy in the middle, idols either side.
  c.rect(0.42, 0.6, 0.58, 0.66, base);
  c.rect(0.47, 0.5, 0.53, 0.6, trophyDark);
  c.fillShaded(ArtCanvas.inEllipse(0.5, 0.36, 0.11, 0.15), 0.5, 0.36, 0.13, const [trophyDark, trophy, trophy]);
  c.fill((x, y) => ArtCanvas.inEllipse(0.5, 0.36, 0.11, 0.15)(x, y) && y < 0.3, bg);
  c.rect(0.38, 0.28, 0.62, 0.31, trophy);
  c.star(0.5, 0.4, 0.045, 0.02, 5, base);
  for (final (cx, hair, style) in [(0.2, hairA, 2), (0.8, hairB, 3)]) {
    _idolBody(c, cx, 0.62, 0.13, 0.9, outfit, trim: trim);
    _idolHead(c, cx, 0.48, 0.13, _Idol(hair: hair, hairDark: hair, eye: eye, blush: blush, outfit: outfit), style: style, skin: skin, cap: trim);
  }
  return c.toPuzzle(id: id, title: 'Award Night', palette: const [
    0xFF1A1033, 0xFFC62828, 0xFFE57373, 0xFFFFD54F, 0xFFF9A825, 0xFF5D4037, _skin, 0xFF2E2233, 0xFFFF8A80, //
    0xFFFF80AB, 0xFF37474F, 0xFF212121, 0xFFF48FB1, 0xFFFFF176, 0xFF80DEEA, 0xFF2A1D52,
  ]);
}

Puzzle xEncoreFireworks(String id, int n) {
  const sky = 0, star = 1, fwA = 2, fwB = 3, fwC = 4, stage = 5, stageEdge = 6, head = 7, glowA = 8, glowB = 9;
  const idol = 10, beam = 11;
  final c = ArtCanvas(n, n, background: sky);
  c.fill((x, y) => y < 0.6 && c.noise(x, y, 23) < 0.025, star);
  for (final (cx, cy, r, col) in const [(0.25, 0.22, 0.16, fwA), (0.68, 0.16, 0.2, fwB), (0.5, 0.4, 0.12, fwC), (0.88, 0.4, 0.1, fwA)]) {
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      c.line(cx + math.cos(a) * r * 0.3, cy + math.sin(a) * r * 0.3, cx + math.cos(a) * r, cy + math.sin(a) * r, r * 0.12, col);
      c.circle(cx + math.cos(a) * r, cy + math.sin(a) * r, r * 0.1, star);
    }
    c.circle(cx, cy, r * 0.12, star);
  }
  for (final x0 in const [0.35, 0.65]) {
    c.polygon([(x0 - 0.03, 0.72), (x0 + 0.03, 0.72), (x0 + 0.1 * (x0 < 0.5 ? -1 : 1), 0.45), (x0 + 0.18 * (x0 < 0.5 ? -1 : 1), 0.45)], beam);
  }
  c.rect(0.1, 0.7, 0.9, 0.76, stage);
  c.rect(0.1, 0.7, 0.9, 0.72, stageEdge);
  for (final cx in const [0.4, 0.5, 0.6]) {
    c.circle(cx, 0.63, 0.03, idol);
    c.rect(cx - 0.02, 0.66, cx + 0.02, 0.71, idol);
  }
  _crowd(c, 0.94, 14, head: head, glows: const [glowA, glowB], seed: 1);
  _crowd(c, 0.86, 18, head: head, glows: const [glowA, glowB]);
  return c.toPuzzle(id: id, title: 'Encore Fireworks', palette: const [
    0xFF0D0B26, 0xFFFFFFFF, 0xFFFF80AB, 0xFFFFD54F, 0xFF80DEEA, 0xFF4A3B8C, 0xFF7E57C2, 0xFF050410, //
    0xFFF48FB1, 0xFFB388FF, 0xFFFFFFFF, 0xFF2E2560,
  ]);
}
