# Ticket template

Every ticket uses these sections. Write "None" or "N/A" instead of deleting one, so a gap is visible.

```markdown
## Goal
What the user can do afterward, and why it matters.

## Scope
In: ...
Out: ...

## Acceptance criteria
- [ ] Checkable behavior
- [ ] Test or command that proves it

## Environment
env-none | env-emulator | env-device, and the devices needed

## UI evidence (UI changes only)
- Prototype: link and artboard or screen name
- Values: colors, sizes, radii, spacing, icons, states (open, pressed, selected, empty, dark)
- [ ] Matches the prototype on the values above
- [ ] Before and after screenshots, light and dark, on the listed devices, captured by the agent (simulator, emulator or browser) and attached in the PR description's Screenshots / recording section
- [ ] Screen recording instead of or besides screenshots if it involves motion, a flow, or a bug that shows over time

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

- Every section is filled, and each acceptance criterion can be checked.
- It has exactly one `env-*` label (Epics have none).
- Human gates says "None", and every blocker is Done.
- It is not `env-device`, which stays `ready-for-human`. Fable approval sits in Review and does not count as a human gate.
- A UI ticket names its prototype artboard and concrete values. If no prototype exists, it says so and states the visual source to follow (for example `docs/DESIGN_SYSTEM.md`), or it stays `ready-for-human` until a prototype is approved.

## Batch review

When a batch of tickets is drafted, the read-only Fable `architect` agent, from Cesar's Mac, critiques the whole batch once, after Cesar approves the review, and before publishing. It looks for missing prototype references, conflicting scope, wrong blocking edges, wrong `env-*` labels, and which tickets need `fable-review`. Fix real findings, then publish.

## Prototype fidelity

The prototype is the spec for UI work. Read its source before writing UI code, list its concrete values in the plan, and report deliberate differences in the PR.
