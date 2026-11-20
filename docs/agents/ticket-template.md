# Ticket template

Every ticket uses these sections. Write "None" or "N/A" instead of deleting one, so a gap is visible.

```markdown
## Goal
What the user can do afterward, and why it matters.

## Scope
In: ...
Out: ...

## Acceptance criteria
- [ ] Checkable behavior. Proof: `command that shows it`
- [ ] Behavior only a device or network shows. Proof: manual: the step to run
- [ ] Behavior a quota-limited or paid service shows. Proof: manual: the step Backup: a recorded output or a stubbed run

## Failure modes
How it could break in production, and what it does then.

## Environment
env-none | env-emulator | env-device, and the devices needed

## UI evidence (UI changes only)
- Prototype: link and artboard or screen name
- Values: colors, sizes, radii, spacing, icons, states (open, pressed, selected, empty, dark)
- [ ] Matches the prototype on the values above
- [ ] Before and after screenshots, light and dark, on the listed devices, captured by the agent (simulator, emulator or browser) and attached in the PR description's Screenshots / recording section
- [ ] Screen recording instead of or besides screenshots if it involves motion, a flow, or a bug that shows over time

## Assets (needs-assets only)
One row per image or SVG the ticket needs, with the `needs-assets` label. With no label, write "None" (or "N/A"): "None" is not enough for a ticket that has the label. Fill every cell (size: pixels, or "vector" for an SVG).

| name | svg/image | platforms | size | usage |
| --- | --- | --- | --- | --- |
| `<feature>_<what>_<variant>` (snake_case) | svg or image | flutter (android, ios) | e.g. 24x24 or 1024x1024 | where it appears |

## Review
- [ ] review-loop
- Fable: required or not, with the reason

## Human gates
Approvals or manual steps needed from Cesar, or "None"

## Blocked by
Ticket keys, or "None"
```

## Ready check

A ticket gets `ready-for-agent` only when all of these hold:

- Every section is filled, and each acceptance criterion ends in a `Proof:` line (a command, or `manual: <step>`).
- A manual proof that needs a quota-limited or paid service (agy images, the Gemini API, a store review) adds `Backup: <proof>`, such as a recorded output or a stubbed run, which counts when the service is unavailable. The PR's proof table says which one ran.
- Failure modes names at least one way it breaks.
- It has exactly one `env-*` label (Epics have none).
- Human gates says "None", and every blocker is Done.
- It is not `env-device`, which stays `ready-for-human`. Fable approval sits in Review and does not count as a human gate.
- A code-owner merge by Cesar (a PR touching `.github/`, `.claude/` or `.nousfx/`) also sits in Review and does not count as a human gate. The agent still finishes the work and asks before the PR; Cesar merges.
- A UI ticket names its prototype artboard and concrete values. If no prototype exists, it says so and states the visual source to follow (for example the current screens in `docs/screenshots/`), or it stays `ready-for-human` until a prototype is approved.
- A ticket with the `needs-assets` label has a filled `## Assets` section (at least one real row). With the label and an empty or `None` section it stays out of `ready-for-agent`.

## Batch review

When a batch of tickets is drafted, the read-only Fable `architect` agent, from Cesar's Mac, critiques the whole batch once, after Cesar approves the review, and before publishing. It looks for missing prototype references, conflicting scope, wrong blocking edges, wrong `env-*` labels, and which tickets need `fable-review`. Fix real findings, then publish.

## Prototype fidelity

The prototype is the spec for UI work. Read its source before writing UI code, list its concrete values in the plan, and report deliberate differences in the PR.
