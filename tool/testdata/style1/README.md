# Style set 1 fixtures (PAP-97)

- `<animal>-c<scale>-s<seed>.png`: kept sources of the PAP-79 style set 1 run (`pixel_gen.py`, canvas grid x scale px). Used by the on-lattice share test: the two fawns are drawn on their grid, the rest are not.
- `pap96/<name>.png` and `.json`: each source's conversion by the parked `cesar/PAP-96` branch (snapped read, feature read, region-safe cut), the n x n puzzle, with the cell lines (`xs`, `ys`, source pixels) it read the source with. Used by the feature check tests: Cesar saw the fox's eyes, the panda's nose and the owl's eyes lost there. Fish c10-s3010 has none: its fit fails on that branch.

Since PAP-97 raised `ON_LATTICE_MIN` to 60%, fawn c8-s3008 (44%) is rejected on purpose: a 42% owl from the slice looked wrong to Cesar (see `../pap97/README.md`).

Don't regenerate these; they record what PAP-96 produced.
