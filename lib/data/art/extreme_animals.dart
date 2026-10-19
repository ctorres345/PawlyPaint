import 'dart:math' as math;

import '../../models/puzzle.dart';
import '../art_canvas.dart';

// ---- Extreme (Animal Friends) -----------------------------------------------

Puzzle xHamster(String id, int n) {
  const wall = 0, wallDot = 1, table = 2, tableDark = 3, cup = 4, cupShade = 5, cupBlue = 6, rim = 7;
  const fur = 8, furDark = 9, belly = 10, pink = 11, eye = 12, seed = 13, steam = cupShade;
  final c = ArtCanvas(n, n, background: wall);
  c.fill((x, y) => (c.col(x) + ((c.row(y) ~/ 4).isEven ? 0 : 2)) % 4 == 0 && c.row(y) % 4 == 1, wallDot);
  c.rect(0, 0.74, 1, 1, table);
  c.fill((x, y) => y > 0.74 && (c.col(x) ~/ 3 + c.row(y) ~/ 3).isEven, tableDark);
  // Saucer.
  c.ellipse(0.5, 0.88, 0.42, 0.08, cupShade);
  c.ellipse(0.5, 0.87, 0.4, 0.065, cup);
  c.ellipse(0.5, 0.87, 0.36, 0.05, rim);
  c.ellipse(0.5, 0.87, 0.33, 0.04, cup);
  // Back of the cup and the hamster inside it.
  c.ellipse(0.5, 0.56, 0.3, 0.06, rim);
  c.ellipse(0.5, 0.56, 0.27, 0.045, cupShade);
  for (final x in const [0.33, 0.67]) {
    c.circle(x, 0.28, 0.07, furDark);
    c.circle(x, 0.29, 0.04, pink);
  }
  final head = ArtCanvas.inEllipse(0.5, 0.45, 0.22, 0.17);
  c.fillShaded(head, 0.5, 0.45, 0.22, const [furDark, fur, fur, fur]);
  c.ellipse(0.5, 0.52, 0.15, 0.09, belly);
  c.ellipse(0.5, 0.38, 0.04, 0.06, belly);
  for (final x in const [0.4, 0.6]) {
    c.circle(x, 0.43, 0.035, eye);
    c.dot(x - 0.01, 0.42, cup);
  }
  c.ellipse(0.5, 0.48, 0.025, 0.018, pink);
  c.circle(0.33, 0.5, 0.03, pink);
  c.circle(0.67, 0.5, 0.03, pink);
  // Seed held in both paws.
  c.ellipse(0.5, 0.57, 0.03, 0.05, seed);
  c.line(0.5, 0.54, 0.5, 0.6, 0.012, belly);
  c.circle(0.44, 0.58, 0.03, pink);
  c.circle(0.56, 0.58, 0.03, pink);
  // Front of the cup.
  final bowl = ArtCanvas.inEllipse(0.5, 0.58, 0.3, 0.26);
  c.ring(0.82, 0.68, 0.04, 0.08, cup);
  c.fill((x, y) => bowl(x, y) && y > 0.59, cup);
  c.fill((x, y) => bowl(x, y) && y > 0.59 && x > 0.64, cupShade);
  c.fill((x, y) => bowl(x, y) && y > 0.59 && y < 0.62, rim);
  for (final x in const [0.32, 0.44, 0.56, 0.68]) {
    c.heart(x, 0.71, 0.04, cupBlue);
  }
  // Steam curls and loose seeds.
  c.line(0.18, 0.3, 0.14, 0.2, 0.025, steam);
  c.line(0.14, 0.2, 0.18, 0.12, 0.025, steam);
  c.line(0.84, 0.28, 0.88, 0.18, 0.025, steam);
  for (final (x, y, a) in const [(0.1, 0.92, 0.5), (0.88, 0.95, -0.6), (0.95, 0.82, 0.2)]) {
    c.ellipse(x, y, 0.035, 0.02, seed, angle: a);
  }
  return c.toPuzzle(id: id, title: 'Teacup Hamster', palette: const [
    0xFFFDE3E6, 0xFFF6BCC6, 0xFF9ED6C3, 0xFF5FA88F, 0xFFFFFFFF, 0xFFCBD5EA, 0xFF5E8FE0, 0xFFF0C531, //
    0xFFF2B26A, 0xFFC4793A, 0xFFFFF0D2, 0xFFF48CA6, 0xFF2A2025, 0xFF4A3D36,
  ]);
}

