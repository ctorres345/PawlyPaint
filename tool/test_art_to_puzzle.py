"""Tests for tool/art_to_puzzle.py: one bad fixture per --check failure.

CI does not run these (it has no Python). Run by hand with a Python that has
Pillow:
  ~/.local/share/nousfx/via/venv/bin/python3 -m unittest tool/test_art_to_puzzle.py
"""
import os
import random
import sys
import tempfile
import unittest

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
