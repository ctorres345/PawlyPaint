# Via asset brief: PawlyPaint

Soft, cozy kawaii style matching the redesign art in `assets/art/` (Mochi, tier frames, icons): rounded shapes, gentle shading, thick soft outlines, no harsh black.
Palette: rose pink `#E5739F` (theme seed), blush `#FCE4EC`, paper white `#FFFBF7`, warm brown `#8D5A3B`, deep cocoa `#3B2A2F`.
Mood: a keepsake photo for a child's finished jewel painting. Style references: `assets/art/tiers/gold.png`, `assets/art/icons/gem_paw.png`.

## Puzzle pictures (PAP-71)
Pixel art for the paint/sort pictures: each picture is painted gem by gem on a square grid, 16x16 (Easy), 24x24 (Medium), 32x32 (Hard) or 40x40 (Extreme). Every pixel is a big, equal, sharp square block: no anti-aliasing, no blur, no gradients, no dithering noise, no text. Cute, cozy kawaii look with a dark outline on the subject and a limited palette: Easy 4-6 colors, Medium 6-8, Hard up to 12, Extreme up to 16. Small details (shine, eyes, cheeks) are single deliberate pixels. The game plays the approved picture 1:1: it is only cropped and its colors cut, never redrawn.

## Local generation (PAP-95, PAP-97)
Pictures are made on Cesar's PC with `tool/pixel_gen.py` (Z-Image Turbo with the PIXELART-REDMOND LoRA on ComfyUI; setup in `docs/RUNBOOK.md`, "Local art generation"). It draws on a canvas of the grid times 8 or 16 px and names the grid in the prompt, so the picture comes out on its grid. A try is kept only when it is drawn on that grid (on-lattice share) and its conversion keeps every small feature (eyes, nose, cheeks); `docs/RUNBOOK.md`, "Make pictures".

House style ("richer prompt v2"), added after the subject by `pixel_gen.py`:

> cute kawaii game sprite, chubby rounded body, big round eyes with a white highlight, a small soft pink blush on each cheek only, natural true-to-life animal colours, soft two-tone shading with one lighter and one darker shade of each colour, dark brown outline, clean readable silhouette, large square pixels drawn on a {grid}x{grid} pixel grid, no anti-aliasing, no dithering, no gradients, at most {level's colours} colours

The subject text names the animal, its pose and its real colors, and the setting:
- Easy and Medium (subject): "centred, plain flat <color> background", a color that contrasts with the animal. The subject's box must fit the grid and span at least 70% of it; the background pads the rest.
- Hard and Extreme (scene): "filling the whole frame", with a light setting (Hard: two or three flat shapes) or a full scene (Extreme). The animal is "large and fills half the picture". The scene fills the grid edge to edge.

Canvas per level (grid x 8 and grid x 16 px, tried with 6 seeds each by default; `--scales` takes any of 7 to 16 px a cell):

| Level | Grid | Colors | Fit | Px a cell | Canvas |
|---|---|---|---|---|---|
| Easy | 16 | 6 | subject | 8, 16 | 128, 256 |
| Medium | 24 | 8 | subject | 8, 16 | 192, 384 |
| Hard | 32 | 12 | scene | 8, 16 | 256, 512 |
| Extreme | 40 | 16 | scene | 8, 16 | 320, 640 |

Record an approved picture's subject text (`prompt`), `seed`, `scale` and `fit` in its `design/assets.toml` entry, so `pixel_gen.py --entry <course>/<slug>` makes it again.