Puzzle xKoala(String id, int n) {
  const sky = 0, skyLow = 1, sun = 2, leaf = 3, leafDark = 4, leafLight = 5, bark = 6, barkDark = 7;
  const fur = 8, furDark = 9, furLight = 10, white = 11, nose = 12, cheek = 13, flower = 14, cloud = white;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.55, 1, 1, skyLow);
  c.circle(0.12, 0.12, 0.08, sun);
  c.ellipse(0.8, 0.82, 0.14, 0.04, cloud);
  c.circle(0.78, 0.79, 0.05, cloud);
  // Trunk, leaning a little.
  final trunk = ArtCanvas.inPolygon(const [(0.58, 0), (0.78, 0), (0.8, 1), (0.6, 1)]);
  c.fill(trunk, bark);
  c.fill((x, y) => trunk(x, y) && (x > 0.74 || (c.row(y) % 6 == 0 && x > 0.66)), barkDark);
  // Branch with eucalyptus leaves.
  c.line(0.6, 0.22, 0.12, 0.42, 0.04, barkDark);
  c.line(0.78, 0.6, 1.0, 0.5, 0.035, barkDark);
  for (final (x, y, a, col) in const [
    (0.2, 0.34, -0.9, leaf),
    (0.3, 0.42, 0.6, leafDark),
    (0.12, 0.48, 0.9, leafLight),
    (0.4, 0.28, -0.7, leafLight),
    (0.06, 0.38, -0.3, leafDark),
    (0.92, 0.44, -0.8, leaf),
    (0.94, 0.6, 0.5, leafLight),
    (0.86, 0.2, 0.7, leafDark),
    (0.94, 0.08, -0.5, leaf),
  ]) {
    c.ellipse(x, y, 0.035, 0.08, col, angle: a);
  }
  // Body hugging the trunk.
  final body = ArtCanvas.inEllipse(0.5, 0.68, 0.18, 0.2);
  c.fillShaded(body, 0.5, 0.68, 0.18, const [furDark, fur, fur, furLight]);
  c.ellipse(0.46, 0.72, 0.1, 0.13, furLight);
  c.ellipse(0.42, 0.9, 0.08, 0.05, fur);
  c.ellipse(0.66, 0.6, 0.13, 0.05, fur, angle: -0.3);
  c.ellipse(0.68, 0.8, 0.12, 0.05, furDark, angle: 0.2);
  c.circle(0.77, 0.57, 0.035, furDark);
  // Head with big fluffy ears.
  for (final x in const [0.26, 0.62]) {
    c.circle(x, 0.24, 0.11, fur);
    c.circle(x, 0.25, 0.065, white);
  }
  final head = ArtCanvas.inEllipse(0.44, 0.38, 0.2, 0.16);
  c.fillShaded(head, 0.44, 0.38, 0.2, const [furDark, fur, fur, furLight]);
  c.ellipse(0.44, 0.42, 0.055, 0.075, nose);
  c.dot(0.43, 0.38, furDark);
  for (final x in const [0.33, 0.55]) {
    c.line(x - 0.03, 0.36, x + 0.03, 0.36, 0.022, nose);
  }
  c.circle(0.29, 0.44, 0.03, cheek);
  c.circle(0.59, 0.44, 0.03, cheek);
  for (final (x, y) in const [(0.05, 0.36), (0.9, 0.3), (0.98, 0.56)]) {
    c.circle(x, y, 0.025, flower);
  }
  return c.toPuzzle(id: id, title: 'Sleepy Koala', palette: const [
    0xFF86CBF0, 0xFFD3EEFA, 0xFFFFD866, 0xFF6FAE6A, 0xFF3F7A54, 0xFFA6D49A, 0xFFB79B80, 0xFF7C6250, //
    0xFF9AA0AC, 0xFF6C7180, 0xFFC4C8D2, 0xFFFFFFFF, 0xFF33303A, 0xFFF4A3B4, 0xFFF06AA0,
  ]);
}

