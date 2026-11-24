"""Turns a generated pixel art picture into a PawlyPaint puzzle grid.

Image models draw pixel art on a block grid of their own, not the one the
prompt asks for, and a screen capture rescales it further. Splitting the image
evenly into the game's grid cuts across those blocks and breaks small details.
So this tool works in four steps:

1. Find the picture's own block grid (block size and offset): the largest
   block size on which the colour changes line up, on both axes.
2. Read one colour per block (the most common colour in its middle), giving
   the picture at its own resolution.
3. Crop to the subject: the square around every block that differs from a
   plain border colour, with one game cell of margin. Full scenes with no
   plain border keep the whole frame.
4. Cut the palette to the level's colour limit and its CIEDE2000 colour gap
   (the game's, lib/data/simplify.dart), shrink to the game grid (16, 24, 32
   or 40), then cut the palette again. A merge keeps the colour of its biggest
   member, so a pale subject doesn't drift into the background. Each cell
   takes the colour that covers most of it, except that a colour rare in the
   cells around it (an eye, a spot) wins a cell it covers enough of.

A source read at exactly the game grid keeps every block in place: crop keeps
it whole and shrink gives each cell its own block, so only the palette cut may
merge colours.

Fit mode (PAP-95, `fit = "subject"` or `"scene"`, or --fit) places a source
drawn near its grid 1:1 before that: a subject on a plain background whose box
fits the grid is padded with the background, a scene drawn at grid to grid+4
blocks is trimmed evenly. Anything else fails with its measured size. Sources
drawn at their grid (`exact` or `fit`) also get the region-safe colour cut: two
close colours that each fill a large region are pushed apart, not merged.
tool/pixel_gen.py makes such sources on a local ComfyUI server.

Needs Pillow. Run with a Python that has it, for example:
  python3 tool/art_to_puzzle.py in.png out.png --grid 16 --preview big.png
Prints the detected block size and the picture's own grid size. --colors
overrides the level's colour limit.

The asset manifest (design/assets.toml) lists every picture source: a puzzle
entry has `course`, `slug`, `grid` and optionally `exact = true` or `fit`, and
`prompt`, `seed` and `scale` from pixel_gen.py. --check
prints each source's block count (whole frame and subject square), converts
each at its own grid and exits non-zero if any fails (missing, no clean pixel
grid, an `exact` source not drawn at grid blocks across, too few or too
many colours, one colour over 95% of cells, two colours under the level's
gap, a subject that lost most of its cells against the native read, or a
built PNG in assets/pictures that is missing or out of date).
--build writes each to assets/pictures/<course>/<slug>.png. --all-grids
makes --check try every picture at all four grids (style spikes).
Tests: python3 -m unittest tool/test_art_to_puzzle.py
"""
import argparse
import bisect
import math
import os
import sys
import tomllib
from collections import Counter
from functools import lru_cache
from typing import NamedTuple

from PIL import Image, ImageFilter

# Two colour distances on purpose: edge finding wants a cheap test of "did
# the colour change at all", palette merging wants how alike two colours look.
EDGE = 48  # summed RGB difference that counts as a colour change
SHADE_MERGE = 9 * 18 ** 2  # _dist below which capture shades are one colour
INSET = 0.25  # part of each block edge skipped when reading its colour
# Game grid size per level -> the level's colour limit (design/brief.md).
COLOR_LIMIT = {16: 6, 24: 8, 32: 12, 40: 16}
LEVEL_GAP = {16: 18.0, 24: 16.0, 32: 14.0, 40: 12.0}
MIN_COLOURS = 3
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, 'design', 'assets.toml')
PICTURES = os.path.join(REPO, 'assets', 'pictures')
# Same floor as separateColors (lib/data/simplify.dart): colours closer than
# this in plain RGB look alike as drill colours.
MIN_RGB_GAP = 24.0
MAX_SHARE = 0.95  # --check: most of one colour means the subject vanished
PLAIN_BORDER = 0.6
PLAIN_BACKGROUND = 0.25
DETAIL_SHARE = 0.18
RARITY = 0.5
SUBJECT_KEPT = 0.5
HINT_MIN_COHERENCE = 0.9
HINT_MARGIN = 0.05
FIT_SUBJECT_MIN_SHARE = 0.7
FIT_SCENE_MAX_EXTRA_BLOCKS = 4
FIT_MODES = ('subject', 'scene')
CELL_PX_RANGE = (7, 16)
LARGE_REGION_SHARE = 0.05
SEPARATE_MAX_SHIFT = 2.0
SEPARATE_MAX_MOVES = 3
SEPARATE_STEP_LAB = 0.5
SEPARATE_MAX_WALK = 3
ON_LATTICE_TOLERANCE = 0.15
FEATURE_AREA_CELLS = (0.3, 7.0)
FEATURE_DE = 20.0
FEATURE_ENCLOSED = 0.8
FEATURE_CLASSES = 24
FEATURE_CLASS_DE = 6.0
FEATURE_REACH_CELLS = 0.5
FEATURE_AREA_RATIO = (0.5, 2.0)
FEATURE_BG_DE = 5.0
FEATURE_SYMMETRY = 0.8
FEATURE_SHAPE_CELLS = 2.5
FEATURE_PAIR_DE = 10.0
FEATURE_PAIR_AREA = 2.0
FEATURE_PAIR_CELLS = 6.0
FEATURE_PAIR_SHAPE = 0.5


def edge_profiles(img):
    """Counts colour changes between neighbouring columns and rows."""
    w, h = img.size
    data = img.tobytes()
    cols = [0] * w
    rows = [0] * h
    stride = w * 3
    for y in range(h):
        base = y * stride
        for x in range(1, w):
            i = base + x * 3
            if (abs(data[i] - data[i - 3]) + abs(data[i + 1] - data[i - 2])
                    + abs(data[i + 2] - data[i - 1])) > EDGE:
                cols[x] += 1
            if y and (abs(data[i] - data[i - stride])
                      + abs(data[i + 1] - data[i + 1 - stride])
                      + abs(data[i + 2] - data[i + 2 - stride])) > EDGE:
                rows[y] += 1
        # Column 0 is skipped above; it still counts for the rows.
        if y and (abs(data[base] - data[base - stride])
                  + abs(data[base + 1] - data[base + 1 - stride])
                  + abs(data[base + 2] - data[base + 2 - stride])) > EDGE:
            rows[y] += 1
    return cols, rows


def _coherence(edges, total, period):
    """How well the colour changes line up on a grid of this block size.

    Each change at x is a unit vector at angle 2*pi*x/period; on the true
    grid they all point the same way. `edges` is the (x, count) pairs with a
    change. Returns (strength 0..1, line offset).
    """
    if not total:
        return 0.0, 0.0
    c = s = 0.0
    k = 2 * math.pi / period
    for x, w in edges:
        c += w * math.cos(k * x)
        s += w * math.sin(k * x)
    phase = (math.atan2(s, c) / k) % period
    return math.hypot(c, s) / total, phase


