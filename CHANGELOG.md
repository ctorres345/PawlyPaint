# Changelog

Every PawlyPaint version, newest first. Android APKs are on the [Releases page](https://github.com/ctorres345/PawlyPaint/releases); installing a newer APK over an older one keeps all progress.

## Unreleased

- Music: all four songs recomposed. Warmer layered instruments (plucked strings, electric piano, vibes, a breathy flute) in stereo with a room reverb, soft brushes instead of sharp hats, and melodies built from repeated motifs on a bright pentatonic scale so nothing wanders into eerie notes.
- Cooler phone: the app no longer asks ProMotion iPhones for 120 frames per second, drops the per-frame blur passes behind the canvas and around picked-up beads, redraws the placed drills from a cached bitmap instead of thousands of shapes every frame, and repaints the shimmer and the Sort board at most 30 times a second while nothing is moving.

## 0.8.4 (2026-10-21)

- Sort: bigger canvases open zoomed in so beads are large enough to tap; pinch out or use Fit to see the whole picture, and a tap while zoomed far out zooms in first.
- Sort: taps aim for what you meant. A tap that lands between beads picks the misplaced bead or the matching empty spot under your fingertip instead of a correct neighbor, so near misses no longer count as mistakes or break combos.
- Sort: a tap counts where your finger touched down, not where it lifted.
- MIT license, app logo and a Ko-fi link in the README.

## 0.8.3 (2026-10-19)

- Sort: the picture is scrambled by swapping small blocks, so misplaced beads come in clumps you pick up and move as one piece.
- Time Attack: two seconds on the clock per move instead of two and a half, since moves are smaller now.

## 0.8.2 (2026-10-19)

- Sort: tapping a misplaced bead picks up only that bead and the misplaced beads of its color touching it, instead of every bead of that color. Lone beads move alone, clumps move as one piece.
- Time Attack clocks grow to match the extra moves.

## 0.8.1 (2026-10-19)

- Sort: tapping an empty spot fills it from the tray, switching to that color automatically. Changing your mind is no longer a mistake; only a real wrong drop counts.
- Sort: a spot whose color isn't in the tray yet gives a hint instead of a mistake.
- Sort: the tray row shows which color you're holding and how many beads.

## 0.8.0 (2026-10-19)

- Selection rings in Paint and Sort have a dark outline, so picked-up and highlighted beads stand out on white and pale colors too.
- Smoother painting on big canvases: placed drills are cached as you go instead of redrawing the whole board on every drill.
- Progress is written once per finish instead of several times; resuming a Sort picture is a little faster.
- README lists every feature and the tech stack.

## 0.7.0 (2026-10-19)

- Replay a finished picture drill by drill, and save any picture to Photos as a big PNG.
- Streaks sound brighter and buzz harder as they grow; combo milestones pop a badge.
- Find-next jumps to the biggest patch left, and the last few spots pulse.
- Sort gets a mini-map when zoomed in and stronger streak feedback.

## 0.6.0 (2026-10-19, no APK; shipped in 0.7.0)

- Paint boosters, earned by finishing pictures: bomb (clears a patch), magic wand (finishes the selected color) and wide brush (paints 3×3).
- Tray colors show a progress ring and burst when done.
- Mini-map while zoomed in.

## 0.5.1 (2026-10-19)

- Undo in Sort and Time Attack (up to 30 moves).
- Daily Time Attack challenge: one board per day (Easy or Medium on weekdays, Hard on weekends) with its own best score.
- The tray keeps beads of the same color together.

## 0.5.0 (2026-10-19)

- Sort works with taps: tap a misplaced bead to pick it up, tap the tray to stash it, tap an empty spot to drop it where it belongs.
- Combos in Sort: quick good drops in a row (within 6 s) earn bonus points.
- Time Attack mode: sort a surprise picture before the clock runs out. Hard and Extreme unlock after a win on the level before.
- Home shows Paint and Sort progress separately.
- Two new badges and a refreshed Sort tutorial.

## 0.4.8 (2026-10-19)

- Extreme level in every course: 5 big 40×40 pictures each, 30 in total, and a Fearless badge.
- Sort mixes 30% / 45% / 60% / 80% of the beads on Easy / Medium / Hard / Extreme; on Hard and Extreme, 3 stars allow the few shakes the hints need.

## 0.4.7 (2026-10-19)

- Sort mixes more beads as difficulty rises (30% Easy, 40% Medium, 45% Hard), still finishable without shaking.
- Switching Relaxed off before finishing no longer gives full stars.

## 0.4.6 (2026-10-19)

- Home and course cards count Sort finishes too.
- Every difficulty keeps its colors clearly distinct.
- Fixes: mistakes saved when leaving right after one, tutorial restart, sturdier Sort saves, no mistake for tapping a landing bead, finished daily pictures stay openable, the daily streak only counts today's picture.

## 0.4.5 (2026-10-19)

- Roomier Sort tray with outlined empty slots, gem-cut tray beads, and a shine sweep across each finished picture.

## 0.4.4 (2026-10-19)

- Each spot shows the color that belongs there, so a bead in the wrong place stands out in Sort; Paint tints are stronger.

## 0.4.3 (2026-10-19)

- Easy and Medium pictures have plain backgrounds and clearly distinct colors. Easy and Medium pictures in progress start fresh; finished ones stay finished.

## 0.4.2 (2026-10-19)

- Today's picture asks whether to play it in Paint or Sort, and either counts for the streak.

## 0.4.1 (2026-10-19)

- Battery and stability fixes.

## 0.4.0 (2026-10-19)

- Settings: relaxed mode, canvas themes, round drills, volume sliders.
- Achievements.

## 0.3.0 (2026-10-19)

- App icon, sound effects, gallery, daily picture with streak, and guided tutorials.

## 0.2.1 (2026-10-19)

- Sort: hold the preview to peek at the finished picture.
- Music: one looping theme per picture.

## 0.2.0 (2026-10-19)

- Sort mode: pick Paint or Sort at the top of any course.

## 0.1.0 (2026-10-19)

- First Android test build: Paint mode with courses of Easy, Medium and Hard pictures.
