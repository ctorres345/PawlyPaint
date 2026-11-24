"""Makes puzzle picture sources on a local ComfyUI server (PAP-95, PAP-97).

Z-Image Turbo with the PIXELART-REDMOND LoRA draws a picture on a canvas of
the puzzle grid times 8 or 16 px a cell (CELL_PX; the VAE works in 8 px
steps), and the prompt names the grid. Each try is judged before it is
converted: its on-lattice share (art_to_puzzle.on_lattice_share) must reach
ON_LATTICE_MIN, else the model drew its own blocks and the try is rejected.
A try on its grid is read with the plain fixed lattice, placed 1:1 by the
fit mode, converted, verified, and then checked for lost features
(art_to_puzzle.feature_check): a feature lost inside the subject rejects it.
The search tries a few seeds at each canvas.

The ComfyUI host comes from --host or the PAWLY_COMFY_HOST environment
variable, never from this repo. Setup: docs/RUNBOOK.md, "Local art
generation". House style: design/brief.md.

Talks to ComfyUI with the standard library only; the fit check imports
art_to_puzzle, which needs Pillow. Run with a Python that has it:
  ~/.local/share/nousfx/via/venv/bin/python3 tool/pixel_gen.py --test owl --out <dir>
  ... tool/pixel_gen.py --entry animals/owl --out <dir>
  ... tool/pixel_gen.py --prompt "a chubby frog on a lily pad, plain light blue background" \\
      --grid 24 --out <dir>
Each kept seed writes <name>-c<scale>-s<seed>.png (the source) and
puzzle-<name>-c<scale>-s<seed>.png (the converted puzzle, 16 px a cell, lost
features boxed); a rejected try writes the same into rejected/ (the puzzle
only when it got that far). report.json lists every try with its on-lattice
share and lost features; tool/contact_sheet.py lays them all out. Record an approved one's prompt, seed and scale
in design/assets.toml so --entry can make it again.
Tests: python3 -m unittest tool/test_pixel_gen.py
"""
import argparse
import http.client
import io
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ENV_HOST = 'PAWLY_COMFY_HOST'
UNET = 'z_image_turbo_bf16.safetensors'
TEXT_ENCODER = 'qwen_3_4b.safetensors'
VAE = 'ae.safetensors'
LORA = 'ZImageTurbo_PixelArt_Redmond.safetensors'
LORA_STRENGTH = 1.0
TRIGGER = 'Pixel Art, PixArFK'
STEPS, SAMPLER, SCHEDULER, SHIFT = 9, 'res_multistep', 'simple', 3.0
HOUSE_STYLE = ('cute kawaii game sprite, chubby rounded body, big round eyes with a white highlight, '
         'a small soft pink blush on each cheek only, natural true-to-life animal colours, '
         'soft two-tone shading with one lighter and one darker shade of each colour, dark brown outline, '
         'clean readable silhouette, large square pixels drawn on a {grid}x{grid} pixel grid, no anti-aliasing, no dithering, no gradients, '
         'at most {colors} colours')
CELL_PX = (8, 16)
ON_LATTICE_MIN = 0.40
MISS_BOX, OUTSIDE_BOX = (255, 0, 255), (255, 170, 0)
FEATURES_SHOWN = 3
FIT_BY_GRID = {16: 'subject', 24: 'subject', 32: 'scene', 40: 'scene'}
SEEDS = 6
HTTP_TIMEOUT_S = 10
JOB_TIMEOUT_S = 300
POLL_S = 0.5
CLOSEST_SHOWN = 3
# The four test pictures of the PAP-79 bake-off.
TESTS = {
    'fish': (16, 'a round orange goldfish seen from the side, one big black eye with a white highlight, '
                 'small fins and a wide flowing tail, centred, plain flat mint green background'),
    'owl': (24, 'a round fluffy brown owl sitting on a short branch, two big yellow eyes with black pupils, '
                'cream belly with small feather marks, little orange beak, centred, plain flat dark navy background'),
    'panda': (32, 'a chubby panda sitting and eating a green bamboo stalk, the panda is large and fills half the '
                  'picture, simple light setting filling the whole frame: a soft green hill, a pale blue sky and '
                  'one white cloud'),
    'fawn': (40, 'a little spotted fawn standing in a forest clearing, the fawn is large in the foreground and '
                 'fills half the picture, full scene filling the whole frame: trees behind, green grass, '
                 'small flowers, a pale sky'),
}


def _import_art_to_puzzle():
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
    import art_to_puzzle
    return art_to_puzzle


def prompt_for(subject, grid):
    """The full prompt: the LoRA trigger, the subject, then the house style
    with the grid and the level's colour limit."""
    return f'{TRIGGER}, {subject}. ' + HOUSE_STYLE.format(grid=grid, colors=_import_art_to_puzzle().COLOR_LIMIT[grid])