Puzzle xOtter(String id, int n) {
  const sky = 0, skyLow = 1, sun = 2, water = 3, waterMid = 4, waterDeep = 5, ripple = 6, otter = 7;
  const otterDark = 8, otterLight = 9, face = 10, nose = 11, shell = 12, shellDark = 13, kelp = 14, kelpDark = 15;
  final c = ArtCanvas(n, n, background: sky);
  c.rect(0, 0.2, 1, 0.38, skyLow);
  c.circle(0.8, 0.3, 0.1, sun);
  c.bands(const [water, waterMid, waterDeep], top: 0.36, bottom: 1);
  c.fill((x, y) => y > 0.36 && c.row(y) % 4 == 2 && (c.col(x) + c.row(y)) % 7 < 3, ripple);
  // Kelp swaying below.
  for (final (x0, col) in const [(0.08, kelp), (0.92, kelpDark), (0.2, kelpDark)]) {
    c.fill((x, y) => y > 0.72 && (x - x0 - 0.03 * math.sin(y * 18)).abs() < 0.018, col);
    for (var i = 0; i < 3; i++) {
      final y = 0.8 + i * 0.07;
      c.ellipse(x0 + 0.03 * math.sin(y * 18) + (i.isEven ? 0.03 : -0.03), y, 0.03, 0.015, col,
          angle: i.isEven ? -0.5 : 0.5);
    }
  }
  // Seagulls.
  for (final (x, y) in const [(0.3, 0.12), (0.42, 0.18)]) {
    c.line(x - 0.04, y + 0.02, x, y, 0.03, nose);
    c.line(x, y, x + 0.04, y + 0.02, 0.03, nose);
  }
  // Otter floating on its back: tail first, then body, feet and head.
  c.ellipse(0.86, 0.62, 0.11, 0.03, otterDark, angle: -0.15);
  final body = ArtCanvas.inEllipse(0.52, 0.58, 0.28, 0.09, angle: -0.05);
  c.fillShaded(body, 0.52, 0.58, 0.28, const [otterDark, otter, otter, otterLight], lightX: 0, lightY: -1);
  c.ellipse(0.52, 0.54, 0.17, 0.045, otterLight, angle: -0.05);
  for (final (x, a) in const [(0.7, 0.2), (0.77, 0.5)]) {
    c.ellipse(x, 0.47, 0.025, 0.05, otterDark, angle: a);
    c.ellipse(x + 0.01, 0.43, 0.03, 0.02, otterLight, angle: a);
  }
  c.circle(0.13, 0.4, 0.035, otterDark);
  c.circle(0.31, 0.4, 0.035, otterDark);
  final head = ArtCanvas.inCircle(0.22, 0.49, 0.12);
  c.fillShaded(head, 0.22, 0.49, 0.12, const [otterLight, face, face]);
  c.ring(0.22, 0.49, 0.105, 0.125, otter);
  c.rect(0.155, 0.45, 0.18, 0.49, nose);
  c.rect(0.255, 0.45, 0.28, 0.49, nose);
  c.ellipse(0.22, 0.525, 0.035, 0.02, nose);
  c.dot(0.22, 0.56, otterLight);
  // Shell held on the tummy.
  final sh = ArtCanvas.inEllipse(0.46, 0.47, 0.065, 0.05);
  c.fill(sh, shell);
  c.fill((x, y) => sh(x, y) && c.col(x) % 2 == 1, shellDark);
  c.ellipse(0.39, 0.5, 0.03, 0.022, otterDark);
  c.ellipse(0.53, 0.5, 0.03, 0.022, otterDark);
  // Water lapping over the body.
  c.fill((x, y) => y > 0.63 && y < 0.67 && (c.col(x) % 6) < 3 && x > 0.06 && x < 0.97, ripple);
  return c.toPuzzle(id: id, title: 'Otter Float', palette: const [
    0xFFFFD9B0, 0xFFFFB98C, 0xFFFF8F45, 0xFF5BBFE0, 0xFF2F8FC4, 0xFF1C5A8E, 0xFFC4EEF8, 0xFF8A5A3B, //
    0xFF553522, 0xFFB98A5E, 0xFFFFF6EA, 0xFF241A16, 0xFFF79AB4, 0xFFCC5C7E, 0xFF5BAA5C, 0xFF2E7448,
  ]);
}

