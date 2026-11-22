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
    yes            the restored run failed and named a failing test, or could not import  exit 0
                   an added production module (`failing: import <path>`)
    no             the restored run passed: the tests do not cover the change             exit 1
    build          the restored run failed and named nothing (build or import error)      exit 1
    baseline-fail  the check fails with the change, so nothing can be concluded            exit 1
    n/a            no production file or no test file changed                              exit 0
Exit 2 prints a reason to stderr and nothing to stdout (timeout, detached HEAD, no check command, tree changed).
NFX-222: a Python import error naming a .py file the change added splits by who else names that module. When a file
that is not a test (docs count) names it, it is production, and the verdict is `yes`. When only tests name it, it is a
helper: a note says to list it in `[check] tests`. A `build` also lists `  suite: <name>` for each failing suite the
log names. These notes go in the stamp, so `attest` prints them too.
The check, its timeout and its two optional keys come from `[check]` in .nousfx/project.toml, read where the gate
reads it (the default branch's copy when it has one):
    tests = ["glob", ...]       test files; default is test_*, *_test.*, or a tests/ folder
    failure_pattern = "regex"   matched per line against the restored run's output; group 1 (or the whole match) is a
                                failing test's name; default covers unittest, pytest, go, cargo and Gradle

A finished run writes a signed stamp in the git dir (claude-testfail-pass) binding tree, branch, base, check and
config. `attest` never runs anything: it prints the same line, with run's exit code, for a stamp that matches the
current tree, else exits 2.
Both clone runs hold one machine-wide suite slot, taken after the clone (NFX-217; rules in suite_slot.py).
The gate is the one --mark runs, never a project's own .claude/hooks copy (NFX-214; gate_paths).
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
# Python's import errors, found anywhere in a line (pytest prefixes them with "E   "): the missing module, or the name
# a `from pkg import n` could not find, read as the module pkg.n (NFX-222).
IMPORT_ERROR = re.compile(r"ModuleNotFoundError: No module named '([\w.]+)'"
                          r"|ImportError: cannot import name '(\w+)' from '([\w.]+)'")
RUN_CHECKS_SUITE_FAILED = r"^FAIL (\S+) \(\d+s\)$"
UNITTEST_MODULE_UNLOADABLE = r"^ERROR: \S+ \(unittest\.loader\._FailedTest\.(\S+)\)$"
PYTEST_COLLECTION_ERROR = r"ERROR collecting (\S+)"
SUITE_LINE = re.compile("|".join([RUN_CHECKS_SUITE_FAILED, UNITTEST_MODULE_UNLOADABLE, PYTEST_COLLECTION_ERROR]), re.M)
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
    """The trusted review gate module (gate_paths), from the real repo, never the clone. A gate that exists but cannot
    load, or lacks a name this script needs, refuses: the next candidate is never tried. The gate puts its own folder
    first on sys.path when it loads, and its `import git_refs` runs later, so sys.path is not restored."""
    path, kind = find_gate(cwd or os.getcwd())
    spec = importlib.util.spec_from_file_location("review_gate_for_testfail", path)
    module = importlib.util.module_from_spec(spec)
    with refusing(f"cannot load {path}"):
        spec.loader.exec_module(module)
    for name in ("trusted_check", "run_check", "write_stamp", "valid_stamp", "TESTFAIL_STAMP_FILE", "worktree_tree"):
        if not hasattr(module, name):
            raise Refused(f"{path} is too old for testfail.py ({name} missing); {too_old_hint(kind)}")
    return module


def load_tier():
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    with refusing("cannot load tier.py next to testfail.py"):
        import tier
    return tier


def suite_slot_hold():
    """The machine-wide suite slot (NFX-217), or no limit with a note when suite_slot.py is not next to this file."""
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    try:
        import suite_slot
    except Exception as e:
        print(f"note: no suite slot limit: cannot load suite_slot.py next to testfail.py ({e})", file=sys.stderr)
        return contextlib.nullcontext()
    return suite_slot.hold()


def git(args, cwd, extra=None, ok=(0,)):
    """git's stdout, run in `cwd` with `extra` added to the environment; an exit code outside `ok` refuses. GIT_DIR and the like are dropped, so a
    command meant for the clone never reaches the real repo. GIT_OPTIONAL_LOCKS=0 keeps `git diff` and friends from
    refreshing (writing) the real index, and GIT_LITERAL_PATHSPECS=1 keeps `a[b].py` from matching `ab.py`."""
    env = {k: v for k, v in os.environ.items() if k not in GIT_ENV_VARS}
    env.update(extra or {}, GIT_OPTIONAL_LOCKS="0", GIT_LITERAL_PATHSPECS="1")
    r = subprocess.run(["git", *args], cwd=cwd, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if r.returncode not in ok:
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
        tree = gate.worktree_tree(top)  # the gate's own hash (NFX-207), so the gate can reproduce the stamp tree
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


def failing_names(output, pattern, limit=MAX_NAMED):
    """Up to `limit` distinct names the pattern finds in the log text: the first group that matched, else the match."""
    named = {}
    for m in pattern.finditer(output):
        name = next((g for g in m.groups() if g), None) if m.groups() else m.group(0)
        if name:
            named[name] = None
            if len(named) == limit:
                break
    return list(named)


def read_log(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def unique(items):
    return list(dict.fromkeys(items))


def new_in(restored, passing):
    """The restored run's names that the passing run did not also print: those are noise, not what the restore broke."""
    noise = set(passing)
    return [n for n in restored if n not in noise]


def missing_modules(text):
    """The modules the log's import errors name, in log order."""
    return unique(m.group(1) or f"{m.group(3)}.{m.group(2)}" for m in IMPORT_ERROR.finditer(text))


def added_files_for(module, added):
    """The added .py files that are `module`: a/b.py or a/b/__init__.py for a.b, or any file under a/b/, since Python
    names an added package by its first missing part. By name only: no match means no claim."""
    rel = "/" + module.replace(".", "/")
    hits = []
    for p in added:
        q = "/" + p.replace("\\", "/")
        if q.endswith(".py") and (q.endswith(rel + ".py") or q.endswith(rel + "/__init__.py") or rel + "/" in q):
            hits.append(p)
    return hits


def mentioned_outside_tests(tier, s, module, matched):
    """True when a tracked or untracked file that is not a test, not generated and not one of the `matched` added
    files names the last part of `module` (the name the import error gave) as a word. Docs count. git grep skips
    binary and ignored files."""
    word = module.rsplit(".", 1)[-1]
    hits = git(["grep", "--untracked", "-I", "-l", "-z", "-w", "-F", "-e", word, "--"], s.top, ok=(0, 1))
    return any(p not in matched and not is_test(p, s.globs) and not tier.is_ignored(p) for p in paths_z(hits))


def import_causes(s, added, passing, restored):
    """(production, helpers): the added files the restored run could not import, split by whether anything but the
    tests names the module the import error gave (NFX-222). The files one module matches go together: a submodule of an
    added package is production when the package is."""
    groups = {m: added_files_for(m, added) for m in new_in(missing_modules(restored), missing_modules(passing))}
    matched = set(p for group in groups.values() for p in group)
    if not matched:
        return [], []
    tier = load_tier()
    production = unique(p for m, group in groups.items() if group and mentioned_outside_tests(tier, s, m, matched)
                        for p in group)
    return production, unique(p for group in groups.values() for p in group if p not in production)


def failing_suites(passing, restored):
    """Up to MAX_NAMED failing suites or test modules the restored log names and the passing log does not."""
    def suites(text):
        return unique(next(g for g in m.groups() if g) for m in SUITE_LINE.finditer(text))
    return new_in(suites(restored), suites(passing))[:MAX_NAMED]


def verdict_from_logs(s, added, log1, log2):
    """(verdict, named, notes) for a restored run that failed: `yes` when it named a failing test or could not import
    an added production module, else `build`. notes name added helpers the run could not import (with the
    [check] tests fix) and, for `build`, the failing suites."""
    passing, restored = read_log(log1), read_log(log2)
    tests = new_in(failing_names(restored, s.pattern, limit=None), failing_names(passing, s.pattern, limit=None))
    production, helpers = import_causes(s, added, passing, restored)
    named = ([f"import {p}" for p in production] + tests)[:MAX_NAMED]
    notes = [f"added helper {p} could not be imported: it is not a test file, so the restored run removed it. "
             f"List it in [check] tests of .nousfx/project.toml (or name it like a test)" for p in helpers]
    if not named:
        notes += [f"suite: {n}" for n in failing_suites(passing, restored)]
    return ("yes" if named else "build"), named, notes


def run_in_copy(gate, s, restore):
    """(verdict, named, log tail, notes) from the two runs in a temporary clone, which is always removed."""
    scratch = tempfile.mkdtemp(prefix="testfail-")
    copy = os.path.join(scratch, "repo")
    log1, log2 = os.path.join(scratch, "with-change.log"), os.path.join(scratch, "restored.log")
    nohooks = os.path.join(scratch, "no-hooks")
    os.mkdir(nohooks)
    # The user's global core.hooksPath would run its hooks on the clone's checkout; point it at an empty folder.
    quiet = {"GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "core.hooksPath", "GIT_CONFIG_VALUE_0": nohooks}
    slot = contextlib.ExitStack()
    try:
        head = git(["rev-parse", "HEAD"], s.top).strip()
        git(["clone", "-q", "--shared", "--no-checkout", s.top, copy], scratch, quiet)
        git(["checkout", "-q", "-B", s.branch, head], copy, quiet)
        git(["read-tree", "--reset", "-u", s.tree], copy, quiet)
        slot.enter_context(suite_slot_hold())  # one slot for both runs, so a verdict never queues twice
        ok, why = gate.run_check(copy, s.check, log1)
        if not ok:
            if why.startswith("did not finish"):
                raise Refused(f"the check with the change {why}; a timeout is never a pass. No stamp recorded.")
            return "baseline-fail", [], tail(log1), []
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
            return "no", [], "", []
        if why.startswith("did not finish"):
            raise Refused(f"the restored check {why}; a timeout is never a pass. No stamp recorded.")
        verdict, named, notes = verdict_from_logs(s, added, log1, log2)
        return verdict, named, ("" if verdict == "yes" else tail(log2)), notes
    finally:
        slot.close()
        shutil.rmtree(scratch, ignore_errors=True)


def line(verdict, tree, base):
    return f"Tests-Fail-Without: {verdict} {tree} base:{base}"


def report(verdict, tree, base, named, notes):
    """What run and attest both print: the verdict line, then the failing names and the notes (NFX-222)."""
    print(line(verdict, tree, base))
    for name in named:
        print(f"  failing: {name}")
    for note in notes:
        print(f"  {note}")


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
            verdict, named, detail, notes = run_in_copy(gate, s, restore)
    else:
        verdict, named, detail, notes = "n/a", [], "", []
    with refusing("cannot hash the working tree"):
        after = gate.worktree_tree(s.top)
    if after != s.tree:
        moved = git(["diff-tree", "-r", "--name-only", s.tree, after], s.top).split()
        raise Refused(f"the working tree changed during the run ({', '.join(moved[:5]) or 'unknown'}); "
                      "nothing was recorded. Run again.")
    with refusing("cannot write the test-fail stamp"):
        gate.write_stamp(s.top, {**s.fields, "verdict": verdict, "named": named, "notes": notes, "exit": 0,
                                 "time": time.strftime("%Y-%m-%dT%H:%M:%S")}, key, gate.TESTFAIL_STAMP_FILE)
    report(verdict, s.tree, s.base, named, notes)
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
    report(stamp["verdict"], s.tree, s.base, stamp.get("named", []), stamp.get("notes", []))
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
