#!/usr/bin/env python3
"""Check that the tests a change adds fail without the change, and stamp the verdict (NFX-190).

Python 3.11+, standard library only; runs the same on macOS and Windows.

    python3 -B testfail.py run [--base HASH]
    python3 -B testfail.py attest [--base HASH]

`run` splits the diff against the base (default: the merge base review-loop uses) into test files and production files,
copies the working tree into a temporary git clone outside the repo, and runs the project's check command there twice:
with the change (it must pass), then with every changed file that is not a test restored to the base (docs too;
files the change added are deleted), so only the changed tests differ from the base. A name the passing run also
printed does not count. It prints
    Tests-Fail-Without: <verdict> <tree> base:<hash>
and, for `yes`, one `  failing: <name>` line per failing test. Verdicts:
    yes            the restored run failed and named at least one failing test or suite   exit 0
    no             the restored run passed: the tests do not cover the change             exit 1
    build          the restored run failed and named nothing (build or import error)      exit 1
    baseline-fail  the check fails with the change, so nothing can be concluded            exit 1
    n/a            no production file or no test file changed                              exit 0
Exit 2 prints a reason to stderr and nothing to stdout (timeout, detached HEAD, no check command, tree changed).
The check, its timeout and its two optional keys come from `[check]` in .nousfx/project.toml, read where the gate
reads it (the default branch's copy when it has one):
    tests = ["glob", ...]       test files; default is test_*, *_test.*, or a tests/ folder
    failure_pattern = "regex"   matched per line against the restored run's output; group 1 (or the whole match) is a
                                failing test's name; default covers unittest, pytest, go, cargo and Gradle

A finished run writes a signed stamp in the git dir (claude-testfail-pass) binding tree, branch, base, check and
config. `attest` never runs anything: it prints the same line, with run's exit code, for a stamp that matches the
current tree, else exits 2.
The real working tree and index are never written; a run that finds the tree changed refuses. Same trust limits as
prove.py: see docs/review-gate.md.
"""
import argparse
import collections
import contextlib
import fnmatch
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
KIND = "testfail"
MAX_NAMED = 20
TAIL_LINES = 20
RESTORE_BATCH = 100  # paths per git command, so the command line stays short on Windows
DEFAULT_PATTERN = "|".join([
    r"^(?:FAIL|ERROR): (\S+ \((?!unittest\.loader)[^)]*\))",  # unittest; _FailedTest is an import error, not a test
    r"^FAILED (\S+::\S+)",                                    # pytest (not unittest's "FAILED (errors=1)")
    r"^--- FAIL: (\S+)",                                       # go
    r"^test (\S+) \.\.\. FAILED$",                             # cargo
    r"^(\S.* > \S.*) FAILED$",                                 # Gradle
])
GIT_ENV_VARS = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR")  # as the gate's run_check drops them
VERDICT_EXIT = {"yes": 0, "n/a": 0, "no": 1, "build": 1, "baseline-fail": 1}


class Refused(Exception):
    """A reason to stop with exit 2."""


def fail(message):
    print(f"Blocked: {message}", file=sys.stderr)
    return 2


@contextlib.contextmanager
def refusing(what):
    """Turn any error but a Refused into one that starts with `what`."""
    try:
        yield
    except Refused:
        raise
    except Exception as e:
        raise Refused(f"{what}: {e}") from None


def load_gate():
    """The review gate module next to this skill: the abspath first (the installed ~/.claude copy, whatever the
    skill folder links to), then the realpath (a repo checkout). Its folder joins sys.path for git_refs."""
    paths = []
    for me in (os.path.abspath(__file__), os.path.realpath(__file__)):
        paths.append(os.path.normpath(os.path.join(os.path.dirname(me), "..", "..", "..", "hooks", "review-gate.py")))
    path = next((p for p in paths if os.path.isfile(p)), None)
    if path is None:
        raise Refused("cannot find review-gate.py next to the skills folder; re-run the sync")
    folder = os.path.dirname(path)
    if folder not in sys.path:
        sys.path.insert(0, folder)
    spec = importlib.util.spec_from_file_location("review_gate_for_testfail", path)
    module = importlib.util.module_from_spec(spec)
    with refusing(f"cannot load {path}"):
        spec.loader.exec_module(module)
    for name in ("trusted_check", "run_check", "write_stamp", "valid_stamp", "TESTFAIL_STAMP_FILE"):
        if not hasattr(module, name):
            raise Refused(f"{os.path.normpath(path)} is too old for testfail.py ({name} missing); re-run the sync")
    return module


