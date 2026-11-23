Read this after Step 0 (NFX-196). It lists the comments the diff adds, so the reviewer can judge whether each one earns its place.

## Run it
After Step 0, and again before each later round (fixes add comments), run `python3 -B <this skill's folder>/scripts/comment_check.py <base hash>` (`python` on Windows). It prints one line per flag (`file:line kind text`) and a count line per kind. Show the count line. Only lines the diff adds count; old comments never do.

Exit 2 is not a pass: report "comment check did not run" with its stderr and go on.

## Severity
A flag the reviewer judges real is a `med` finding at confidence 60 (NFX-233), so it is `fix-now`; one still unfixed when the loop ends is open. The fix is the change the finding names: a rename, extract or type change, a test or check, or an ADR, after which the comment it replaces goes; or, for kind `ticket` or `suppression`, the reason added to the same line, which keeps it under `ticket-why` or `suppression-why`. Otherwise delete a comment only when it is a Tautology or Stale. Besides "quote not found" (step 4) and "not an added comment" (an old line, or text the parser misread), the loop rejects a comment finding only with a reason that names the keep-list item it fits, names the external cause of a vendor or platform quirk, or says why the named fix cannot be made (a public or external name, no practical test, an ADR below the bar); the comment then stays. The script itself never blocks, and old comments never fail a PR.

## What the reviewer gets
Give the reviewer the flag lines as evidence, the keep list as `scripts/comment_check.py --keep-list` prints it (the list lives only in that script's `KEEP`; never copy it here), and this rule:
- Judge each flag plainly. If no keep-list item clearly applies, it is a finding: `med` at confidence 60.
- A comment that explains a surprise in our own code: the finding names the rename, extract or type change that removes the need for it.
- A "do not remove" or "do not change" comment (kind `guard`): the finding names the test or check that encodes it; the loop adds it and deletes the comment.
- A vendor or platform quirk stays only if the comment names the external cause.
- A bare ticket key (kind `ticket-tag`) is Stale: git log holds the history. A key with too short a reason (kind `ticket`) is not a reason either: the line must also say why.
- A section divider (kind `banner`) is a Tautology.
- A docstring on a test method (kind `test-docstring`) is a finding when it only repeats the test name.
- A lint suppression (kind `suppression`) needs its reason on the same line.

## In the final report
Comment check: flags, how many the reviewer judged real, and how many it kept (with the keep-list item for each).
