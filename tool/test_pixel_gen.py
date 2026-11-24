"""Tests for tool/pixel_gen.py against a stubbed ComfyUI server.

Run by hand with a Python that has Pillow:
  ~/.local/share/nousfx/via/venv/bin/python3 -m unittest tool/test_pixel_gen.py
"""
import io
import json
import os
import sys
import tempfile
import threading
import time
import unittest
import urllib.parse
from unittest import mock
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel_gen as pg  # noqa: E402
from test_art_to_puzzle import BLUE, RED, WHITE, YELLOW, draw, paint, plain  # noqa: E402


def owl(blocks, size):
    """A subject on a plain background, drawn `blocks` blocks across on a
    canvas of `size` px. Its box is (blocks - 4) x (blocks - 3), so it fits
    grid 24 1:1 from 21 to 27 blocks."""
    rows = plain(blocks, blocks, BLUE)
    paint(rows, 2, 2, blocks - 2, blocks - 1, WHITE)
    paint(rows, 4, 4, blocks - 4, blocks - 6, RED)
    rows[5][5] = YELLOW
    return draw(rows, block=1).resize((size, size), Image.NEAREST)


class StubComfy:
    """A ComfyUI stand-in: /system_stats, /prompt, /history/<id> (empty on the
    first poll) and /view. `picture(size, seed)` draws each result, or
    returns 'refuse' (a 400 from /prompt), 'empty' (a job with no image),
    'garbage' (an image that does not decode), 'hang' (a job that never
    finishes), 'slow' (the first history poll answers late, then the image
    of picture(240, 0)) or 'die' (the server stops)."""

    def __init__(self, picture):
        self.picture, self.jobs, self.polls, self.results, self.cancels = picture, {}, {}, {}, []
        stub = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, body, kind='application/json'):
                self.send_response(200)
                self.send_header('Content-Type', kind)
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self):
                url = urllib.parse.urlparse(self.path)
                if url.path == '/system_stats':
                    return self.reply(b'{"system": {}}')
                if url.path.startswith('/history/'):
                    pid = url.path.rsplit('/', 1)[1]
                    stub.polls[pid] = stub.polls.get(pid, 0) + 1
                    if stub.results[pid] == 'slow' and stub.polls[pid] == 1:
                        time.sleep(0.3)
                    if stub.polls[pid] < 2 or stub.results[pid] == 'hang':
                        return self.reply(b'{}')
                    image = {'filename': f'{pid}.png', 'subfolder': '', 'type': 'output'}
                    images = [] if stub.results[pid] == 'empty' else [image]
                    return self.reply(json.dumps({pid: {'outputs': {'10': {'images': images}}}}).encode())
                if url.path == '/view':
                    pid = urllib.parse.parse_qs(url.query)['filename'][0][:-4]
                    if stub.results[pid] == 'slow':
                        stub.results[pid] = stub.picture(240, 0)
                    if stub.results[pid] == 'garbage':
                        return self.reply(b'not a png', 'image/png')
                    out = io.BytesIO()
                    stub.results[pid].save(out, 'PNG')
                    return self.reply(out.getvalue(), 'image/png')
                self.send_error(404)

            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                if self.path in ('/queue', '/interrupt'):
                    stub.cancels.append((self.path, body))
                    return self.reply(b'{}')
                pid = f'job{len(stub.jobs)}'
                stub.jobs[pid] = inputs = body['prompt']
                result = stub.picture(inputs['7']['inputs']['width'], inputs['8']['inputs']['seed'])
                if result == 'die':
                    threading.Thread(target=stub.close).start()
                    self.close_connection = True
                    return
                if result == 'refuse':
                    self.send_response(400)
                    self.end_headers()
                    self.wfile.write(b'{"error": "value_not_in_list: ae.safetensors"}')
                    return
                stub.results[pid] = result
                self.reply(json.dumps({'prompt_id': pid}).encode())

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.host = f'http://127.0.0.1:{self.server.server_port}'
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class Workflow(unittest.TestCase):
    def test_builds_the_redmond_workflow(self):
        wf = pg.workflow('Pixel Art, PixArFK, an owl', 240, 2010)
        by_class = {node['class_type']: node['inputs'] for node in wf.values()}
        self.assertEqual(by_class['UNETLoader']['unet_name'], 'z_image_turbo_bf16.safetensors')
        self.assertEqual(by_class['CLIPLoader']['clip_name'], 'qwen_3_4b.safetensors')
        self.assertEqual(by_class['VAELoader']['vae_name'], 'ae.safetensors')
        lora = by_class['LoraLoaderModelOnly']
        self.assertEqual((lora['lora_name'], lora['strength_model']), ('ZImageTurbo_PixelArt_Redmond.safetensors', 1.0))
        self.assertEqual(by_class['ModelSamplingAuraFlow']['shift'], 3.0)
        sampler = by_class['KSampler']
        self.assertEqual((sampler['steps'], sampler['sampler_name'], sampler['scheduler'], sampler['cfg'], sampler['seed']),
                         (9, 'res_multistep', 'simple', 1.0, 2010))
        self.assertEqual((by_class['EmptySD3LatentImage']['width'], by_class['EmptySD3LatentImage']['height']), (240, 240))
        self.assertEqual(by_class['CLIPTextEncode']['text'], 'Pixel Art, PixArFK, an owl')
        self.assertEqual(wf[lora_id(wf)]['inputs']['model'], ['1', 0], 'the LoRA takes the model')
        self.assertEqual(by_class['ModelSamplingAuraFlow']['model'], [lora_id(wf), 0], 'the sampler takes the LoRA')

    def test_the_prompt_starts_with_the_trigger_and_names_the_level_colours(self):
        prompt = pg.prompt_for('a round owl', 24)
        self.assertTrue(prompt.startswith('Pixel Art, PixArFK, a round owl. '))
        self.assertIn('at most 8 colours', prompt)

    def test_the_prompt_names_the_grid(self):
        self.assertIn('drawn on a 24x24 pixel grid', pg.prompt_for('a round owl', 24))
        self.assertIn('drawn on a 40x40 pixel grid', pg.prompt_for('a fawn', 40))

    def test_every_grid_gets_canvases_of_8_and_16_px_a_cell(self):
        for grid in sorted(pg.FIT_BY_GRID):
            sizes = [grid * 8, grid * 8, grid * 16, grid * 16]
            stub = StubComfy(lambda size, seed: 'refuse')
            self.addCleanup(stub.close)
            with tempfile.TemporaryDirectory() as out:
                job = {'name': 'pic', 'grid': grid, 'fit': 'subject', 'prompt': 'p'}
                pg.search(pg.Comfy(stub.host, poll=0.01), job, out, seeds=2, log=lambda *_: None)
            self.assertEqual(sorted(job['7']['inputs']['width'] for job in stub.jobs.values()), sizes)