def load_tier():
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    with refusing("cannot load tier.py next to testfail.py"):
        import tier
    return tier


def git(args, cwd, extra=None):
    """git's stdout, run in `cwd` with `extra` added to the environment. GIT_DIR and the like are dropped, so a
    command meant for the clone never reaches the real repo. GIT_OPTIONAL_LOCKS=0 keeps `git diff` and friends from
    refreshing (writing) the real index, and GIT_LITERAL_PATHSPECS=1 keeps `a[b].py` from matching `ab.py`."""
    env = {k: v for k, v in os.environ.items() if k not in GIT_ENV_VARS}
    env.update(extra or {}, GIT_OPTIONAL_LOCKS="0", GIT_LITERAL_PATHSPECS="1")
    r = subprocess.run(["git", *args], cwd=cwd, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if r.returncode != 0:
        raise Refused(f"git {' '.join(args[:2])} failed: {r.stderr.strip() or r.stdout.strip()}")
    return r.stdout


def paths_z(text):
    return [p for p in text.split("\0") if p]


def read_config(gate, top, check):
    """(test globs or None, compiled failure pattern) from the same [check] table the command came from."""
    with refusing(f"cannot read [check] in {gate.CHECK_FILE}"):
        if check["source"] == "working tree":
            with open(os.path.join(top, gate.CHECK_FILE), encoding="utf-8") as f:
                text = f.read()
        else:
            text = git(["show", f"{check['source']}:{gate.CHECK_FILE}"], top)
        table = gate.tomllib.loads(text).get("check", {})
    globs = table.get("tests")
    if globs is not None and not (isinstance(globs, list) and globs and all(isinstance(g, str) for g in globs)):
        raise Refused("[check] tests must be a non-empty list of glob strings")
    pattern = table.get("failure_pattern", DEFAULT_PATTERN)
    if not isinstance(pattern, str) or not pattern:
        raise Refused("[check] failure_pattern must be a regular expression string")
    try:
        compiled = re.compile(pattern, re.M)
    except re.error as e:
        raise Refused(f"[check] failure_pattern is not a valid regular expression: {e}") from None
    return globs, compiled


def is_test(path, globs):
    p = path.replace("\\", "/")
    name = p.rsplit("/", 1)[-1]
    if globs:
        return any(fnmatch.fnmatch(p, g) or fnmatch.fnmatch(name, g) for g in globs)
    return name.startswith("test_") or fnmatch.fnmatch(name, "*_test.*") or "tests" in p.split("/")[:-1]


def split(tier, top, base, globs):
    """(tests, production, restore). tests: changed test files that still exist. production: changed code files
    (docs and generated files are neither); they decide n/a. restore: every changed file that is not a test, docs and
    generated files included, so the second run is exactly the base plus the changed tests. Changed means different
    from the base in the working tree, untracked files included."""
    files = set(paths_z(git(["diff", "--name-only", "--no-renames", "-z", base, "--"], top)))
    files |= set(paths_z(git(["ls-files", "--others", "--exclude-standard", "-z"], top)))
    files = sorted(files)
    test_like = {p for p in files if is_test(p, globs) and not tier.is_doc(p) and not tier.is_ignored(p)}
    tests = [p for p in files if p in test_like and os.path.lexists(os.path.join(top, p))]
    production = [p for p in files if p not in test_like and not tier.is_doc(p) and not tier.is_ignored(p)]
    restore = [p for p in files if p not in test_like]
    return tests, production, restore


def worktree_tree(cwd):
    """Tree hash of the working tree from a fresh temporary index, so every file is hashed again. A copy of the real
    index keeps its stat data, and a same-size edit made right after a commit can look unchanged there (git's stat
    shortcut); a verdict must not rest on that. The gate's worktree_tree (NFX-198) seeds from the real index
    instead, so the two differ when the index holds staged ignored paths or skip-worktree bits."""
    fd, tmp = tempfile.mkstemp(prefix="testfail-index-")
    os.close(fd)
    os.remove(tmp)  # git creates it
    try:
        # Seed from HEAD so tracked files that match .gitignore stay in; read-tree keeps no stat data, so add -A still
        # hashes every file again.
        git(["read-tree", "HEAD"], cwd, {"GIT_INDEX_FILE": tmp})
        git(["add", "-A"], cwd, {"GIT_INDEX_FILE": tmp})
        return git(["write-tree"], cwd, {"GIT_INDEX_FILE": tmp}).strip()
    finally:
        for path in (tmp, tmp + ".lock"):
            with contextlib.suppress(OSError):
                os.remove(path)


Setup = collections.namedtuple("Setup", "top check globs pattern base branch tree fields")


def setup(gate, base):
    """What run and attest share. `fields` are the stamp fields both must agree on."""
    tier = load_tier()
    with refusing("cannot read the repo here"):
        top = git(["rev-parse", "--show-toplevel"], os.getcwd()).strip()
    with refusing("cannot read the check command"):
        check, _ = gate.trusted_check(top)
    if not check:
        raise Refused(f"no [check] command in {gate.CHECK_FILE}; the test-fail check runs the project's check")
    globs, pattern = read_config(gate, top, check)
    try:
        base = git(["rev-parse", "--verify", "--quiet", f"{base or tier.merge_base(top)}^{{commit}}"], top).strip()
    except Exception:  # a Refused from git too: the hint below is the useful part
        raise Refused(f"cannot find the base commit {base or '(merge base)'}; pass --base <hash>") from None
    with refusing("cannot read the repo here"):
        branch = gate.current_branch(top)
        if branch == "HEAD":
            raise Refused("HEAD is detached, and a test-fail stamp covers only the branch it was recorded on")
        tree = worktree_tree(top)
    config = json.dumps([check["command"], check["timeout"], globs, pattern.pattern], sort_keys=True)
    fields = {"kind": KIND, "tree": tree, "branch": branch, "base": base, "command": check["command"],
              "source": check["source"], "timeout": check["timeout"],
              "config_sha": hashlib.sha256(config.encode("utf-8")).hexdigest()}
    return tier, Setup(top, check, globs, pattern, base, branch, tree, fields)


def tail(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return "".join(collections.deque(f, maxlen=TAIL_LINES))
    except OSError:
        return ""


def failing_names(path, pattern, limit=MAX_NAMED):
    """Up to `limit` distinct names the pattern finds in the log: the first group that matched, else the match."""
    with open(path, encoding="utf-8", errors="replace") as f:
        output = f.read()
    named = {}
    for m in pattern.finditer(output):
        name = next((g for g in m.groups() if g), None) if m.groups() else m.group(0)
        if name:
            named[name] = None
            if len(named) == limit:
                break
    return list(named)


def run_in_copy(gate, s, restore):
    """(verdict, named, log tail) from the two runs in a temporary clone, which is always removed."""
    scratch = tempfile.mkdtemp(prefix="testfail-")
    copy = os.path.join(scratch, "repo")
    log1, log2 = os.path.join(scratch, "with-change.log"), os.path.join(scratch, "restored.log")
    nohooks = os.path.join(scratch, "no-hooks")
    os.mkdir(nohooks)
    # The user's global core.hooksPath would run its hooks on the clone's checkout; point it at an empty folder.
    quiet = {"GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "core.hooksPath", "GIT_CONFIG_VALUE_0": nohooks}
    try:
        head = git(["rev-parse", "HEAD"], s.top).strip()
        git(["clone", "-q", "--shared", "--no-checkout", s.top, copy], scratch, quiet)
        git(["checkout", "-q", "-B", s.branch, head], copy, quiet)
        git(["read-tree", "--reset", "-u", s.tree], copy, quiet)
        ok, why = gate.run_check(copy, s.check, log1)
        if not ok:
            if why.startswith("did not finish"):
                raise Refused(f"the check with the change {why}; a timeout is never a pass. No stamp recorded.")
            return "baseline-fail", [], tail(log1)
        in_base = set(paths_z(git(["ls-tree", "-r", "-z", "--name-only", s.base], copy)))
        # Remove the added files first, then check out the base ones: safe for a file turned into a folder (or back)
        # and for a case-only rename on a case-insensitive disk.
        added = [p for p in restore if p not in in_base]
        for i in range(0, len(added), RESTORE_BATCH):
            git(["rm", "-f", "-q", "--ignore-unmatch", "--", *added[i:i + RESTORE_BATCH]], copy, quiet)
        back = [p for p in restore if p in in_base]
        for i in range(0, len(back), RESTORE_BATCH):
            git(["checkout", s.base, "--", *back[i:i + RESTORE_BATCH]], copy, quiet)
        ok, why = gate.run_check(copy, s.check, log2)
        if ok:
            return "no", [], ""
        if why.startswith("did not finish"):
            raise Refused(f"the restored check {why}; a timeout is never a pass. No stamp recorded.")
        # A name the passing run also printed is noise, not a test that the restore broke.
        noise = set(failing_names(log1, s.pattern, limit=None))
        named = [n for n in failing_names(log2, s.pattern, limit=None) if n not in noise][:MAX_NAMED]
        return ("yes", named, "") if named else ("build", [], tail(log2))
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def line(verdict, tree, base):
    return f"Tests-Fail-Without: {verdict} {tree} base:{base}"


def run(args):
    gate = load_gate()
    with refusing("cannot prepare the test-fail check"):
        gate.remove_stamp(os.getcwd(), gate.TESTFAIL_STAMP_FILE)  # first: no refusal may leave an older stamp behind
    tier, s = setup(gate, args.base)
    with refusing("cannot read the stamp key"):
        key = gate.stamp_key(s.top)
    tests, production, restore = split(tier, s.top, s.base, s.globs)
    if tests and production:
        with refusing("the test-fail run stopped; nothing was recorded"):
            verdict, named, detail = run_in_copy(gate, s, restore)
    else:
        verdict, named, detail = "n/a", [], ""
    after = worktree_tree(s.top)
    if after != s.tree:
        moved = git(["diff-tree", "-r", "--name-only", s.tree, after], s.top).split()
        raise Refused(f"the working tree changed during the run ({', '.join(moved[:5]) or 'unknown'}); "
                      "nothing was recorded. Run again.")
    with refusing("cannot write the test-fail stamp"):
        gate.write_stamp(s.top, {**s.fields, "verdict": verdict, "named": named, "exit": 0,
                                 "time": time.strftime("%Y-%m-%dT%H:%M:%S")}, key, gate.TESTFAIL_STAMP_FILE)
    print(line(verdict, s.tree, s.base))
    for name in named:
        print(f"  failing: {name}")
    if verdict == "n/a" and production:
        print("  production files changed, but no changed file matched a test glob; if the tests are named another "
              "way, list them in [check] tests = [...]")
    elif verdict == "n/a":
        print("  no production file changed")
    if detail:
        print(detail.rstrip(), file=sys.stderr)
    return VERDICT_EXIT[verdict]


def attest(args):
    gate = load_gate()
    _, s = setup(gate, args.base)
    stamp = gate.valid_stamp(s.top, s.fields, gate.TESTFAIL_STAMP_FILE)
    if not stamp or stamp.get("verdict") not in VERDICT_EXIT:
        raise Refused("no valid test-fail stamp for this tree, branch, base and check; run `testfail.py run` again")
    print(line(stamp["verdict"], s.tree, s.base))
    for name in stamp.get("named", []):
        print(f"  failing: {name}")
    return VERDICT_EXIT[stamp["verdict"]]


def main(argv=None):
    parser = argparse.ArgumentParser(prog="testfail.py", description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    for name, fn, helptext in (("run", run, "run the check with and without the change, print the verdict"),
                               ("attest", attest, "print the verdict line for a valid stamp")):
        p = sub.add_parser(name, help=helptext)
        p.add_argument("--base", help="base commit (default: the merge base with the default branch)")
        p.set_defaults(fn=fn)
    args = parser.parse_args(argv)
    for name in GIT_ENV_VARS:  # the gate's helpers read os.environ too: all git calls find the repo from the folder
        os.environ.pop(name, None)
    try:
        return args.fn(args)
    except Refused as e:
        return fail(e)


if __name__ == "__main__":
    sys.exit(main())
