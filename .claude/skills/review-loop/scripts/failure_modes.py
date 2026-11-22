#!/usr/bin/env python3
"""Map each "Failure modes" bullet of a ticket to the test that covers it (NFX-201).

Python only, standard library only; runs the same on macOS and Windows. Needs no repo and runs nothing.

    python3 -B failure_modes.py list TICKET
    python3 -B failure_modes.py check TICKET TABLE

TICKET is the ticket text in Markdown. Its failure modes are the list items (`*`, `-`, `+`, `1.` or `1)`) under the
heading "Failure modes" (any level; a trailing `:` or `(note)` is ignored), up to the next heading of the same or a
higher level, outside code fences (closed only by the same marker, at least as long); an item may be indented one
space, and a line indented further, an item included, continues the item above it. A section with text but no list
item is refused, so prose never reads as "no failure modes". With no such heading the output says so, unless a line
still names failure modes (bold text, Jira wiki `h2.`, a longer heading): that is refused too, never a silent pass.
They are numbered FM1..FMn in file order.

`list` prints the table for the plan, one empty row per failure mode:
    | failure mode | test |
    |---|---|
    | FM1 <bullet text> | |

TABLE is a Markdown file holding that table filled in, such as the PR body. Only rows whose first cell starts with
FM<n> are read, so the proof table beside it is ignored. The last cell of a row is one of:
    `test name or command`   tested: only backticked, non-empty names (commas between several); prose is no test
    waived: <why>            a judgement call the PR explains; only an empty reason is refused, and the reviewer
                             judges whether the reason holds (as it judges whether a named test covers its row)

`check` prints one finding per failure mode with no row, a prose or empty cell, or a waiver with no reason:
    FM<n> | med | 80 | ticket:Failure modes | no covering test | <fix> | <bullet text, which may hold a |>
then the summary line
    Failure-Modes: <n> listed, <t> tested, <w> waived, <m> missing
Exit 0 with no finding, 1 with findings, 2 when a file cannot be read, the section has no list item, failure modes
are named without the heading, or a row names an unknown or repeated FM<n>
(the reason goes to stderr and nothing to stdout).
"""
import argparse
import collections
import contextlib
import re
import sys

HEADING = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
NOTE = re.compile(r"\s*\(.*\)$")
FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})(.*)$")
MENTION = re.compile(r"failure modes?\b", re.I)
BULLET = re.compile(r"^ ?(?:[*+-]|\d{1,9}[.)])\s+(.*\S)\s*$")
CONTINUED = re.compile(r"^\s+(\S.*?)\s*$")
CELL_SPLIT = re.compile(r"(?<!\\)\|")
ROW_ID = re.compile(r"^FM(\d+)\b")
TESTED = re.compile(r"^`[^`]*\S[^`]*`(?:[\s,;]+`[^`]*\S[^`]*`)*$")
WAIVED = re.compile(r"^waived:\s*(.*?)\s*$", re.I)
SECTION = "failure modes"


class Refused(Exception):
    """A reason to stop with exit 2."""


