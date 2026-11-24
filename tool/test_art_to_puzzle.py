"""Tests for tool/art_to_puzzle.py: one bad fixture per --check failure.

CI does not run these (it has no Python). Run by hand with a Python that has
Pillow:
  ~/.local/share/nousfx/via/venv/bin/python3 -m unittest tool/test_art_to_puzzle.py
"""
import io
import math
import os
import random
import sys
import tempfile
import threading
import unittest
from collections import Counter
from contextlib import redirect_stdout
from unittest import mock

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_to_puzzle as a2p  # noqa: E402

RED, GREEN, BLUE, YELLOW, WHITE = (220, 30, 40), (40, 160, 60), (30, 60, 200), (250, 220, 40), (255, 255, 255)


def blocks(colours, cells=32, block=16, seed=1):
    """A pixel art picture: cells x cells blocks, each one colour from `colours`."""
    rnd = random.Random(seed)
    img = Image.new('RGB', (cells * block, cells * block))
    for y in range(cells):
        for x in range(cells):
            img.paste(rnd.choice(colours), (x * block, y * block, (x + 1) * block, (y + 1) * block))
    return img


def indexed(rows, palette):
    """An indexed image from rows of palette indexes."""
    img = Image.new('P', (len(rows[0]), len(rows)))
    img.putpalette([v for c in palette for v in c])
    img.putdata([i for row in rows for i in row])
    return img


def plain(w, h, colour):
    """A native grid (rows of RGB tuples) of one colour."""
    return [[colour] * w for _ in range(h)]


def paint(grid, x0, y0, x1, y1, colour):
    for y in range(y0, y1):
        for x in range(x0, x1):
            grid[y][x] = colour
    return grid


class Crop(unittest.TestCase):
    def test_ground_that_runs_off_the_frame_stays_on_its_edges(self):
        grid = paint(plain(98, 100, WHITE), 0, 85, 98, 100, GREEN)
        grid = paint(grid, 40, 20, 60, 40, RED)
        framed = a2p.crop(grid, 40)
        self.assertEqual(len(framed), 98)
        self.assertEqual(set(framed[-1]), {GREEN})
        self.assertEqual({row[0] for row in framed[-15:]} | {row[-1] for row in framed[-15:]}, {GREEN})

    def test_an_oversized_square_pads_only_the_open_side(self):
        size, side = 10, 20
        self.assertEqual(a2p._square_start(0, 8, side, size), 0)
        self.assertEqual(a2p._square_start(2, size, side, size), size - side)
        self.assertEqual(a2p._square_start(2, 8, side, size), -5)

    def test_a_one_block_diagonal_antenna_is_kept(self):
        grid = paint(plain(100, 100, WHITE), 40, 50, 60, 80, RED)
        for i in range(1, 15):
            grid[50 - i][60 + i - 1] = RED
        self.assertEqual(a2p.subject_box(grid, WHITE), (40, 36, 74, 80))

    def test_crops_a_square_around_the_subject_with_one_cell_of_margin(self):
        w, h, n = 20, 40, 16
        grid = paint(plain(100, 100, WHITE), 60, 50, 60 + w, 50 + h, RED)
        framed = a2p.crop(grid, n)
        side = math.ceil(h * n / (n - 2))
        self.assertEqual((len(framed), len(framed[0])), (side, side))
        reds = [(x, y) for y, row in enumerate(framed) for x, c in enumerate(row) if c == RED]
        self.assertEqual(len(reds), w * h)
        margin = side / n
        self.assertGreaterEqual(min(y for _, y in reds), margin - 1)
        self.assertLessEqual(max(y for _, y in reds), side - margin)

    def test_never_crops_below_the_target_grid(self):
        grid = paint(plain(100, 100, WHITE), 50, 50, 53, 53, RED)
        self.assertEqual(len(a2p.crop(grid, 40)), 40)

    def test_a_full_scene_keeps_the_whole_frame(self):
        grid = [[(x * 2, y * 2, 100) for x in range(60)] for y in range(60)]
        self.assertIs(a2p.crop(grid, 16), grid)
        self.assertIsNone(a2p.border_colour(grid))

    def test_a_frame_line_around_a_full_scene_is_not_a_background(self):
        grid = [[(x * 2, y * 2, 100) for x in range(60)] for y in range(60)]
        for i in range(60):
            grid[0][i] = grid[59][i] = grid[i][0] = grid[i][59] = BLUE
        self.assertIsNone(a2p.border_colour(grid))
        self.assertIs(a2p.crop(grid, 16), grid)

    def test_a_stray_speck_does_not_widen_the_crop(self):
        grid = paint(plain(100, 100, WHITE), 40, 40, 60, 60, RED)
        speck_x, speck_y = 97, 2
        grid[speck_y][speck_x] = BLUE
        self.assertEqual(a2p.subject_box(grid, WHITE), (40, 40, 60, 60))

    def test_a_subject_wider_than_a_short_frame_is_padded_not_cut(self):
        grid = paint(plain(100, 40, WHITE), 5, 10, 95, 30, RED)
        framed = a2p.crop(grid, 16)
        self.assertEqual(len(framed), len(framed[0]))
        self.assertEqual(sum(c == RED for row in framed for c in row), 90 * 20)


class DominantMerge(unittest.TestCase):
    def test_a_merged_group_keeps_its_biggest_members_colour(self):
        pale_bg, pale_body = (200, 200, 235), (214, 214, 240)
        body_rows = 3
        grid = paint(plain(10, 10, pale_bg), 0, 0, 10, body_rows, pale_body)
        out = a2p.reduce_palette(grid, gap=a2p.MIN_RGB_GAP)
        self.assertEqual({c for row in out for c in row}, {pale_bg})

    def test_the_most_common_colour_wins_over_a_bigger_group_of_shades(self):
        shade_a, shade_b, flat = (100, 100, 100), (115, 100, 100), (100, 100, 120)
        grid = [[shade_a] * 40 + [shade_b] * 35 + [flat] * 50]
        out = a2p.reduce_palette(grid, limit=1)
        self.assertEqual({c for row in out for c in row}, {flat})

    def test_shade_folding_keeps_the_main_shade(self):
        grid = paint(plain(10, 10, RED), 0, 0, 10, 2, (226, 34, 44))
        out = a2p.reduce_palette(grid, merge_below=a2p.SHADE_MERGE)
        self.assertEqual({c for row in out for c in row}, {RED})


