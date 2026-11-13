"""git_refs: which remote-tracking branch the gate and tier.py trust (NFX-108). One rule, two callers.

review-gate.py imports this file from its own folder; tier.py loads it by path (it is flat next to tier.py in CI and
in the cloud copy, and under ../../../hooks in the repo). Standard library only, and it imports nothing from either
caller. Both callers pass their own `git(args, cwd) -> str` that raises RuntimeError on failure.

Local state only, nothing is fetched. `origin/HEAD` is trusted as `git remote set-head origin -a` set it: a shell user
can move it, so CI (which names the PR base explicitly) is the control.
"""

ORIGIN = "refs/remotes/origin/"


def _resolves(git, cwd, ref, passthrough):
    """True when `ref` names a commit. An error in `passthrough` (a timeout) is raised, not read as 'missing'."""
    try:
        git(["rev-parse", "--verify", "--quiet", ref + "^{commit}"], cwd)
        return True
    except passthrough:
        raise
    except RuntimeError:
        return False


def default_ref(git, cwd, passthrough=()):
    """origin/HEAD (only when it points at another refs/remotes/origin/ ref), else origin/main, else origin/master,
    else None."""
    passthrough = tuple(passthrough)
    candidates = []
    try:
        target = git(["symbolic-ref", "-q", ORIGIN + "HEAD"], cwd)
        if target.startswith(ORIGIN) and target != ORIGIN + "HEAD":
            candidates.append(target)
    except passthrough:
        raise
    except RuntimeError:
        pass
    candidates += [ORIGIN + "main", ORIGIN + "master"]
    for ref in candidates:
        if _resolves(git, cwd, ref, passthrough):
            return ref
    return None


def branch_ref(git, cwd, branch, passthrough=()):
    """refs/remotes/origin/<branch>. ValueError for an empty name, one starting with '-', or one git rejects;
    RuntimeError when the ref is not a commit. It never falls back to origin/HEAD: a PR base that is missing
    locally must be seen, not replaced."""
    passthrough = tuple(passthrough)
    if not branch or branch.startswith("-"):
        raise ValueError("not a branch name: %r" % branch)
    try:
        git(["check-ref-format", "--branch", branch], cwd)
    except passthrough:
        raise
    except RuntimeError:
        raise ValueError("not a branch name: %r" % branch)
    ref = ORIGIN + branch
    if not _resolves(git, cwd, ref, passthrough):
        raise RuntimeError("origin/%s is not a commit here (fetch it first)" % branch)
    return ref