def lora_id(wf):
    return next(k for k, node in wf.items() if node['class_type'] == 'LoraLoaderModelOnly')


class Host(unittest.TestCase):
    def test_the_host_comes_from_the_flag_or_the_environment(self):
        self.assertEqual(pg.host_of('pc.lan:8188', {}), 'http://pc.lan:8188')
        self.assertEqual(pg.host_of(None, {'PAWLY_COMFY_HOST': 'http://pc.lan:8188/'}), 'http://pc.lan:8188')
        with self.assertRaises(SystemExit) as caught:
            pg.host_of(None, {})
        self.assertIn('PAWLY_COMFY_HOST', str(caught.exception))


class Search(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.out = os.path.join(self.dir.name, 'owl')
        self.job = {'name': 'owl', 'grid': 24, 'fit': 'subject', 'prompt': pg.prompt_for('a round owl', 24)}

    def serve(self, picture):
        stub = StubComfy(picture)
        self.addCleanup(stub.close)
        return stub

    def test_keeps_only_the_seeds_drawn_on_the_grid(self):
        stub = self.serve(lambda size, seed: owl(24 if seed == 2008 else 30, size))
        result = pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=2, log=lambda *_: None)
        self.assertEqual([(h['seed'], h['scale']) for h in result['hits']], [(2008, 8)],
                         'only seed 2008 draws 24 blocks; the rest draw 30')
        self.assertEqual(sorted(job['7']['inputs']['width'] for job in stub.jobs.values()), [192, 192, 384, 384])
        self.assertEqual(sorted(os.listdir(self.out)), ['owl-c8-s2008.png', 'puzzle-owl-c8-s2008.png', 'rejected', 'report.json'])
        with Image.open(os.path.join(self.out, 'puzzle-owl-c8-s2008.png')) as puzzle:
            self.assertEqual(puzzle.size, (24 * 16, 24 * 16))
        with open(os.path.join(self.out, 'report.json')) as f:
            report = json.load(f)
        self.assertEqual((report['prompt'], report['grid'], report['fit']), (self.job['prompt'], 24, 'subject'))
        self.assertEqual(report['hits'][0]['on_lattice'], 1.0)
        self.assertEqual(report['hits'][0]['features'], [])

    def test_a_rerun_leaves_no_stale_copy_of_a_try_in_the_other_folder(self):
        kept = {'now': True}
        stub = self.serve(lambda size, seed: owl(24 if kept['now'] else 30, size))
        pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=1, scales=[8], log=lambda *_: None)
        self.assertIn('owl-c8-s1008.png', os.listdir(self.out))
        kept['now'] = False
        pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=1, scales=[8], log=lambda *_: None)
        self.assertEqual(sorted(os.listdir(self.out)), ['rejected', 'report.json'])
        self.assertEqual(os.listdir(os.path.join(self.out, 'rejected')), ['owl-c8-s1008.png'])

    def test_a_try_off_its_grid_is_rejected_with_its_share(self):
        stub = self.serve(lambda size, seed: owl(30, size))
        lines = []
        result = pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=1, log=lines.append)
        self.assertEqual(result['hits'], [])
        with open(os.path.join(self.out, 'report.json')) as f:
            report = json.load(f)
        self.assertEqual(len(report['misses']), 2)
        for miss in report['misses']:
            self.assertLess(miss['on_lattice'], pg.ON_LATTICE_MIN)
            self.assertIn(f"on-lattice share {miss['on_lattice']:.0%} under 60%", miss['why'])
        self.assertEqual(sorted(os.listdir(os.path.join(self.out, 'rejected'))), ['owl-c16-s1016.png', 'owl-c8-s1008.png'],
                         'a rejected source is kept for the contact sheet; it has no puzzle')
        self.assertTrue(lines[-1].startswith('no 1:1 fit in 2 tries; closest: off its grid'), lines[-1])

    def test_a_try_that_loses_a_feature_in_the_subject_is_rejected_and_boxed(self):
        stub = self.serve(lambda size, seed: owl(24, size))
        lost = [{'cells': (5, 5, 5, 5), 'colour': '#fadc28', 'around': '#dc1e28', 'area': 1.0, 'subject': True,
                 'why': 'gone (no cell of its colour within half a cell)'},
                {'cells': (0, 0, 0, 0), 'colour': '#ffffff', 'around': '#1e3cc8', 'area': 1.0, 'subject': False,
                 'why': 'gone (no cell of its colour within half a cell)'}]
        a2p = pg._import_art_to_puzzle()
        with mock.patch.object(a2p, 'feature_check', return_value=lost):
            result = pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=1, scales=[8], log=lambda *_: None)
        self.assertEqual(result['hits'], [])
        miss = result['misses'][0]
        self.assertEqual(miss['why'], 'lost 1 feature: gone (no cell of its colour within half a cell) at cells 5,5')
        self.assertEqual([tuple(f['cells']) for f in miss['features']], [(5, 5, 5, 5), (0, 0, 0, 0)])
        with Image.open(os.path.join(self.out, 'rejected', 'puzzle-owl-c8-s1008.png')) as preview:
            px = preview.convert('RGB')
            self.assertEqual(px.getpixel((5 * 16, 5 * 16 + 8)), pg.MISS_BOX, 'a lost feature is boxed')
            self.assertEqual(px.getpixel((0, 8)), pg.OUTSIDE_BOX, 'one outside the subject is boxed apart')

    def test_stops_when_comfyui_is_not_reachable_and_writes_nothing(self):
        stub = StubComfy(lambda size, seed: owl(24, size))
        host = stub.host
        stub.close()
        with self.assertRaises(SystemExit) as caught:
            pg.search(pg.Comfy(host, poll=0.01), self.job, self.out, seeds=1, scales=[10], log=lambda *_: None)
        self.assertEqual(str(caught.exception), f'ComfyUI not reachable at {host}')
        self.assertFalse(os.path.exists(self.out))


    def test_a_failed_job_is_a_miss_and_the_search_goes_on(self):
        outcomes = {1010: 'refuse', 2010: 'empty', 3010: 'garbage'}
        stub = self.serve(lambda size, seed: outcomes.get(seed) or owl(24, size))
        result = pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=4, scales=[10], log=lambda *_: None)
        self.assertEqual([h['seed'] for h in result['hits']], [4010])
        whys = {m['seed']: m['why'] for m in result['misses']}
        self.assertIn('HTTP 400', whys[1010])
        self.assertIn('ae.safetensors', whys[1010])
        self.assertIn('no image', whys[2010])
        self.assertIn('cannot identify image', whys[3010])

    def test_a_job_that_times_out_is_cancelled_and_the_next_one_still_runs(self):
        stub = self.serve(lambda size, seed: 'hang' if seed == 1010 else owl(24, size))
        comfy = pg.Comfy(stub.host, poll=0.01, timeout=0.2)
        result = pg.search(comfy, self.job, self.out, seeds=2, scales=[10], log=lambda *_: None)
        self.assertEqual([h['seed'] for h in result['hits']], [2010])
        self.assertIn('no picture after', result['misses'][0]['why'])
        self.assertEqual(stub.cancels, [('/queue', {'delete': ['job0']}), ('/interrupt', {})])

    def test_a_poll_that_answers_late_is_retried_not_cancelled(self):
        stub = self.serve(lambda size, seed: 'slow' if seed else owl(24, size))
        comfy = pg.Comfy(stub.host, poll=0.01, timeout=5, http_timeout=0.1)
        result = pg.search(comfy, self.job, self.out, seeds=1, scales=[10], log=lambda *_: None)
        self.assertEqual([h['seed'] for h in result['hits']], [1010])
        self.assertEqual(stub.cancels, [])

    def test_when_every_job_is_refused_the_summary_says_why(self):
        stub = self.serve(lambda size, seed: 'refuse')
        lines = []
        pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=2, scales=[10], log=lines.append)
        self.assertTrue(lines[-1].startswith('no 1:1 fit in 2 tries; closest: none measured: ComfyUI refused the job'))
        self.assertIn('ae.safetensors', lines[-1])

    def test_a_server_lost_mid_run_stops_and_keeps_the_report(self):
        stub = StubComfy(lambda size, seed: 'die' if seed == 2010 else owl(24, size))
        with self.assertRaises(SystemExit) as caught:
            pg.search(pg.Comfy(stub.host, poll=0.01), self.job, self.out, seeds=3, scales=[10], log=lambda *_: None)
        self.assertEqual(str(caught.exception), f'ComfyUI not reachable at {stub.host}')
        with open(os.path.join(self.out, 'report.json')) as f:
            report = json.load(f)
        self.assertEqual([h['seed'] for h in report['hits']], [1010])

    def test_a_bad_port_is_reported_as_not_reachable(self):
        with self.assertRaises(SystemExit) as caught:
            pg.Comfy('http://pc.lan:88a8').check()
        self.assertEqual(str(caught.exception), 'ComfyUI not reachable at http://pc.lan:88a8')


TESTDATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'testdata')


class OnLatticeGate(unittest.TestCase):
    def check(self, path, grid, fit):
        with open(os.path.join(TESTDATA, path), 'rb') as f:
            return pg.fit_check(f.read(), grid, fit)

    def test_the_slice_owl_cesar_rejected_is_off_its_grid(self):
        result = self.check('pap97/owl-c8-s1008.png', 24, 'subject')
        self.assertFalse(result['ok'])
        self.assertEqual(result['why'], 'off its grid: on-lattice share 42% under 60%',
                         'its eye rings are 1.5 cells wide: no 1:1 puzzle can copy them')

    def test_the_fawn_drawn_on_its_grid_clears_the_gate(self):
        result = self.check('style1/fawn-c8-s2008.png', 40, 'scene')
        self.assertEqual(result['on_lattice'], 0.714)
        self.assertNotIn('off its grid', result['why'])

    def test_the_fawn_at_44_percent_is_rejected_on_purpose(self):
        result = self.check('style1/fawn-c8-s3008.png', 40, 'scene')
        self.assertEqual(result['why'], 'off its grid: on-lattice share 44% under 60%',
                         'Cesar chose 60% knowing it costs this fawn: 42% passed an owl he rejected')


class ContactSheet(unittest.TestCase):
    def test_lays_out_every_kept_and_rejected_try_with_its_numbers(self):
        import contact_sheet
        stub = StubComfy(lambda size, seed: owl(24 if seed == 1008 else 30, size))
        self.addCleanup(stub.close)
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        out = os.path.join(d.name, 'owl')
        job = {'name': 'owl', 'grid': 24, 'fit': 'subject', 'prompt': 'p'}
        pg.search(pg.Comfy(stub.host, poll=0.01), job, out, seeds=2, log=lambda *_: None)
        page, lines = contact_sheet.sheet([out])
        self.assertEqual(len(lines), 4)
        self.assertTrue(lines[0].startswith('owl KEPT  c8 s1008  lattice 100%  lost 0'), lines[0])
        self.assertTrue(lines[1].startswith('owl rejected  c8 s2008  lattice '), lines[1])
        self.assertIn('off its grid', lines[1])
        self.assertGreater(page.size[0], 6 * 2 * contact_sheet.THUMB)