class DetailVote(unittest.TestCase):
    def face_with_outline_and_eye_in_cell_3_3(self):
        """48 x 48 yellow blocks with a one-block outline ring. At 16 cells a
        cell is 3 x 3 blocks; the 2 x 2 eye covers 4/9 of cell (3, 3)."""
        grid = plain(48, 48, YELLOW)
        for i in range(48):
            grid[0][i] = grid[47][i] = grid[i][0] = grid[i][47] = BLUE
        return paint(grid, 10, 10, 12, 12, BLUE)

    def test_a_small_feature_wins_a_cell_it_covers_under_half_of(self):
        self.assertEqual(a2p.shrink(self.face_with_outline_and_eye_in_cell_3_3(), 16)[3][3], BLUE)

    def test_the_plain_majority_vote_drops_it(self):
        no_colour_qualifies = 1.01
        with mock.patch.object(a2p, 'DETAIL_SHARE', no_colour_qualifies):
            out = a2p.shrink(self.face_with_outline_and_eye_in_cell_3_3(), 16)
        self.assertFalse(any(out[y][x] == BLUE for y in range(1, 15) for x in range(1, 15)))

    def test_a_sliver_under_the_minimum_share_does_not_win(self):
        grid = plain(64, 64, YELLOW)
        sliver_x, sliver_y = 10, 10
        grid[sliver_y][sliver_x] = BLUE
        self.assertEqual({c for row in a2p.shrink(grid, 16) for c in row}, {YELLOW})

    def test_even_texture_does_not_speckle(self):
        fur, stroke = (150, 100, 60), (90, 60, 30)
        grid = [[stroke if (x + 2 * y) % 5 == 0 else fur for x in range(48)] for y in range(48)]
        self.assertEqual({c for row in a2p.shrink(grid, 16) for c in row}, {fur})

    def test_a_one_block_outline_stays_one_cell_thick(self):
        out = a2p.shrink(self.face_with_outline_and_eye_in_cell_3_3(), 16)
        self.assertTrue(all(out[0][x] == BLUE and out[1][x] == YELLOW for x in range(2, 14)))


class SubjectLoss(unittest.TestCase):
    def test_fails_a_subject_merged_into_the_background(self):
        rows = [[0] * 16 for _ in range(16)]
        for x, y, colour in [(3, 3, 1), (4, 3, 2), (3, 4, 1)]:
            rows[y][x] = colour
        img = indexed(rows, [WHITE, RED, BLUE])
        self.assertTrue(any('subject' in p for p in a2p.verify(img, 16, subject=0.5)))

    def test_passes_a_subject_that_kept_its_cells(self):
        rows = [[1 if 3 <= x < 13 and 3 <= y < 13 else 0 for x in range(16)] for y in range(16)]
        rows[5][5] = 2
        img = indexed(rows, [WHITE, RED, BLUE])
        self.assertEqual(a2p.verify(img, 16, subject=0.45), [])

    def test_check_passes_a_framed_subject(self):
        grid = paint(plain(80, 80, WHITE), 20, 20, 60, 60, RED)
        paint(grid, 30, 30, 34, 34, BLUE)
        paint(grid, 46, 30, 50, 34, GREEN)
        out, info = a2p.convert(a2p.Analysis(grid, 8.0, True), 16, a2p.COLOR_LIMIT[16], a2p.LEVEL_GAP[16])
        self.assertAlmostEqual(info['subject'], 40 * 40 / info['crop'] ** 2)
        self.assertEqual(a2p.verify(out, 16, info['subject']), [])


class Fixtures(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)

    def save(self, name, img):
        path = os.path.join(self.dir.name, name)
        img.save(path)
        return path

    def entry(self, path, grid=16, slug='pic'):
        return {'course': 'test', 'slug': slug, 'grid': grid, 'source': path}

    def problems_of(self, entry):
        return a2p.check_picture(entry)


class ColourGap(unittest.TestCase):
    def test_ciede2000_matches_sharma_wu_dalal_2005_pairs_1_7_17(self):
        self.assertAlmostEqual(a2p.de2000((50, 2.6772, -79.7751), (50, 0, -82.7485)), 2.0425, places=4)
        self.assertAlmostEqual(a2p.de2000((50, 0, 0), (50, -1, 2)), 2.3669, places=4)
        self.assertAlmostEqual(a2p.de2000((50, 2.5, 0), (73, 25, -18)), 27.1492, places=4)

    def test_lab_of_white_and_black(self):
        l, a, b = a2p.lab((255, 255, 255))
        self.assertAlmostEqual(l, 100, places=2)
        self.assertAlmostEqual(a, 0, delta=0.05)
        self.assertAlmostEqual(b, 0, delta=0.05)
        self.assertEqual(a2p.lab((0, 0, 0))[0], 0)

    def test_matches_the_game_colour_distance(self):
        pairs = [((220, 30, 40), (200, 40, 50), 4.6386), ((255, 255, 255), (0, 0, 0), 100.0),
                 ((40, 160, 60), (30, 60, 200), 61.2893), ((250, 220, 40), (255, 240, 120), 7.5354)]
        for a, b, de in pairs:
            self.assertAlmostEqual(a2p.min_de_gap([a, b]), de, places=4)