Puzzle xLion(String id, int n) {
  const skyTop = 0, skyMid = 1, skyLow = 2, sun = 3, grass = 4, grassDark = 5, tree = 6, mane = 7;
  const maneDark = 8, fur = 9, furShade = 10, muzzle = 11, wing = 12, bird = 13, flower = 14;
  const nose = maneDark, eye = tree;
  final c = ArtCanvas(n, n, background: skyTop);
  c.bands(const [skyTop, skyMid, skyLow], bottom: 0.66);
  c.circle(0.5, 0.62, 0.2, sun);
  // Acacia trees on the horizon.
  for (final (x, s) in const [(0.12, 1.0), (0.88, 0.8)]) {
    c.line(x, 0.68, x, 0.52 + 0.06 * (1 - s), 0.025, tree);
    c.ellipse(x, 0.5 + 0.06 * (1 - s), 0.12 * s, 0.04 * s, tree);
  }
  c.rect(0, 0.66, 1, 1, grass);
  c.fill((x, y) => y > 0.66 && c.noise(x, y, 11) < 0.18, grassDark);
  for (final (x, y) in const [(0.06, 0.8), (0.14, 0.92), (0.9, 0.86), (0.96, 0.96), (0.8, 0.95)]) {
    c.dot(x, y, flower);
    c.dot(x, y - 0.025, sun);
  }
  c.dot(0.25, 0.2, bird);
  c.dot(0.275, 0.21, bird);
  c.dot(0.225, 0.21, bird);
  // Mane: a ring of rounded tufts.
  c.polygon(ArtCanvas.starPoints(0.5, 0.5, 0.38, 0.3, 12, rotation: 0.2), maneDark);
  c.circle(0.5, 0.5, 0.32, mane);
  c.fill((x, y) => ArtCanvas.inCircle(0.5, 0.5, 0.32)(x, y) && c.noise(x, y, 4) < 0.15, maneDark);
  // Ears and face.
  for (final x in const [0.32, 0.68]) {
    c.circle(x, 0.3, 0.07, fur);
    c.circle(x, 0.31, 0.035, maneDark);
  }
  final face = ArtCanvas.inEllipse(0.5, 0.5, 0.22, 0.21);
  c.fillShaded(face, 0.5, 0.5, 0.22, const [furShade, fur, fur, fur]);
  c.ellipse(0.43, 0.62, 0.08, 0.065, muzzle);
  c.ellipse(0.57, 0.62, 0.08, 0.065, muzzle);
  c.ellipse(0.5, 0.7, 0.06, 0.04, muzzle);
  c.polygon(const [(0.44, 0.54), (0.56, 0.54), (0.5, 0.6)], nose);
  c.line(0.5, 0.59, 0.5, 0.64, 0.02, nose);
  for (final x in const [0.4, 0.6]) {
    c.ellipse(x, 0.46, 0.035, 0.045, eye);
    c.dot(x - 0.01, 0.445, muzzle);
  }
  // A butterfly resting on the mane.
  c.ellipse(0.8, 0.24, 0.035, 0.03, wing, angle: 0.5);
  c.ellipse(0.86, 0.22, 0.035, 0.03, wing, angle: -0.5);
  c.ellipse(0.82, 0.29, 0.025, 0.02, wing);
  c.line(0.83, 0.2, 0.83, 0.3, 0.02, bird);
  c.ellipse(0.4, 0.39, 0.04, 0.012, furShade);
  c.ellipse(0.6, 0.39, 0.04, 0.012, furShade);
  return c.toPuzzle(id: id, title: 'Little Lion', palette: const [
    0xFFA898E0, 0xFFF4A3BC, 0xFFFFD6A6, 0xFFFFE466, 0xFFAFA84A, 0xFF7E7A2E, 0xFF4A3328, 0xFFC9602C, //
    0xFF8A3A1B, 0xFFF2B04E, 0xFFD48A34, 0xFFFFF1D6, 0xFF5BB0E8, 0xFF5A4A70, 0xFFE84A8A,
  ]);
}

