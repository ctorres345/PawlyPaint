Read this after Step 0 (NFX-243), beside the comment and test-fail checks, and again before Record the review. It turns the ticket's flagged decisions into ADRs in the same PR and gives the reviewer the accepted ADRs.

## Log decisions as you make them
Log each decision as you make it with `scripts/session_report.py decide`, not only at the end. Add `--adr "<title>"` when the decision meets the ADR bar. The bar is stated once, in the `delete-comments` skill's Decision record kind (`claude/skills/delete-comments/SKILL.md` in NousFX): read it there and never restate it here. A `--held` entry never gets `--adr` (`decide` refuses it): it is not decided yet. To drop or change a flag, log a correction with `--supersedes ID`; only the newest entry in a chain counts.

## Run it
After Step 0, and again before Record the review (it catches entries logged during the loop), run `python3 -B <this skill's folder>/scripts/adr_step.py` (`python` on Windows). It finds the ticket's log by the key in the branch name (pass `--name` for a log under another name) and prints the current flagged decisions, the next free ADR number and the accepted ADRs.

- "no docs/adr/ ... Going on" or "no decision log ... Going on" (a cloud session, a log outside the repo): say so in the report and go on. The step never blocks.
- Exit 1 or 2: report "ADR step did not run" with its stderr and go on.

## Write the ADRs
Each flagged entry becomes `docs/adr/NNNN-<slug>.md` in this PR, in the format NousFX pins in scripts/test_adr_format.py (elsewhere, the `domain-modeling` skill's ADR-FORMAT): frontmatter with a lowercase status (`status: accepted`), a `# Title`, then a short body that names the ticket key. Write it before the next review round, so the reviewer reads it in the diff.

- The number is a suggestion, not a reservation: two open PRs can take the same one with no git conflict. Whoever merges second renumbers before merge, then marks the review again.
- A PR that changes an accepted decision adds a new ADR and sets the old one's status to `superseded by ADR-NNNN` (the new number).

## What the reviewer gets
Give the reviewer the helper's accepted-ADR list as evidence, sent as printed (as the comment flags are), with this rule: a diff that contradicts an accepted ADR is a `high` finding, unless the PR adds an ADR that marks the old one `superseded by ADR-NNNN`. No script detects a contradiction; the reviewer judges it.

## In the final report
ADR step: flagged decisions, the ADRs written (numbers), or why it was skipped.
