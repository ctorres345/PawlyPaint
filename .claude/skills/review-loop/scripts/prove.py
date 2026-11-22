#!/usr/bin/env python3
"""Run a ticket's proofs, stamp them, and print an AC-Proof line (NFX-105).

Python only, standard library only; runs the same on macOS and Windows.

    python3 -B prove.py run LIST [--timeout SECONDS]
    python3 -B prove.py attest LIST
    python3 -B prove.py lint LIST

LIST is a Markdown file taken from the ticket's acceptance criteria (a PR table's cells have no `Proof:` prefix, so
they are not read). Every line with `Proof:` is one proof:
    Proof: `command`        run at the repo top level; must exit 0 and leave the working tree unchanged
    Proof: manual: <step>   listed by attest, never run and never counted
    Proof: manual: <step> Backup: <other proof>
                            the same, with a backup that counts when the step needs a quota-limited or paid service
                            that is unavailable (NFX-177); attest lists both, and the PR's proof table says which ran
                            ` Backup:` is reserved in a manual step: an older step that uses it is split there
Any other `Proof:` line is refused, so a typo cannot drop a criterion. Prose such as a `Proof:` in backticks is not
a proof line.

`lint` (NFX-208) runs nothing and needs no repo: with the same parser, it prints every refused line as
"line N: why" and exits 2, else exits 0. A list with only manual proofs passes, since `run`'s no-command rule is
about the list, not a line.

A command proof that is exactly the trusted `[check]` command is not run again when a valid `run-check --stamp` stamp
matches the tree, branch and check, as --mark matches it (NFX-218, reusable_check): `run` prints
"proof N: reused check stamp <tree>" and counts it as passed. In every other case the proof runs.

`run` stops at the first failing proof (exit 2, no stamp). When all pass, it writes a signed stamp in the git dir
(claude-proof-pass) that binds the working-tree hash, the branch and a hash of the normalized proofs. `attest`
never runs anything: it checks that stamp against the current tree and list, then prints
    AC-Proof: <passed>/<total> manual:<m> <tree> <sha of the proofs>
Exit 0 prints the line; exit 2 prints a reason to stderr and nothing to stdout.

Proofs are self-asserted. They come from a list the branch author controls and CI does not re-run them; see
docs/review-gate.md. The stamp helpers are the review gate's, loaded from the gate --mark runs: ~/.claude/hooks, else
the cloud copy in the git dir, else (in a NousFX checkout only) claude/hooks next to the skills folder. A project's
own .claude/hooks copy is never loaded (NFX-214; gate_paths, and "Where prove.py and testfail.py load the gate" in
docs/review-gate.md).
"""
import argparse
import contextlib
import hashlib
import importlib.util
import os
import re
import subprocess
import sys
import time

DEFAULT_TIMEOUT = 600
PROOF_LINE = re.compile(r"(?<![-`\w])Proof:[ \t]*(.*?)[ \t]*$")
COMMAND = re.compile(r"`([^`]*)`\.?")
MANUAL = "manual:"
BACKUP = re.compile(r"\s+Backup:\s*")
KIND = "proof"


class Refused(Exception):
    """A reason to stop with exit 2."""


def fail(message):
    print(f"Blocked: {message}", file=sys.stderr)
    return 2


def home_dir():
    """The home from the user record, not $HOME: a repo's committed settings `env` block can set HOME (NFX-214).
    Windows has no pwd, so there it is USERPROFILE, which that block can also set; so can PYTHONPATH, on every OS,
    for a script run as `python3 -B` (a stated limit in docs/review-gate.md). "" when unknown: never the cwd."""
    try:
        import pwd
        home = pwd.getpwuid(os.getuid()).pw_dir
    except ImportError:
        home = os.environ.get("USERPROFILE") or os.path.expanduser("~")
    return os.path.realpath(home) if home and os.path.isabs(home) else ""


