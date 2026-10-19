import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import '../models/puzzle.dart';

/// Makes a picture easier to read: a plain background and clearly distinct
/// colors.
///
/// 1. Backdrop decoration (dots, stripes and speckles sitting on the
///    background, the most common color on the border) is painted over with
///    the background.
/// 2. Any two other colors closer than [minDistance] (CIE Lab ΔE) are merged,
///    the smaller group taking the larger one's color.
/// 3. If a color is still that close to the background, the background is
///    lightened or darkened away from it, so shapes never blend into it.
///
/// Never goes below [minColors] colors.
Puzzle simplifyPicture(Puzzle p, {required double minDistance, int minColors = 3}) {
  final n = p.colorCount;
  final lab = [for (final c in p.palette) _lab(c)];
  final bg = _borderColor(p);
  var cells = Uint8List.fromList(p.cells);
  final flat = _flattenBackdrop(cells, p.width, n, bg);
  if (_used(flat, n).where((u) => u).length >= minColors) cells = flat;

  final alive = _used(cells, n);
  final counts = List<int>.filled(n, 0);
  for (final c in cells) {
    counts[c]++;
  }
  var colors = alive.where((a) => a).length;
  // Texture in the background's tone may merge into it; shapes may not.
  final mayJoinBackground = [
    for (var c = 0; c < n; c++) c != bg && alive[c] && _isTexture(cells, p.width, c, bg),
  ];

  // Closest pair first, until every pair is at least minDistance apart.
  // Two shapes only merge when they share a real border (shades of one
  // object), so a white petal never turns into the pale sky behind it.
  while (colors > minColors) {
    final touching = _touching(cells, p.width, n);
    var bestA = -1, bestB = -1;
    var best = minDistance;
    for (var a = 0; a < n; a++) {
      if (!alive[a] || (a == bg && !mayJoinBackground.any((m) => m))) continue;
      for (var b = a + 1; b < n; b++) {
        if (!alive[b]) continue;
        final small = counts[a] <= counts[b] ? a : b;
        final blocked = a == bg || b == bg
            ? !mayJoinBackground[a == bg ? b : a]
            : touching[small][small == a ? b : a] * 4 < counts[small];
        if (blocked) continue;
        final d = _distance(lab[a], lab[b]);
        if (d < best) (best, bestA, bestB) = (d, a, b);
      }
    }
    if (bestA < 0) break;
    // The background always survives; otherwise the bigger group does.
    final keepA = bestA == bg || (bestB != bg && counts[bestA] >= counts[bestB]);
    final (keep, drop) = keepA ? (bestA, bestB) : (bestB, bestA);
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == drop) cells[i] = keep;
    }
    counts[keep] += counts[drop];
    alive[drop] = false;
    colors--;
  }

  // Nudge the background's lightness a little away from a color it nearly
  // matches, as long as that doesn't bring it closer to any other color.
  double nearest((double, double, double) to) {
    var d = double.infinity;
    for (var c = 0; c < n; c++) {
      if (c != bg && alive[c]) d = math.min(d, _distance(lab[c], to));
    }
    return d;
  }

  var bgLab = lab[bg];
  for (var step = 0; step < 4 && nearest(bgLab) < 12; step++) {
    final closest = [
      for (var c = 0; c < n; c++)
        if (c != bg && alive[c]) c,
    ].reduce((a, b) => _distance(lab[a], bgLab) <= _distance(lab[b], bgLab) ? a : b);
    final l = bgLab.$1 + (bgLab.$1 >= lab[closest].$1 ? 3 : -3);
    final next = (l, bgLab.$2, bgLab.$3);
    if (l < 5 || l > 98 || nearest(next) <= nearest(bgLab)) break;
    bgLab = next;
  }

  final remap = List<int>.filled(n, -1);
  final palette = <Color>[];
  for (var i = 0; i < n; i++) {
    if (!alive[i]) continue;
    remap[i] = palette.length;
    palette.add(i == bg && bgLab != lab[bg] ? _fromLab(bgLab, p.palette[i]) : p.palette[i]);
  }
  for (var i = 0; i < cells.length; i++) {
    cells[i] = remap[cells[i]];
  }
  return Puzzle(id: p.id, title: p.title, width: p.width, height: p.height, cells: cells, palette: palette);
}

