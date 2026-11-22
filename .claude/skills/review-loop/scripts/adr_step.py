#!/usr/bin/env python3
"""adr-step: what the review loop's ADR step needs, from the ticket's decision log and docs/adr/.

Usage:
  adr_step.py [KEY] [--name N] [--date YYYY-MM-DD] [--adr-dir DIR]

Prints three lists:
  - the flagged decisions (`session_report.py decide --adr TITLE`) that are current: in a --supersedes chain only
    the newest entry counts, so a correction without --adr drops the flag;
  - the next free ADR number (one past the highest NNNN in docs/adr/): a suggestion, not a reservation, since
    another open PR may take the same one;
  - the accepted ADRs (number, title, first sentence of the body). Proposed, deprecated and
    `superseded by ADR-NNNN` ones are left out.
The log is found the way `session_report.py` finds it: KEY (default: the key in the branch name) or --name, and
the newest folder for it unless --date is given. --adr-dir defaults to docs/adr/ at the work tree top.
With no docs/adr/ the step says so and stops; with no decision log it says so and still lists the ADRs.

Exit 0 done (also when the step has nothing to do), 1 other error, 2 refused input.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import session_report  # noqa: E402

NAME_RE = re.compile(r"^(\d{4})-[a-z0-9]+(?:-[a-z0-9]+)*\.md$")


def one_line(text, limit=200):
    text = re.sub(r"\s+", " ", text or "").strip()
    return text if len(text) <= limit else text[:limit - 3].rstrip() + "..."


def read_adr(number, path):
    """{number, status, title, first}: first is the first sentence of the body; a missing part is ""."""
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    front = re.match(r"---\n(.*?)\n---\n", text, re.S)
    status = re.search(r"^status:\s*(.*?)\s*$", front.group(1), re.M) if front else None
    rest = [line for line in text[front.end() if front else 0:].splitlines() if line.strip()]
    title = rest[0][2:].strip() if rest and rest[0].startswith("# ") else ""
    body = next((line for line in rest[1:] if not line.startswith("#")), "") if title else ""
    return {"number": number, "status": status.group(1) if status else "", "title": title,
            "first": one_line(re.split(r"(?<=[.!?])\s", body.strip(), maxsplit=1)[0])}


def adrs(directory):
    """Every NNNN-slug.md in the folder, by number."""
    return [read_adr(m.group(1), os.path.join(directory, m.group(0)))
            for m in map(NAME_RE.match, sorted(os.listdir(directory))) if m]


def print_flagged(args, repo, key):
    """The log's current flagged entries, or why there is no log. A held entry never has --adr (`decide`)."""
    if not (key or args.name):
        print("ADR step: no ticket key in the branch name and no --name, so no decision log. Going on.")
        return
    directory = session_report.report_dir(args, repo, key)
    log = os.path.join(directory, "decisions.jsonl")
    if not os.path.isfile(log):
        print("ADR step: no decision log at %s (cloud session, or nothing logged). Going on." % log)
        return
    entries, _lines, bad = session_report.read_log(directory)
    flagged = [e for e in session_report.current_entries(entries) if e.get("adr")]
    print("Decision log: %s" % log)
    if bad:
        print("Warning: %d unreadable log lines skipped." % bad)
    print("Flagged decisions (current): %d" % len(flagged))
    for e in flagged:
        print("- entry %d: %s (decision: %s)" % (e["id"], one_line(e["adr"]), one_line(e["decision"])))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("key", nargs="?")
    ap.add_argument("--name")
    ap.add_argument("--date")
    ap.add_argument("--adr-dir")
    args = ap.parse_args()
    if args.key and not session_report.KEY_RE.match(args.key):
        session_report.die("%r is not a ticket key like NFX-191." % args.key, 2)
    repo = session_report.repo_paths()
    adr_dir = args.adr_dir or os.path.join(repo[0] or os.getcwd(), "docs", "adr")
    if not os.path.isdir(adr_dir):
        print("ADR step: no %s in this project, so no ADRs to write or check. Going on." % adr_dir)
        return 0
    print_flagged(args, repo, args.key or session_report.branch_key())
    found = adrs(adr_dir)
    print("Next free ADR number: %04d" % (max([int(a["number"]) for a in found] or [0]) + 1))
    accepted = [a for a in found if a["status"] == "accepted"]
    print("Accepted ADRs: %d" % len(accepted))
    for a in accepted:
        print("- ADR-%s %s: %s" % (a["number"], a["title"], a["first"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
