#!/usr/bin/env python3
"""Run a ticket's proofs, stamp them, and print an AC-Proof line (NFX-105).

Python only, standard library only; runs the same on macOS and Windows.

    python3 -B prove.py run LIST [--timeout SECONDS]
    python3 -B prove.py attest LIST

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

`run` stops at the first failing proof (exit 2, no stamp). When all pass, it writes a signed stamp in the git dir
(claude-proof-pass) that binds the working-tree hash, the branch and a hash of the normalized proofs. `attest`
never runs anything: it checks that stamp against the current tree and list, then prints
    AC-Proof: <passed>/<total> manual:<m> <tree> <sha of the proofs>
Exit 0 prints the line; exit 2 prints a reason to stderr and nothing to stdout.

Proofs are self-asserted. They come from a list the branch author controls and CI does not re-run them; see
docs/review-gate.md. The stamp helpers are the review gate's (claude/hooks/review-gate.py), found next to this
skill's folder, so the install layout ~/.claude/{hooks,skills} and the repo layout claude/{hooks,skills} both work.
"""
import argparse
import contextlib
import hashlib
import importlib.util
import os
import re
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


def load_gate():
    """The review gate module next to this skill: the abspath first (the installed ~/.claude copy, whatever the
    skill folder links to), then the realpath (a repo checkout)."""
    paths = []
    for me in (os.path.abspath(__file__), os.path.realpath(__file__)):
        # normpath, so the `..` steps are taken in the path as written: the OS would walk them through a symlink
        paths.append(os.path.normpath(os.path.join(os.path.dirname(me), "..", "..", "..", "hooks", "review-gate.py")))
    path = next((p for p in paths if os.path.isfile(p)), None)
    if path is None:
        raise Refused("cannot find review-gate.py next to the skills folder; re-run the sync")
    spec = importlib.util.spec_from_file_location("review_gate_for_prove", path)
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as e:
        raise Refused(f"cannot load {path}: {e}") from None
    if not hasattr(module, "PROOF_STAMP_FILE"):
        raise Refused(f"{os.path.normpath(path)} is too old for prove.py (no proof stamp); re-run the sync")
    return module


def read_list(path):
    """(proofs, sha): the list is read once, and the hash comes from the proofs parsed from that read.
    A proof is ("command", text) or ("manual", text), in file order."""
    try:
        with open(path, "rb") as f:
            data = f.read()
        text = data.decode("utf-8")
    except (OSError, UnicodeDecodeError) as e:
        raise Refused(f"cannot read the proof list {path}: {e}") from None
    proofs = []
    for number, line in enumerate(text.splitlines(), 1):
        m = PROOF_LINE.search(line)
        if not m:
            continue
        rest = m.group(1)
        if rest.startswith(MANUAL):
            step = rest[len(MANUAL):].strip()
            parts = BACKUP.split(" " + step)
            if not parts[0].strip():
                raise Refused(f"line {number}: `Proof: manual:` names no step")
            if len(parts) > 2 or (len(parts) == 2 and not parts[1].strip()):
                raise Refused(f"line {number}: a manual proof takes one `Backup:` that names the backup proof")
            proofs.append(("manual", step))
            continue
        c = COMMAND.fullmatch(rest)
        if not c or not c.group(1).strip():
            raise Refused(f"line {number}: a Proof must be `command` or manual: <step>, got: {rest or '(nothing)'}")
        proofs.append(("command", c.group(1).strip()))
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
    try:
        for i, command in enumerate(commands, 1):
            print(f"Proof {i}/{len(commands)}: {command}", flush=True)
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


def main(argv=None):
    parser = argparse.ArgumentParser(prog="prove.py", description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("run", help="run the proofs and write the stamp")
    p.add_argument("list")
    p.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="seconds per proof (default 600)")
    p.set_defaults(fn=run)
    p = sub.add_parser("attest", help="print the AC-Proof line for a valid stamp")
    p.add_argument("list")
    p.set_defaults(fn=attest)
    args = parser.parse_args(argv)
    try:
        return args.fn(args)
    except Refused as e:
        return fail(e)


if __name__ == "__main__":
    sys.exit(main())