List<bool> _used(Uint8List cells, int n) {
  final used = List<bool>.filled(n, false);
  for (final c in cells) {
    used[c] = true;
  }
  return used;
}

/// A copy of [cells] with backdrop decoration painted over with [bg]: every
/// color that is [_isSpeckle], and every patch of up to 3 cells whose
/// side neighbors are all background.
Uint8List _flattenBackdrop(Uint8List cells, int width, int n, int bg) {
  final out = Uint8List.fromList(cells);
  for (var c = 0; c < n; c++) {
    if (c == bg || !_isSpeckle(cells, width, c, bg)) continue;
    for (var i = 0; i < out.length; i++) {
      if (out[i] == c) out[i] = bg;
    }
  }
  for (final patch in _patches(out, width)) {
    if (patch.length > 3 || out[patch.first] == bg) continue;
    final inPatch = patch.toSet();
    final surrounded =
        patch.every((i) => _neighbors(i, width, out.length).every((j) => inPatch.contains(j) || out[j] == bg));
    if (surrounded) {
      for (final i in patch) {
        out[i] = bg;
      }
    }
  }
  return out;
}

/// Side neighbors of cell [i].
List<int> _neighbors(int i, int width, int length) {
  final x = i % width;
  return [if (x > 0) i - 1, if (x < width - 1) i + 1, if (i >= width) i - width, if (i + width < length) i + width];
}

/// Side-connected patches of one color.
List<List<int>> _patches(Uint8List cells, int width) {
  final seen = Uint8List(cells.length);
  final patches = <List<int>>[];
  for (var start = 0; start < cells.length; start++) {
    if (seen[start] == 1) continue;
    seen[start] = 1;
    final patch = <int>[];
    final stack = [start];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      patch.add(i);
      for (final j in _neighbors(i, width, cells.length)) {
        if (seen[j] == 1 || cells[j] != cells[start]) continue;
        seen[j] = 1;
        stack.add(j);
      }
    }
    patches.add(patch);
  }
  return patches;
}

/// Whether [color] is backdrop decoration: repeated tiny patches (dots,
/// diagonal stripes, small checks; at least 3 patches of at most 4 cells on
/// average) that mostly sit on the background [bg] rather than on the
/// subject, like a highlight would.
bool _isSpeckle(Uint8List cells, int width, int color, int bg) {
  var total = 0, patches = 0, backdrop = 0;
  for (final patch in _patches(cells, width)) {
    if (cells[patch.first] != color) continue;
    patches++;
    total += patch.length;
    for (final i in patch) {
      final sitsOnBackdrop = _neighbors(i, width, cells.length).every((j) => cells[j] == color || cells[j] == bg);
      if (sitsOnBackdrop) backdrop++;
    }
  }
  return patches >= 3 && total / patches <= 4 && backdrop >= total * 0.7;
}

/// For each pair of colors (a, b), how many cells of a sit next to b.
List<List<int>> _touching(Uint8List cells, int width, int n) {
  final t = List.generate(n, (_) => List<int>.filled(n, 0));
  final seen = List<bool>.filled(n, false);
  for (var i = 0; i < cells.length; i++) {
    seen.fillRange(0, n, false);
    for (final j in _neighbors(i, width, cells.length)) {
      final c = cells[j];
      if (c != cells[i] && !seen[c]) {
        seen[c] = true;
        t[cells[i]][c]++;
      }
    }
  }
  return t;
}

/// Whether [color] is texture on the background [bg] (stone, skin or dirt
/// noise): broken into patches of at most 8 cells on average, with at least
/// a third of its cells right next to the background.
bool _isTexture(Uint8List cells, int width, int color, int bg) {
  var total = 0, patches = 0, touching = 0;
  for (final patch in _patches(cells, width)) {
    if (cells[patch.first] != color) continue;
    patches++;
    total += patch.length;
    for (final i in patch) {
      if (_neighbors(i, width, cells.length).any((j) => cells[j] == bg)) touching++;
    }
  }
  return patches > 0 && total / patches <= 8 && touching * 3 >= total;
}

