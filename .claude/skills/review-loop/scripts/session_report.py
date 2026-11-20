#!/usr/bin/env python3
"""session-report: log each decision while you work, then render one report for Cesar.

Usage:
  session_report.py decide KEY --decision T --why T --rejected T --evidence POINTER --result T
                    [--supersedes ID] [--lesson T] [--held REASON] [--unverified T] [--term "word: meaning"]
                    [--name N] [--date YYYY-MM-DD]
  session_report.py render [--name N] [--date YYYY-MM-DD] [--prs FILE] [--proofs FILE]

`decide` appends one line to <root>/<project>/reports/<date>-<name>/decisions.jsonl. `render` writes report.md
beside it: what shipped, decisions, one-way doors held for Cesar, what could not be verified, what to learn.
<root> is $NOUSFX_REPORT_ROOT or ~/Releases; <name> defaults to the ticket key. Files never go inside a git
checkout, and a value that looks like a secret is refused before anything is written.

The log is append-only (idea from pstack's show-me-your-work skill, MIT, github.com/cursor/plugins).
`decide` never edits or deletes: each entry gets the next id, and a wrong one is corrected by a new entry with
--supersedes ID, which `render` shows beside the old one. A correction keeps the old entry's --held reason
unless it gives its own: only Cesar releases a held door. --evidence is a pointer, never prose: a commit SHA,
#PR, file or file:line, or an https URL. --result says where it stands (tests green, reverted, open,
INCONCLUSIVE). `render` warns on stderr when a SHA or path does not resolve; PRs and URLs are not checked.

--prs FILE is a JSON list of {number, url, title, state}; without it `render` asks `gh pr list`.
--proofs FILE is pasted into the report as is (for example the proof table).

Exit 0 done, 1 other error, 2 refused input (nothing written).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

KEY_RE = re.compile(r"^[A-Z][A-Z0-9]{0,9}-[1-9][0-9]{0,6}$")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# Same pattern the gemini-review scripts, via_run.py, via_setup.py and claude/hooks/review-gate.py use to stop
# on a secret. Each script ships alone, so the copies stay: when you add a key pattern, add it to all of them.
SECRET_RE = re.compile(
    r"(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|AQ\.[0-9A-Za-z_-]{20,}|gh[pousr]_[0-9A-Za-z]{36}"
    r"|github_pat_[0-9A-Za-z_]{20,}|glpat-[0-9A-Za-z_-]{20,}|(^|[^0-9A-Za-z_-])sk-[0-9A-Za-z_-]{20,}"
    r"|[sr]k_live_[0-9A-Za-z]{10,}|xox[baprs]-[0-9A-Za-z-]{10,}"
    r"|eyJ[0-9A-Za-z_-]{10,}\.eyJ[0-9A-Za-z_-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY)"
)

FIELDS = ("decision", "why", "rejected", "evidence", "result", "lesson", "held", "unverified", "term")
REQUIRED = ("decision", "why", "rejected", "evidence", "result")
SHA_RE = re.compile(r"^[0-9a-f]{7,40}$")
PR_RE = re.compile(r"^#[1-9][0-9]*$")
URL_RE = re.compile(r"^https?://\S+$")


def die(message, code=1):
    print("Stopped: %s" % message, file=sys.stderr)
    sys.exit(code)


def has_secret(value):
    return bool(SECRET_RE.search(str(value)))


def repo_paths():
    """(work tree top, common git dir) of the checkout in the current folder, or ("", "") outside one.
    One git call; the common dir is shared by all worktrees, so its parent names the project."""
    try:
        r = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir"],
                           capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as e:
        die("git did not answer: %s" % e)
    lines = r.stdout.splitlines() if r.returncode == 0 else []
    return (lines[0], lines[1]) if len(lines) == 2 else ("", "")


def branch_key():
    """The ticket key from a `<prefix>/<KEY>` branch, or None."""
    try:
        r = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    last = r.stdout.strip().rsplit("/", 1)[-1] if r.returncode == 0 else ""
    return last if KEY_RE.match(last) else None


def report_dir(args, repo, key=None, guess=None):
    top, common = repo
    root = os.path.realpath(os.path.expanduser(os.environ.get("NOUSFX_REPORT_ROOT") or "~/Releases"))
    project = os.path.basename(os.path.dirname(common.rstrip("/"))) if common else os.path.basename(os.getcwd())
    parent = os.path.join(root, project or "project", "reports")
    target = os.path.realpath(parent)  # where files go, which a root that holds the checkout would put inside it
    for path in (top, common, os.path.dirname(common.rstrip("/")) if common else ""):  # last: the main checkout
        if path:
            path = os.path.realpath(path)
            if target == path or target.startswith(path + os.sep):
                die("the report folder %s is inside a git checkout. Set NOUSFX_REPORT_ROOT outside it." % target, 2)
    name = args.name or key
    if not args.date:  # a name keeps one folder across days: the newest one made for it
        for candidate in (name, guess):  # guess: render's ticket key from the branch, tried only with no name
            same = sorted(d for d in os.listdir(parent)
                          if re.match(r"^\d{4}-\d{2}-\d{2}-%s$" % re.escape(candidate), d)) \
                if candidate and os.path.isdir(parent) else []
            if same:
                return os.path.join(parent, same[-1])
            if name:
                break
    date = args.date or datetime.date.today().isoformat()
    if not DATE_RE.match(date):
        die("--date must look like 2026-11-19.", 2)
    if not name:  # render: take the one report of that date
        found = sorted(d for d in os.listdir(parent) if d.startswith(date + "-")) if os.path.isdir(parent) else []
        if len(found) != 1:
            die("%d reports for %s; pass --name." % (len(found), date), 2)
        name = found[0][len(date) + 1:]
    if not NAME_RE.match(name):
        die("--name may hold letters, digits, dots, hyphens and underscores only.", 2)
    return os.path.join(parent, "%s-%s" % (date, name))


def cmd_decide(args):
    if not KEY_RE.match(args.key):
        die("%r is not a ticket key like NFX-191." % args.key, 2)
    entry = {"key": args.key, "time": datetime.datetime.now().astimezone().isoformat(timespec="seconds")}
    for field in FIELDS:
        entry[field] = (getattr(args, field) or "").strip()
    for field in REQUIRED:
        if not entry[field]:
            die("--%s is empty. A decision needs what, why, the alternative you rejected, evidence and a result."
                % field, 2)
    if len(entry["evidence"]) > 300 or re.search(r"[\s`]", entry["evidence"]):
        die("--evidence is a pointer, not prose: a commit SHA, #PR, file:line or URL, with no spaces or backticks.", 2)
    if any(has_secret(v) for v in entry.values()):
        die("a value looks like a secret. Nothing was written.", 2)
    directory = report_dir(args, repo_paths(), args.key)
    existing, lines, _bad = read_log(directory)
    ids = {e["id"] for e in existing}
    entry["id"] = max(ids | {lines}) + 1  # past every line, so a bad line's place is never reused
    if args.supersedes is not None:
        if args.supersedes not in ids:
            die("--supersedes %d: there is no such entry in the log." % args.supersedes, 2)
        later = [e["id"] for e in existing if e.get("supersedes") == args.supersedes]
        if later:  # one chain per decision, so the newest entry is the only current one
            die("entry %d already corrects entry %d: supersede entry %d (or the newest in its chain)."
                % (later[-1], args.supersedes, later[-1]), 2)
        entry["supersedes"] = args.supersedes
        old = next(e for e in existing if e["id"] == args.supersedes)
        if old.get("held") and not entry["held"]:  # a correction never releases a held door by leaving it out
            entry["held"] = old["held"]
            if has_secret(entry["held"]):
                die("the held reason carried from entry %d looks like a secret. Nothing was written."
                    % args.supersedes, 2)
    line = json.dumps(entry, ensure_ascii=False)
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, "decisions.jsonl")
    with open(path, "a+b") as f:
        f.seek(0, os.SEEK_END)
        if f.tell():
            f.seek(-1, os.SEEK_END)
            if f.read(1) != b"\n":  # a torn last line: start ours on a fresh one
                f.write(b"\n")
        f.write((line + "\n").encode("utf-8"))
    print(path)
    return 0


def read_log(directory):
    """(entries, lines, bad): the readable entries, the count of non-blank lines, and of lines that are not an
    entry (a torn write, a hand edit). A bad line is skipped, never fatal, so the log stays appendable."""
    path = os.path.join(directory, "decisions.jsonl")
    if not os.path.isfile(path):
        return [], 0, 0
    entries, lines, bad = [], 0, 0
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if not line.strip():
                continue
            lines += 1
            try:
                entry = json.loads(line)
            except ValueError:
                entry = None
            if isinstance(entry, dict) and all(isinstance(entry.get(k), str) for k in ("key",) + REQUIRED) \
                    and all(isinstance(entry.get(k, ""), str) for k in FIELDS) \
                    and all(type(entry.get(k, 1)) is int for k in ("id", "supersedes")) and "id" in entry:
                entries.append(entry)
            else:
                bad += 1
    return entries, lines, bad


def unresolved(evidence, top):
    """True when a SHA or path named by `evidence` is not there. PRs and URLs are not checked."""
    if PR_RE.match(evidence) or URL_RE.match(evidence):
        return False
    if SHA_RE.match(evidence):
        try:
            return subprocess.run(["git", "cat-file", "-e", evidence + "^{commit}"], cwd=top,
                                  capture_output=True, timeout=60).returncode != 0
        except (OSError, subprocess.TimeoutExpired):
            return True
    path = re.sub(r":\d+(-\d+)?$", "", evidence)
    return not os.path.exists(os.path.join(top, path))


def cell(text):
    """One table cell: one line, the backslash and `|` escaped (as via_run.py's cell)."""
    return re.sub(r"\s+", " ", text or "").replace("\\", "\\\\").replace("|", "\\|")


def pr_list(args, keys):
    if args.prs:
        try:
            with open(args.prs, encoding="utf-8") as f:
                prs = json.load(f)
        except (OSError, ValueError) as e:
            die("cannot read --prs %s: %s" % (args.prs, e))
        if not isinstance(prs, list) or not all(isinstance(p, dict) for p in prs):
            die("--prs must be a JSON list of {number, url, title, state} objects.", 2)
        if has_secret(json.dumps(prs)):
            die("--prs holds a secret-shaped value. Nothing was written.", 2)
        return prs, None
    if not keys:
        return [], None
    prs = {}
    for key in sorted(keys):
        try:
            r = subprocess.run(["gh", "pr", "list", "--state", "all", "--search", key, "--limit", "200",
                                "--json", "number,url,title,state,headRefName"], capture_output=True, text=True,
                               timeout=120)
            found = json.loads(r.stdout or "[]") if r.returncode == 0 else None
        except (OSError, subprocess.TimeoutExpired, ValueError):
            found = None
        if not isinstance(found, list):
            return [], "PR list unavailable (`gh pr list` failed)."
        for pr in found:
            if any(re.search(r"(?<![A-Za-z0-9-])%s(?![0-9])" % re.escape(key), pr.get(f) or "")
                   for f in ("title", "headRefName")):
                if has_secret(json.dumps(pr)):
                    die("PR #%s from `gh` holds a secret-shaped value. Nothing was written." % pr.get("number"), 2)
                prs[pr["number"]] = pr
    return sorted(prs.values(), key=lambda p: p["number"]), None


def cmd_render(args):
    repo = repo_paths()
    top = repo[0] or os.getcwd()
    directory = report_dir(args, repo, guess=None if args.name else branch_key())
    entries, _lines, bad = read_log(directory)
    if bad:
        print("Warning: %d unreadable log lines skipped in %s" % (bad, directory), file=sys.stderr)
    keys = {e["key"] for e in entries}
    replaced = {e["supersedes"]: e["id"] for e in entries if e.get("supersedes")}
    prs, pr_problem = pr_list(args, keys)
    out = ["# Session report: %s" % os.path.basename(directory), "", "## What shipped"]
    if pr_problem:
        out.append(pr_problem)
    elif not prs:
        out.append("No pull requests found.")
    else:
        out += ["| PR | title | state |", "| --- | --- | --- |"]
        out += ["| [#%s](%s) | %s | %s |" % (p.get("number"), p.get("url"), cell(p.get("title")), cell(p.get("state")))
                for p in prs]
    out += ["", "## Decisions"]
    if bad:
        out += ["%d unreadable log lines were skipped; the report may be missing decisions." % bad, ""]
    if not entries:
        out.append("No decisions logged. The log is missing or empty, so this report is not a full account.")
        print("Warning: no decisions logged in %s" % directory, file=sys.stderr)
    else:
        out += ["| id | ticket | decision | why | rejected alternative | evidence | result | lesson |",
                "| --- | --- | --- | --- | --- | --- | --- | --- |"]
        for e in entries:
            bad = unresolved(e["evidence"], top)
            if bad:
                print("Warning: entry %s evidence does not resolve: %s" % (e["id"], e["evidence"]), file=sys.stderr)
            ident = str(e["id"]) + (" (replaces %s)" % e["supersedes"] if e.get("supersedes") else "")
            result = cell(e["result"]) + (" (superseded by %s)" % replaced[e["id"]] if e["id"] in replaced else "")
            out.append("| %s | %s | %s | %s | %s | `%s`%s | %s | %s |" % (
                ident, e["key"], cell(e["decision"]), cell(e["why"]), cell(e["rejected"]), cell(e["evidence"]),
                " (unresolved)" if bad else "", result, cell(e.get("lesson"))))
    current = [e for e in entries if e["id"] not in replaced]  # a replaced entry stays only in the table
    out += ["", "## Held for Cesar (one-way doors)"]
    held = [e for e in current if e.get("held")]
    out += ["- %s: %s. Held because: %s" % (e["key"], cell(e["decision"]), cell(e["held"])) for e in held] or ["None."]
    out += ["", "## Not verified"]
    out += ["- %s: %s" % (e["key"], cell(e["unverified"])) for e in current if e.get("unverified")] or ["None."]
    if args.proofs:
        try:
            with open(args.proofs, encoding="utf-8") as f:
                proofs = f.read().strip()
        except OSError as e:
            die("cannot read --proofs %s: %s" % (args.proofs, e))
        if has_secret(proofs):
            die("--proofs holds a secret-shaped value. Nothing was written.", 2)
        out += ["", "## Proofs", proofs]
    out += ["", "## What to learn"]
    learn = ["- %s: %s" % (e["key"], cell(e["lesson"])) for e in current if e.get("lesson")]
    learn += ["- %s" % cell(e["term"]) for e in current if e.get("term")]
    out += learn or ["None."]
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, "report.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(path)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="command", required=True)
    d = sub.add_parser("decide")
    d.add_argument("key")
    d.add_argument("--supersedes", type=int)
    for field in FIELDS:
        d.add_argument("--" + field)
    r = sub.add_parser("render")
    r.add_argument("--prs")
    r.add_argument("--proofs")
    for p in (d, r):
        p.add_argument("--name")
        p.add_argument("--date")
    args = ap.parse_args()
    return cmd_decide(args) if args.command == "decide" else cmd_render(args)


if __name__ == "__main__":
    sys.exit(main())
