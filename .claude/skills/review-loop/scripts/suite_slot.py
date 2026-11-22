#!/usr/bin/env python3
"""A machine-wide slot for full test suites (NFX-217), so parallel sessions wait instead of piling up.

Python 3.11+, standard library only. Used by scripts/run_checks.py and testfail.py (around its clone runs):

    with suite_slot.hold():
        ...run the suite...

There are N slots, one lock file each, in <user cache>/nousfx/suite-slots (outside any repo; the home folder comes from
the system user record, not $HOME, so a suite that points HOME at a temp dir still shares the same slots):
N = max(1, CPUs // 4), so 3 on a 12-CPU Mac. A slot is an exclusive flock on its file. The kernel drops it when the
holder exits in any way, kill -9 included, so a dead holder's slot is free at once: no stale slot to reclaim, and no
race between two reclaimers. The file holds the holder's PID, for the nesting check below and for a person reading it.
While every slot is busy, hold() prints "waiting for a suite slot (k of N busy)" to stderr once, then every 5 minutes.

Nesting: the holder exports NOUSFX_SUITE_SLOT_HELD=<pid>:<slot file>. A process that inherits it, and finds that file
still naming a live PID, runs inside that slot without taking another. So testfail.py -> its check -> run_checks.py, or
run_checks.py -> a suite that starts run_checks.py, never waits on its own parent. A marker whose holder is gone counts
for nothing.

Environment: NOUSFX_SUITE_SLOTS=<n> overrides N (a value that is not a whole number of 1 or more falls back to the
default, with a note); NOUSFX_SUITE_SLOT_DIR=<dir> overrides the folder (tests use it).
No limit, with a one-line note: on Windows (no flock; it runs as before), or when the folder cannot be created.
"""
import contextlib
import os
import stat
import sys
import time

try:
    import fcntl
except ImportError:  # Windows
    fcntl = None

ENV_SLOTS = "NOUSFX_SUITE_SLOTS"
ENV_DIR = "NOUSFX_SUITE_SLOT_DIR"
ENV_HELD = "NOUSFX_SUITE_SLOT_HELD"
POLL = 0.5          # seconds between tries while every slot is busy
REPEAT = 300        # seconds between "still waiting" lines


def slot_count(env=None, out=None):
    """N from the environment, else max(1, CPUs // 4)."""
    env = os.environ if env is None else env
    default = max(1, (os.cpu_count() or 1) // 4)
    raw = env.get(ENV_SLOTS, "").strip()
    if not raw:
        return default
    try:
        n = int(raw)
    except ValueError:
        n = 0
    if n < 1:
        print(f"note: {ENV_SLOTS}={raw!r} is not a whole number of 1 or more; using {default} suite slots",
              file=out or sys.stderr)
        return default
    return n


def home_dir():
    try:
        import pwd
        return pwd.getpwuid(os.getuid()).pw_dir
    except (ImportError, KeyError):  # Windows has no pwd (and no limit); a user with no record falls back to $HOME
        return os.path.expanduser("~")


def slot_dir(env=None):
    env = os.environ if env is None else env
    if env.get(ENV_DIR):
        return env[ENV_DIR]
    if sys.platform == "darwin":
        base = os.path.join(home_dir(), "Library", "Caches")
    else:
        base = env.get("XDG_CACHE_HOME") or os.path.join(home_dir(), ".cache")
    return os.path.join(base, "nousfx", "suite-slots")


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:  # someone else's process: alive
        return True
    except OSError:
        return False
    return True


def held_by_parent(env=None):
    """True when the environment names a slot that a live process still holds (our parent, in practice)."""
    env = os.environ if env is None else env
    pid, _, path = env.get(ENV_HELD, "").partition(":")
    if not pid.isdigit() or not path:
        return False
    try:
        with open(path, encoding="ascii") as f:
            owner = f.read().strip()
    except (OSError, UnicodeDecodeError):
        return False
    return owner == pid and alive(int(pid))


def try_slot(directory, n):
    """(fd, path, busy): fd and path of a free slot, now locked by this process with our PID in it, or (None, None,
    busy) when all are taken; busy counts the slots another process holds."""
    busy = 0
    for i in range(n):
        path = os.path.join(directory, f"slot-{i}.lock")
        # Never through a symlink: the folder can come from the environment, and we truncate and write the file.
        # Not inherited by child processes (PEP 446).
        fd = os.open(path, os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            os.close(fd)
            raise OSError(f"{path} is not a regular file")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            os.close(fd)
            busy += 1
            continue
        os.ftruncate(fd, 0)
        os.write(fd, str(os.getpid()).encode("ascii"))
        return fd, path, busy
    return None, None, busy


def release(fd):
    try:
        os.ftruncate(fd, 0)
    except OSError:
        pass
    os.close(fd)  # closing the only descriptor drops the flock


@contextlib.contextmanager
def hold(out=None):
    """Hold one suite slot for the body; wait for one first if all N are busy."""
    out = out or sys.stderr
    if held_by_parent():
        yield
        return
    if fcntl is None:
        print("note: no suite slot limit on this platform (no flock); the suite runs at once", file=out)
        yield
        return
    n = slot_count(out=out)
    directory = slot_dir()

    def take():
        # The folder again on every try: a cache cleaner may remove it while we wait.
        os.makedirs(directory, mode=0o700, exist_ok=True)
        return try_slot(directory, n)

    start, said = time.monotonic(), None
    try:
        fd, path, busy = take()
        while fd is None:
            waited = time.monotonic() - start
            if said is None or waited - said >= REPEAT:
                more = f", {waited / 60:.0f} min so far" if said is not None else ""
                print(f"waiting for a suite slot ({busy} of {n} busy{more})", file=out, flush=True)
                said = waited
            time.sleep(POLL)
            fd, path, busy = take()
    except OSError as e:
        fd = None
        print(f"note: no suite slot limit: cannot use {directory} ({e})", file=out, flush=True)
    if fd is None:
        yield
        return
    if said is not None:
        print(f"got a suite slot after {time.monotonic() - start:.0f}s", file=out, flush=True)
    before = os.environ.get(ENV_HELD)
    os.environ[ENV_HELD] = f"{os.getpid()}:{path}"
    try:
        yield
    finally:
        if before is None:
            os.environ.pop(ENV_HELD, None)
        else:
            os.environ[ENV_HELD] = before
        release(fd)