/// The most common color along the edge of the picture.
int _borderColor(Puzzle p) {
  final counts = List<int>.filled(p.colorCount, 0);
  for (var x = 0; x < p.width; x++) {
    counts[p.cells[x]]++;
    counts[p.cells[(p.height - 1) * p.width + x]]++;
  }
  for (var y = 1; y < p.height - 1; y++) {
    counts[p.cells[y * p.width]]++;
    counts[p.cells[y * p.width + p.width - 1]]++;
  }
  var best = 0;
  for (var i = 1; i < counts.length; i++) {
    if (counts[i] > counts[best]) best = i;
  }
  return best;
}

double _distance((double, double, double) a, (double, double, double) b) {
  final dl = a.$1 - b.$1, da = a.$2 - b.$2, db = a.$3 - b.$3;
  return math.sqrt(dl * dl + da * da + db * db);
}

/// sRGB to CIE Lab (D65).
(double, double, double) _lab(Color c) {
  double lin(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  double f(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

/// CIE Lab (D65) back to sRGB, keeping [like]'s alpha.
Color _fromLab((double, double, double) lab, Color like) {
  final fy = (lab.$1 + 16) / 116, fx = fy + lab.$2 / 500, fz = fy - lab.$3 / 200;
  double inv(double t) => t * t * t > 0.008856 ? t * t * t : (t - 16 / 116) / 7.787;
  final x = inv(fx) * 0.95047, y = inv(fy), z = inv(fz) * 1.08883;
  double gamma(double v) =>
      (v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055).clamp(0.0, 1.0).toDouble();
  return Color.from(
    alpha: like.a,
    red: gamma(x * 3.2406 - y * 1.5372 - z * 0.4986),
    green: gamma(-x * 0.9689 + y * 1.8758 + z * 0.0415),
    blue: gamma(x * 0.0557 - y * 0.2040 + z * 1.0570),
  );
}

/// CIEDE2000 color difference between two Lab colors. About 2 is the
/// smallest difference people notice side by side; 10 and up reads as a
/// different color at a glance.
double _de2000((double, double, double) x, (double, double, double) y) {
  final (l1, a1, b1) = x;
  final (l2, a2, b2) = y;
  const rad = math.pi / 180;
  final c1 = math.sqrt(a1 * a1 + b1 * b1), c2 = math.sqrt(a2 * a2 + b2 * b2);
  final cm7 = math.pow((c1 + c2) / 2, 7).toDouble();
  final g = 0.5 * (1 - math.sqrt(cm7 / (cm7 + 6103515625.0)));
  final ap1 = a1 * (1 + g), ap2 = a2 * (1 + g);
  final cp1 = math.sqrt(ap1 * ap1 + b1 * b1), cp2 = math.sqrt(ap2 * ap2 + b2 * b2);
  double hue(double b, double a) {
    if (a == 0 && b == 0) return 0;
    final h = math.atan2(b, a) / rad;
    return h < 0 ? h + 360 : h;
  }

  final hp1 = hue(b1, ap1), hp2 = hue(b2, ap2);
  final dl = l2 - l1, dc = cp2 - cp1;
  var dh = 0.0;
  if (cp1 * cp2 != 0) {
    dh = hp2 - hp1;
    if (dh > 180) dh -= 360;
    if (dh < -180) dh += 360;
  }
  final dH = 2 * math.sqrt(cp1 * cp2) * math.sin(dh / 2 * rad);
  final lm = (l1 + l2) / 2, cm = (cp1 + cp2) / 2;
  var hm = hp1 + hp2;
  if (cp1 * cp2 != 0) {
    if ((hp1 - hp2).abs() > 180) hm += hm < 360 ? 360 : -360;
    hm /= 2;
  }
  final t = 1 -
      0.17 * math.cos((hm - 30) * rad) +
      0.24 * math.cos(2 * hm * rad) +
      0.32 * math.cos((3 * hm + 6) * rad) -
      0.20 * math.cos((4 * hm - 63) * rad);
  final dTheta = 30 * math.exp(-math.pow((hm - 275) / 25, 2));
  final cm7p = math.pow(cm, 7).toDouble();
  final rc = 2 * math.sqrt(cm7p / (cm7p + 6103515625.0));
  final sl = 1 + 0.015 * (lm - 50) * (lm - 50) / math.sqrt(20 + (lm - 50) * (lm - 50));
  final sc = 1 + 0.045 * cm, sh = 1 + 0.015 * cm * t;
  final rt = -math.sin(2 * dTheta * rad) * rc;
  final ql = dl / sl, qc = dc / sc, qh = dH / sh;
  return math.sqrt(ql * ql + qc * qc + qh * qh + rt * qc * qh);
}

/// CIEDE2000 difference between two colors.
double colorDistance(Color a, Color b) => _de2000(_lab(a), _lab(b));

const _minRgbGap = 24.0;

/// Straight-line distance between two Lab colors in 0–255 RGB.
double _rgbDistance((double, double, double) a, (double, double, double) b) {
  const black = Color(0xFF000000);
  final x = _fromLab(a, black), y = _fromLab(b, black);
  final dr = (x.r - y.r) * 255, dg = (x.g - y.g) * 255, db = (x.b - y.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// Pushes look-alike colors apart until every pair is at least [minDistance]
/// (CIEDE2000) and 24 RGB steps apart, so each drill color can be told from
/// the others at a glance. Cells stay as they are, so gradients keep their
/// steps, just with clearer differences between them. Bigger color groups
/// move less than small ones, so the picture keeps its overall look.
Puzzle separateColors(Puzzle p, {required double minDistance}) {
  final n = p.colorCount;
  final lab = [for (final c in p.palette) _lab(c)];
  final weight = [for (final c in p.counts) math.max(c, 1).toDouble()];
  // Colors stuck at the edge of what a screen can show (pure white, say)
  // can't move further, so their partner moves instead.
  final pinned = List<bool>.filled(n, false);
  for (var round = 0; round < 400; round++) {
    final push = List.generate(n, (_) => [0.0, 0.0, 0.0]);
    var tooClose = false;
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        final d = _de2000(lab[a], lab[b]);
        // CIEDE2000 forgives differences among very pale colors more than
        // small drills on a bright screen do, so plain RGB distance is
        // checked too.
        final rgb = _rgbDistance(lab[a], lab[b]);
        if (d >= minDistance && rgb >= _minRgbGap) continue;
        tooClose = true;
        var dir = [lab[b].$1 - lab[a].$1, lab[b].$2 - lab[a].$2, lab[b].$3 - lab[a].$3];
        var len = math.sqrt(dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2]);
        if (len < 1e-6) {
          // Identical colors: split them by lightness.
          dir = [lab[a].$1 > 50 ? -1.0 : 1.0, 0, 0];
          len = 1;
        }
        // Euclidean Lab step that would roughly close the gap, shared so
        // the smaller group moves further.
        final ratio = math.max(minDistance / math.max(d, 0.5), _minRgbGap / math.max(rgb, 0.5));
        final step = math.max(len * (ratio - 1), 0.5) * 0.5;
        final share = pinned[a] == pinned[b]
            ? weight[b] / (weight[a] + weight[b])
            : pinned[a]
                ? 0.0
                : 1.0;
        for (var k = 0; k < 3; k++) {
          push[a][k] -= dir[k] / len * step * share;
          push[b][k] += dir[k] / len * step * (1 - share);
        }
      }
    }
    if (!tooClose) break;
    for (var c = 0; c < n; c++) {
      final wanted = math.sqrt(push[c][0] * push[c][0] + push[c][1] * push[c][1] + push[c][2] * push[c][2]);
      if (wanted == 0) continue;
      final moved = (lab[c].$1 + push[c][0], lab[c].$2 + push[c][1], lab[c].$3 + push[c][2]);
      // Keep the color inside what a screen can show.
      final shown = _lab(_fromLab(moved, p.palette[c]));
      if (_distance(shown, lab[c]) < wanted * 0.3) pinned[c] = true;
      lab[c] = shown;
    }
  }
  final palette = [for (var c = 0; c < n; c++) _fromLab(lab[c], p.palette[c])];
  return Puzzle(id: p.id, title: p.title, width: p.width, height: p.height, cells: p.cells, palette: palette);
}