def workflow(prompt, size, seed):
    """The ComfyUI API workflow: Z-Image Turbo with the REDMOND LoRA on a
    size x size canvas."""
    return {
        '1': {'class_type': 'UNETLoader', 'inputs': {'unet_name': UNET, 'weight_dtype': 'default'}},
        '2': {'class_type': 'CLIPLoader', 'inputs': {'clip_name': TEXT_ENCODER, 'type': 'lumina2'}},
        '3': {'class_type': 'VAELoader', 'inputs': {'vae_name': VAE}},
        '11': {'class_type': 'LoraLoaderModelOnly',
               'inputs': {'model': ['1', 0], 'lora_name': LORA, 'strength_model': LORA_STRENGTH}},
        '4': {'class_type': 'ModelSamplingAuraFlow', 'inputs': {'model': ['11', 0], 'shift': SHIFT}},
        '5': {'class_type': 'CLIPTextEncode', 'inputs': {'clip': ['2', 0], 'text': prompt}},
        '6': {'class_type': 'ConditioningZeroOut', 'inputs': {'conditioning': ['5', 0]}},
        '7': {'class_type': 'EmptySD3LatentImage', 'inputs': {'width': size, 'height': size, 'batch_size': 1}},
        '8': {'class_type': 'KSampler',
              'inputs': {'model': ['4', 0], 'positive': ['5', 0], 'negative': ['6', 0], 'latent_image': ['7', 0],
                         'seed': seed, 'steps': STEPS, 'cfg': 1.0, 'sampler_name': SAMPLER,
                         'scheduler': SCHEDULER, 'denoise': 1.0}},
        '9': {'class_type': 'VAEDecode', 'inputs': {'samples': ['8', 0], 'vae': ['3', 0]}},
        '10': {'class_type': 'SaveImage', 'inputs': {'images': ['9', 0], 'filename_prefix': 'pawlypaint'}},
    }


def host_of(flag, environ):
    """The server URL from --host or PAWLY_COMFY_HOST, with http:// added
    when no scheme is given."""
    host = (flag or environ.get(ENV_HOST) or '').strip().rstrip('/')
    if not host:
        sys.exit(f'no ComfyUI host: pass --host or set {ENV_HOST} (for example http://<pc-name>:8188)')
    return host if '://' in host else f'http://{host}'


class JobTimeout(Exception):
    """A job that gave no picture before the job deadline."""


class Comfy:
    """A ComfyUI server's HTTP API: queue a workflow, wait, fetch the image."""

    def __init__(self, host, poll=POLL_S, timeout=JOB_TIMEOUT_S, http_timeout=HTTP_TIMEOUT_S):
        self.host, self.poll, self.timeout, self.http_timeout = host, poll, timeout, http_timeout
        self.client = str(uuid.uuid4())

    def _call(self, path, data=None):
        body = json.dumps(data).encode() if data is not None else None
        req = urllib.request.Request(self.host + path, data=body, headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=self.http_timeout) as r:
            return r.read()

    def check(self):
        """Stops the run when the server doesn't answer."""
        try:
            self._call('/system_stats')
        except (OSError, ValueError, http.client.HTTPException):
            self.unreachable()

    def unreachable(self):
        sys.exit(f'ComfyUI not reachable at {self.host}')

    def cancel(self, pid):
        """Takes a job off the queue and stops it if it is running, so the
        next one doesn't wait behind it. Best effort."""
        for path, data in (('/queue', {'delete': [pid]}), ('/interrupt', {})):
            try:
                self._call(path, data)
            except (OSError, http.client.HTTPException):
                pass

    def generate(self, wf):
        """Runs one workflow; returns the PNG bytes of its SaveImage node. A
        poll that answers late is retried; past the job deadline the job is
        cancelled and JobTimeout raised."""
        pid = json.loads(self._call('/prompt', {'prompt': wf, 'client_id': self.client}))['prompt_id']
        start = time.time()
        while True:
            try:
                history = json.loads(self._call(f'/history/{pid}'))
            except TimeoutError:
                history = {}
            if pid in history:
                break
            if time.time() - start > self.timeout:
                self.cancel(pid)
                raise JobTimeout(f'no picture after {self.timeout}s (job {pid})')
            time.sleep(self.poll)
        images = history[pid].get('outputs', {}).get('10', {}).get('images')
        if not images:
            raise RuntimeError(f'job {pid} returned no image: {history[pid].get("status")}')
        image = images[0]
        query = urllib.parse.urlencode({k: image[k] for k in ('filename', 'subfolder', 'type')})
        return self._call(f'/view?{query}')


