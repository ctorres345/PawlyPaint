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
   limit and its CIEDE2000 colour gap (the game's, lib/data/simplify.dart).

Needs Pillow. Run with a Python that has it, for example:
  python3 tool/art_to_puzzle.py in.png out.png --grid 16 --preview big.png
Prints the detected block size and the picture's own grid size. --colors
overrides the level's colour limit.

The asset manifest (design/assets.toml) lists every picture source: a puzzle
entry has `course`, `slug` and `grid`. --check converts each at its own grid
and exits non-zero if any fails (missing, no clean pixel grid, too few or too
many colours, one colour over 95% of cells, or two colours under the level's
gap). --build writes each to assets/pictures/<course>/<slug>.png. --all-grids
makes --check try every picture at all four grids (style spikes).
Tests: python3 -m unittest tool/test_art_to_puzzle.py
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
LEVEL_GAP = {16: 18.0, 24: 16.0, 32: 14.0, 40: 12.0}
MIN_COLOURS = 3
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, 'design', 'assets.toml')
PICTURES = os.path.join(REPO, 'assets', 'pictures')
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


def _closest(colours, measure):
    """(distance, a, b) of the closest pair of colours by `measure`, or
    (inf, None, None) when there is no pair."""
    colours = list(colours)
    return min(((measure(a, b), a, b) for i, a in enumerate(colours) for b in colours[i + 1:]),
               default=(math.inf, None, None))


def min_gap(colours):
    """Smallest plain RGB distance between any two colours (inf for one)."""
    return _closest(colours, _rgb_gap)[0]


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
    median cut.
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

    def closest(measure):
        keys = list(pal)
        return min((measure(means[a], means[b]), a, b)
                   for i, a in enumerate(keys) for b in keys[i + 1:])

    while len(pal) > 1:
        d, a, b = closest(_dist)
        palette_fits = d >= merge_below and (limit is None or len(pal) <= limit)
        if palette_fits:
            d, a, b = closest(_rgb_gap)
            if d >= gap:
                if not de_gap:
                    break
                d, a, b = closest(_de_gap)
                if d >= de_gap:
                    break
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


def convert(analysis, n, colors, de_gap=0.0):
    native, period, clean = analysis
    out, used = to_indexed(reduce_palette(shrink(native, n), limit=colors,
                                          gap=MIN_RGB_GAP, de_gap=de_gap))
    info = {
        'block': round(period, 2),
        'native': (len(native[0]), len(native)),
        'colors': used,
        'fallback': not clean,
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
        seen.add(key)
        out.append({'course': a['course'], 'slug': a['slug'], 'grid': a['grid'],
                    'source': os.path.join(REPO, a['source'])})
    return out


def verify(img, n):
    """What is wrong with a converted picture for a level of grid n (empty: ok)."""
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
    return problems


def convert_entry(entry, grids=None):
    """Converts one manifest picture at its grid (or at each of `grids`).
    Returns (problems, {grid: (image, info)}); each problem is prefixed with
    the grid when there are several."""
    path = entry['source']
    if not os.path.exists(path):
        shown = os.path.relpath(path, REPO) if path.startswith(REPO + os.sep) else path
        return [f'missing source {shown}'], {}
    try:
        analysis = analyse(path)
    except (OSError, ValueError) as e:
        return [f'unreadable: {e}'], {}
    if not analysis[2]:
        return ['no clean grid (sampled evenly, check it by eye)'], {}
    problems, outputs = [], {}
    for n in grids or [entry['grid']]:
        outputs[n] = convert(analysis, n, COLOR_LIMIT[n], LEVEL_GAP[n])
        problems += [f'{n}x{n}: {p}' if grids else p for p in verify(outputs[n][0], n)]
    return problems, outputs


def check_picture(entry, grids=None):
    """The problems of one manifest picture (empty: it passes)."""
    return convert_entry(entry, grids)[0]


def check(entries, all_grids=False):
    """Checks every picture and prints one line each. Returns the failures."""
    if not entries:
        print('the manifest lists no puzzle pictures')
        return 1
    failures = 0
    for e in entries:
        problems = check_picture(e, sorted(COLOR_LIMIT) if all_grids else None)
        failures += bool(problems)
        print(f"{'FAIL' if problems else 'ok  '} {e['course']}/{e['slug']} {e['grid']}x{e['grid']}"
              + (': ' + '; '.join(problems) if problems else ''), flush=True)
    print(f'{len(entries)} pictures, {failures} failed')
    return failures


def build(entries, out_root=PICTURES):
    """Writes every picture that passes to <out_root>/<course>/<slug>.png.
    Returns the failures; a failing picture is not written."""
    failures = 0
    for e in entries:
        n = e['grid']
        problems, outputs = convert_entry(e)
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
        sys.exit(1 if check(puzzle_entries(), args.all_grids) else 0)
    if args.build:
        sys.exit(1 if build(puzzle_entries()) else 0)
    if not (args.src and args.out and args.grid):
        ap.error('src, out and --grid are required unless --check or --build is given')
    colors = args.colors or COLOR_LIMIT[args.grid]
    analysis = analyse(args.src)
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
