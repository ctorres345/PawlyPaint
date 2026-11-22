"""Turns a generated pixel art picture into a PawlyPaint puzzle grid.

Image models draw pixel art on a block grid of their own, not the one the
prompt asks for, and a screen capture rescales it further. Splitting the image
evenly into the game's grid cuts across those blocks and breaks small details.
So this tool works in three steps:

1. Find the picture's own block grid (block size and offset): the largest
   block size on which the colour changes line up, on both axes.
2. Read one colour per block (the most common colour in its middle), giving
   the picture at its own resolution.
3. Shrink that to the game grid (16, 24, 32 or 40), picking for each cell the
   colour covering most of it, then cut the palette to the level's colour
   limit.

Needs Pillow. Run with a Python that has it, for example:
  python3 tool/art_to_puzzle.py in.png out.png --grid 16 --preview big.png
Prints the detected block size and the picture's own grid size. --colors
overrides the level's colour limit. --check converts every puzzle picture the
manifest (design/assets.toml) lists at all four grids and exits non-zero if
one is missing, has no clean pixel grid, or any result fails.
"""
import argparse
import math
import os
import sys
import tomllib
from collections import Counter

from PIL import Image

# Two colour distances on purpose: edge finding wants a cheap test of "did
# the colour change at all", palette merging wants how alike two colours look.
EDGE = 48  # summed RGB difference that counts as a colour change
SHADE_MERGE = 9 * 18 ** 2  # _dist below which capture shades are one colour
INSET = 0.25  # part of each block edge skipped when reading its colour
# Game grid size per level -> the level's colour limit (design/brief.md).
COLOR_LIMIT = {16: 6, 24: 8, 32: 12, 40: 16}
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, 'design', 'assets.toml')
PUZZLE_PREFIX = 'puzzle_classics_'
# Same floor as separateColors (lib/data/simplify.dart): colours closer than
# this in plain RGB look alike as drill colours.
MIN_RGB_GAP = 24.0
MAX_SHARE = 0.95  # --check: most of one colour means the subject vanished


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


