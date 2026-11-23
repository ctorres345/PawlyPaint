Read this after Step 0 and in Record the review (NFX-190). It shows whether the tests in the diff fail without the change.

## After Step 0, before round 1
Run `python3 -B <this skill's folder>/scripts/testfail.py run --base <base hash>` (`python` on Windows) and show the verdict line. It copies the working tree to a temporary clone, runs the project's check there with the change, then with the production files restored to the base. The real tree is never touched. When other sessions already run N full suites, it prints `waiting for a suite slot (k of N busy)` to stderr and waits: that is not a hang, so do not kill it (NFX-217).

| Verdict | Meaning | What you do |
|---|---|---|
| `yes` | the restored run failed and named a failing test, or `failing: import <path>`: the tests cannot import a production module the change added (a file that is not a test, docs included, names it) | nothing |
| `no` | the restored run passed: the tests do not cover the change | a `med` finding, confidence 80, quoting the first changed test file. If the PR states a pure-refactor reason, it is a `note` with that reason |
| `build` | the restored run failed and named no test, so it proves nothing | report it with the log tail and its `suite:` lines, no finding. If it names an `added helper`, list that file in `[check] tests` and run again. Otherwise ask the reviewer to check that a test reaches the changed code |
| `baseline-fail` | the check fails in the copy with the change | if `run-check` fails too, fix that before round 1. If it passes, the copy lacks gitignored setup (`node_modules`, `.venv`, `local.properties`): report it with the log tail, no finding |
| `n/a` | no production file or no test file changed | report it. If it says no file matched a test glob, the project names tests another way: suggest `[check] tests = [...]` |
| `n/a` ... `(comments only)` | `comment_check.py verify` found only comment changes and left no file to the suite, so nothing ran (NFX-251) | report it; the PR needs no hand-written reason. Comments here are verify's: it ignores docstrings a file does not read and lint suppressions, so where `[check]` runs doctests or a linter, `run-check --stamp` is what tests them |

- Exit 2 (timeout, detached HEAD, no `[check]` command) is not a verdict: report why it stopped. A timeout is never a pass.
- Give the reviewer the verdict line as evidence. The reviewer still judges test names, duplicated cases and tests that assert implementation details; pass/fail evidence comes from the script.
- Test files and the failure-line pattern come from `[check]` in `.nousfx/project.toml` (`tests = [...]`, `failure_pattern = "..."`); the default is `test_*`, `*_test.*`, a `tests/` folder, and the Gradle layout: a `src/test*/`, `src/androidTest*/` (variants like `testDebug` included) or `src/*Test/` source set, or with no `src/<set>` a `*Test.*` or `*Tests.*` name (`src/main/`, `src/*Main/` and `src/testFixtures/` stay production). The name rule holds in any language, so a production file named like `SpeedTest.tsx` counts as a test: such a repo sets `tests`. An added file that only tests name counts as a helper: testfail names it and says to list it in `tests`. Any other added file counts as production.

## In Record the review
After `run-check --stamp` (and `prove.py attest`), run `testfail.py attest --base <base hash>`. Only if it refuses (exit 2: the tree changed since the last run), run `testfail.py run --base <base hash>` on the final tree, then `attest` again. Put its `Tests-Fail-Without:` line in the PR body next to `AC-Proof:`. A final verdict of `no` with no stated reason is an open `med` finding. Any edit after the run needs a new run.