def find_grid(cols, rows, min_block=4.0, max_cells=160, hint=None):
    """Returns (block size, x offset, y offset) of the picture's square grid,
    or None when the colour changes don't line up on any grid.

    Every divisor of the true block size lines up as well as the block
    itself, while multiples do not, so the answer is the largest block size
    that lines up nearly as well as the best one. `max_cells` leaves room for
    Gemini's own grid, which runs to about 100 cells across.

    `hint` is the block size the picture should have (its width over the
    puzzle grid). A sparse picture (flat shapes on a plain background) can
    have every colour change on every second or third block, so a bigger
    block lines up nearly as well and wins. The hint wins instead when it is
    smaller and lines up at least as well, to within HINT_MIN_COHERENCE of
    perfectly, and HINT_MARGIN better than each of its whole multiples up to
    the found block. A divisor of the true block lines up as well as the
    block itself, so without that last test a source drawn at 8 blocks would
    read as 16; with it some changes must fall on odd lines of the hint.
    """
    n = min(len(cols), len(rows))
    ex = [(x, w) for x, w in enumerate(cols) if w]
    ey = [(y, w) for y, w in enumerate(rows) if w]
    tx, ty = sum(cols), sum(rows)
    found = []
    period = max(min_block, n / max_cells)
    while period <= n / 6:
        cx, px = _coherence(ex, tx, period)
        cy, py = _coherence(ey, ty, period)
        found.append(((cx + cy) / 2, period, px, py))
        period += 0.02
    if not found:
        raise ValueError('picture too small to find a grid')
    peak = max(f[0] for f in found)
    if peak < 0.3:
        return None
    good = [f for f in found if f[0] >= 0.85 * peak]
    top = max(good, key=lambda f: f[1])
    if hint and top[1] > hint:
        def both(period):
            (cx, px), (cy, py) = _coherence(ex, tx, period), _coherence(ey, ty, period)
            return (cx + cy) / 2, px, py

        line_up, px, py = both(hint)
        multiples = max(both(k * hint)[0] for k in range(2, int(top[1] / hint) + 2))
        if line_up >= max(top[0], HINT_MIN_COHERENCE) and line_up - multiples >= HINT_MARGIN:
            return hint, px, py
    # Fine-tune around the chosen size: the local best line-up.
    near = [f for f in found if abs(f[1] - top[1]) <= 0.3]
    _, period, px, py = max(near, key=lambda f: f[0])
    return period, px, py