def gate_paths(cwd):
    """Where the review gate may come from, reader first (NFX-214; the rule via_run.py follows, NFX-207), as
    (path, kind) pairs, plus the trusted paths a refusal names. The gate --mark runs comes first:
      installed  <home>/.claude/hooks/review-gate.py
      cloud      <git-dir>/nousfx-gate/current/hooks/review-gate.py, the default branch's copy the project hook
                 extracts when there is no ~/.claude. git runs with every GIT_* variable dropped: a committed
                 settings `env` block could point GIT_DIR at a fake git dir in the repo.
      checkout   only in a NousFX checkout: the gate next to the skills folder, abspath then realpath. A project copy
                 sits in .claude/skills/review-loop/scripts, and its sibling .claude/hooks/review-gate.py is a repo
                 file the branch under review can edit, so it is never a candidate. The checkout is told by the
                 invoked path: the folder holding skills/ and hooks/ is named `claude` (NousFX's source layout) for
                 both the abspath and the realpath. Projects, ~/.claude and anything else are `.claude` or another
                 name; a committed link from .claude/skills into a claude/ folder still has a `.claude` abspath."""
    home = home_dir()
    installed = os.path.join(home or "<home>", ".claude", "hooks", "review-gate.py")
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    # A committed folder that looks like a bare repo is not a git dir: --show-toplevel fails inside any git dir,
    # and safe.bareRepository=explicit (git 2.38+) refuses bare discovery as a second layer.
    try:
        r = subprocess.run(["git", "-c", "safe.bareRepository=explicit", "rev-parse", "--absolute-git-dir",
                            "--show-toplevel"], cwd=cwd, env=env, capture_output=True, text=True,
                           stdin=subprocess.DEVNULL, timeout=30)
        git_dir = (r.stdout.splitlines() + [""])[0] if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        git_dir = ""  # not a repo, or no git: no cloud copy to find
    cloud = os.path.join(git_dir or "<git-dir>", "nousfx-gate", "current", "hooks", "review-gate.py")
    paths = ([(installed, "installed")] if home else []) + ([(cloud, "cloud")] if git_dir else [])
    roots = [os.path.normpath(os.path.join(os.path.dirname(me), "..", "..", ".."))
             for me in (os.path.abspath(__file__), os.path.realpath(__file__))]
    if all(os.path.basename(root) == "claude" for root in roots):
        # normpath, so the `..` steps are taken in the path as written: the OS would walk them through a symlink
        paths += [(os.path.join(root, "hooks", "review-gate.py"), "checkout") for root in roots]
    return paths, (installed, cloud)


def find_gate(cwd):
    """The first gate in gate_paths() that exists, as (path, kind). None found: refuse, naming the trusted paths."""
    paths, (installed, cloud) = gate_paths(cwd)
    found = next(((p, kind) for p, kind in paths if os.path.isfile(p)), None)
    if found is None:
        raise Refused(f"no trusted review gate: looked for {installed} and {cloud}. The repo's own "
                      ".claude/hooks/review-gate.py is never loaded: it is code under review. Re-run the NousFX sync "
                      "(in a cloud session, any Bash call lets the project hook extract the default branch's gate)")
    return found


def too_old_hint(kind):
    if kind == "cloud":
        return "the default branch's gate is older than this script; merge the gate change first"
    return "re-run the sync"


def load_gate(cwd=None):
    """The trusted review gate module (gate_paths). A gate that exists but cannot load, or lacks the proof stamp,
    refuses: the next candidate is never tried."""
    path, kind = find_gate(cwd or os.getcwd())
    spec = importlib.util.spec_from_file_location("review_gate_for_prove", path)
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as e:
        raise Refused(f"cannot load {path}: {e}") from None
    if not hasattr(module, "PROOF_STAMP_FILE"):
        raise Refused(f"{path} is too old for prove.py (no proof stamp); {too_old_hint(kind)}")
    return module