def fit_check(png, grid, mode):
    """Judges and converts one generated PNG at the grid in fit mode.
    Returns {'ok', 'why', 'distance', 'image', 'on_lattice', 'features'}:
    image is the puzzle when the try got that far, distance how many blocks
    a side it is off (None when not measured), on_lattice its share and
    features the ones the puzzle lost (art_to_puzzle.feature_check)."""
    a2p = _import_art_to_puzzle()
    result = {'ok': False, 'why': None, 'distance': None, 'image': None, 'on_lattice': None, 'features': []}
    try:
        src = a2p.Image.open(io.BytesIO(png))
        src.load()
    except OSError as e:
        return {**result, 'why': f'unreadable image: {e}'}
    share = result['on_lattice'] = round(a2p.on_lattice_share(src, grid), 3)
    if share < ON_LATTICE_MIN:
        return {**result, 'why': f'off its grid: on-lattice share {share:.0%} under {ON_LATTICE_MIN:.0%}'}
    analysis = a2p.lattice_analysis(src, grid)
    try:
        placed = a2p.fit_analysis(analysis, grid, mode)
    except a2p.FitError as e:
        return {**result, 'why': str(e), 'distance': e.miss}
    image, info = a2p.convert(placed, grid, a2p.COLOR_LIMIT[grid], a2p.LEVEL_GAP[grid], region_safe=True)
    lost = a2p.feature_check(src, image, analysis.lines)
    result.update(distance=0, image=image, features=lost)
    problems = a2p.verify(image, grid, info['subject'])
    inside = [f for f in lost if f['subject']]
    if inside:
        shown = '; '.join(f"{f['why']} at cells {f['cells'][0]},{f['cells'][1]}" for f in inside[:FEATURES_SHOWN])
        more = f' and {len(inside) - FEATURES_SHOWN} more' if len(inside) > FEATURES_SHOWN else ''
        problems.append(f"lost {len(inside)} feature{'s' if len(inside) > 1 else ''}: {shown}{more}")
    if problems:
        return {**result, 'why': '; '.join(problems)}
    return {**result, 'ok': True, 'why': f"{placed.placement}, {info['colors']} colours"}


def preview(image, grid, lost):
    """The puzzle at 16 px a cell with each lost feature boxed: MISS_BOX
    inside the subject, OUTSIDE_BOX outside it."""
    from PIL import Image, ImageDraw
    big = image.convert('RGB').resize((grid * 16,) * 2, Image.NEAREST)
    draw = ImageDraw.Draw(big)
    for f in lost:
        x0, y0, x1, y1 = f['cells']
        draw.rectangle([x0 * 16, y0 * 16, (x1 + 1) * 16 - 1, (y1 + 1) * 16 - 1],
                       outline=MISS_BOX if f['subject'] else OUTSIDE_BOX, width=2)
    return big


def generated(comfy, wf):
    """(PNG bytes, None), or (None, why) when ComfyUI refused or lost the
    job. Stops the run when the server stops answering."""
    try:
        return comfy.generate(wf), None
    except urllib.error.HTTPError as e:
        return None, f'ComfyUI refused the job: HTTP {e.code} {e.read().decode(errors="replace")[:300]}'
    except (JobTimeout, TimeoutError, RuntimeError) as e:
        return None, str(e)
    except (OSError, http.client.HTTPException):
        comfy.unreachable()


def search(comfy, job, out, seeds=SEEDS, scales=None, log=print):
    """Generates `seeds` pictures at each canvas scale (or the job's one
    recorded seed and scale) and keeps the ones that fit 1:1 in `out`.
    Writes nothing when the server is not reachable at the start; when it
    stops answering mid-run, report.json keeps the tries so far. A job
    ComfyUI fails is a miss. Rejected tries go to out/rejected/. Returns
    the report."""
    comfy.check()
    grid, mode = job['grid'], job['fit']
    if job.get('seed') is not None:
        tries = [(job['scale'], job['seed'])]
    else:
        tries = [(scale, i * 1000 + scale) for scale in scales or CELL_PX for i in range(1, seeds + 1)]
    os.makedirs(out, exist_ok=True)
    report = {'name': job['name'], 'grid': grid, 'fit': mode, 'prompt': job['prompt'], 'hits': [], 'misses': []}
    try:
        for scale, seed in tries:
            start = time.time()
            png, failed = generated(comfy, workflow(job['prompt'], grid * scale, seed))
            result = fit_check(png, grid, mode) if png else {'ok': False, 'why': failed, 'distance': None,
                                                             'image': None, 'on_lattice': None, 'features': []}
            row = {'seed': seed, 'scale': scale, 'why': result['why'], 'seconds': round(time.time() - start, 1),
                   'on_lattice': result['on_lattice'], 'features': result['features']}
            stem = f"{job['name']}-c{scale}-s{seed}"
            where = out if result['ok'] else os.path.join(out, 'rejected')
            for folder in (out, os.path.join(out, 'rejected')):
                for name in (f'{stem}.png', f'puzzle-{stem}.png'):
                    if os.path.exists(os.path.join(folder, name)):
                        os.remove(os.path.join(folder, name))
            if png:
                os.makedirs(where, exist_ok=True)
                with open(os.path.join(where, f'{stem}.png'), 'wb') as f:
                    f.write(png)
            if result['image'] is not None:
                preview(result['image'], grid, result['features']).save(os.path.join(where, f'puzzle-{stem}.png'))
            if result['ok']:
                report['hits'].append(row)
            else:
                report['misses'].append({**row, 'distance': result['distance']})
            log(f"{'fit ' if result['ok'] else 'miss'} {stem} ({row['seconds']}s): {result['why']}")
    finally:
        with open(os.path.join(out, 'report.json'), 'w') as f:
            json.dump(report, f, indent=1)
    if report['hits']:
        log(f"{len(report['hits'])}/{len(tries)} fit 1:1 in {out}")
    else:
        near = sorted((m for m in report['misses'] if m['on_lattice'] is not None),
                      key=lambda m: (m['distance'] is None, m['distance'] or 0, -m['on_lattice']))
        shown = list(dict.fromkeys(m['why'] for m in near))[:CLOSEST_SHOWN]
        if not shown:
            whys = list(dict.fromkeys(m['why'] for m in report['misses']))[:CLOSEST_SHOWN]
            shown = ['none measured: ' + '; '.join(whys)]
        log(f"no 1:1 fit in {len(tries)} tries; closest: {'; '.join(shown)}")
    return report


