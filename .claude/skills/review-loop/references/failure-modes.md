Read this when planning a ticket's tests, after Step 0, and in Record the review (NFX-201). Each bullet of the ticket's "Failure modes" section maps to a test that covers it, so review stops being where those edges are found.

## When planning
Save the ticket text (the Jira description of the ticket in the branch name) to a scratch file outside the repo and run `python3 -B <this skill's folder>/scripts/failure_modes.py list <file>` (`python` on Windows). It prints the failure-mode table, one empty row `| FMn <bullet> |  |` per bullet. Put it in the plan and write a test for each row, test-first, before the code. Fill the last cell with the test, backticked (`test_x.py::test_name` or the command that runs it; several are comma-separated, each backticked). Prose around a name does not count. A failure mode that is a judgement call (wording, a choice no test can pin) gets `waived: <why>` instead; the reason must say why it cannot be tested. A ticket with no "Failure modes" heading prints an empty table and says so: skip the rest. A section written as prose, with no list item, or failure modes named without a `## Failure modes` heading (bold text, Jira wiki `h2.`), is refused (exit 2): fix the ticket file's form and run it again.

## After Step 0, before round 1
Write the filled table into a scratch draft of the PR body and run `python3 -B <this skill's folder>/scripts/failure_modes.py check <ticket file> <draft>`. Only rows whose first cell starts with `FMn` are read, so the proof table can sit in the same draft.

| Exit | Meaning | What you do |
|---|---|---|
| 0 | every failure mode has a test or a stated waiver | nothing |
| 1 | it printed an `FMn` line marked `med` for each failure mode with no row, a prose or empty cell, or `waived:` with no reason | each line is a `med` finding, confidence 80: add the test and fill the row, or state the waiver |
| 2 | a file cannot be read, the "Failure modes" section has text but no list item, failure modes are named without that heading, or a row names an unknown or repeated `FMn` | fix the input and run it again; not a verdict |

- Give the reviewer the table and the `Failure-Modes:` line as evidence. The script checks that each row names a test, not that the test covers it: the reviewer judges that, and reports a row whose test does not exercise its failure mode as a `med` finding.
- A waived row is not a finding. The reviewer may still report a waiver whose reason does not hold.

## In Record the review
Run `check` again on the final table. Exit 1 there is an open `med` finding for each line, counted in `--findings`. Put the table in the PR body under "Failure modes" and its `Failure-Modes:` line next to `AC-Proof:`.
