# PAP-97 slice fixtures

- `owl-c8-s1008.png`: an owl (grid 24, ×8 canvas, seed 1008) from the PAP-97 slice run. Its on-lattice share is 42%, and it passed the first gate at 40%. Cesar rejected it: the eyes and the right ear don't match the source, because its eye rings are about 1.5 cells wide and no 1:1 puzzle can copy them. It fixes `ON_LATTICE_MIN` at 60%: the test checks that the gate now rejects it.