def find_grid(cols, rows, min_block=4.0, max_cells=160):
    """Returns (block size, x offset, y offset) of the picture's square grid,
    or None when the colour changes don't line up on any grid.

    Every divisor of the true block size lines up as well as the block
    itself, while multiples do not, so the answer is the largest block size
    that lines up nearly as well as the best one. `max_cells` leaves room for
    Gemini's own grid, which runs to about 100 cells across.
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


def shrink(grid, n):
    """Area-weighted majority colour of the native blocks under each cell."""
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
            votes = Counter()
            for gy in range(int(y0), min(gh, math.ceil(y1))):
                hy = min(y1, gy + 1) - max(y0, gy)
                for gx in range(int(x0), min(gw, math.ceil(x1))):
                    hx = min(x1, gx + 1) - max(x0, gx)
                    if hx > 0 and hy > 0:
                        votes[grid[gy][gx]] += hx * hy
            if not votes:  # rounding left no overlap: take the nearest block
                votes[grid[min(gh - 1, int(y0))][min(gw - 1, int(x0))]] = 1
            row.append(votes.most_common(1)[0][0])
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


def min_gap(colours):
    """Smallest plain RGB distance between any two colours (inf for one)."""
    colours = list(colours)
    return min((_rgb_gap(a, b) for i, a in enumerate(colours) for b in colours[i + 1:]),
               default=math.inf)


def reduce_palette(grid, limit=None, merge_below=0, gap=0.0):
    """Merges the closest pair of colours until the palette fits.

    Merging stops early at `limit` colours, and always goes on while the
    closest pair is nearer than `merge_below`, which folds the many shades a
    screen capture gives one flat colour back into one, or any pair is under
    `gap` apart in plain RGB, so no two drill colours look alike. Small but distinct
    colours (an eye, a shine) survive, unlike with a median cut.
    """
    counts = Counter(c for row in grid for c in row)
    parent = {}  # colour -> the group it joined (followed to the root below)
    pal = {}  # group key -> [count, r sum, g sum, b sum]
    means = {}

    def add(key, c, n):
        t = pal.setdefault(key, [0, 0, 0, 0])
        t[0] += n
        t[1] += c[0] * n
        t[2] += c[1] * n
        t[3] += c[2] * n
        means[key] = (round(t[1] / t[0]), round(t[2] / t[0]), round(t[3] / t[0]))

    # One quick pass first: each colour, most common first, joins the first
    # group within `merge_below`, so the pairwise loop below starts small.
    for c, n in counts.most_common():
        home = next((k for k in pal if _dist(c, means[k]) < merge_below), c)
        parent[c] = home
        add(home, c, n)

    while len(pal) > 1:
        keys = list(pal)
        d, a, b = min((_dist(means[a], means[b]), a, b)
                      for i, a in enumerate(keys) for b in keys[i + 1:])
        if d >= merge_below and (limit is None or len(pal) <= limit):
            if min_gap(means.values()) >= gap:
                break
            # Merge the look-alike pair instead of the closest by weight.
            _, a, b = min((_rgb_gap(means[a], means[b]), a, b)
                          for i, a in enumerate(keys) for b in keys[i + 1:])
        pb = pal.pop(b)
        del means[b]
        pal[a] = [x + y for x, y in zip(pal[a], pb)]
        t = pal[a]
        means[a] = (round(t[1] / t[0]), round(t[2] / t[0]), round(t[3] / t[0]))
        parent[b] = a

    def root(c):
        while parent[c] != c:
            c = parent[c]
        return c

    return [[means[root(c)] for c in row] for row in grid]


def to_indexed(grid):
    """The grid as a palette ('P') PNG image with exactly its own colours."""
    colours = sorted({c for row in grid for c in row})
    index = {c: i for i, c in enumerate(colours)}
    img = Image.new('P', (len(grid[0]), len(grid)))
    img.putpalette([v for c in colours for v in c])
    img.putdata([index[c] for row in grid for c in row])
    return img, len(colours)


def analyse(src):
    """Reads the picture at its own grid, with capture shades folded together.

    Returns (native grid, block size, whether a clean grid was found). The
    result does not depend on the target grid, so one analysis serves all four.
    """
    img = Image.open(src).convert('RGB')
    cols, rows = edge_profiles(img)
    found = find_grid(cols, rows)
    # No clean grid (blurred capture or free-hand pixels): sample twice as fine
    # as the largest game grid, so the majority vote in shrink still has a say.
    period, phase_x, phase_y = found or (min(img.size) / (2 * max(COLOR_LIMIT)), 0.0, 0.0)
    native = native_grid(img, period, phase_x, phase_y)
    # Fold capture shades together first so they don't split the vote.
    return reduce_palette(native, merge_below=SHADE_MERGE), period, found is not None


def convert(analysis, n, colors):
    native, period, clean = analysis
    out, used = to_indexed(reduce_palette(shrink(native, n), limit=colors,
                                          gap=MIN_RGB_GAP))
    info = {
        'block': round(period, 2),
        'native': (len(native[0]), len(native)),
        'colors': used,
        'fallback': not clean,
    }
    return out, info


def expected_sources(manifest=MANIFEST):
    """The source image of every puzzle picture the asset manifest lists."""
    with open(manifest, 'rb') as f:
        assets = tomllib.load(f).get('asset', [])
    return [os.path.join(REPO, a['source']) for a in assets
            if a.get('name', '').startswith(PUZZLE_PREFIX)]


def check(paths):
    """Converts every picture at all four grids and checks each result.

    Returns the number of failures. A picture fails when it is missing, can't
    be read, or has no clean pixel grid (its result would be guessed). A
    result passes when it has 2 to the level's colour limit, every pair of
    colours is at least MIN_RGB_GAP apart (distinct drill colours; the game's
    separateColors still applies its CIEDE2000 gap on import), and no single
    colour covers more than MAX_SHARE of it (the subject is still there).
    """
    if not paths:
        print(f'the manifest lists no {PUZZLE_PREFIX}* pictures')
        return 1
    failures = 0
    for path in paths:
        name = os.path.basename(path)
        if not os.path.exists(path):
            print(f'FAIL {name} missing')
            failures += len(COLOR_LIMIT)
            continue
        try:
            analysis = analyse(path)
        except (OSError, ValueError) as e:
            print(f'FAIL {name} unreadable: {e}')
            failures += len(COLOR_LIMIT)
            continue
        for n, limit in COLOR_LIMIT.items():
            out, info = convert(analysis, n, limit)
            counts = out.getcolors()
            share = max(c for c, _ in counts) / (n * n)
            pal = out.getpalette()
            gap = min_gap(tuple(pal[i * 3:i * 3 + 3]) for _, i in counts)
            ok = (out.mode == 'P' and out.size == (n, n) and not info['fallback']
                  and 2 <= info['colors'] <= limit
                  and share <= MAX_SHARE and gap >= MIN_RGB_GAP)
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {name} {n}x{n} "
                  f"{info['colors']}/{limit} colors, top colour {share:.0%}, "
                  f"closest pair {gap:.0f}"
                  + (' (no clean grid)' if info['fallback'] else ''), flush=True)
    print(f'{len(paths) * len(COLOR_LIMIT) - failures} passed, {failures} failed')
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
                         'at all four grids and verify the results')
    args = ap.parse_args(argv)
    if args.check:
        sys.exit(1 if check(expected_sources()) else 0)
    if not (args.src and args.out and args.grid):
        ap.error('src, out and --grid are required unless --check is given')
    colors = args.colors or COLOR_LIMIT[args.grid]
    analysis = analyse(args.src)
    out, info = convert(analysis, args.grid, colors)
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