def read_text(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8")
    except (OSError, UnicodeDecodeError) as e:
        raise Refused(f"cannot read the proof list {path}: {e}") from None


def parse(text):
    """(proofs, problems): the one parser `run`, `attest` and `lint` share (NFX-208). A proof is ("command", text) or
    ("manual", text), in file order; a problem is "line N: why" for a `Proof:` line that is neither."""
    proofs, problems = [], []
    for number, line in enumerate(text.splitlines(), 1):
        m = PROOF_LINE.search(line)
        if not m:
            continue
        rest = m.group(1)
        if rest.startswith(MANUAL):
            step = rest[len(MANUAL):].strip()
            parts = BACKUP.split(" " + step)
            if not parts[0].strip():
                problems.append(f"line {number}: `Proof: manual:` names no step")
            elif len(parts) > 2 or (len(parts) == 2 and not parts[1].strip()):
                problems.append(f"line {number}: a manual proof takes one `Backup:` that names the backup proof")
            else:
                proofs.append(("manual", step))
            continue
        c = COMMAND.fullmatch(rest)
        if not c or not c.group(1).strip():
            problems.append(f"line {number}: a Proof must be `command` or manual: <step>, got: {rest or '(nothing)'}")
            continue
        proofs.append(("command", c.group(1).strip()))
    return proofs, problems


def read_list(path):
    """(proofs, sha): the list is read once, and the hash comes from the proofs parsed from that read.
    Refused at the first problem, or when there is no command proof to run."""
    proofs, problems = parse(read_text(path))
    if problems:
        raise Refused(problems[0])
    if not any(kind == "command" for kind, _ in proofs):
        raise Refused("the list has no `command` proof, so there is nothing to run")
    return proofs, proofs_sha(proofs)


def split(proofs):
    """(commands, manual): the texts of the command proofs and of the manual ones."""
    return ([t for kind, t in proofs if kind == "command"], [t for kind, t in proofs if kind == "manual"])


def proofs_sha(proofs):
    """Hash of the normalized, ordered proofs: the wording around them can change, a proof cannot."""
    body = "\n".join(f"{kind}:{text}" for kind, text in proofs)
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def prepare(gate, cwd):
    """(branch, tree) for a repo on a branch, else Refused."""
    try:
        branch = gate.current_branch(cwd)
        if branch == "HEAD":
            raise Refused("HEAD is detached, and a proof stamp covers only the branch it was recorded on")
        return branch, gate.worktree_tree(cwd)
    except Refused:
        raise
    except Exception as e:
        raise Refused(f"cannot read the repo here: {e}") from None


def reusable_check(gate, cwd, tree, branch):
    """The trusted [check] command when a valid `run-check --stamp` stamp matches this tree, branch and check, else
    None (NFX-218). The match is --mark's own: the gate's trusted_check, stamp_fields and valid_stamp. Read once,
    before any proof runs, since a proof is branch code. Anything missing or failing (a gate that predates
    stamp_fields, no git_refs.py next to it, no [check]) means None: the proof runs as before. The stamp is left in
    place for --mark."""
    try:
        check, _ = gate.trusted_check(cwd)
        if check and gate.valid_stamp(cwd, gate.stamp_fields(tree, branch, check), gate.STAMP_FILE):
            return check["command"]
    except Exception:
        pass
    return None


def run(args):
    cwd = os.getcwd()
    gate = load_gate()
    name = gate.PROOF_STAMP_FILE
    try:
        gate.remove_stamp(cwd, name)  # first: any refusal below must not leave an older stamp behind
    except Exception as e:
        raise Refused(f"cannot prepare the proofs: {e}") from None
    if args.timeout < 1:
        raise Refused("--timeout must be at least 1 second")
    proofs, sha = read_list(args.list)
    branch, tree = prepare(gate, cwd)
    try:
        key = gate.stamp_key(cwd)  # before the run, so a key a proof replaces never signs the stamp
    except Exception as e:
        raise Refused(f"cannot read the stamp key: {e}") from None
    commands, manual = split(proofs)
    stamped = reusable_check(gate, cwd, tree, branch)
    try:
        for i, command in enumerate(commands, 1):
            print(f"Proof {i}/{len(commands)}: {command}", flush=True)
            if command == stamped:
                print(f"proof {i}: reused check stamp {tree[:10]}", flush=True)
                continue
            check = {"command": command, "timeout": args.timeout, "source": "proof list"}
            ok, why = gate.run_verified(cwd, check, tree)
            if not ok:
                gate.remove_stamp(cwd, name)
                raise Refused(f"proof {i} ({command}) {why}. No stamp recorded.")
        gate.remove_stamp(cwd, name)  # a proof is branch code: it may have written a stamp itself
        fields = {"kind": KIND, "tree": tree, "branch": branch, "list_sha": sha, "passed": len(commands),
                  "total": len(commands), "manual": len(manual), "exit": 0,
                  "time": time.strftime("%Y-%m-%dT%H:%M:%S")}
        gate.write_stamp(cwd, fields, key, name)
    except Refused:
        raise
    except Exception as e:
        with contextlib.suppress(Exception):
            gate.remove_stamp(cwd, name)
        raise Refused(f"the proofs could not finish: {e}. No stamp recorded.") from None
    note = f", {len(manual)} manual not run" if manual else ""
    print(f"{len(commands)}/{len(commands)} proofs passed{note}. Stamp recorded for tree {tree[:10]}: "
          "`prove.py attest` prints the AC-Proof line until a file or the list changes.")
    return 0


def attest(args):
    cwd = os.getcwd()
    gate = load_gate()
    proofs, sha = read_list(args.list)
    branch, tree = prepare(gate, cwd)
    stamp = gate.valid_stamp(cwd, {"kind": KIND, "tree": tree, "branch": branch, "list_sha": sha},
                             gate.PROOF_STAMP_FILE)
    if not stamp:
        raise Refused("no valid proof stamp for this tree, branch and proof list; run `prove.py run` again")
    commands, manual = split(proofs)
    if not (stamp.get("passed") == stamp.get("total") == len(commands) > 0) or stamp.get("manual") != len(manual):
        raise Refused("the proof stamp does not match the list; run `prove.py run` again")
    print(f"AC-Proof: {len(commands)}/{len(commands)} manual:{len(manual)} {tree} {sha}")
    for text in commands:
        print(f"  proof: {text}")
    for text in manual:
        step, *backup = BACKUP.split(text, 1)
        print(f"  manual: {step} (not run)")
        if backup:
            print(f"    backup: {backup[0]}")
    return 0


def lint(args):
    """Every `Proof:` line `run` would refuse, before any code exists (NFX-208). Needs no repo and runs nothing.
    A list with no command proof passes: a ticket whose proofs are all manual is valid."""
    proofs, problems = parse(read_text(args.list))
    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} Proof: line(s) prove.py cannot read; write each as `command` or manual: <step>",
              file=sys.stderr)
        return 2
    print(f"{len(proofs)} Proof: line(s) OK")
    return 0


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):  # ticket text echoed to a cp1252 pipe on Windows must not crash lint
        with contextlib.suppress(AttributeError, ValueError):
            stream.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(prog="prove.py", description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("run", help="run the proofs and write the stamp")
    p.add_argument("list")
    p.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="seconds per proof (default 600)")
    p.set_defaults(fn=run)
    p = sub.add_parser("attest", help="print the AC-Proof line for a valid stamp")
    p.add_argument("list")
    p.set_defaults(fn=attest)
    p = sub.add_parser("lint", help="list the Proof: lines run would refuse; runs nothing")
    p.add_argument("list")
    p.set_defaults(fn=lint)
    args = parser.parse_args(argv)
    try:
        return args.fn(args)
    except Refused as e:
        return fail(e)


if __name__ == "__main__":
    sys.exit(main())