class Check(Fixtures):
    def test_a_good_picture_passes(self):
        path = self.save('good.png', blocks([RED, GREEN, BLUE, WHITE]))
        self.assertEqual(self.problems_of(self.entry(path)), [])

    def test_missing_source_fails(self):
        problems = self.problems_of(self.entry(os.path.join(self.dir.name, 'nope.png')))
        self.assertTrue(any('missing' in p for p in problems), problems)

    def test_no_clean_grid_fails(self):
        gradient = Image.new('RGB', (512, 512))
        gradient.putdata([(x // 2, y // 2, 128) for y in range(512) for x in range(512)])
        problems = self.problems_of(self.entry(self.save('blur.png', gradient)))
        self.assertTrue(any('no clean grid' in p for p in problems), problems)

    def test_fewer_than_three_colours_fails(self):
        path = self.save('two.png', blocks([RED, BLUE]))
        problems = self.problems_of(self.entry(path))
        self.assertTrue(any('colours' in p for p in problems), problems)

    def test_colours_too_close_for_the_level_are_merged_not_kept(self):
        red_9_de_away = (200, 40, 50)
        path = self.save('close.png', blocks([RED, red_9_de_away, BLUE, WHITE, GREEN]))
        out, _ = a2p.convert(a2p.analyse(path), 16, a2p.COLOR_LIMIT[16], a2p.LEVEL_GAP[16])
        pal = out.getpalette()
        used = [tuple(pal[i * 3:i * 3 + 3]) for _, i in out.getcolors()]
        self.assertGreaterEqual(a2p.min_de_gap(used), 18.0)

    def test_check_reports_every_picture_and_counts_failures(self):
        good = self.save('good.png', blocks([RED, GREEN, BLUE, WHITE]))
        entries = [self.entry(good, slug='a'), self.entry(os.path.join(self.dir.name, 'x.png'), slug='b')]
        self.assertEqual(a2p.check(entries), 1)


def layout(colours, cells, seed=1):
    """cells x cells rows of colours picked at random: what blocks() draws."""
    rnd = random.Random(seed)
    return [[rnd.choice(colours) for _ in range(cells)] for _ in range(cells)]


def draw(rows, block=32):
    """A pixel art picture with one block of `block` px per entry of `rows`."""
    img = Image.new('RGB', (len(rows[0]) * block, len(rows) * block))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            img.paste(c, (x * block, y * block, (x + 1) * block, (y + 1) * block))
    return img


def bordered(cells, border, colours, seed=1):
    """A one-block ring of `border` around random blocks of `colours`."""
    rows = layout(colours, cells, seed)
    for i in range(cells):
        rows[0][i] = rows[-1][i] = rows[i][0] = rows[i][-1] = border
    return rows


def pixels(img):
    w, h = img.size
    rgb = list(img.convert('RGB').getdata())
    return [rgb[y * w:(y + 1) * w] for y in range(h)]


class BlockCount(Fixtures):
    def test_counts_the_blocks_across_the_frame(self):
        analysis = a2p.analyse(self.save('37.png', blocks([RED, GREEN, BLUE, WHITE], cells=37)))
        self.assertEqual(analysis.frame, (37, 37))
        self.assertTrue(analysis.clean)

    def test_a_one_block_border_is_counted_not_dropped(self):
        rows = bordered(16, BLUE, [RED, GREEN, YELLOW, WHITE])
        analysis = a2p.analyse(self.save('border.png', draw(rows)))
        self.assertEqual(analysis.frame, (16, 16))

    def test_counts_the_subject_square_on_a_plain_background(self):
        rows = plain(37, 37, WHITE)
        for y, row in enumerate(layout([RED, GREEN, BLUE], 20)[:12]):
            rows[10 + y][8:28] = row
        analysis = a2p.analyse(self.save('subject.png', draw(rows, block=16)))
        self.assertEqual(analysis.subject, 20)

    def test_a_sparse_source_is_read_at_its_grid_not_a_multiple(self):
        one_block_eye_on_an_odd_line = (6, 6, 7, 7)
        rows = paint(plain(16, 16, WHITE), 4, 4, 12, 12, RED)
        path = self.save('sparse.png', draw(paint(rows, *one_block_eye_on_an_odd_line, BLUE)))
        self.assertNotEqual(a2p.analyse(path).frame, (16, 16))
        self.assertEqual(a2p.analyse(path, 16).frame, (16, 16))

    def test_a_source_drawn_at_half_the_grid_is_not_read_at_the_grid(self):
        path = self.save('8.png', blocks([RED, GREEN, BLUE, WHITE], cells=8, block=64))
        self.assertEqual(a2p.analyse(path, 16).frame, (8, 8))

    def test_shapes_on_every_second_block_line_read_at_half_the_grid(self):
        rows = paint(plain(16, 16, WHITE), 4, 4, 12, 12, RED)
        path = self.save('even.png', draw(paint(rows, 6, 6, 8, 8, BLUE)))
        self.assertEqual(a2p.analyse(path, 16).frame, (8, 8))

    def test_a_grid_hint_does_not_override_a_source_drawn_at_another_count(self):
        path = self.save('37.png', blocks([RED, GREEN, BLUE, WHITE], cells=37))
        self.assertEqual(a2p.analyse(path, 16).frame, (37, 37))

    def test_a_full_scene_has_no_subject_square(self):
        analysis = a2p.analyse(self.save('scene.png', blocks([RED, GREEN, BLUE, WHITE], cells=24)))
        self.assertIsNone(analysis.subject)


class OneToOne(Fixtures):
    def converted(self, rows, n=16):
        analysis = a2p.analyse(self.save('src.png', draw(rows)), n)
        out, _ = a2p.convert(analysis, n, a2p.COLOR_LIMIT[n], a2p.LEVEL_GAP[n])
        return pixels(out)

    def test_a_source_at_its_grid_converts_block_for_block(self):
        rows = layout([RED, GREEN, BLUE, YELLOW, WHITE], 16)
        self.assertEqual(self.converted(rows), rows)

    def test_a_one_block_border_stays_in_place(self):
        rows = bordered(16, BLUE, [RED, GREEN, YELLOW, WHITE])
        self.assertEqual(self.converted(rows), rows)

    def test_a_sparse_source_with_a_one_block_border_converts_block_for_block(self):
        rows = paint(plain(16, 16, WHITE), 5, 4, 10, 11, RED)
        rows[6][7] = GREEN
        for i in range(16):
            rows[0][i] = rows[-1][i] = rows[i][0] = rows[i][-1] = BLUE
        self.assertEqual(self.converted(rows), rows)

    def test_a_small_subject_is_not_cropped_or_shrunk(self):
        rows = paint(plain(16, 16, WHITE), 5, 5, 11, 11, RED)
        rows[7][7] = BLUE
        self.assertEqual(self.converted(rows), rows)

    def test_too_many_colours_are_merged_down_to_the_level(self):
        many = [RED, GREEN, BLUE, YELLOW, WHITE, (0, 0, 0), (250, 130, 200), (120, 60, 20)]
        out = self.converted(layout(many, 16))
        colours = {c for row in out for c in row}
        self.assertLessEqual(len(colours), a2p.COLOR_LIMIT[16])
        self.assertGreaterEqual(a2p.min_de_gap(colours), a2p.LEVEL_GAP[16])


class Exact(Fixtures):
    def exact(self, path, grid=16):
        return {**self.entry(path, grid), 'exact': True}

    def test_fails_a_source_drawn_at_the_wrong_block_count(self):
        path = self.save('37.png', blocks([RED, GREEN, BLUE, WHITE], cells=37))
        self.assertIn('drawn at 37 blocks, needs 16: regenerate', self.problems_of(self.exact(path)))

    def test_fails_a_source_drawn_at_half_its_grid(self):
        path = self.save('8.png', blocks([RED, GREEN, BLUE, WHITE], cells=8, block=64))
        self.assertIn('drawn at 8 blocks, needs 16: regenerate', self.problems_of(self.exact(path)))

    def test_without_the_flag_the_same_source_passes(self):
        path = self.save('37.png', blocks([RED, GREEN, BLUE, WHITE], cells=37))
        self.assertEqual(self.problems_of(self.entry(path)), [])

    def test_passes_a_source_drawn_at_its_grid(self):
        path = self.save('16.png', draw(bordered(16, BLUE, [RED, GREEN, YELLOW, WHITE])))
        self.assertEqual(self.problems_of(self.exact(path)), [])

    def test_fails_a_source_with_no_clean_grid(self):
        gradient = Image.new('RGB', (512, 512))
        gradient.putdata([(x // 2, y // 2, 128) for y in range(512) for x in range(512)])
        problems = self.problems_of(self.exact(self.save('blur.png', gradient)))
        self.assertTrue(any('no clean grid' in p and 'regenerate' in p for p in problems), problems)

    def test_check_prints_the_block_count_of_every_picture(self):
        path = self.save('37.png', blocks([RED, GREEN, BLUE, WHITE], cells=37))
        out = io.StringIO()
        with redirect_stdout(out):
            failures = a2p.check([self.entry(path, slug='a'), {**self.exact(path), 'slug': 'b'}])
        self.assertEqual(failures, 1)
        lines = out.getvalue().splitlines()
        self.assertRegex(lines[0], r'^ok   test/a source 37 blocks, grid 16, \d colours$')
        self.assertTrue(lines[1].startswith('FAIL test/b') and 'needs 16: regenerate' in lines[1], lines[1])


class Verify(unittest.TestCase):
    """The rules a converted picture must meet (some can't come out of convert)."""

    def test_too_many_colours(self):
        palette = [(i * 40, 255 - i * 40, (i * 90) % 256) for i in range(7)]
        img = indexed([[i % 7 for i in range(16)] for _ in range(16)], palette)
        self.assertTrue(any('colours' in p for p in a2p.verify(img, 16)))

    def test_one_colour_over_95_percent(self):
        rows = [[0] * 16 for _ in range(16)]
        rows[0][0], rows[0][1] = 1, 2
        img = indexed(rows, [WHITE, RED, BLUE])
        self.assertTrue(any('top colour' in p for p in a2p.verify(img, 16)))

    def test_gap_under_the_level_minimum(self):
        rows = [[(x + y) % 3 for x in range(16)] for y in range(16)]
        img = indexed(rows, [RED, (200, 40, 50), BLUE])
        self.assertTrue(any('colour gap' in p for p in a2p.verify(img, 16)))

    def test_wrong_size(self):
        img = indexed([[(x + y) % 3 for x in range(24)] for y in range(24)], [RED, GREEN, BLUE])
        self.assertTrue(any('size' in p for p in a2p.verify(img, 16)))

    def test_a_good_result_has_no_problems(self):
        img = indexed([[(x + y) % 3 for x in range(16)] for y in range(16)], [RED, GREEN, BLUE])
        self.assertEqual(a2p.verify(img, 16), [])


class Manifest(unittest.TestCase):
    def write(self, text):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        path = os.path.join(d.name, 'assets.toml')
        with open(path, 'w') as f:
            f.write(text)
        return path

    def test_reads_puzzle_entries_only(self):
        path = self.write('[[asset]]\nname = "ui"\nsource = "x.png"\n\n'
                          '[[asset]]\nname = "p"\nsource = "design/p.png"\n'
                          'course = "classics"\nslug = "heart-balloons"\ngrid = 40\n')
        (e,) = a2p.puzzle_entries(path)
        self.assertEqual((e['course'], e['slug'], e['grid']), ('classics', 'heart-balloons', 40))
        self.assertTrue(e['source'].endswith(os.path.join('design', 'p.png')))
        self.assertFalse(e['exact'])

    def test_reads_the_exact_flag_and_rejects_a_non_boolean(self):
        entry = '[[asset]]\nname = "p"\nsource = "p.png"\ncourse = "c"\nslug = "s"\ngrid = 16\n'
        (e,) = a2p.puzzle_entries(self.write(entry + 'exact = true\n'))
        self.assertTrue(e['exact'])
        with self.assertRaises(ValueError):
            a2p.puzzle_entries(self.write(entry + 'exact = "yes"\n'))

    def test_rejects_a_missing_source_or_a_bad_course(self):
        no_source = self.write('[[asset]]\nname = "p"\ncourse = "c"\nslug = "s"\ngrid = 16\n')
        with self.assertRaises(ValueError):
            a2p.puzzle_entries(no_source)
        bad_course = self.write('[[asset]]\nname = "p"\nsource = "p.png"\ncourse = "Cat-Cafe"\nslug = "s"\ngrid = 16\n')
        with self.assertRaises(ValueError):
            a2p.puzzle_entries(bad_course)

    def test_rejects_a_bad_grid_or_a_duplicate_slug(self):
        bad_grid = self.write('[[asset]]\nname = "p"\nsource = "p.png"\ncourse = "c"\nslug = "s"\ngrid = 20\n')
        with self.assertRaises(ValueError):
            a2p.puzzle_entries(bad_grid)
        twice = ('[[asset]]\nname = "p"\nsource = "p.png"\ncourse = "c"\nslug = "s"\ngrid = 16\n\n'
                 '[[asset]]\nname = "q"\nsource = "q.png"\ncourse = "c"\nslug = "s"\ngrid = 16\n')
        with self.assertRaises(ValueError):
            a2p.puzzle_entries(self.write(twice))

    def test_build_writes_one_indexed_png_per_picture(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        src = os.path.join(d.name, 'src.png')
        blocks([RED, GREEN, BLUE, WHITE]).save(src)
        out_root = os.path.join(d.name, 'pictures')
        entry = {'course': 'classics', 'slug': 'heart', 'grid': 24, 'source': src}
        self.assertEqual(a2p.build([entry], out_root), 0)
        with Image.open(os.path.join(out_root, 'classics', 'heart.png')) as img:
            self.assertEqual((img.mode, img.size), ('P', (24, 24)))
            self.assertNotIn('transparency', img.info)

    def test_check_fails_a_built_png_that_is_missing_or_out_of_date(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        src = os.path.join(d.name, 'src.png')
        blocks([RED, GREEN, BLUE, WHITE]).save(src)
        out_root = os.path.join(d.name, 'pictures')
        entry = {'course': 'classics', 'slug': 'heart', 'grid': 16, 'source': src}
        self.assertEqual(a2p.check([entry], out_root=out_root), 1)
        a2p.build([entry], out_root)
        self.assertEqual(a2p.check([entry], out_root=out_root), 0)
        built = os.path.join(out_root, 'classics', 'heart.png')
        indexed([[(x + y) % 3 for x in range(16)] for y in range(16)], [RED, GREEN, BLUE]).save(built)
        self.assertEqual(a2p.check([entry], out_root=out_root), 1)

    def test_build_removes_the_old_png_of_a_picture_that_now_fails(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        out_root = os.path.join(d.name, 'pictures')
        os.makedirs(os.path.join(out_root, 'classics'))
        stale = os.path.join(out_root, 'classics', 'heart.png')
        indexed([[0, 1, 2]], [RED, GREEN, BLUE]).save(stale)
        entry = {'course': 'classics', 'slug': 'heart', 'grid': 16, 'source': os.path.join(d.name, 'gone.png')}
        self.assertEqual(a2p.build([entry], out_root), 1)
        self.assertFalse(os.path.exists(stale))


if __name__ == '__main__':
    unittest.main()


class FitMode(Fixtures):
    """PAP-95: a source drawn near its grid is placed 1:1, never resampled."""

    def test_a_subject_that_fits_is_padded_with_its_background_block_for_block(self):
        native = paint(plain(22, 22, WHITE), 1, 2, 21, 20, RED)
        native[5][5] = BLUE
        fitted, note = a2p.fit_native(native, 24, 'subject')
        self.assertEqual((len(fitted), len(fitted[0])), (24, 24))
        self.assertEqual([row[2:22] for row in fitted[3:21]], [row[1:21] for row in native[2:20]])
        self.assertEqual(sum(c == WHITE for row in fitted for c in row), 24 * 24 - 20 * 18)
        self.assertEqual(note, 'subject 20x18 padded to 24')

    def test_a_scene_up_to_four_blocks_over_is_trimmed_evenly(self):
        native = layout([RED, GREEN, BLUE, YELLOW, WHITE], 27)
        fitted, note = a2p.fit_native(native, 24, 'scene')
        self.assertEqual(fitted, [row[1:25] for row in native[1:25]], '3 over: 1 off the left and top, 2 off the right and bottom')
        self.assertEqual(note, 'scene 27x27 trimmed to 24')

    def test_a_scene_at_its_grid_is_kept_whole(self):
        native = layout([RED, GREEN, BLUE, YELLOW], 24)
        self.assertEqual(a2p.fit_native(native, 24, 'scene')[0], native)

    def test_a_subject_running_off_one_edge_stays_on_it(self):
        native = paint(plain(20, 20, WHITE), 0, 2, 18, 18, RED)
        fitted, _ = a2p.fit_native(native, 24, 'subject')
        self.assertEqual([row[:18] for row in fitted[4:20]], [row[:18] for row in native[2:18]])
        self.assertTrue(all(c == WHITE for row in fitted for c in row[20:]))

    def test_too_big_or_too_small_fails_with_the_measured_size(self):
        cases = [
            (paint(plain(30, 30, WHITE), 1, 4, 28, 26, RED), 'subject', 'subject 27x22 over grid 24', 3),
            (paint(plain(24, 24, WHITE), 6, 6, 18, 16, RED), 'subject',
             'subject 12x10 under grid 24 (needs 17 blocks across)', 12),
            (layout([RED, GREEN, BLUE], 29), 'scene', 'scene 29x29 over grid 24 (needs 24 to 28 blocks)', 5),
            (layout([RED, GREEN, BLUE], 23), 'scene', 'scene 23x23 under grid 24 (needs 24 to 28 blocks)', 1),
        ]
        for native, mode, message, miss in cases:
            with self.subTest(message), self.assertRaises(a2p.FitError) as caught:
                a2p.fit_native(native, 24, mode)
            self.assertEqual((str(caught.exception), caught.exception.miss), (message, miss))

    def fitted_entry(self, rows, mode, grid=24):
        path = self.save(f'{mode}.png', draw(rows, block=12))
        return {**self.entry(path, grid), 'fit': mode}

    def test_a_fit_entry_converts_block_for_block(self):
        rows = paint(plain(22, 22, BLUE), 2, 2, 20, 21, WHITE)
        rows = paint(rows, 5, 6, 15, 14, RED)
        rows[8][8] = GREEN
        problems, outputs, _ = a2p.convert_entry(self.fitted_entry(rows, 'subject'))
        self.assertEqual(problems, [])
        out = pixels(outputs[24][0])
        self.assertEqual([row[3:21] for row in out[2:21]], [row[2:20] for row in rows[2:21]], 'the 18x19 subject, centred')

    def test_a_fit_entry_that_does_not_fit_fails_with_its_size(self):
        rows = paint(plain(30, 30, BLUE), 1, 4, 28, 26, WHITE)
        rows = paint(rows, 5, 6, 15, 14, RED)
        problems = self.problems_of(self.fitted_entry(rows, 'subject'))
        self.assertIn('subject 27x22 over grid 24: regenerate', problems)

    def test_a_generated_entry_is_read_on_its_canvas_lattice_like_pixel_gen(self):
        # PAP-79: the model drew 20 blocks of 12 px on a 240 px canvas for grid 24
        # (10 px a cell). The block search finds a 16-block subject, under the grid;
        # pixel_gen.py judged it on the canvas lattice, where it fits.
        rows = paint(plain(20, 20, BLUE), 2, 2, 18, 18, WHITE)
        rows = paint(rows, 6, 6, 14, 12, RED)
        entry = self.fitted_entry(rows, 'subject')
        (searched,) = self.problems_of(entry)
        self.assertRegex(searched, r'^subject \d+x\d+ under grid 24 ')
        problems, outputs, _ = a2p.convert_entry({**entry, 'seed': 1010, 'scale': 10})
        self.assertEqual(problems, [])
        self.assertEqual((outputs[24][0].size), (24, 24))

    def test_a_generated_entry_whose_canvas_is_not_grid_times_scale_fails(self):
        entry = self.fitted_entry(paint(plain(20, 20, BLUE), 2, 2, 18, 18, WHITE), 'subject')
        problems = self.problems_of({**entry, 'seed': 1008, 'scale': 8})
        self.assertEqual(problems, ['source is 240x240 px, not 192x192 (grid 24 at 8 px a cell): regenerate'])


class GenerationFields(unittest.TestCase):
    """PAP-95: puzzle entries record how pixel_gen.py made them."""

    ENTRY = '[[asset]]\nname = "p"\nsource = "p.png"\ncourse = "animals"\nslug = "owl"\ngrid = 24\n'

    def read(self, extra):
        return Manifest.write(self, self.ENTRY + extra)

    def test_reads_fit_prompt_seed_and_scale(self):
        (e,) = a2p.puzzle_entries(self.read('fit = "subject"\nprompt = "a round owl"\nseed = 3012\nscale = 12\n'))
        self.assertEqual((e['fit'], e['prompt'], e['seed'], e['scale']), ('subject', 'a round owl', 3012, 12))

    def test_they_are_optional(self):
        (e,) = a2p.puzzle_entries(self.read(''))
        self.assertEqual((e['fit'], e['prompt'], e['seed'], e['scale']), (None, None, None, None))

    def test_rejects_bad_values(self):
        for extra in ['fit = "blob"\n', 'seed = "7"\nscale = 12\n', 'seed = 7\nscale = 6\n', 'seed = 7\nscale = 17\n',
                      'prompt = 4\n', 'fit = "scene"\nexact = true\n', 'seed = 7\n', 'scale = 12\n']:
            with self.subTest(extra), self.assertRaises(ValueError):
                a2p.puzzle_entries(self.read(extra))


class FitCheckLine(Fixtures):
    def test_check_prints_how_a_fit_source_was_placed(self):
        rows = paint(plain(22, 22, BLUE), 2, 2, 20, 21, WHITE)
        rows = paint(rows, 5, 6, 15, 14, RED)
        path = self.save('owl.png', draw(rows, block=12))
        out = io.StringIO()
        with redirect_stdout(out):
            a2p.check([{**self.entry(path, 24), 'fit': 'subject'}])
        self.assertRegex(out.getvalue().splitlines()[0],
                         r'^ok   test/pic source 22 blocks, subject 18x19 padded to 24, grid 24, \d colours$')


PANDA_WHITE, CREAM = (245, 245, 232), (249, 230, 185)
BLACK, COCOA, BAMBOO = (30, 30, 34), (59, 42, 47), (70, 160, 60)


def panda():
    """The PAP-79 level-32 panda case: a 106-cell white face on a cream
    background, ΔE 11.6 apart, under the level's gap of 14. A cocoa ring
    outlines the 11x10 face, which has two 2-cell black eyes (110 - 4 = 106
    white cells); black ears and a bamboo stalk sit around it."""
    grid = plain(32, 32, CREAM)
    paint(grid, 9, 7, 22, 19, COCOA)
    paint(grid, 10, 8, 21, 18, PANDA_WHITE)
    paint(grid, 12, 10, 14, 11, BLACK)
    paint(grid, 17, 10, 19, 11, BLACK)
    paint(grid, 9, 4, 12, 7, BLACK)
    paint(grid, 19, 4, 22, 7, BLACK)
    paint(grid, 25, 2, 28, 30, BAMBOO)
    return grid


def colours_of(grid):
    return Counter(c for row in grid for c in row)


class RegionSafeCut(unittest.TestCase):
    """PAP-95: two close colours that each fill a large region are pushed
    apart instead of merged; small features still merge (PAP-92)."""

    def cut(self, grid, n=32):
        return a2p.reduce_palette(grid, limit=a2p.COLOR_LIMIT[n], gap=a2p.MIN_RGB_GAP, de_gap=a2p.LEVEL_GAP[n],
                                  region_safe=True)

    def test_the_fixture_is_the_panda_case(self):
        self.assertEqual(colours_of(panda())[PANDA_WHITE], 106)
        self.assertAlmostEqual(a2p.min_de_gap([PANDA_WHITE, CREAM]), 11.6, places=1)

    def test_a_white_face_on_cream_stays_two_colours_the_level_gap_apart(self):
        out = self.cut(panda())
        face, background = out[12][12], out[0][0]
        self.assertEqual(background, CREAM, 'the bigger region keeps its colour')
        self.assertNotEqual(face, background)
        self.assertEqual(colours_of(out)[face], 106)
        self.assertGreaterEqual(a2p.min_de_gap(colours_of(out)), a2p.LEVEL_GAP[32])
        self.assertLessEqual(a2p.min_de_gap([face, PANDA_WHITE]), 2 * a2p.LEVEL_GAP[32], 'still a white')

    def test_a_palette_over_the_limit_merges_details_before_the_face(self):
        grid = panda()
        extras = [(255, 0, 0), (0, 0, 255), (255, 0, 255), (0, 200, 200), (255, 128, 0), (128, 0, 255),
                  (0, 100, 0), (128, 64, 0), (255, 105, 180), (100, 100, 255), (200, 200, 0), (0, 0, 120)]
        for i, colour in enumerate(extras):
            grid[1 + 2 * (i // 6)][1 + 2 * (i % 6)] = colour
        self.assertGreater(len(colours_of(grid)), a2p.COLOR_LIMIT[32])
        out = self.cut(grid)
        self.assertLessEqual(len(colours_of(out)), a2p.COLOR_LIMIT[32])
        self.assertNotEqual(out[12][12], out[0][0], 'the face stays apart from the cream')

    def test_a_two_cell_eye_close_to_a_big_colour_still_merges_into_it(self):
        grid = panda()
        near_black = (52, 44, 52)
        self.assertLess(a2p.min_de_gap([near_black, BLACK]), a2p.LEVEL_GAP[32])
        paint(grid, 0, 20, 8, 28, BLACK)
        paint(grid, 2, 22, 4, 23, near_black)
        self.assertGreaterEqual(a2p.largest_region(grid, {BLACK}), a2p.LARGE_REGION_SHARE * 32 * 32,
                                'only the eye is small, so its size alone decides')
        out = self.cut(grid)
        self.assertEqual(out[22][2], BLACK)
        self.assertNotIn(near_black, colours_of(out))

    def test_the_large_region_threshold(self):
        def two_patches(cells):
            grid = plain(32, 32, CREAM)
            for i in range(cells):
                grid[10 + i // 16][8 + i % 16] = PANDA_WHITE
            paint(grid, 0, 28, 32, 32, BAMBOO)
            paint(grid, 0, 24, 32, 28, BLACK)
            return grid

        small = math.floor(a2p.LARGE_REGION_SHARE * 32 * 32) - 1
        self.assertNotIn(PANDA_WHITE, colours_of(self.cut(two_patches(small))))
        self.assertEqual(len(colours_of(self.cut(two_patches(small + 2)))), 4)

    def test_a_colour_pushed_onto_a_third_one_still_ends_the_gap_apart(self):
        pushed_white = (226, 240, 255)
        grid = panda()
        paint(grid, 0, 20, 8, 32, pushed_white)
        out = self.cut(grid)
        face, background, third = out[12][12], out[0][0], out[25][2]
        self.assertEqual(len({face, background, third}), 3, 'face, background and the third colour all stay')
        self.assertGreaterEqual(a2p.min_de_gap(colours_of(out)), a2p.LEVEL_GAP[32])
        self.assertGreaterEqual(a2p.min_gap(colours_of(out)), a2p.MIN_RGB_GAP)

    def test_without_it_the_face_merges_as_the_classics_expect(self):
        out = a2p.reduce_palette(panda(), limit=12, gap=a2p.MIN_RGB_GAP, de_gap=a2p.LEVEL_GAP[32])
        self.assertEqual(out[12][12], CREAM)

    def finishes(self, call):
        """call() run with a 10 s limit; its result, or a failure if it hangs."""
        result = []
        worker = threading.Thread(target=lambda: result.append(call()), daemon=True)
        worker.start()
        worker.join(10)
        self.assertFalse(worker.is_alive(), 'still running after 10 s')
        return result[0]

    def test_a_colour_at_the_edge_of_the_gamut_stops_instead_of_looping(self):
        pairs = [(WHITE, (240, 240, 240)), (BLACK, (20, 20, 20)), ((255, 0, 0), (235, 20, 20)),
                 ((0, 255, 0), (20, 235, 20)), ((0, 0, 255), (20, 20, 235)), ((255, 255, 0), (235, 235, 20))]
        for mover, anchor in pairs:
            with self.subTest(mover=mover):
                moved = self.finishes(lambda: a2p.separate(mover, anchor, a2p.MIN_RGB_GAP, a2p.LEVEL_GAP[32]))
                if moved is not None:
                    self.assertGreaterEqual(a2p.min_de_gap([moved, anchor]), a2p.LEVEL_GAP[32])

    def test_repeated_moves_stay_within_the_cap_of_the_source_colour(self):
        gap, cap = a2p.LEVEL_GAP[32], a2p.SEPARATE_MAX_SHIFT * a2p.LEVEL_GAP[32]
        origin, anchor = (200, 120, 80), (195, 125, 85)
        already_moved = (150, 160, 120)
        self.assertGreater(a2p.min_de_gap([already_moved, origin]), cap)
        self.assertIsNone(a2p.separate(already_moved, anchor, a2p.MIN_RGB_GAP, gap, origin=origin))
        self.assertIsNotNone(a2p.separate(origin, anchor, a2p.MIN_RGB_GAP, gap, origin=origin))

    def test_a_pure_white_face_moves_its_background_instead(self):
        for background in [(240, 240, 240), (245, 238, 220)]:
            with self.subTest(background=background):
                grid = plain(32, 32, background)
                paint(grid, 10, 10, 22, 22, WHITE)
                self.assertLess(a2p.min_de_gap([WHITE, background]), a2p.LEVEL_GAP[32])
                out = self.finishes(lambda: self.cut(grid))
                self.assertEqual(out[15][15], WHITE, 'white has nowhere to go, so it stays')
                self.assertNotEqual(out[0][0], WHITE)
                self.assertGreaterEqual(a2p.min_de_gap(colours_of(out)), a2p.LEVEL_GAP[32])

    def test_rgb_of_lab_round_trips(self):
        for c in [PANDA_WHITE, CREAM, BLACK, BAMBOO, (255, 0, 0), (0, 0, 255)]:
            self.assertEqual(a2p.rgb_of_lab(a2p.lab(c)), c)


class RegionSafeEntries(Fixtures):
    def test_a_fit_entry_keeps_the_panda_face(self):
        path = self.save('panda.png', draw(panda(), block=12))
        for extra in ({'fit': 'scene'}, {'exact': True}):
            with self.subTest(extra):
                problems, outputs, _ = a2p.convert_entry({**self.entry(path, 32), **extra})
                self.assertEqual(problems, [])
                out = pixels(outputs[32][0])
                self.assertNotEqual(out[12][12], out[0][0])

    def test_a_plain_entry_still_merges_it(self):
        path = self.save('panda.png', draw(panda(), block=12))
        _, outputs, _ = a2p.convert_entry(self.entry(path, 32))
        out = pixels(outputs[32][0])
        self.assertEqual(out[12][12], out[0][0])


STYLE1 = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'testdata', 'style1')


def style1(name):
    """A PAP-79 style set 1 source (tool/testdata/style1) and its grid."""
    grid = {'bunny': 16, 'fish': 16, 'owl': 24, 'fox': 24, 'panda': 32, 'fawn': 40}[name.split('-')[0]]
    return Image.open(os.path.join(STYLE1, f'{name}.png')), grid


def pap96(name):
    """A source with its PAP-96 conversion (the n x n puzzle) and the cell
    lines that conversion read it with (tool/testdata/style1/pap96)."""
    import json
    with open(os.path.join(STYLE1, 'pap96', f'{name}.json')) as f:
        lines = json.load(f)
    return (Image.open(os.path.join(STYLE1, f'{name}.png')),
            Image.open(os.path.join(STYLE1, 'pap96', f'{name}.png')), (lines['xs'], lines['ys']))


class OnLatticeShare(unittest.TestCase):
    def test_the_fawns_rank_above_every_other_style1_source(self):
        names = sorted(f[:-4] for f in os.listdir(STYLE1) if f.endswith('.png'))
        share = {name: a2p.on_lattice_share(*style1(name)) for name in names}
        fawns = [s for name, s in share.items() if name.startswith('fawn')]
        others = [s for name, s in share.items() if not name.startswith('fawn')]
        self.assertEqual(len(fawns), 2)
        self.assertGreater(min(fawns), max(others), share)

    def test_a_picture_drawn_on_its_grid_scores_all_and_one_drawn_finer_scores_low(self):
        on_grid = blocks([RED, GREEN, BLUE, YELLOW], cells=24, block=8)
        self.assertEqual(a2p.on_lattice_share(on_grid, 24), 1.0)
        finer = blocks([RED, GREEN, BLUE, YELLOW], cells=31, block=8).resize((24 * 8,) * 2, Image.NEAREST)
        self.assertLess(a2p.on_lattice_share(finer, 24), 0.4)


class LatticeRead(unittest.TestCase):
    def test_reads_a_source_drawn_on_its_grid_block_for_block(self):
        rows = paint(paint(plain(16, 16, BLUE), 3, 3, 13, 14, WHITE), 5, 6, 7, 7, RED)
        buf = io.BytesIO()
        draw(rows, block=8).save(buf, 'PNG')
        analysis = a2p.lattice_analysis(Image.open(io.BytesIO(buf.getvalue())), 16)
        self.assertEqual(analysis.native, rows)
        self.assertEqual(analysis.lines, ([i * 8.0 for i in range(17)], [i * 8.0 for i in range(17)]))


def face(left_eye, right_eye):
    """A 16-cell face (white on blue) with a red eye on each side: each eye
    is a list of (x, y) cells."""
    rows = paint(plain(16, 16, BLUE), 2, 2, 14, 14, WHITE)
    for x, y in left_eye + right_eye:
        rows[y][x] = RED
    return rows


def as_puzzle(rows):
    palette = sorted(colours_of(rows))
    return indexed([[palette.index(c) for c in row] for row in rows], palette)


class FeatureCheck(unittest.TestCase):
    LINES = ([i * 10.0 for i in range(17)], [i * 10.0 for i in range(17)])

    def test_a_puzzle_that_keeps_every_feature_passes(self):
        rows = face([(5, 6)], [(10, 6)])
        self.assertEqual(a2p.feature_check(draw(rows, block=10), as_puzzle(rows), self.LINES), [])

    def test_a_pair_drawn_with_different_cell_shapes_on_each_side_is_reported(self):
        source = face([(5, 6)], [(10, 6)])
        puzzle = face([(5, 6)], [(10, 6), (11, 6)])
        misses = a2p.feature_check(draw(source, block=10), as_puzzle(puzzle), self.LINES)
        self.assertEqual(sorted(m['cells'] for m in misses), [(5, 6, 5, 6), (10, 6, 10, 6)])
        self.assertTrue(all(m['subject'] and m['why'].startswith('pair drawn unevenly') for m in misses), misses)

    def misses(self, source, puzzle):
        return a2p.feature_check(draw(source, block=10), as_puzzle(puzzle), self.LINES)

    def test_a_feature_with_no_cell_left_is_reported_gone(self):
        misses = self.misses(face([(5, 6)], [(10, 6)]), face([(5, 6)], []))
        self.assertEqual([m['cells'] for m in misses], [(10, 6, 10, 6)])
        self.assertIn('gone', misses[0]['why'])

    def test_a_feature_whose_colour_joins_its_surround_is_reported_merged(self):
        grey = (170, 170, 170)
        source = paint(face([], []), 7, 6, 9, 7, grey)
        misses = self.misses(source, face([], []))
        self.assertEqual([m['cells'] for m in misses], [(7, 6, 8, 6)])
        self.assertTrue(misses[0]['why'].startswith('merged into its surround'), misses)

    def test_a_feature_drawn_in_the_background_colour_is_reported(self):
        navy = (30, 30, 90)
        source = paint(face([], []), 7, 6, 9, 7, navy)
        misses = self.misses(source, paint(face([], []), 7, 6, 9, 7, BLUE))
        self.assertEqual([m['cells'] for m in misses], [(7, 6, 8, 6)])
        self.assertTrue(misses[0]['why'].startswith('drawn in the background colour'), misses)

    def test_a_symmetric_feature_drawn_lopsided_is_reported(self):
        source = face([(6, 9), (7, 9), (8, 9)], [])
        misses = self.misses(source, face([(6, 9), (7, 9), (6, 10)], []))
        self.assertEqual([m['cells'] for m in misses], [(6, 9, 8, 9)])
        self.assertTrue(misses[0]['why'].startswith('lopsided'), misses)


class FeatureCheckOnPap96(unittest.TestCase):
    """The PAP-96 conversions of style set 1: the details Cesar saw lost."""

    def misses(self, name):
        return [m for m in a2p.feature_check(*pap96(name)) if m['subject']]

    def test_the_fox_eyes_are_missed(self):
        cells = {m['cells'] for m in self.misses('fox-c12-s4012')}
        self.assertLessEqual({(5, 6, 6, 7), (8, 6, 11, 7)}, cells)

    def test_the_panda_nose_is_missed(self):
        self.assertIn((14, 14, 19, 16), {m['cells'] for m in self.misses('panda-c12-s2012')})

    def test_the_owl_eyes_are_missed(self):
        cells = {m['cells'] for m in self.misses('owl-c10-s4010')}
        self.assertLessEqual({(9, 7, 11, 9), (15, 7, 16, 9)}, cells)

    def test_fawn_2008_passes(self):
        self.assertEqual(self.misses('fawn-c8-s2008'), [])