def native_grid(img, period, phase_x, phase_y):
    """Reads one colour per detected block: the most common in its middle."""
    w, h = img.size

    def starts(phase, size):
        # phase is already within one block; start a block early if the
        # first full block would leave more than half a block uncovered.
        pos = phase - period if phase > period / 2 else phase
        out = []
        while pos + period / 2 <= size:
            out.append(pos)
            pos += period
        return out

    grid = []
    for y0 in starts(phase_y, h):
        row = []
        for x0 in starts(phase_x, w):
            box = (max(0, int(x0 + period * INSET)),
                   max(0, int(y0 + period * INSET)),
                   min(w, int(x0 + period * (1 - INSET)) + 1),
                   min(h, int(y0 + period * (1 - INSET)) + 1))
            # Bin near-identical pixels (4 bits a channel), take the biggest
            # bin and return its real average colour.
            bins = {}
            for count, (r, g, b) in img.crop(box).getcolors(box_area(box)):
                t = bins.setdefault((r >> 4, g >> 4, b >> 4), [0, 0, 0, 0])
                t[0] += count
                t[1] += r * count
                t[2] += g * count
                t[3] += b * count
            n, r, g, b = max(bins.values())
            row.append((r // n, g // n, b // n))
        grid.append(row)
    return grid


def box_area(box):
    return max(1, (box[2] - box[0]) * (box[3] - box[1]))


def _ring_mode(grid):
    """(colour, count, ring size) of the commonest block on the grid's edge."""
    ring = grid[0] + grid[-1] + [row[0] for row in grid[1:-1]] + [row[-1] for row in grid[1:-1]]
    colour, count = Counter(ring).most_common(1)[0]
    return colour, count, len(ring)


def plain_ring(grid):
    """The most common colour of the outer ring of blocks when it covers at
    least PLAIN_BORDER of that ring, else None."""
    colour, count, ring = _ring_mode(grid)
    return colour if count >= PLAIN_BORDER * ring else None


def border_colour(grid):
    """The plain background colour around the picture, or None for a full
    scene: the most common colour of the outer ring of blocks, when it covers
    at least PLAIN_BORDER of that ring and PLAIN_BACKGROUND of the picture."""
    colour = plain_ring(grid)
    if colour is None:
        return None
    covered = sum(c == colour for row in grid for c in row)
    more_than_a_frame_line = covered >= PLAIN_BACKGROUND * len(grid) * len(grid[0])
    return colour if more_than_a_frame_line else None


def subject_box(grid, bg):
    """(x0, y0, x1, y1) around every block that is not `bg`, ignoring lone
    blocks with no non-background neighbour (stray specks), or None."""
    gh, gw = len(grid), len(grid[0])

    def solid(x, y):
        return any(0 <= x + dx < gw and 0 <= y + dy < gh and grid[y + dy][x + dx] != bg
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy)

    pts = [(x, y) for y in range(gh) for x in range(gw) if grid[y][x] != bg and solid(x, y)]
    if not pts:
        return None
    xs, ys = [x for x, _ in pts], [y for _, y in pts]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def _square_start(lo, hi, side, size):
    """Where a square of `side` starts on one axis: centred on lo..hi, then
    slid inside 0..size when it fits. A square bigger than the frame stays on
    the edge the subject runs off, so the padding goes to the open side."""
    if side > size and (lo == 0) != (hi == size):
        return 0 if lo == 0 else size - side
    start = round((lo + hi - side) / 2)
    return min(max(start, 0), size - side) if side <= size else start


def crop(grid, n, bg=None):
    """The square of native blocks around the subject, with one target cell
    of margin on each side the subject doesn't run off, and never under n
    blocks across. Where the square runs past the frame it is padded with the
    background colour. A picture with no plain border (a full scene) comes
    back whole. `bg` is border_colour(grid), passed in when the caller has it
    already."""
    bg = border_colour(grid) if bg is None else bg
    if bg is None:
        return grid
    box = subject_box(grid, bg)
    if not box:
        return grid
    x0, y0, x1, y1 = box
    gh, gw = len(grid), len(grid[0])

    def span(lo, hi, size):
        open_sides = (lo > 0) + (hi < size)
        return math.ceil((hi - lo) * n / (n - open_sides))

    side = max(n, span(x0, x1, gw), span(y0, y1, gh))
    nothing_to_trim = gw == gh and side >= gw
    if nothing_to_trim:
        return grid
    sx, sy = _square_start(x0, x1, side, gw), _square_start(y0, y1, side, gh)
    return [[grid[y][x] if 0 <= x < gw and 0 <= y < gh else bg for x in range(sx, sx + side)]
            for y in range(sy, sy + side)]


class FitError(ValueError):
    """A source too far from its grid to place 1:1; the message gives its
    measured size and `miss` how many blocks a side it is off (None when
    nothing was measured)."""

    def __init__(self, message, miss=None):
        super().__init__(message)
        self.miss = miss


def _fit_start(lo, hi, n, size):
    """Where an n-block window starts on one axis around a subject at lo..hi
    in a frame of `size` blocks: on the edge the subject runs off, else
    centred (any odd block to the right or bottom), inside the frame when it
    fits."""
    if lo == 0 and hi < size:
        return 0
    if hi == size and lo > 0:
        return size - n
    start = lo - (n - (hi - lo)) // 2
    return min(max(start, 0), size - n) if n <= size else start


def fit_subject(native):
    """(background, subject box) for fit mode, or (None, None). Only the
    outer ring must be plain (PLAIN_BORDER): unlike crop, a subject that
    fills most of the frame still gets measured, so it fails with its size."""
    colour = plain_ring(native)
    return (None, None) if colour is None else (colour, subject_box(native, colour))


def fit_native(native, n, mode):
    """Places a picture read at its own grid onto the n x n puzzle grid block
    for block, with no resampling. Returns (grid, note) or raises FitError.

    'subject': a subject on a plain background whose box fits inside n x n
    and is at least FIT_SUBJECT_MIN_SHARE of n across is framed by an n-block
    window, padded with the background where the window runs past the frame.
    'scene': a full scene of n to n + FIT_SCENE_MAX_EXTRA_BLOCKS blocks a side is
    trimmed evenly at the edges (any odd block comes off the right or
    bottom)."""
    gw, gh = len(native[0]), len(native)
    if mode == 'scene':
        if not (n <= gw <= n + FIT_SCENE_MAX_EXTRA_BLOCKS and n <= gh <= n + FIT_SCENE_MAX_EXTRA_BLOCKS):
            side = 'under' if min(gw, gh) < n else 'over'
            raise FitError(f'scene {gw}x{gh} {side} grid {n} (needs {n} to {n + FIT_SCENE_MAX_EXTRA_BLOCKS} blocks)',
                           max(abs(gw - n), abs(gh - n)))
        ox, oy = (gw - n) // 2, (gh - n) // 2
        return [row[ox:ox + n] for row in native[oy:oy + n]], f'scene {gw}x{gh} trimmed to {n}'
    if mode != 'subject':
        raise ValueError(f'fit mode {mode!r} is not subject or scene')
    bg, box = fit_subject(native)
    if not box:
        raise FitError(f'no subject on a plain background ({blocks_text((gw, gh))})')
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if w > n or h > n:
        raise FitError(f'subject {w}x{h} over grid {n}', max(abs(w - n), abs(h - n)))
    least = math.ceil(FIT_SUBJECT_MIN_SHARE * n)
    if max(w, h) < least:
        raise FitError(f'subject {w}x{h} under grid {n} (needs {least} blocks across)', n - max(w, h))
    sx, sy = _fit_start(x0, x1, n, gw), _fit_start(y0, y1, n, gh)
    return ([[native[y][x] if 0 <= x < gw and 0 <= y < gh else bg for x in range(sx, sx + n)]
             for y in range(sy, sy + n)], f'subject {w}x{h} padded to {n}')


def _area_votes(grid, x0, x1, y0, y1):
    """Each colour's area (in blocks) inside the box, clipped to the grid."""
    gh, gw = len(grid), len(grid[0])
    votes = Counter()
    for gy in range(max(0, int(y0)), min(gh, math.ceil(y1))):
        hy = min(y1, gy + 1) - max(y0, gy)
        for gx in range(max(0, int(x0)), min(gw, math.ceil(x1))):
            hx = min(x1, gx + 1) - max(x0, gx)
            if hx > 0 and hy > 0:
                votes[grid[gy][gx]] += hx * hy
    return votes


def shrink(grid, n):
    """One colour per target cell from the native blocks under it.

    Votes are weighted by area. Every colour covering at least
    DETAIL_SHARE of the cell scores its share of the cell divided by its share
    of the cell and its eight neighbours ** RARITY, so a small feature (an
    eye, a spot) beats the colour around it. Rarity is measured nearby rather
    than over the whole picture because an eye is often the outline colour,
    which is common overall. When no colour reaches DETAIL_SHARE, the
    majority wins.
    """
    gh, gw = len(grid), len(grid[0])
    side = min(gw, gh)
    ox, oy = (gw - side) / 2, (gh - side) / 2
    scale = side / n
    out = []
    for ty in range(n):
        row = []
        for tx in range(n):
            x0, x1 = ox + tx * scale, ox + (tx + 1) * scale
            y0, y1 = oy + ty * scale, oy + (ty + 1) * scale
            votes = _area_votes(grid, x0, x1, y0, y1)
            if not votes:  # rounding left no overlap: take the nearest block
                votes[grid[min(gh - 1, int(y0))][min(gw - 1, int(x0))]] = 1
            area = sum(votes.values())
            near = _area_votes(grid, x0 - scale, x1 + scale, y0 - scale, y1 + scale)
            around = sum(near.values())
            scores = {c: v / area / (near[c] / around) ** RARITY
                      for c, v in votes.items() if v / area >= DETAIL_SHARE and near[c]}
            row.append(max(scores, key=scores.get) if scores else votes.most_common(1)[0][0])
        out.append(row)
    return out


def to_image(grid):
    h, w = len(grid), len(grid[0])
    img = Image.new('RGB', (w, h))
    img.putdata([c for row in grid for c in row])
    return img


def _dist(a, b):
    # Weighted RGB, close enough to how different two flat colours look.
    return 2 * (a[0] - b[0]) ** 2 + 4 * (a[1] - b[1]) ** 2 + 3 * (a[2] - b[2]) ** 2


def _rgb_gap(a, b):
    return math.dist(a, b)


def _closest(colours, measure):
    """(distance, a, b) of the closest pair of colours by `measure`, or
    (inf, None, None) when there is no pair."""
    colours = list(colours)
    return min(((measure(a, b), a, b) for i, a in enumerate(colours) for b in colours[i + 1:]),
               default=(math.inf, None, None))


def min_gap(colours):
    """Smallest plain RGB distance between any two colours (inf for one)."""
    return _closest(colours, _rgb_gap)[0]


@lru_cache(maxsize=None)
def lab(rgb):
    """sRGB (0-255) to CIE Lab (D65), as _lab in lib/data/simplify.dart."""
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(v) for v in rgb)
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def de2000(x, y):
    """CIEDE2000 difference between two Lab colours, as _de2000 in the game."""
    l1, a1, b1 = x
    l2, a2, b2 = y
    rad = math.pi / 180
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    cm7 = ((c1 + c2) / 2) ** 7
    g = 0.5 * (1 - math.sqrt(cm7 / (cm7 + 6103515625.0)))
    ap1, ap2 = a1 * (1 + g), a2 * (1 + g)
    cp1, cp2 = math.hypot(ap1, b1), math.hypot(ap2, b2)

    def hue(b, a):
        if a == 0 and b == 0:
            return 0.0
        h = math.atan2(b, a) / rad
        return h + 360 if h < 0 else h

    hp1, hp2 = hue(b1, ap1), hue(b2, ap2)
    dl, dc = l2 - l1, cp2 - cp1
    dh = 0.0
    if cp1 * cp2 != 0:
        dh = hp2 - hp1
        if dh > 180:
            dh -= 360
        if dh < -180:
            dh += 360
    d_h = 2 * math.sqrt(cp1 * cp2) * math.sin(dh / 2 * rad)
    lm, cm = (l1 + l2) / 2, (cp1 + cp2) / 2
    hm = hp1 + hp2
    if cp1 * cp2 != 0:
        if abs(hp1 - hp2) > 180:
            hm += 360 if hm < 360 else -360
        hm /= 2
    t = (1 - 0.17 * math.cos((hm - 30) * rad) + 0.24 * math.cos(2 * hm * rad)
         + 0.32 * math.cos((3 * hm + 6) * rad) - 0.20 * math.cos((4 * hm - 63) * rad))
    d_theta = 30 * math.exp(-(((hm - 275) / 25) ** 2))
    cm7p = cm ** 7
    rc = 2 * math.sqrt(cm7p / (cm7p + 6103515625.0))
    sl = 1 + 0.015 * (lm - 50) ** 2 / math.sqrt(20 + (lm - 50) ** 2)
    sc, sh = 1 + 0.045 * cm, 1 + 0.015 * cm * t
    rt = -math.sin(2 * d_theta * rad) * rc
    ql, qc, qh = dl / sl, dc / sc, d_h / sh
    return math.sqrt(ql * ql + qc * qc + qh * qh + rt * qc * qh)


def rgb_of_lab(colour):
    """CIE Lab (D65) back to sRGB 0-255, clamped to the gamut: the inverse
    of lab()."""
    l, a, b = colour
    fy = (l + 16) / 116
    fx, fz = fy + a / 500, fy - b / 200

    def finv(t):
        return t ** 3 if t ** 3 > 0.008856 else (t - 16 / 116) / 7.787

    x, y, z = finv(fx) * 0.95047, finv(fy), finv(fz) * 1.08883
    linear = (3.2406 * x - 1.5372 * y - 0.4986 * z,
              -0.9689 * x + 1.8758 * y + 0.0415 * z,
              0.0557 * x - 0.2040 * y + 1.0570 * z)

    def gamma(v):
        v = min(max(v, 0.0), 1.0)
        return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055

    return tuple(round(gamma(v) * 255) for v in linear)


def _de_gap(a, b):
    return de2000(lab(a), lab(b))


def min_de_gap(colours):
    """Smallest CIEDE2000 difference between any two colours (inf for one)."""
    return _closest(colours, _de_gap)[0]


def largest_region(grid, colours):
    """Cells in the largest 4-connected region of cells whose colour is in
    `colours`."""
    gh, gw = len(grid), len(grid[0])
    seen = set()
    best = 0
    for sy in range(gh):
        for sx in range(gw):
            if (sx, sy) in seen or grid[sy][sx] not in colours:
                continue
            seen.add((sx, sy))
            todo, size = [(sx, sy)], 0
            while todo:
                x, y = todo.pop()
                size += 1
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < gw and 0 <= ny < gh and (nx, ny) not in seen and grid[ny][nx] in colours:
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            best = max(best, size)
    return best


def separate(mover, anchor, gap, de_gap, origin=None):
    """`mover` pushed along the Lab line away from `anchor` until the two are
    `gap` apart in plain RGB and `de_gap` in CIEDE2000, or None when that
    needs more than SEPARATE_MAX_SHIFT times the gap or the gamut stops it
    (a white can't get any whiter). It walks in SEPARATE_STEP_LAB steps, at
    most SEPARATE_MAX_WALK times that shift in Lab distance, since CIEDE2000
    can grow slower than Lab distance. The shift is measured from `origin`
    (default `mover`), so repeated moves of one colour share one cap."""
    start, away = lab(mover), lab(anchor)
    direction = [m - a for m, a in zip(start, away)]
    length = math.hypot(*direction)
    if not length:
        return None
    unit = [v / length for v in direction]
    most = SEPARATE_MAX_SHIFT * max(de_gap, min(LEVEL_GAP.values()))
    steps = math.ceil(SEPARATE_MAX_WALK * most / SEPARATE_STEP_LAB)
    for i in range(1, steps + 1):
        moved = rgb_of_lab(tuple(s + u * i * SEPARATE_STEP_LAB for s, u in zip(start, unit)))
        if _de_gap(moved, origin or mover) > most:
            return None
        if _rgb_gap(moved, anchor) >= gap and _de_gap(moved, anchor) >= de_gap:
            return moved
    return None


def reduce_palette(grid, limit=None, merge_below=0, gap=0.0, de_gap=0.0, region_safe=False):
    """Merges the closest pair of colours until the palette fits.

    Merging stops early at `limit` colours, and always goes on while the
    closest pair is nearer than `merge_below`, which folds the many shades a
    screen capture gives one flat colour back into one, while any pair is under
    `gap` apart in plain RGB, or while any pair is under `de_gap` apart in
    CIEDE2000 (the game's drill colour gap), so no two drill colours look
    alike. Small but distinct colours (an eye, a shine) survive, unlike with a
    median cut. A merged group keeps the colour of its biggest single member
    rather than the mean, so merging a pale subject with a pale background
    doesn't drag both toward a colour neither had. The biggest member, not the
    bigger group: a group of shades would otherwise pass a minor shade's colour
    over the picture's most common one (the Classics butterfly's pink flowers
    turned coral).

    With `region_safe` (PAP-95, sources drawn at their grid), two colours
    under the gap whose largest 4-connected regions each cover at least
    LARGE_REGION_SHARE of the grid are pushed apart instead (see separate):
    the smaller one moves, or the larger when the smaller can't, at most
    SEPARATE_MAX_MOVES times per colour, else they merge as before. So a
    white face on a cream background stays a face. Merges the `limit` forces
    take a pair that is not two such regions while there is one. The Classics
    leave it off: their built PNGs rely on the merge.
    """
    counts = Counter(c for row in grid for c in row)
    parent = {}  # colour -> the group it joined (followed to the root below)
    group_cells = {}
    biggest_member = {}

    # One quick pass first: each colour, most common first, joins the first
    # group within `merge_below`, so the pairwise loop below starts small.
    for c, n in counts.most_common():
        home = next((k for k in group_cells if _dist(c, biggest_member[k][1]) < merge_below), c)
        parent[c] = home
        group_cells[home] = group_cells.get(home, 0) + n
        biggest_member.setdefault(home, (n, c))

    def closest(measure):
        keys = list(group_cells)
        return min((measure(biggest_member[a][1], biggest_member[b][1]), a, b)
                   for i, a in enumerate(keys) for b in keys[i + 1:])

    def root(c):
        while parent[c] != c:
            c = parent[c]
        return c

    def region(group):
        return largest_region(grid, {c for c in counts if root(c) == group})

    big_region = LARGE_REGION_SHARE * len(grid) * len(grid[0])
    moves, origin = Counter(), {}

    def both_regions(a, b):
        small, large = (a, b) if group_cells[a] < group_cells[b] else (b, a)
        return group_cells[small] >= big_region and region(small) >= big_region and region(large) >= big_region

    def closest_detail_pair():
        """The closest pair by _dist that is not two large regions, or the
        closest pair when every pair is."""
        keys = list(group_cells)
        pairs = sorted((_dist(biggest_member[a][1], biggest_member[b][1]), a, b)
                       for i, a in enumerate(keys) for b in keys[i + 1:])
        return next((p for p in pairs if not both_regions(p[1], p[2])), pairs[0])

    def pushed_apart(a, b):
        """Moves the smaller of two large regions away from the other, or the
        larger one when the smaller can't move (a pure white); False when
        they are not both regions or neither can move."""
        small, large = (a, b) if group_cells[a] < group_cells[b] else (b, a)
        if not both_regions(a, b):
            return False
        for mover, anchor in ((small, large), (large, small)):
            if moves[mover] < SEPARATE_MAX_MOVES:
                source = origin.setdefault(mover, biggest_member[mover][1])
                moved = separate(biggest_member[mover][1], biggest_member[anchor][1], gap, de_gap, origin=source)
                if moved is not None:
                    biggest_member[mover] = (biggest_member[mover][0], moved)
                    moves[mover] += 1
                    return True
        return False

    while len(group_cells) > 1:
        d, a, b = closest(_dist)
        palette_fits = d >= merge_below and (limit is None or len(group_cells) <= limit)
        if not palette_fits and region_safe and d >= merge_below:
            d, a, b = closest_detail_pair()
        elif palette_fits:
            d, a, b = closest(_rgb_gap)
            if d >= gap:
                if not de_gap:
                    break
                d, a, b = closest(_de_gap)
                if d >= de_gap:
                    break
            if region_safe and pushed_apart(a, b):
                continue
        group_cells[a] += group_cells.pop(b)
        kept_b = biggest_member[b] > biggest_member[a]
        biggest_member[a] = max(biggest_member[a], biggest_member.pop(b))
        if kept_b:
            origin.pop(a, None)
            if b in origin:
                origin[a] = origin.pop(b)
        else:
            origin.pop(b, None)
        parent[b] = a

    return [[biggest_member[root(c)][1] for c in row] for row in grid]


def to_indexed(grid):
    """The grid as a palette ('P') PNG image with exactly its own colours."""
    colours = sorted({c for row in grid for c in row})
    index = {c: i for i, c in enumerate(colours)}
    img = Image.new('P', (len(grid[0]), len(grid)))
    img.putpalette([v for c in colours for v in c])
    img.putdata([index[c] for row in grid for c in row])
    return img, len(colours)


class Analysis(NamedTuple):
    """A picture read at its own grid. Only a sparse source drawn at its
    puzzle grid reads differently for another grid (analyse), so one analysis
    serves all four."""
    native: list  # rows of RGB tuples, one per source block
    period: float  # block size in source pixels
    clean: bool  # False: no clean grid, sampled evenly
    placement: str = ''
    lines: tuple = None  # lattice_analysis: block lines (xs, ys) in source pixels

    @property
    def frame(self):
        """(columns, rows) of source blocks across the whole frame."""
        return len(self.native[0]), len(self.native)

    @property
    def subject(self):
        """Blocks across the square around the subject, or None for a full
        scene with no plain background."""
        bg = border_colour(self.native)
        box = bg is not None and subject_box(self.native, bg)
        return max(box[2] - box[0], box[3] - box[1]) if box else None


def blocks_text(frame):
    """'37 blocks' for a square frame, '37x30 blocks' otherwise."""
    w, h = frame
    return f'{w} blocks' if w == h else f'{w}x{h} blocks'


def analyse(src, grid=None):
    """Reads the picture at its own grid, with capture shades folded together.
    `grid` is the puzzle grid the source should be drawn at: a sparse source
    drawn at it is read at it, not at a multiple of its block (find_grid)."""
    img = Image.open(src).convert('RGB')
    cols, rows = edge_profiles(img)
    found = find_grid(cols, rows, hint=img.size[0] / grid if grid else None)
    # No clean grid (blurred capture or free-hand pixels): sample twice as fine
    # as the largest game grid, so the majority vote in shrink still has a say.
    period, phase_x, phase_y = found or (min(img.size) / (2 * max(COLOR_LIMIT)), 0.0, 0.0)
    native = native_grid(img, period, phase_x, phase_y)
    # Fold capture shades together first so they don't split the vote.
    return Analysis(reduce_palette(native, merge_below=SHADE_MERGE), period, found is not None)


def subject_share(grid, bg=None):
    """The part of the grid that is not background: `bg`, or else the most
    common colour of the outer ring."""
    if bg is None:
        bg = _ring_mode(grid)[0]
    return sum(c != bg for row in grid for c in row) / (len(grid) * len(grid[0]))


def convert(analysis, n, colors, de_gap=0.0, region_safe=False):
    """The n x n indexed picture and its info. info['subject'] is the
    subject's share of the cropped native read (None for a full scene), which
    verify compares with the result.

    The palette is cut to the level's drill colours before the shrink as well
    as after, so the rarity vote in shrink weighs drill colours rather than
    leftover capture shades. A source read at exactly n x n blocks converts
    block for block: crop never goes under n blocks, so it keeps the grid
    whole, and shrink gives each cell its one block. Only the palette cut
    changes it. `region_safe` goes to reduce_palette."""
    native, period, clean = analysis.native, analysis.period, analysis.clean
    bg = border_colour(native)

    def fit(grid):
        return reduce_palette(grid, limit=colors, gap=MIN_RGB_GAP, de_gap=de_gap, region_safe=region_safe)

    framed = crop(native, n, bg)
    out, used = to_indexed(fit(shrink(fit(framed), n)))
    info = {
        'block': round(period, 2),
        'native': (len(native[0]), len(native)),
        'crop': len(framed),
        'colors': used,
        'fallback': not clean,
        'subject': None if bg is None else subject_share(framed, bg),
    }
    return out, info


def puzzle_entries(manifest=MANIFEST):
    """Every puzzle picture the asset manifest lists: course, slug, grid and
    the source path. Raises ValueError on a bad grid or a repeated slug."""
    with open(manifest, 'rb') as f:
        assets = tomllib.load(f).get('asset', [])
    out, seen = [], set()
    for a in assets:
        if 'course' not in a:
            continue
        name = a.get('name', '?')
        if not a.get('source'):
            raise ValueError(f'{name}: no source')
        if not str(a['course']).isalnum() or a['course'] != a['course'].lower():
            raise ValueError(f"{name}: course {a['course']!r} is not a lower-case word")
        if a.get('grid') not in COLOR_LIMIT:
            raise ValueError(f"{name}: grid {a.get('grid')} is not one of {sorted(COLOR_LIMIT)}")
        if not a.get('slug') or not a['slug'].replace('-', '').isalnum() or a['slug'] != a['slug'].lower():
            raise ValueError(f"{name}: slug {a.get('slug')!r} is not a lower-case hyphenated slug")
        key = (a['course'], a['slug'])
        if key in seen:
            raise ValueError(f'{name}: {key[0]}/{key[1]} is listed twice')
        exact = a.get('exact', False)
        if not isinstance(exact, bool):
            raise ValueError(f'{name}: exact {exact!r} is not true or false')
        fit = a.get('fit')
        if fit is not None and fit not in FIT_MODES:
            raise ValueError(f'{name}: fit {fit!r} is not one of {", ".join(FIT_MODES)}')
        if fit and exact:
            raise ValueError(f'{name}: use exact or fit, not both')
        prompt, seed, scale = a.get('prompt'), a.get('seed'), a.get('scale')
        if prompt is not None and not (isinstance(prompt, str) and prompt.strip()):
            raise ValueError(f'{name}: prompt {prompt!r} is not text')
        if seed is not None and (not isinstance(seed, int) or isinstance(seed, bool) or seed < 0):
            raise ValueError(f'{name}: seed {seed!r} is not a whole number')
        if scale is not None and (not isinstance(scale, int) or isinstance(scale, bool)
                                  or not CELL_PX_RANGE[0] <= scale <= CELL_PX_RANGE[1]):
            raise ValueError(f'{name}: scale {scale!r} is not {CELL_PX_RANGE[0]} to {CELL_PX_RANGE[1]} px a cell')
        if (seed is None) != (scale is None):
            raise ValueError(f'{name}: record seed and scale together')
        seen.add(key)
        out.append({'course': a['course'], 'slug': a['slug'], 'grid': a['grid'],
                    'source': os.path.join(REPO, a['source']), 'exact': exact,
                    'fit': fit, 'prompt': prompt, 'seed': seed, 'scale': scale})
    return out


def verify(img, n, subject=None):
    """What is wrong with a converted picture for a level of grid n (empty: ok).

    `subject` is the subject's share of the native read (convert's
    info['subject']); the picture fails when it keeps under SUBJECT_KEPT of
    it, for example a pale body merged into the background."""
    problems = []
    if img.mode != 'P' or img.size != (n, n):
        problems.append(f'size {img.size[0]}x{img.size[1]} {img.mode}, want {n}x{n} P')
    counts = img.getcolors()
    pal = img.getpalette()
    used = [tuple(pal[i * 3:i * 3 + 3]) for _, i in counts]
    if not MIN_COLOURS <= len(used) <= COLOR_LIMIT[n]:
        problems.append(f'{len(used)} colours, want {MIN_COLOURS} to {COLOR_LIMIT[n]}')
    share = max(c for c, _ in counts) / (img.size[0] * img.size[1])
    if share > MAX_SHARE:
        problems.append(f'top colour covers {share:.0%}')
    gap = min_de_gap(used)
    if gap < LEVEL_GAP[n]:
        problems.append(f'colour gap {gap:.1f} under {LEVEL_GAP[n]:.0f}')
    rgb = min_gap(used)
    if rgb < MIN_RGB_GAP:
        problems.append(f'plain RGB gap {rgb:.0f} under {MIN_RGB_GAP:.0f}')
    if subject:
        w, h = img.size
        data = img.tobytes()
        kept = subject_share([list(data[y * w:(y + 1) * w]) for y in range(h)])
        if kept < SUBJECT_KEPT * subject:
            problems.append(f'subject covers {kept:.0%} of the grid, {subject:.0%} in the native read')
    return problems


def fit_analysis(analysis, n, mode):
    """The analysis with its native read placed on the n x n grid by
    fit_native, so convert keeps it block for block. Raises FitError."""
    fitted, note = fit_native(analysis.native, n, mode)
    return analysis._replace(native=fitted, placement=note)


def drawn_at_grid(entry):
    """True for a source drawn at its grid (`exact` or `fit`): its colours
    get the region-safe cut."""
    return bool(entry.get('exact') or entry.get('fit'))


def exact_problem(entry, analysis):
    """Why an `exact` entry's source isn't drawn at its grid, or None. The
    whole frame must be grid x grid blocks: 1:1 needs every block of the
    source, so a subject square of the right size inside a bigger frame
    doesn't count."""
    n = entry['grid']
    if not entry.get('exact') or analysis.frame == (n, n):
        return None
    return f'drawn at {blocks_text(analysis.frame)}, needs {n}: regenerate'


def analyse_entry(entry):
    """Reads a manifest picture. A source made by pixel_gen.py (it records
    `seed` and `scale`) is read on its canvas lattice, grid x grid cells of
    `scale` px, the way pixel_gen.py judged it: the block search can find
    the model's own coarser blocks there and reject a try that was kept.
    Raises FitError when the canvas isn't grid x scale px."""
    n, scale = entry['grid'], entry.get('scale')
    if scale is None:
        return analyse(entry['source'], n)
    img = Image.open(entry['source'])
    if img.size != (n * scale,) * 2:
        w, h = img.size
        raise FitError(f'source is {w}x{h} px, not {n * scale}x{n * scale} (grid {n} at {scale} px a cell)', None)
    return lattice_analysis(img, n)


def convert_entry(entry, grids=None):
    """Converts one manifest picture at its grid (or at each of `grids`).
    Returns (problems, {grid: (image, info)}, analysis or None); each problem
    is prefixed with the grid when there are several."""
    path = entry['source']
    if not os.path.exists(path):
        shown = os.path.relpath(path, REPO) if path.startswith(REPO + os.sep) else path
        return [f'missing source {shown}'], {}, None
    try:
        analysis = analyse_entry(entry)
    except FitError as e:
        return [f'{e}: regenerate'], {}, None
    except (OSError, ValueError) as e:
        return [f'unreadable: {e}'], {}, None
    if not analysis.clean:
        regenerate = f', needs {entry["grid"]}: regenerate' if entry.get('exact') else ''
        return [f'no clean grid (sampled evenly, check it by eye){regenerate}'], {}, analysis
    placed = analysis
    if entry.get('fit'):
        try:
            placed = fit_analysis(analysis, entry['grid'], entry['fit'])
        except FitError as e:
            return [f'{e}: regenerate'], {}, analysis
        analysis = analysis._replace(placement=placed.placement)
    problems, outputs = list(filter(None, [exact_problem(entry, analysis)])), {}
    for n in grids or [entry['grid']]:
        outputs[n] = convert(placed, n, COLOR_LIMIT[n], LEVEL_GAP[n], drawn_at_grid(entry))
        out, info = outputs[n]
        problems += [f'{n}x{n}: {p}' if grids else p for p in verify(out, n, info['subject'])]
    return problems, outputs, analysis


def check_picture(entry, grids=None):
    """The problems of one manifest picture (empty: it passes)."""
    return convert_entry(entry, grids)[0]


def source_text(entry, analysis, outputs):
    """'source 37 blocks (subject 30), grid 16, 6 colours' for one --check
    line; the colour count is the converted picture's at its grid."""
    n = entry['grid']
    colours = f", {outputs[n][1]['colors']} colours" if n in outputs else ''
    if analysis is None:
        return f'grid {n}{colours}'
    subject = analysis.subject
    if not analysis.clean:
        note = ' (no clean grid)'
    elif analysis.placement:
        note = f', {analysis.placement}'
    else:
        note = f' (subject {subject})' if subject else ''
    return f'source {blocks_text(analysis.frame)}{note}, grid {n}{colours}'


def stale(entry, image, out_root):
    """A problem when <out_root>/<course>/<slug>.png is missing or differs
    from `image` (what --build would write now), else None."""
    target = os.path.join(out_root, entry['course'], entry['slug'] + '.png')
    if not os.path.exists(target):
        return 'not built (run --build)'
    with Image.open(target) as built:
        if built.convert('RGB').tobytes() != image.convert('RGB').tobytes():
            return 'built PNG differs from the converter output (run --build)'
    return None


def check(entries, all_grids=False, out_root=None):
    """Checks every picture and prints one line each, with the source's block
    count. With `out_root`, a built PNG that is missing or out of date fails
    too. Returns the failures."""
    if not entries:
        print('the manifest lists no puzzle pictures')
        return 1
    failures = 0
    for e in entries:
        problems, outputs, analysis = convert_entry(e, sorted(COLOR_LIMIT) if all_grids else None)
        if out_root and e['grid'] in outputs:
            problems += filter(None, [stale(e, outputs[e['grid']][0], out_root)])
        failures += bool(problems)
        print(f"{'FAIL' if problems else 'ok  '} {e['course']}/{e['slug']} {source_text(e, analysis, outputs)}"
              + (': ' + '; '.join(problems) if problems else ''), flush=True)
    print(f'{len(entries)} pictures, {failures} failed')
    return failures


def build(entries, out_root=PICTURES):
    """Writes every picture that passes to <out_root>/<course>/<slug>.png.
    Returns the failures; a failing picture is not written."""
    failures = 0
    for e in entries:
        n = e['grid']
        problems, outputs, _ = convert_entry(e)
        target = os.path.join(out_root, e['course'], e['slug'] + '.png')
        if problems:
            failures += 1
            if os.path.exists(target):
                os.remove(target)
            print(f"FAIL {e['course']}/{e['slug']}: {'; '.join(problems)}")
            continue
        out, info = outputs[n]
        os.makedirs(os.path.dirname(target), exist_ok=True)
        out.save(target, optimize=True)
        print(f"wrote {e['course']}/{e['slug']}.png {n}x{n}, {info['colors']} colours")
    return failures


# tool/pixel_gen.py draws each picture on its puzzle grid (8 or 16 px a cell)
# and runs these; --check and --build never do, so the Classics can't change.


def on_lattice_share(img, grid):
    """The share of colour runs, across and down, whose length is a whole
    number of cells (within ON_LATTICE_TOLERANCE of a cell). A cell is the
    picture's width over `grid`. A source drawn on its grid scores high; one
    whose model drew its own, smaller or uneven blocks scores low. A run is
    counted when a colour change (EDGE) ends it, so plain rows don't count."""
    img = img.convert('RGB')
    w, h = img.size
    cell = w / grid
    data = img.tobytes()
    on = total = 0

    def changed(i, j):
        return abs(data[i] - data[j]) + abs(data[i + 1] - data[j + 1]) + abs(data[i + 2] - data[j + 2]) > EDGE

    for a, b, step_a, step_b in ((h, w, w * 3, 3), (w, h, 3, w * 3)):
        for line in range(a):
            base, run = line * step_a, 1
            for k in range(1, b):
                i = base + k * step_b
                if changed(i, i - step_b):
                    cells = max(1, round(run / cell))
                    on += abs(run - cells * cell) <= ON_LATTICE_TOLERANCE * cell
                    total += 1
                    run = 1
                else:
                    run += 1
    return on / total if total else 0.0


def lattice_analysis(img, grid):
    """Reads a source drawn on its grid with the plain fixed lattice: grid x
    grid blocks of the picture's width over grid, offset by the phase where
    its colour changes line up. No block search, no snapping. `lines` are
    the block lines in source pixels, for feature_check."""
    img = img.convert('RGB')
    period = img.size[0] / grid
    cols, rows = edge_profiles(img)
    phases = []
    for profile in (cols, rows):
        edges = [(x, v) for x, v in enumerate(profile) if v]
        phase = _coherence(edges, sum(profile), period)[1]
        phases.append(phase - period if phase > period / 2 else phase)
    native = native_grid(img, period, *phases)
    lines = tuple([round(p + i * period, 3) + 0.0 for i in range(len(axis) + 1)] for p, axis in zip(phases, (native[0], native)))
    return Analysis(reduce_palette(native, merge_below=SHADE_MERGE), period, True, lines=lines)


def _components(w, h, data):
    """(value, [index]) of each 4-connected run of equal values in a w x h
    row-major sequence."""
    seen = bytearray(w * h)
    out = []
    for start in range(w * h):
        if seen[start]:
            continue
        value, todo, members = data[start], [start], []
        seen[start] = 1
        while todo:
            p = todo.pop()
            members.append(p)
            x = p % w
            for q in (p - 1 if x else -1, p + 1 if x < w - 1 else -1, p - w, p + w):
                if 0 <= q < w * h and not seen[q] and data[q] == value:
                    seen[q] = 1
                    todo.append(q)
        out.append((value, members))
    return out


def _source_classes(img):
    """The source as colour classes: a median-cut palette of
    FEATURE_CLASSES colours, entries under FEATURE_CLASS_DE apart joined,
    then a 3 x 3 mode filter that drops the soft 1 px seams the model draws
    between two colours. Returns (class per pixel, colour per class)."""
    q = img.quantize(FEATURE_CLASSES, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()
    colours = [tuple(pal[i * 3:i * 3 + 3]) for i in range(len(pal) // 3)]
    used = sorted(i for _, i in q.getcolors())
    joined = {}
    for i in used:
        joined[i] = next((joined[j] for j in used if j < i and _de_gap(colours[i], colours[j]) < FEATURE_CLASS_DE), i)
    q = Image.frombytes('L', q.size, bytes(joined.get(v, v) for v in q.tobytes()))
    return q.filter(ImageFilter.ModeFilter(3)).tobytes(), colours


def _cell_at(lines, v):
    """Pixel position v on one axis as a fractional cell index."""
    i = min(max(bisect.bisect_right(lines, v) - 1, 0), len(lines) - 2)
    return i + (v - lines[i]) / (lines[i + 1] - lines[i])


class Feature(NamedTuple):
    """A small source region (an eye, a nose, a spot) in cell units."""
    colour: tuple
    around: tuple
    area_cells: float
    box: tuple  # (x0, y0, x1, y1) fractional cells, x1/y1 exclusive
    mask: frozenset  # its source pixels, as (x, y)


def features(img, lines, classes=None):
    """Every small source region: a colour class region of FEATURE_AREA_CELLS
    cells whose colour is at least FEATURE_DE (CIEDE2000) from its surround,
    the class bordering it most. `lines` are the cell lines (xs, ys) in source
    pixels; `classes` is _source_classes(img), when the caller has it."""
    img = img.convert('RGB')
    w, h = img.size
    xs, ys = lines
    cell = _cell_px(lines)
    data, colours = classes or _source_classes(img)
    low, high = FEATURE_AREA_CELLS
    out = []
    for value, members in _components(w, h, data):
        area = len(members) / cell ** 2
        if not low <= area <= high:
            continue
        inside = set(members)
        ring = Counter()
        for p in members:
            x = p % w
            for q in (p - 1 if x else -1, p + 1 if x < w - 1 else -1, p - w, p + w):
                if 0 <= q < w * h and q not in inside:
                    ring[data[q]] += 1
        if not ring:
            continue
        around = colours[ring.most_common(1)[0][0]]
        bounded = sum(c for k, c in ring.items() if _de_gap(colours[k], colours[value]) >= FEATURE_DE)
        if _de_gap(colours[value], around) < FEATURE_DE or bounded < FEATURE_ENCLOSED * sum(ring.values()):
            continue
        px = [p % w for p in members]
        py = [p // w for p in members]
        if _cut_by_frame(px, py, w, h):
            continue
        box = (_cell_at(xs, min(px)), _cell_at(ys, min(py)), _cell_at(xs, max(px) + 1), _cell_at(ys, max(py) + 1))
        out.append(Feature(colours[value], around, area, box, frozenset((p % w, p // w) for p in members)))
    return out


def _cut_by_frame(px, py, w, h):
    """True for a region touching the picture's edge: its shape is unknown."""
    return min(px) == 0 or min(py) == 0 or max(px) == w - 1 or max(py) == h - 1


def _cell_px(lines):
    xs, ys = lines
    return ((xs[-1] - xs[0]) / (len(xs) - 1) + (ys[-1] - ys[0]) / (len(ys) - 1)) / 2


def _mirror_overlap(points):
    """How much a set of (x, y) points overlaps its own left-right mirror
    image (intersection over union, 1.0: symmetric)."""
    if not points:
        return 0.0
    xs = [x for x, _ in points]
    axis = min(xs) + max(xs)
    mirrored = {(axis - x, y) for x, y in points}
    return len(mirrored & points) / len(mirrored | points)


def _shape(cells):
    """A cell set moved to the origin, and its left-right mirror image."""
    if not cells:
        return frozenset(), frozenset()
    x0, y0 = min(x for x, _ in cells), min(y for _, y in cells)
    x1 = max(x for x, _ in cells)
    return (frozenset((x - x0, y - y0) for x, y in cells), frozenset((x1 - x, y - y0) for x, y in cells))


def _shape_text(cells):
    xs, ys = [x for x, _ in cells], [y for _, y in cells]
    return f'{len(cells)} cells in {max(xs) - min(xs) + 1}x{max(ys) - min(ys) + 1}' if cells else 'none'


def _hex(rgb):
    return '#%02x%02x%02x' % tuple(rgb)


def _ring_colour(img):
    """The commonest colour of the picture's outer ring of pixels."""
    w, h = img.size
    px = img.load()
    edges = [[px[x, 0] for x in range(w)]] + [[px[0, y], px[w - 1, y]] for y in range(1, h - 1)]
    return _ring_mode(edges + [[px[x, h - 1] for x in range(w)]])[0]


def feature_check(src, puzzle, lines):
    """The source features (features) that the converted `puzzle` lost, as
    dicts: 'cells' (x0, y0, x1, y1, inclusive), 'colour' and 'around'
    (#rrggbb), 'area' (cells), 'subject' (inside the puzzle's subject box; a
    scene's subject is the whole grid) and 'why'. `src` is the source image,
    `lines` its cell lines (xs, ys) in source pixels: the block lines of the
    read the puzzle was converted from.

    A feature's cells are the puzzle cells within FEATURE_REACH_CELLS cells of it
    whose colour is on its side (closer to its colour than to its
    surround's), less those the source fills mostly with other shapes on
    that side (an outline next to an eye is not the eye). It is missed when:
    - its colour and its surround's map to the same puzzle colour (merged);
    - it takes the background colour of a subject on a plain background,
      though the source drew it at least FEATURE_BG_DE from that background;
    - it has no cells: gone, or moved by more than FEATURE_REACH_CELLS;
    - its cells cover under half or over twice its area (at least one cell);
    - the source draws it mirror-symmetric (FEATURE_SYMMETRY) and its cells
      are not;
    - it is one of a pair (two eyes, two cheeks: like colour, size and
      shape, side by side) and the two get different cell shapes, mirrored
      or not.
    """
    img = src.convert('RGB')
    final = puzzle.convert('RGB')
    n = final.width
    cell = final.load()
    grid = [[cell[x, y] for x in range(n)] for y in range(n)]
    palette = {c for row in grid for c in row}
    bg = border_colour(grid)
    box = subject_box(grid, bg) if bg is not None else None
    subject = box or (0, 0, n, n)
    source_bg = _ring_colour(img) if bg is not None else None
    w, h = img.size
    classes = _source_classes(img)
    data, colours = classes
    xs, ys = lines

    def pixels(x, y):
        x0, x1 = max(round(xs[x]), 0), min(round(xs[x + 1]), w)
        y0, y1 = max(round(ys[y]), 0), min(round(ys[y + 1]), h)
        return [(px, py) for py in range(y0, y1) for px in range(x0, x1)]

    def nearest(colour):
        return min(palette, key=lambda c: _de_gap(c, colour))

    found, out = [], []
    for f in features(img, lines, classes):
        x0, y0, x1, y1 = f.box
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        if not (0 <= cx < n and 0 <= cy < n):
            continue
        side = {c for c in palette if _de_gap(c, f.colour) < _de_gap(c, f.around)}
        side_class = {i for i, c in enumerate(colours) if _de_gap(c, f.colour) < _de_gap(c, f.around)}
        r = FEATURE_REACH_CELLS
        mine = set()
        for y in range(max(math.floor(y0 - r), 0), min(math.ceil(y1 + r), n)):
            for x in range(max(math.floor(x0 - r), 0), min(math.ceil(x1 + r), n)):
                if grid[y][x] not in side or x + 1 <= x0 - r or x >= x1 + r or y + 1 <= y0 - r or y >= y1 + r:
                    continue
                inside = pixels(x, y)
                others = sum(p not in f.mask and data[p[1] * w + p[0]] in side_class for p in inside)
                if inside and others < 0.5 * len(inside):
                    mine.add((x, y))
        why = None
        if nearest(f.colour) == nearest(f.around):
            why = f'merged into its surround {_hex(nearest(f.around))}'
        elif bg is not None and nearest(f.colour) == bg and _de_gap(f.colour, source_bg) >= FEATURE_BG_DE:
            why = f'drawn in the background colour {_hex(bg)}'
        elif not mine:
            why = 'gone (no cell of its colour within half a cell)'
        elif not FEATURE_AREA_RATIO[0] * max(f.area_cells, 1.0) <= len(mine) <= FEATURE_AREA_RATIO[1] * max(f.area_cells, 1.0):
            why = f'{len(mine)} cells for {f.area_cells:.1f}'
        elif (f.area_cells >= FEATURE_SHAPE_CELLS and _mirror_overlap(f.mask) >= FEATURE_SYMMETRY
              and _mirror_overlap(mine) < FEATURE_SYMMETRY):
            why = f'lopsided: symmetric in the source, {_shape_text(mine)} here'
        inside = subject[0] <= cx < subject[2] and subject[1] <= cy < subject[3]
        found.append((f, mine, inside))
        if why:
            out.append(_missed(f, inside, why))
    missed = {o['cells'] for o in out}
    for (a, cells_a), (b, cells_b) in _pairs([(f, mine) for f, mine, inside in found if inside and f.area_cells <= FEATURE_PAIR_CELLS], n / 2):
        if cells_a and cells_b and _shape(cells_a)[0] not in _shape(cells_b):
            for f, cells, other in ((a, cells_a, cells_b), (b, cells_b, cells_a)):
                entry = _missed(f, True, f'pair drawn unevenly: {_shape_text(cells)} here, {_shape_text(other)} on '
                                         'the other side')
                if entry['cells'] not in missed:
                    missed.add(entry['cells'])
                    out.append(entry)
    return out


def _missed(f, inside, why):
    x0, y0, x1, y1 = f.box
    return {'cells': (math.floor(x0), math.floor(y0), math.ceil(x1) - 1, math.ceil(y1) - 1),
            'colour': _hex(f.colour), 'around': _hex(f.around), 'area': round(f.area_cells, 2),
            'subject': inside, 'why': why}


def _pairs(found, reach):
    """Mirror pairs among (feature, cells): like colour (FEATURE_PAIR_DE),
    area within FEATURE_PAIR_AREA of each other, a like source shape
    (FEATURE_PAIR_SHAPE, mirrored or not), centres within a cell of the same
    height and one cell to `reach` cells apart across. Each feature joins its nearest
    such partner when that one picks it back."""
    def centre(f):
        return (f.box[0] + f.box[2]) / 2, (f.box[1] + f.box[3]) / 2

    shapes = [_shape(f.mask) for f, _ in found]

    def alike(i, j):
        shape_a = shapes[i][0]
        return max(len(shape_a & s) / len(shape_a | s) for s in shapes[j]) >= FEATURE_PAIR_SHAPE

    def partner(i):
        a = found[i][0]
        (ax, ay), best = centre(a), None
        for j, (b, _) in enumerate(found):
            bx, by = centre(b)
            if (j != i and _de_gap(a.colour, b.colour) < FEATURE_PAIR_DE and abs(ay - by) <= 1
                    and 1 <= abs(ax - bx) <= reach and max(a.area_cells, b.area_cells) <= FEATURE_PAIR_AREA * min(a.area_cells, b.area_cells)
                    and (best is None or abs(ax - bx) < best[0]) and alike(i, j)):
                best = (abs(ax - bx), j)
        return best and best[1]

    chosen = [partner(i) for i in range(len(found))]
    return [(found[i], found[j]) for i, j in enumerate(chosen) if j is not None and j > i and chosen[j] == i]

def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('src', nargs='?')
    ap.add_argument('out', nargs='?', help='N x N indexed PNG')
    ap.add_argument('--grid', type=int, choices=sorted(COLOR_LIMIT))
    ap.add_argument('--colors', type=int,
                    help="palette limit (default: the level's, 6/8/12/16)")
    ap.add_argument('--preview', help='also write an upscaled PNG here')
    ap.add_argument('--native', help='also write the picture at its own grid here')
    ap.add_argument('--fit', choices=FIT_MODES,
                    help='place a source drawn near its grid 1:1 (pad a subject, trim a scene); '
                         'also turns on the region-safe colour cut')
    ap.add_argument('--check', action='store_true',
                    help='convert every puzzle picture in design/assets.toml '
                         'at its grid and verify the results')
    ap.add_argument('--all-grids', action='store_true',
                    help='with --check: try every picture at all four grids')
    ap.add_argument('--build', action='store_true',
                    help='write every puzzle picture to assets/pictures/<course>/<slug>.png')
    args = ap.parse_args(argv)
    if args.check:
        sys.exit(1 if check(puzzle_entries(), args.all_grids, PICTURES) else 0)
    if args.build:
        sys.exit(1 if build(puzzle_entries()) else 0)
    if not (args.src and args.out and args.grid):
        ap.error('src, out and --grid are required unless --check or --build is given')
    colors = args.colors or COLOR_LIMIT[args.grid]
    analysis = analyse(args.src, args.grid)
    placed = analysis
    if args.fit:
        try:
            placed = fit_analysis(analysis, args.grid, args.fit)
        except FitError as e:
            sys.exit(f'{e}: regenerate')
    out, info = convert(placed, args.grid, colors, LEVEL_GAP[args.grid], bool(args.fit))
    out.save(args.out)
    if args.preview:
        out.convert('RGB').resize((args.grid * 16,) * 2, Image.NEAREST).save(args.preview)
    if args.native:
        to_image(analysis[0]).save(args.native)
    print(f"block {info['block']} px, own grid "
          f"{analysis.frame[0]}x{analysis.frame[1]}, out {args.grid}x{args.grid}, "
          f"{info['colors']} colors" + (f", {placed.placement}" if placed.placement else '')
          + (" (no clean grid found: sampled evenly, check it by eye)" if info['fallback'] else ''))


if __name__ == '__main__':
    main(sys.argv[1:])