def bakeoff_job(name):
    """One of the bake-off test pictures (TESTS)."""
    grid, subject = TESTS[name]
    return {'name': name, 'grid': grid, 'fit': FIT_BY_GRID[grid], 'prompt': prompt_for(subject, grid)}


def entry_job(ref, entries):
    """The job for a manifest picture, `course/slug` or a slug only one
    course uses, from its recorded prompt (and seed and scale, if any)."""
    course, _, slug = ref.rpartition('/')
    found = [e for e in entries if e['slug'] == slug and (not course or e['course'] == course)]
    if len(found) != 1:
        sys.exit(f'{ref}: {"no" if not found else "more than one"} puzzle entry in design/assets.toml'
                 + ('' if not found else ': use course/slug'))
    e = found[0]
    if not e.get('prompt'):
        sys.exit(f"{e['course']}/{e['slug']}: no prompt recorded in design/assets.toml")
    return {'name': f"{e['course']}-{e['slug']}", 'grid': e['grid'], 'fit': e.get('fit') or FIT_BY_GRID[e['grid']],
            'prompt': prompt_for(e['prompt'], e['grid']), 'seed': e.get('seed'), 'scale': e.get('scale')}


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    what = ap.add_mutually_exclusive_group(required=True)
    what.add_argument('--test', choices=sorted(TESTS), help='one of the bake-off test pictures')
    what.add_argument('--entry', help='a puzzle entry with a recorded prompt: course/slug')
    what.add_argument('--prompt', help='the subject and setting (the house style is added)')
    ap.add_argument('--grid', type=int, choices=sorted(FIT_BY_GRID), help='with --prompt: the puzzle grid')
    ap.add_argument('--fit', choices=_import_art_to_puzzle().FIT_MODES, help='how to place it (default: by level)')
    ap.add_argument('--name', default='picture', help='with --prompt: file name prefix')
    ap.add_argument('--out', required=True, help='folder for the kept pictures (keep it outside the repo)')
    ap.add_argument('--seeds', type=int, default=SEEDS, help='seeds per canvas')
    ap.add_argument('--scales', help=f'canvas px a cell to try, for example 8 (default: {",".join(map(str, CELL_PX))})')
    ap.add_argument('--host', help=f'ComfyUI URL (default: ${ENV_HOST})')
    args = ap.parse_args(argv)
    if args.test:
        job = bakeoff_job(args.test)
    elif args.entry:
        job = entry_job(args.entry, _import_art_to_puzzle().puzzle_entries())
    else:
        if not args.grid:
            ap.error('--prompt needs --grid')
        job = {'name': args.name, 'grid': args.grid, 'fit': FIT_BY_GRID[args.grid], 'prompt': prompt_for(args.prompt, args.grid)}
    if args.fit:
        job['fit'] = args.fit
    scales = [int(s) for s in args.scales.split(',')] if args.scales else None
    low, high = _import_art_to_puzzle().CELL_PX_RANGE
    if scales and not all(low <= s <= high for s in scales):
        ap.error(f'--scales must be {low} to {high} px a cell')
    report = search(Comfy(host_of(args.host, os.environ)), job, args.out, args.seeds, scales)
    sys.exit(0 if report['hits'] else 1)


if __name__ == '__main__':
    main(sys.argv[1:])