def read_text(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8-sig")
    except (OSError, UnicodeDecodeError) as e:
        raise Refused(f"cannot read {path}: {e}") from None


def failure_modes(text):
    """(modes, found): the list items of the first "Failure modes" section, in order, each joined onto one line, and
    whether that heading exists. Refused when the section has text but no list item, so prose never reads as none."""
    modes, level, found, text_seen, opener = [], 0, False, False, None
    lines = text.splitlines()
    for line in lines:
        fence = FENCE.match(line)
        fenced = bool(opener or fence)
        if opener is None:
            opener = fence.group(1) if fence else None
        elif fence and fence.group(1).startswith(opener) and opener[0] * len(fence.group(1)) == fence.group(1) \
                and not fence.group(2).strip():
            opener = None
        heading = None if fenced else HEADING.match(line)
        if heading:
            depth = len(heading.group(1))
            if level and depth <= level:
                break
            if not level and NOTE.sub("", heading.group(2)).rstrip(":").strip().lower() == SECTION:
                level, found = depth, True
            continue
        if not level:
            continue
        text_seen = text_seen or bool(line.strip())
        if fenced:
            continue
        bullet = BULLET.match(line)
        if bullet:
            modes.append(bullet.group(1))
            continue
        more = CONTINUED.match(line)
        if more and modes:
            modes[-1] += " " + more.group(1)
    if text_seen and not modes:
        raise Refused('the "Failure modes" section has text but no list item; write each failure mode as a bullet')
    if not found:
        named = next((n for n, line in enumerate(lines, 1) if MENTION.search(line)), None)
        if named:
            raise Refused(f'line {named}: names failure modes but is not a "Failure modes" Markdown heading; make it '
                          '`## Failure modes`, so its bullets are read')
    return modes, found


def cells(line):
    """The cells of a Markdown table row, trimmed, or None when the line is not a row. A closing pipe leaves a blank
    last piece, which is dropped."""
    line = line.strip()
    if not line.startswith("|"):
        return None
    parts = [p.strip() for p in CELL_SPLIT.split(line)[1:]]
    if parts and not parts[-1]:
        parts.pop()
    return parts or None


def table_rows(text, count):
    """{n: last cell} for each FM<n> row; refused on an FM<n> outside 1..count or one given twice."""
    rows = {}
    for number, line in enumerate(text.splitlines(), 1):
        row = cells(line)
        if not row:
            continue
        m = ROW_ID.match(row[0])
        if not m:
            continue
        n = int(m.group(1))
        if not 1 <= n <= count:
            raise Refused(f"line {number}: FM{n} names no failure mode (the ticket lists {count})")
        if n in rows:
            raise Refused(f"line {number}: FM{n} has a second row")
        rows[n] = row[-1] if len(row) > 1 else ""
    return rows


def verdict(cell):
    """"tested", "waived" or "missing" for a test cell (None: no row)."""
    if cell is None:
        return "missing"
    waived = WAIVED.match(cell)
    if waived:
        return "waived" if waived.group(1) else "missing"
    return "tested" if TESTED.search(cell) else "missing"


def escape(text):
    return text.replace("|", "\\|")


def do_list(args):
    modes, found = failure_modes(read_text(args.ticket))
    print("| failure mode | test |\n|---|---|")
    for n, mode in enumerate(modes, 1):
        print(f"| FM{n} {escape(mode)} |  |")
    if not found:
        print('(no "Failure modes" heading in the ticket, so no rows)')
    return 0


def do_check(args):
    modes, found = failure_modes(read_text(args.ticket))
    rows = table_rows(read_text(args.table), len(modes))
    counts = collections.Counter()
    lines = []
    for n, mode in enumerate(modes, 1):
        kind = verdict(rows.get(n))
        counts[kind] += 1
        if kind == "missing":
            lines.append(f"FM{n} | med | 80 | ticket:Failure modes | no covering test | add a test and fill its "
                         f"FM{n} row, or waived: <why> for a judgement call | {mode}")
    if not found:
        lines.append('Failure-Modes: 0 listed (no "Failure modes" heading)')
    else:
        lines.append(f"Failure-Modes: {len(modes)} listed, {counts['tested']} tested, {counts['waived']} waived, "
                     f"{counts['missing']} missing")
    print("\n".join(lines))
    return 1 if counts["missing"] else 0


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):  # ticket text echoed to a cp1252 pipe on Windows must not crash
        with contextlib.suppress(AttributeError, ValueError):
            stream.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(prog="failure_modes.py", description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("list", help="print the plan table, one row per failure mode")
    p.add_argument("ticket")
    p.set_defaults(fn=do_list)
    p = sub.add_parser("check", help="one med finding per failure mode with no test or stated waiver")
    p.add_argument("ticket")
    p.add_argument("table")
    p.set_defaults(fn=do_check)
    args = parser.parse_args(argv)
    try:
        return args.fn(args)
    except Refused as e:
        print(f"Blocked: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
