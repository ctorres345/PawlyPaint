"""Lays out every try of a tool/pixel_gen.py run on one contact sheet (PAP-97).

Each run folder (one picture: its report.json, kept tries, rejected/) gets a
row of tiles, one a try: the source, the puzzle (lost features boxed, when
the try got that far), KEPT or rejected, the canvas and seed, the on-lattice
share, how many features it lost inside the subject and why it was rejected.

  ~/.local/share/nousfx/via/venv/bin/python3 tool/contact_sheet.py <run folder>... --out sheet.png
"""
import argparse
import json
import math
import os
import sys
import textwrap

from PIL import Image, ImageDraw, ImageFont

THUMB = 192
GAP = 8
COLUMNS = 6
TEXT_LINES = 5
LINE_PX = 15
WRAP = 52
PAPER, INK, KEPT, REJECTED, EMPTY = (250, 246, 240), (20, 20, 20), (20, 130, 60), (190, 40, 40), (225, 225, 225)


def _font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def tries(run):
    """Every try in a run folder, in the order made: (row, kept, source path,
    puzzle path or None)."""
    with open(os.path.join(run, 'report.json')) as f:
        report = json.load(f)
    rows = [(r, True) for r in report['hits']] + [(r, False) for r in report['misses']]
    rows.sort(key=lambda rk: (rk[0]['scale'], rk[0]['seed']))
    out = []
    for row, kept in rows:
        where = run if kept else os.path.join(run, 'rejected')
        stem = f"{report['name']}-c{row['scale']}-s{row['seed']}"
        source, puzzle = os.path.join(where, f'{stem}.png'), os.path.join(where, f'puzzle-{stem}.png')
        out.append((row, kept, source if os.path.exists(source) else None, puzzle if os.path.exists(puzzle) else None))
    return report, out


def caption(row, kept):
    """The text under a tile."""
    share = '-' if row.get('on_lattice') is None else f"{row['on_lattice']:.0%}"
    lost = sum(1 for f in row.get('features') or [] if f['subject'])
    head = f"{'KEPT' if kept else 'rejected'}  c{row['scale']} s{row['seed']}  lattice {share}  lost {lost}"
    return [head] + textwrap.wrap(row.get('why') or '', WRAP, max_lines=TEXT_LINES - 1, placeholder=' ...')


def _thumb(path):
    if not path:
        return Image.new('RGB', (THUMB, THUMB), EMPTY)
    with Image.open(path) as img:
        return img.convert('RGB').resize((THUMB, THUMB), Image.NEAREST)


def sheet(runs):
    """The contact sheet of the run folders, and one text line a try."""
    tile_w, tile_h = 2 * THUMB + GAP, THUMB + GAP + TEXT_LINES * LINE_PX
    blocks, lines = [], []
    for run in runs:
        report, made = tries(run)
        blocks.append((report, made))
        for row, kept, _, _ in made:
            lines.append(f"{report['name']} " + ' | '.join(caption(row, kept)))

    def rows_of(made):
        return math.ceil(max(len(made), 1) / COLUMNS)

    title_h = 2 * LINE_PX
    height = GAP + sum(title_h + rows_of(m) * (tile_h + GAP) for _, m in blocks)
    width = GAP + COLUMNS * (tile_w + 2 * GAP)
    page = Image.new('RGB', (width, height), PAPER)
    draw = ImageDraw.Draw(page)
    small, big = _font(12), _font(16)
    y = GAP
    for report, made in blocks:
        kept = sum(k for _, k, _, _ in made)
        draw.text((GAP, y), f"{report['name']}  grid {report['grid']}  {report['fit']}  {kept}/{len(made)} kept",
                  fill=INK, font=big)
        y += title_h
        for i, (row, ok, source, puzzle) in enumerate(made):
            x, ty = GAP + (i % COLUMNS) * (tile_w + 2 * GAP), y + (i // COLUMNS) * (tile_h + GAP)
            page.paste(_thumb(source), (x, ty))
            page.paste(_thumb(puzzle), (x + THUMB + GAP, ty))
            draw.rectangle([x - 3, ty - 3, x + tile_w + 2, ty + THUMB + 2], outline=KEPT if ok else REJECTED, width=3)
            for j, text in enumerate(caption(row, ok)):
                draw.text((x, ty + THUMB + GAP + j * LINE_PX), text, fill=(KEPT if ok else REJECTED) if j == 0 else INK,
                          font=small)
        y += rows_of(made) * (tile_h + GAP)
    return page, lines


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('runs', nargs='+', help='pixel_gen.py --out folders')
    ap.add_argument('--out', required=True, help='the sheet PNG (keep it outside the repo)')
    args = ap.parse_args(argv)
    missing = [r for r in args.runs if not os.path.exists(os.path.join(r, 'report.json'))]
    if missing:
        sys.exit(f"no report.json in {', '.join(missing)}")
    page, lines = sheet(args.runs)
    page.save(args.out)
    print('\n'.join(lines))
    print(f'{len(lines)} tries on {args.out}')


if __name__ == '__main__':
    main(sys.argv[1:])
