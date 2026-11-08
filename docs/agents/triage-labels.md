# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the "Label in our tracker" column to match whatever vocabulary you actually use.

## Work labels

| Label | Meaning | Who runs it |
| --- | --- | --- |
| `env-none` | Tests and builds alone prove it | Queue and cloud |
| `env-emulator` | Needs an emulator, simulator or screenshots | Interactive Mac sessions for now |
| `env-device` | Needs real hardware, a store track or an outside account | Cesar (`ready-for-human`) |
| `fable-review` | Large or risky: security, auth, migrations, concurrency, public API, billing | The PR waits for `reviewer-deep` on Cesar's Mac, after Cesar approves it |

Every non-Epic ticket has exactly one `env-*` label. The nightly queue takes `ready-for-agent` with `env-none`, and skips `fable-review` and tickets with an unfinished blocker.
