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

Needs Pillow. Run with a Python that has it, for example:
  python3 tool/art_to_puzzle.py in.png out.png --grid 16 --preview big.png
Prints the detected block size and the picture's own grid size. --colors
overrides the level's colour limit.

The asset manifest (design/assets.toml) lists every picture source: a puzzle
entry has `course`, `slug`, `grid` and optionally `exact = true`. --check
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
import math
import os
import sys
import tomllib
from collections import Counter
from functools import lru_cache
from typing import NamedTuple

from PIL import Image

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


def border_colour(grid):
    """The plain background colour around the picture, or None for a full
    scene: the most common colour of the outer ring of blocks, when it covers
    at least PLAIN_BORDER of that ring and PLAIN_BACKGROUND of the picture."""
    colour, count, ring = _ring_mode(grid)
    if count < PLAIN_BORDER * ring:
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


def _de_gap(a, b):
    return de2000(lab(a), lab(b))


def min_de_gap(colours):
    """Smallest CIEDE2000 difference between any two colours (inf for one)."""
    return _closest(colours, _de_gap)[0]


def reduce_palette(grid, limit=None, merge_below=0, gap=0.0, de_gap=0.0):
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

    while len(group_cells) > 1:
        d, a, b = closest(_dist)
        palette_fits = d >= merge_below and (limit is None or len(group_cells) <= limit)
        if palette_fits:
            d, a, b = closest(_rgb_gap)
            if d >= gap:
                if not de_gap:
                    break
                d, a, b = closest(_de_gap)
                if d >= de_gap:
                    break
        group_cells[a] += group_cells.pop(b)
        biggest_member[a] = max(biggest_member[a], biggest_member.pop(b))
        parent[b] = a

    def root(c):
        while parent[c] != c:
            c = parent[c]
        return c

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


def convert(analysis, n, colors, de_gap=0.0):
    """The n x n indexed picture and its info. info['subject'] is the
    subject's share of the cropped native read (None for a full scene), which
    verify compares with the result.

    The palette is cut to the level's drill colours before the shrink as well
    as after, so the rarity vote in shrink weighs drill colours rather than
    leftover capture shades. A source read at exactly n x n blocks converts
    block for block: crop never goes under n blocks, so it keeps the grid
    whole, and shrink gives each cell its one block. Only the palette cut
    changes it."""
    native, period, clean = analysis
    bg = border_colour(native)

    def fit(grid):
        return reduce_palette(grid, limit=colors, gap=MIN_RGB_GAP, de_gap=de_gap)

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
        seen.add(key)
        out.append({'course': a['course'], 'slug': a['slug'], 'grid': a['grid'],
                    'source': os.path.join(REPO, a['source']), 'exact': exact})
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


def exact_problem(entry, analysis):
    """Why an `exact` entry's source isn't drawn at its grid, or None. The
    whole frame must be grid x grid blocks: 1:1 needs every block of the
    source, so a subject square of the right size inside a bigger frame
    doesn't count."""
    n = entry['grid']
    if not entry.get('exact') or analysis.frame == (n, n):
        return None
    return f'drawn at {blocks_text(analysis.frame)}, needs {n}: regenerate'


def convert_entry(entry, grids=None):
    """Converts one manifest picture at its grid (or at each of `grids`).
    Returns (problems, {grid: (image, info)}, analysis or None); each problem
    is prefixed with the grid when there are several."""
    path = entry['source']
    if not os.path.exists(path):
        shown = os.path.relpath(path, REPO) if path.startswith(REPO + os.sep) else path
        return [f'missing source {shown}'], {}, None
    try:
        analysis = analyse(path, entry['grid'])
    except (OSError, ValueError) as e:
        return [f'unreadable: {e}'], {}, None
    if not analysis.clean:
        regenerate = f', needs {entry["grid"]}: regenerate' if entry.get('exact') else ''
        return [f'no clean grid (sampled evenly, check it by eye){regenerate}'], {}, analysis
    problems, outputs = list(filter(None, [exact_problem(entry, analysis)])), {}
    for n in grids or [entry['grid']]:
        outputs[n] = convert(analysis, n, COLOR_LIMIT[n], LEVEL_GAP[n])
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
    note = ' (no clean grid)' if not analysis.clean else f' (subject {subject})' if subject else ''
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


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('src', nargs='?')
    ap.add_argument('out', nargs='?', help='N x N indexed PNG')
    ap.add_argument('--grid', type=int, choices=sorted(COLOR_LIMIT))
    ap.add_argument('--colors', type=int,
                    help="palette limit (default: the level's, 6/8/12/16)")
    ap.add_argument('--preview', help='also write an upscaled PNG here')
    ap.add_argument('--native', help='also write the picture at its own grid here')
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
    out, info = convert(analysis, args.grid, colors, LEVEL_GAP[args.grid])
    out.save(args.out)
    if args.preview:
        out.convert('RGB').resize((args.grid * 16,) * 2, Image.NEAREST).save(args.preview)
    if args.native:
        to_image(analysis[0]).save(args.native)
    print(f"block {info['block']} px, own grid "
          f"{info['native'][0]}x{info['native'][1]}, out {args.grid}x{args.grid}, "
          f"{info['colors']} colors"
          + (" (no clean grid found: sampled evenly, check it by eye)" if info['fallback'] else ''))


if __name__ == '__main__':
    main(sys.argv[1:])