class Jobs(unittest.TestCase):
    def test_the_owl_test_picture(self):
        job = pg.bakeoff_job('owl')
        self.assertEqual((job['grid'], job['fit']), (24, 'subject'))
        self.assertIn('owl', job['prompt'])

    def test_an_entry_with_a_seed_and_scale_makes_that_one_picture_again(self):
        entries = [{'course': 'animals', 'slug': 'owl', 'grid': 24, 'fit': 'subject', 'prompt': 'a round owl',
                    'seed': 2012, 'scale': 12},
                   {'course': 'classics', 'slug': 'heart', 'grid': 16, 'fit': None, 'prompt': None,
                    'seed': None, 'scale': None}]
        job = pg.entry_job('owl', entries)
        self.assertEqual((job['name'], job['grid'], job['fit'], job['seed'], job['scale']),
                         ('animals-owl', 24, 'subject', 2012, 12))
        self.assertTrue(job['prompt'].startswith('Pixel Art, PixArFK, a round owl. '))
        self.assertEqual(pg.entry_job('animals/owl', entries)['name'], 'animals-owl')
        with self.assertRaises(SystemExit, msg='heart has no prompt recorded'):
            pg.entry_job('heart', entries)
        with self.assertRaises(SystemExit):
            pg.entry_job('fox', entries)

    def test_a_recorded_seed_is_searched_alone(self):
        stub = StubComfy(lambda size, seed: owl(24, size))
        self.addCleanup(stub.close)
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        job = {'name': 'animals-owl', 'grid': 24, 'fit': 'subject', 'prompt': 'p', 'seed': 2012, 'scale': 12}
        result = pg.search(pg.Comfy(stub.host, poll=0.01), job, d.name, seeds=6, scales=[10, 12], log=lambda *_: None)
        self.assertEqual([(h['seed'], h['scale']) for h in result['hits']], [(2012, 12)])
        self.assertEqual(len(stub.jobs), 1)


if __name__ == '__main__':
    unittest.main()
