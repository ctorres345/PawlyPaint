Read this after Step 0 (NFX-196). It lists the comments the diff adds, so the reviewer can judge whether each one earns its place.

## Run it
After Step 0, and again before each later round (fixes add comments), run `python3 -B <this skill's folder>/scripts/comment_check.py <base hash>` (`python` on Windows). It prints one line per flag (`file:line kind text`) and a count line per kind. Show the count line. Only lines the diff adds count; old comments never do.

Exit 2 is not a pass: report "comment check did not run" with its stderr and go on.

## Warn-only
The check never blocks. A flag the reviewer judges real is a `low` finding, so it gets a disposition (`fix-now` or `note`) and never stops the loop. NFX-233 changes this severity to `med`.

## What the reviewer gets
Give the reviewer the flag lines as evidence, the keep list as `scripts/comment_check.py --keep-list` prints it (the list lives only in that script's `KEEP`; never copy it here), and this rule:
- Judge each flag plainly. If no keep-list item clearly applies, it is a finding.
- A comment that explains a surprise in our own code: the finding names the rename, extract or type change that removes the need for it.
- A "do not remove" or "do not change" comment (kind `guard`): the finding offers to encode it as a test or check.
- A vendor or platform quirk stays only if the comment names the external cause.
- A bare ticket key (kind `ticket-tag`) is Stale: git log holds the history. A key with too short a reason (kind `ticket`) is not a reason either: the line must also say why.
- A section divider (kind `banner`) is a Tautology.
- A docstring on a test method (kind `test-docstring`) is a finding when it only repeats the test name.
- A lint suppression (kind `suppression`) needs its reason on the same line.

## In the final report
Comment check: flags, how many the reviewer judged real, and how many it kept (with the keep-list item for each).