Puzzle xFawn(String id, int n) {
  const glow = 0, treeFar = 1, treeMid = 2, trunk = 3, grass = 4, grassDark = 5, fawn = 6, fawnDark = 7;
  const spot = 8, eye = 9, earIn = 10, cap = 11, purple = 12, yellow = 13, stem = spot, beam = spot;
  final c = ArtCanvas(n, n, background: glow);
  // Forest backdrop.
  for (var i = 0; i < 7; i++) {
    final x = i * 0.17;
    c.ellipse(x, 0.3, 0.12, 0.3, treeFar);
  }
  for (final x in const [0.06, 0.94, 0.72]) {
    c.rect(x - 0.04, 0, x + 0.04, 0.7, trunk);
    c.circle(x, 0.08, 0.15, treeMid);
  }
  c.fill((x, y) => y < 0.7 && (x - y * 0.5 - 0.28).abs() < 0.04, beam);
  c.fill((x, y) => y < 0.7 && (x - y * 0.5 - 0.42).abs() < 0.025, beam);
  c.rect(0, 0.66, 1, 1, grass);
  c.fill((x, y) => y > 0.66 && c.noise(x, y, 5) < 0.18, grassDark);
  // Fawn, facing left.
  for (final (x1, x2) in const [(0.44, 0.42), (0.5, 0.5), (0.66, 0.68), (0.72, 0.74)]) {
    c.line(x1, 0.66, x2, 0.88, 0.035, x1 == 0.5 || x1 == 0.72 ? fawnDark : fawn);
    c.dot(x2, 0.88, eye);
  }
  c.ellipse(0.79, 0.52, 0.035, 0.03, spot);
  final body = ArtCanvas.inEllipse(0.59, 0.58, 0.2, 0.1);
  c.fillShaded(body, 0.59, 0.58, 0.2, const [fawnDark, fawn, fawn, fawn]);
  c.ellipse(0.58, 0.64, 0.14, 0.03, spot);
  for (final (x, y) in const [(0.52, 0.52), (0.6, 0.5), (0.68, 0.53), (0.56, 0.57), (0.64, 0.58), (0.74, 0.57)]) {
    c.dot(x, y, spot);
  }
  c.polygon(const [(0.38, 0.6), (0.3, 0.36), (0.4, 0.33), (0.5, 0.56)], fawn);
  c.ellipse(0.33, 0.33, 0.08, 0.065, fawn, angle: -0.3);
  c.ellipse(0.26, 0.37, 0.04, 0.03, fawnDark, angle: -0.3);
  c.dot(0.23, 0.37, eye);
  c.ellipse(0.42, 0.25, 0.06, 0.025, fawnDark, angle: -0.5);
  c.ellipse(0.42, 0.25, 0.04, 0.012, earIn, angle: -0.5);
  c.circle(0.32, 0.31, 0.02, eye);
  c.ellipse(0.34, 0.4, 0.03, 0.04, spot);
  // Mushrooms and flowers in the grass.
  for (final (x, y, s) in const [(0.12, 0.84, 1.0), (0.2, 0.9, 0.7), (0.9, 0.86, 0.9)]) {
    c.rect(x - 0.015 * s, y - 0.04 * s, x + 0.015 * s, y + 0.02, stem);
    c.fill((xx, yy) => ArtCanvas.inEllipse(x, y - 0.04 * s, 0.06 * s, 0.045 * s)(xx, yy) && yy < y - 0.035 * s, cap);
    c.dot(x - 0.02 * s, y - 0.06 * s, spot);
  }
  for (final (x, y, col) in const [
    (0.32, 0.94, purple),
    (0.58, 0.95, yellow),
    (0.82, 0.96, purple),
    (0.04, 0.72, yellow)
  ]) {
    c.circle(x, y, 0.025, col);
  }
  return c.toPuzzle(id: id, title: 'Forest Fawn', palette: const [
    0xFFD6EAB0, 0xFF7FB39A, 0xFF3E7046, 0xFF5E4232, 0xFF9CD06C, 0xFF6EA84C, 0xFFD08C4E, 0xFF96582C, //
    0xFFFFF8EA, 0xFF2A1E1A, 0xFFF4B4A6, 0xFFE0443A, 0xFFA77BDB, 0xFFFFD84D,
  ]);
}
