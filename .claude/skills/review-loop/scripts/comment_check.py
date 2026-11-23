#!/usr/bin/env python3
"""List the comments a diff adds, so the reviewer can judge each one (NFX-196).

  comment_check.py <base>       flags in `git diff <base>` (the working tree) plus untracked files
  comment_check.py --keep-list  print the keep list
  comment_check.py --all PATH   inventory every comment under PATH (the delete-comments skill, NFX-228)
  comment_check.py verify [BASE]  prove that only comments changed since BASE (the delete-comments skill)

Prints one line per flag, `file:line kind text`, then `comment_check: N flags (kind n, ...)`.
Kinds: comment; banner (a section divider like `# --- gh ---`, a Tautology); docstring (on a private function or
class); test-docstring (on a `test_*` def or a `Test*` class's method in a test file: judged, not kept); suppression (a
lint suppression with no reason on its line); ticket-tag (a bare ticket key, history that git log holds: Stale);
ticket (a ticket key or issue link with too short a reason); guard ("do not remove" and the like).
Languages: Python, shell, Kotlin, Dart, TypeScript and JavaScript, by extension or a python/sh shebang. Other files,
Markdown included, are never read. A comment on the keep list (KEEP) is not printed. Only added lines count, and a
comment whose text the diff also removes was moved, not added.
Exit 0 when the check ran, with flags or without; 2 when git fails.

--all prints `file:line form verdict text` per comment, where form is docstring, inline (shares its line with code),
shell (a whole-line comment in a shell file) or line (any other whole-line or block comment), and verdict is
keep:<rule> or flag:<kind>. The last line counts each form, the kept items, and the lines that deleting the
non-kept docstring, line and shell items would shed. Files git ignores and generated files are skipped.

verify compares the working tree (untracked files included) with `git merge-base BASE HEAD` (with no BASE,
review-loop's base: origin/HEAD, else origin/main), prints that commit, then prints `file: difference` per problem: a
Python file whose AST, docstrings stripped, differs; in a file that reads __doc__, a changed module docstring or a
changed docstring of a def or class it reads as `name.__doc__` (any of them can be --help text; verify reads scripts
and never runs them); a symlink that changed or replaced a file; a changed file mode, in any language; a shell file
whose text outside comments differs (a heredoc is text), or that newly fails `bash -n` (`zsh -n` for a zsh file); a
changed shebang or encoding line; a Kotlin, Dart, TypeScript or JavaScript file whose tokens outside comments
differ, as `file:line code changed` (a line break and the space between two operators count; a JSX (.tsx, .jsx, .js)
`{/* note */}` child is a comment as a whole, so empty braces left behind are code, unless it parts two lines of JSX
text; JSX text between tags, quotes and `//` included, is text, never a comment or string; a bare trailing `//` in
Dart is a `dart format` marker and always code), or whose compiler directives changed (a `/// <reference>` line,
`@dart=`, a JSX pragma, `@ts-nocheck` and the like; the reason after a suppression may change); an added or deleted
file in any of these languages; an ADR-NNNN (or ADR NNNN) pointer in a changed file's comments with no
docs/adr/NNNN-*.md (in NousFX, under claude/ and plugins/ it must read `NousFX ADR-NNNN`; outside NousFX such a
pointer is not looked up). Other languages, and a Python file that did not parse at BASE, are left to the test
suite, and the OK line counts them. Exit 0 when only comments changed, 2 on any difference or when git fails.
KEEP, comments_in() and classify() are the one keep list for all three modes.
"""
import argparse
import ast
import difflib
import glob
import io
import os
import re
import shutil
import subprocess
import sys
import tokenize
from collections import Counter, namedtuple
from dataclasses import dataclass
from typing import Callable, Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tier  # noqa: E402 (a sibling script: its git() and untracked_files() are the safe, capped ones)

EXTENSIONS = {".py": "python", ".sh": "shell", ".bash": "shell", ".zsh": "shell",
              ".kt": "kotlin", ".kts": "kotlin", ".dart": "dart", ".ts": "js", ".tsx": "js", ".mts": "js", ".cts": "js",
              ".js": "js", ".jsx": "js", ".mjs": "js", ".cjs": "js"}
C_LIKE = ("kotlin", "dart", "js")


EVERY_LINE = None


@dataclass
class Comment:
    """One comment from `line` to `end` (1-based). `text` is as written, markers included; for an annotation, the
    whole line. `style`: line, block, doc (/** or ///), docstring or annotation (@Suppress in code). `target`, for a
    doc or docstring: module, public, private or test. `reads_doc`: the file reads __doc__. `path_import`: a
    module-level import after a `sys.path.insert` or `.append` (its `noqa: E402` has its reason above it)."""
    line: int
    end: int
    text: str
    style: str
    target: str = ""
    reads_doc: bool = False
    path_import: bool = False


@dataclass(frozen=True)
class KeepRule:
    """A keep-list item. With no `match`, the reviewer judges it: the script cannot."""
    name: str
    text: str
    match: Optional[Callable[[Comment], bool]]


CODING = re.compile(r"coding[:=]\s*[-\w.]+")
LICENSE = re.compile(r"(?i)SPDX-License-Identifier|copyright\s*(?:\(c\)|©)?\s*\d{4}|(?:\(c\)|©)\s*\d{4}"
                     r"|licensed under|all rights reserved")
FORMATTER = re.compile(r"(?i)\bfmt:\s*(?:off|on|skip)\b|prettier-ignore|isort:\s*(?:skip|off|on)|@formatter:(?:off|on)"
                       r"|dart format (?:off|on)|clang-format (?:off|on)|yapf:\s*(?:disable|enable)")
TICKET = re.compile(r"\b(?!(?:UTF|ISO|SHA|MD|RFC|AES|GPT|PEP|HTTP|TLS|SSL|CVE|ES|IPV|TCP|UDP|WCAG|ECMA|IEEE"
                    r"|POSIX|FIPS|RS|AVX|LATIN)-)[A-Z]{2,10}-\d+\b|https?://\S*/(?:issues?|browse|pull)/\S+")
GUARD = re.compile(r"(?i)\b(?:do not|don't|never)\s+(?:remove|delete|change|touch|edit|modify|move|reorder|rename)\b")
SUPPRESSION_AND_CODES = re.compile(
    r"(?i)\bnoqa\b(?::\s*[A-Z]+\d+(?:\s*,\s*[A-Z]+\d+)*)?"
    r"|\b(?:type|pyright|mypy):\s*ignore\b(?:\[[\w\-, ]*\])?"
    r"|\bpylint:\s*disable(?:-next)?=[\w\-]+(?:,[\w\-]+)*"
    r"|\beslint-disable(?:-next-line|-line)?\b(?:[ \t]+[@\w/\-]+(?:\s*,\s*[@\w/\-]+)*)?"
    r"|@ts-(?:ignore|expect-error|nocheck)\b"
    r"|(?:^|//)\s*ignore(?:_for_file)?:\s*(?:[a-z][a-z0-9]*_\w*(?:\s*,\s*[a-z]\w*_\w*)*"
    r"|[a-z]\w*(?:=\w+)?(?:\s*,\s*[a-z]\w*(?:=\w+)?)*(?=\s*(?:$|,|//|\s-)))"
    r"|\bshellcheck\s+disable=[\w,]+"
    r"|\bktlint-disable\b(?:[ \t]+[\w-]*[:-][\w:-]*)*"
    r"|\bbiome-ignore\b(?:[ \t]+[\w/]+)?"
    r"|@(?:file:)?Suppress(?:Warnings|Lint)?\s*\([^)]*\)?")
ANNOTATION = re.compile(r"@(?:file:)?Suppress(?:Warnings|Lint)?\s*\(")
ANNOTATION_SPAN = re.compile(r"@(?:file:)?Suppress(?:Warnings|Lint)?\s*\([^)]*\)")
HEREDOC = re.compile(r"<<(-|~)?\s*(['\"]?)([A-Za-z_]\w*)\2")
GENERATED = re.compile(r"(?i)@generated\b|\bgenerated (?:code|file)\b.*\bdo not (?:edit|modify)"
                       r"|\bcode generated\b.*\bdo not edit|\bauto-?generated\b.*\bdo not (?:edit|modify)"
                       r"|\bauto-?generated (?:file|code)\b|\bthis (?:file|code) (?:is|was) auto-?generated\b")
BANNER = re.compile(r"(?:#|//+)[ \t]*[-=*~#]{3,}(?:[ \t]+[\w.,/'()]+){0,4}(?:[ \t]+[-=*~#]+)?")
HISTORY_WORDS = {"moved", "added", "removed", "renamed", "fixed", "fix", "new", "the", "a", "an", "section"}
CONTRACT = re.compile(r"\b[Rr]aises?\s+[A-Z]\w+|(?:\b(?:None|True|False)|\{\}|\[\])\s+(?:when|if|unless|on)\b"
                      r"|\b[Rr]eturns?\b[^.\n]{0,200}?\b(?:when|if|unless)\b")
NEGATION = re.compile(r"(?i)\b(?:not|never|must|don't)\b")
E402 = re.compile(r"\bnoqa:\s*E402\s*$")
MARKERS = re.compile(r"^\s*(?:#!?|//+|/\*+|\*+/?|\"\"\"|''')|\*+/\s*$|\s--\s")


def words(text):
    return re.findall(r"[A-Za-z][A-Za-z'’]+", text)


def has_suppression(c):
    return bool(SUPPRESSION_AND_CODES.search(c.text))


def suppression_reason(c):
    """A suppression keeps its line only with two or more words besides the directive and the rule codes it takes."""
    return len(words(MARKERS.sub(" ", SUPPRESSION_AND_CODES.sub(" ", c.text)))) >= 2


def bare_ticket(c):
    """A comment that is a ticket key and nothing besides history words (`# NFX-100`, `# NFX-114: moved`): Stale,
    git log holds it. A docstring is never one: it documents a def, so it stays a ticket flag."""
    return c.style not in ("docstring", "doc") and bool(TICKET.search(c.text)) and not re.search(r"https?://", c.text) \
        and all(w.lower() in HISTORY_WORDS for w in words(TICKET.sub(" ", c.text)))


def ticket_reason(c):
    """A ticket key keeps a line only when the line also says why: four or more other words (NFX-196 comment). A
    test docstring is never kept this way: it is judged (NFX-240)."""
    return c.target != "test" and bool(TICKET.search(c.text)) and len(words(TICKET.sub(" ", c.text))) >= 4


# The keep list, in order: the first rule that matches keeps the comment. NFX-228 reuses it; change it only here.
KEEP = (
    KeepRule("shebang", "a shebang on line 1", lambda c: c.line == 1 and c.text.startswith("#!")),
    KeepRule("encoding", "an encoding line on line 1 or 2",
             lambda c: c.line <= 2 and c.style == "line" and bool(CODING.search(c.text))),
    KeepRule("license", "a license or copyright header", lambda c: bool(LICENSE.search(c.text))),
    KeepRule("formatter", "a formatter directive (`# fmt: off`, `// prettier-ignore`)",
             lambda c: bool(FORMATTER.search(c.text))),
    KeepRule("suppression-why", "a lint suppression with its reason on the same line",
             lambda c: has_suppression(c) and suppression_reason(c)),
    KeepRule("path-import", "a bare `noqa: E402` on an import after a `sys.path.insert` (the reason is that line)",
             lambda c: c.path_import and bool(E402.search(c.text))),
    KeepRule("module-doc-read", "a module docstring in a file that reads `__doc__` (argparse builds the CLI from it)",
             lambda c: c.style == "docstring" and c.target == "module" and c.reads_doc),
    KeepRule("public-doc", "a docstring or doc comment on a public module, function, class or CLI",
             lambda c: c.style in ("docstring", "doc") and c.target in ("module", "public")),
    KeepRule("contract", "a private docstring that states a contract (`None when ...`, `Raises ...`)",
             lambda c: c.style in ("docstring", "doc") and c.target == "private" and bool(CONTRACT.search(c.text))),
    KeepRule("ticket-why", "a ticket key or issue link plus the reason on the same line", ticket_reason),
    KeepRule("external-quirk", "a vendor or platform quirk whose external cause the comment names", None),
)


def classify(c):
    """(kept rule name, None) for a comment on the keep list, else (None, flag kind). A guard comment ("do not
    remove") is flagged whatever else the line says: the reviewer offers to encode it as a test or check. A docstring
    or doc comment that says "never" is documentation, so the keep list goes first there."""
    is_doc = c.style in ("docstring", "doc")
    if GUARD.search(c.text) and not is_doc and not LICENSE.search(c.text):
        return None, "guard"
    for rule in KEEP:
        if rule.match and rule.match(c):
            return rule.name, None
    if has_suppression(c):
        return None, "suppression"
    if is_doc and c.target == "test":
        return None, "test-docstring"
    if TICKET.search(c.text):
        return None, "ticket-tag" if bare_ticket(c) else "ticket"
    if GUARD.search(c.text):
        return None, "guard"
    if is_doc:
        return None, "docstring"
    if c.style == "line" and len(c.text) <= 200 and "-*-" not in c.text and not NEGATION.search(c.text) and BANNER.fullmatch(c.text.strip()):
        return None, "banner"
    return None, "comment"


def language(path, text):
    ext = os.path.splitext(path)[1].lower()
    if ext:
        return EXTENSIONS.get(ext)
    first = text.split("\n", 1)[0]
    if first.startswith("#!"):
        if "python" in first:
            return "python"
        if re.search(r"\b(?:ba|z|da|k)?sh\b", first):
            return "shell"
    return None


def merge_line_comments(comments, code_lines):
    """Consecutive full-line comments of one style are one comment. A directive line (shebang, encoding, formatter,
    suppression, ticket key) stays alone, so a neighbour's words never become its reason."""
    def alone(c):
        return (any(rule.match(c) for rule in KEEP if rule.name in ("shebang", "encoding", "formatter"))
                or has_suppression(c) or bool(TICKET.search(c.text)))

    out = []
    for c in comments:
        prev = out[-1] if out else None
        if (prev and c.style in ("line", "doc") and prev.style == c.style and prev.end == c.line - 1
                and prev.line not in code_lines and c.line not in code_lines and not alone(prev) and not alone(c)):
            prev.end = c.line
            prev.text += "\n" + c.text
        else:
            out.append(c)
    return out


def is_test_file(path):
    """test_*.py, *_test.py, tests.py (Django) or conftest.py, or any file under a tests/ or test/ folder. A library's
    production tests.py (Jinja2's test_odd) is judged as tests: the reviewer reads each flag."""
    parts = re.split(r"[\\/]", path)
    name = parts[-1]
    return name.startswith("test_") or name.endswith("_test.py") or name in ("tests.py", "conftest.py") \
        or any(p in ("tests", "test") for p in parts[:-1])


def python_comments(text, path=""):
    comments, code_lines = [], set()
    try:
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            if tok.type == tokenize.COMMENT:
                row, col = tok.start
                if tok.line[:col].strip():
                    code_lines.add(row)
                comments.append(Comment(row, row, tok.string, "line"))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        return scan(text, "shell")
    comments = merge_line_comments(comments, code_lines)
    try:
        tree = ast.parse(text)
    except (SyntaxError, ValueError):
        return comments
    reads_doc = "__doc__" in text
    in_tests = is_test_file(path)
    lines = text_lines(text)

    def visit(node, target):
        body = getattr(node, "body", None)
        if isinstance(body, list) and body and isinstance(body[0], ast.Expr) \
                and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
            doc = body[0]
            comments.append(Comment(doc.lineno, doc.end_lineno, "\n".join(lines[doc.lineno - 1:doc.end_lineno]),
                                    "docstring", target, reads_doc))
        in_function = isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        test_class = in_tests and isinstance(node, ast.ClassDef) and bool(re.match(r"Test(?:[A-Z_]|$)", node.name))
        for child in defs(node):
            private = (target == "private" or in_function
                       or child.name.startswith("_") and not child.name.endswith("__"))
            test = in_tests and isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) \
                and (child.name.startswith("test_") or test_class)
            visit(child, "private" if private else "test" if test else "public")

    def defs(node):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                yield child
            elif isinstance(child, (ast.stmt, ast.excepthandler, ast.match_case)):
                yield from defs(child)

    visit(tree, "module")
    mark_path_imports(tree, comments)
    return sorted(comments, key=lambda c: c.line)


def mark_path_imports(tree, comments):
    """Set path_import on the line comments of each module-level import after a `sys.path.insert` or `.append`,
    guarded (`if ...:`, `try:`) or not."""
    inserted, rows = False, set()
    for stmt in tree.body:
        if not isinstance(stmt, (ast.Import, ast.ImportFrom)) and any(
                isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr in ("insert", "append")
                and ast.unparse(n.func.value) == "sys.path" for n in ast.walk(stmt)):
            inserted = True
        elif inserted and isinstance(stmt, (ast.Import, ast.ImportFrom)):
            rows.update(range(stmt.lineno, stmt.end_lineno + 1))
    for c in comments:
        if c.style == "line" and c.line in rows:
            c.path_import = True


GAPS = ("", " ", "\n")
REGEX_AFTER = set("(,=:[!&|?{;") | {"return", "typeof", "case", "of", "in", "await", "yield", "throw", "void",
                                       "delete", "new", "else", "do", "instanceof"}
QUOTES = ('"""', "'''", '"', "'", "`")


def string_end(text, i, quote, lang):
    """The index just past the string literal that opens with `quote` at i. A `${...}` in a Dart string, a JS
    template or a Kotlin double-quoted string is code, so a quote inside it opens a nested string. A backslash
    escapes nothing in a Dart r'...' or a Kotlin triple-quoted string. A one-quote string other than a template
    ends at the line end in C-like files."""
    n, c_like = len(text), lang in C_LIKE
    raw = lang == "kotlin" and quote == '"""' or lang == "dart" and text[i - 1:i] == "r" \
        and not (i > 1 and (text[i - 2].isalnum() or text[i - 2] in "_$"))
    interpolates = not raw and (lang == "dart" or lang == "kotlin" and quote != "'" or lang == "js" and quote == "`")
    j = i + len(quote)
    while j < n and not text.startswith(quote, j):
        if text[j] == "\\" and not raw and not (lang == "shell" and quote == "'"):
            j += 1
        elif text[j] == "\n" and len(quote) == 1 and quote != "`" and c_like:
            return j
        elif interpolates and text.startswith("${", j):
            j, depth = j + 2, 1
            while j < n and depth:
                nested = next((q for q in QUOTES if text.startswith(q, j)), None)
                if nested:
                    j = string_end(text, j, nested, lang)
                    continue
                depth += {"{": 1, "}": -1}.get(text[j], 0)
                j += 1
            continue
        j += 1
    return min(n, j + len(quote))


def regex_end(text, i):
    """The index just past a JS regex literal at i (flags included), or None when the line ends first."""
    j, in_class = i + 1, False
    while j < len(text) and text[j] != "\n":
        if text[j] == "\\":
            j += 2
            continue
        if text[j] == "/" and not in_class:
            j += 1
            while j < len(text) and text[j].isalpha():
                j += 1
            return j
        in_class = text[j] != "]" and (in_class or text[j] == "[")
        j += 1
    return None


def block_end(text, i, nested):
    """The index just past the block comment that opens at i. Kotlin and Dart nest block comments; JS does not."""
    depth, j = 0, i
    while j < len(text):
        if nested and text.startswith("/*", j) or j == i:
            depth, j = depth + 1, j + 2
        elif text.startswith("*/", j):
            depth, j = depth - 1, j + 2
            if not depth:
                return j
        else:
            j += 1
    return len(text)


def scan(text, lang, tokens=None, jsx=False):
    """Comments in shell or C-like text (Kotlin, Dart, TypeScript, JavaScript), skipping strings and JS regex
    literals. A `tokens` list gets [line, token, gap] for the code: a word, a string or regex literal (at its closing
    line), or one other character, and the widest gap before it ("", " " or "\n"; a comment counts as a space, or as
    a line break when it spans lines). A comment is [line, None, "", its text]. Not comments: a bare trailing `//` in
    Dart (a `dart format` line-break marker) and, with `jsx`, JSX text between tags, where quotes and `//` are rendered
    text. A `{` that opens a JSX child is [line, "{", gap, "child"]."""
    comments, code, heredocs = [], {}, []
    i, n, line = 0, len(text), 1
    c_like = lang in C_LIKE
    tokens = [] if tokens is None else tokens
    in_word, gap = False, ""
    frames = [["code", 0]]

    def widen(to):
        nonlocal gap, in_word
        in_word = False
        gap = max(gap, to, key=GAPS.index)

    def add_token(token):
        nonlocal in_word, gap
        in_word = False
        tokens.append([line, token, gap])
        gap = ""

    def add_comment(body):
        tokens.append([line, None, "", body])
        widen("\n" if "\n" in body else " ")

    def note_code(ch):
        nonlocal in_word
        if ch.isspace():
            widen(" ")
            return
        code.setdefault(line, []).append(ch)
        if ch.isalnum() or ch in "_$":
            if in_word:
                tokens[-1][1] += ch
            else:
                add_token(ch)
                in_word = True
        else:
            add_token(ch)
            if jsx:
                follow_jsx(ch)

    def peek(j):
        while j < n and text[j].isspace():
            j += 1
        return text[j:j + 1]

    def follow_jsx(t):
        """Moves through JSX: a `<` opens a tag in children, or in code after an operator, `(`, `,`, `=>` or
        `return`, never after a name (`f<T>(`, `a < b`); a `,`, `(`, `)` or `;` in a tag, or `(` right after its `>`,
        means it was a type argument."""
        kind = frames[-1][0]
        before = [x[1] for x in tokens[-4:-1] if x[1] is not None]
        if kind == "children":
            if t == "<":
                frames.append(["close" if peek(i + 1) == "/" else "tag", 0])
            elif t == "{":
                tokens[-1].append("child")
                frames.append(["code", 1])
        elif kind in ("tag", "close"):
            if kind == "tag" and t in NOT_IN_TAG:
                frames.pop()
            elif t == "{":
                frames.append(["code", 1])
            elif t == ">":
                frames.pop()
                if kind == "close" and frames[-1][0] == "children":
                    frames.pop()
                elif kind == "tag" and before[-1:] != ["/"] and peek(i + 1) != "(":
                    frames.append(["children", 0])
        elif t == "<" and (not before or before[-1] in JSX_AFTER or before[-2:] == ["=", ">"]) \
                and (peek(i + 1) == ">" or WORD.fullmatch(peek(i + 1))):
            frames.append(["tag", 0])
        elif frames[-1][1] and t in "{}":
            frames[-1][1] += 1 if t == "{" else -1
            if not frames[-1][1]:
                frames.pop()

    def regex_may_start():
        """A `/` opens a regex after an operator or keyword, not after an operand: `x! / 2` divides."""
        last = [t[1] for t in tokens[-8:] if t[1] is not None][-2:]
        if not last:
            return True
        if last[-1] == "!" and len(last) > 1 and (WORD.fullmatch(last[0]) or last[0] in ")]!"):
            return False
        return last[-1] in REGEX_AFTER or last == ["=", ">"]

    while i < n:
        ch = text[i]
        if ch == "\n":
            widen("\n")
            line += 1
            i += 1
            for word, strip_tabs in heredocs:
                while i < n:
                    j = text.find("\n", i)
                    j = n if j < 0 else j
                    body = text[i:j]
                    i = min(n, j + 1)
                    line += j < n
                    if (body.lstrip("\t") if strip_tabs else body) == word:
                        break
            heredocs.clear()
            continue
        heredoc = HEREDOC.match(text, i) if lang == "shell" and not text.startswith("<<<", i) \
            and text[i - 1:i] != "<" and not in_arithmetic(text, i) else None
        if heredoc:
            heredocs.append((heredoc.group(3), heredoc.group(1) == "-"))
            for part in heredoc.group(0):
                note_code(part)
            i = heredoc.end()
            continue
        if lang == "shell" and ch == "#" and (i == 0 or text[i - 1] in " \t\n;|&("):
            j = text.find("\n", i)
            j = n if j < 0 else j
            comments.append(Comment(line, line, text[i:j], "line"))
            add_comment(text[i:j])
            i = j
            continue
        if jsx and frames[-1][0] == "children" and not ch.isspace() and ch not in "<{":
            note_code(ch)
            i += 1
            continue
        if c_like and text.startswith("//", i) and text[i - 1:i] != "\\":
            j = text.find("\n", i)
            j = n if j < 0 else j
            body = text[i:j]
            if lang == "dart" and body.rstrip() == "//" and line in code:
                add_token("//")
                i = j
                continue
            style = "doc" if body.startswith("///") and not body.startswith("////") else "line"
            comments.append(Comment(line, line, body, style))
            add_comment(body)
            i = j
            continue
        if c_like and text.startswith("/*", i) and text[i - 1:i] != "\\":
            j = block_end(text, i, nested=lang != "js")
            body = text[i:j]
            style = "doc" if body.startswith("/**") and body != "/**/" else "block"
            comments.append(Comment(line, line + body.count("\n"), body, style))
            add_comment(body)
            line += body.count("\n")
            i = j
            continue
        if lang == "js" and ch == "/" and regex_may_start():
            j = regex_end(text, i)
            if j is not None:
                code.setdefault(line, []).append("/")
                add_token(text[i:j])
                i = j
                continue
        quote = next((q for q in QUOTES if text.startswith(q, i)), None)
        quote = quote[0] if quote and lang == "js" else quote
        if quote and (c_like or len(quote) == 1 and quote != "`"):
            j = string_end(text, i, quote, lang)
            code.setdefault(line, []).append('"')
            line += text.count("\n", i, j)
            add_token(text[i:j])
            code.setdefault(line, []).append('"')
            i = j
            continue
        if ch == "\\" and lang == "shell":
            note_code(ch)
            line += text[i + 1:i + 2] == "\n"
            i += 2
            continue
        note_code(ch)
        i += 1
    comments = merge_line_comments(comments, code)
    lines = text_lines(text)
    for c in comments:
        if c.style == "doc":
            c.target = doc_target(lines, c.end)
    for row, chars in code.items():
        if "@" in chars and ANNOTATION.search("".join(chars)):
            for c in [c for c in comments if c.line == row]:
                comments.remove(c)
            comments.append(Comment(row, row, annotation_text(lines[row - 1]), "annotation"))
    return sorted(comments, key=lambda c: c.line)


def text_lines(text):
    """Lines split on newline only, as git counts them (splitlines also splits on U+2028 and a lone CR)."""
    return [l.rstrip("\r") for l in text.split("\n")]


def in_arithmetic(text, i):
    """True inside an unclosed `((` on this line: there `<<` is a shift, not a heredoc."""
    before = text[text.rfind("\n", 0, i) + 1:i]
    return before.count("((") > before.count("))")


def annotation_text(raw):
    """The @Suppress(...) spans of a code line plus its trailing comment, never the code: code words are no reason."""
    spans = list(ANNOTATION_SPAN.finditer(raw))
    opened = ANNOTATION.search(raw)
    if opened and not spans:
        return raw[opened.start():].strip()
    rest = raw[spans[-1].end():] if spans else raw
    tail = re.search(r"//|/\*", rest)
    return " ".join([m.group(0) for m in spans] + ([rest[tail.start():].strip()] if tail else []))


def doc_target(lines, end):
    """private when the declaration after a doc comment is private (`private`, a Dart `_name`, a JS `#name`)."""
    for raw in lines[end:]:
        decl = raw.strip()
        if not decl or decl.startswith("@"):
            continue
        head = re.split(r"[(=:{]", decl, 1)[0]
        if re.search(r"\bprivate\b", head) or re.search(r"(?<![\w$])_[A-Za-z]\w*", head) \
                or re.match(r"(?:static\s+)?#\w", decl):
            return "private"
        if raw[:1].isspace() and re.match(r"(?:const|let|return|if|for|while|switch|throw|await)\b", decl):
            return "private"
        return "public"
    return "public"


def comments_in(path, text):
    """Every comment in a file (docstrings and suppression annotations included), or [] for a language not covered."""
    lang = language(path, text)
    if lang == "python":
        return python_comments(text, path)
    if lang:
        return scan(text, lang, jsx=is_jsx(path))
    return []


def git(root, *args):
    return tier.git(list(args), root, raw=True).decode("utf-8", "replace")


def changed_lines(root, base):
    """({path: added line numbers}, Counter of removed comment texts) for the working tree against base, untracked
    included. The fixed prefixes and --text keep the parse independent of the user's diff config, as in tier.collect."""
    added, removed, path, header = {}, Counter(), None, False
    diff = git(root, "diff", "-U0", "--no-color", "--no-ext-diff", "--no-textconv", "--text", "-M",
               "--src-prefix=a/", "--dst-prefix=b/", base, "--")
    for raw in diff.splitlines():
        if raw.startswith("diff --git"):
            path, header = None, True
            continue
        hunk = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", raw)
        if hunk:
            header = False
            start, count = int(hunk.group(1)), int(hunk.group(2) or 1)
            if path:
                added.setdefault(path, set()).update(range(start, start + count))
        elif header:
            if raw.startswith("+++ "):
                name = raw[4:].rstrip("\t")
                if name.startswith('"'):
                    try:
                        name = ast.literal_eval(name)
                    except (SyntaxError, ValueError):
                        name = ""
                path = name[2:] if name.startswith("b/") else None
        elif raw.startswith("-"):
            text = raw[1:].strip()
            tails = {text, annotation_text(text)} | {text[m.start():].strip() for m in re.finditer(r"#|//|/\*", text)}
            removed.update(t for t in tails if t)
    for f in tier.untracked_files(root):
        if f["added"]:
            added[f["path"]] = EVERY_LINE
    return added, removed


def moved(c, removed):
    """A comment whose lines the diff also removes was moved. Each removal covers one addition."""
    need = Counter(l.strip() for l in c.text.splitlines() if l.strip())
    if need and all(removed[t] >= k for t, k in need.items()):
        removed.subtract(need)
        return True
    return False


def parts(c, lines):
    """A license block that is only partly added is judged line by line, so a new comment under an old header is
    not kept by the header's rule. A wholly added header (a new file) stays one block."""
    if lines is EVERY_LINE or classify(c)[0] != "license" or all(n in lines for n in range(c.line, c.end + 1)):
        return [c]
    return [Comment(c.line + k, c.line + k, row, c.style) for k, row in enumerate(c.text.split("\n"))
            if c.line + k in lines]


def read_text(full):
    """A regular file's text as written (newlines kept), or None for a missing file, a folder or a link."""
    if not os.path.isfile(full) or os.path.islink(full):
        return None
    with open(full, encoding="utf-8", errors="replace", newline="") as f:
        return f.read()


def source(root, path):
    """The text of a file the check reads, or None: a skipped extension, an ignored path, a link, or a generated file.
    `path` is relative to `root`, so the ignore rules never see the folders above it."""
    ext = os.path.splitext(path)[1].lower()
    if ext and ext not in EXTENSIONS or tier.is_ignored(path):
        return None
    text = read_text(os.path.join(root, path))
    return None if text is None or GENERATED.search("\n".join(text_lines(text)[:5])) else text


def first_words(c, start=0):
    rest = c.text.splitlines()[start:]
    return next((" ".join(l.split()) for l in rest if words(l)), " ".join(c.text.split()))[:120]


def flags(root, base):
    """[(path, line, kind, text)] for the comments the diff adds that the keep list does not keep."""
    added, removed = changed_lines(root, base)
    out = []
    for path in sorted(added):
        text = source(root, path)
        if text is None:
            continue
        lines = added[path]
        for c in (part for whole in comments_in(path, text) for part in parts(whole, lines)):
            hit = next((n for n in range(c.line, c.end + 1) if lines is EVERY_LINE or n in lines), None)
            if hit is None or moved(c, removed):
                continue
            _, kind = classify(c)
            if kind:
                out.append((path, hit, kind, first_words(c, hit - c.line)))
    return out


FORMS = ("docstring", "inline", "line", "shell")
SHED_FORMS = tuple(f for f in FORMS if f != "inline")
Item = namedtuple("Item", "path line form verdict text shed")


def form(c, lang, lines):
    """docstring, inline (shares a line with code), shell (a whole-line shell comment) or line."""
    if c.style in ("docstring", "doc"):
        return "docstring"
    rows = c.text.split("\n")
    if c.style == "annotation" or lines[c.line - 1].replace(rows[0], "", 1).strip() \
            or lines[c.end - 1].replace(rows[-1], "", 1).strip():
        return "inline"
    return "shell" if lang == "shell" else "line"


def files_under(path):
    """(root, relative path) of each file under PATH: git's tracked and untracked-not-ignored files in a work tree,
    else every file outside dot folders. One file is its own folder plus its name."""
    if os.path.isfile(path):
        return [(os.path.dirname(path) or ".", os.path.basename(path))]
    try:
        out = tier.git(["ls-files", "-co", "--exclude-standard", "-z"], path, raw=True).decode("utf-8", "replace")
        return [(path, rel) for rel in sorted(filter(None, out.split("\0")))]
    except RuntimeError:
        found = []
        for top, dirs, names in os.walk(path):
            dirs[:] = sorted(d for d in dirs if not d.startswith("."))
            found += [(path, os.path.relpath(os.path.join(top, n), path)) for n in sorted(names)]
        return found


def inventory(path):
    """[Item] for every comment under PATH, each path as PATH joined with the file's path under it."""
    out = []
    for root, rel in files_under(path):
        text = source(root, rel)
        if text is None:
            continue
        shown = os.path.normpath(os.path.join(root, rel))
        lang, lines = language(rel, text), text_lines(text)
        for c in comments_in(os.path.join(os.path.basename(os.path.abspath(root)), rel), text):
            kept, kind = classify(c)
            f = form(c, lang, lines)
            shed = c.end - c.line + 1 if not kept and kind != "suppression" and f in SHED_FORMS else 0
            out.append(Item(shown, c.line, f, f"keep:{kept}" if kept else f"flag:{kind}", first_words(c), shed))
    return out


def inventory_summary(found):
    counts = Counter(i.form for i in found)
    forms = ", ".join(f"{f} {counts[f]}" for f in FORMS)
    kept = sum(i.verdict.startswith("keep:") for i in found)
    return (f"comment_check --all: {len(found)} items ({forms}), kept {kept}, "
            f"shed {sum(i.shed for i in found)} lines")


def summary(found):
    if not found:
        return "comment_check: 0 flags"
    counts = {}
    for _, _, kind, _ in found:
        counts[kind] = counts.get(kind, 0) + 1
    kinds = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    return f"comment_check: {len(found)} flag{'s' if len(found) != 1 else ''} ({kinds})"


ADR_POINTER = re.compile(r"(NousFX )?\bADR[- ](\d{4})\b")
NOUSFX_ROOTS = ("claude/", "plugins/")
DELETED_LINES_WARN = 800
CANNOT_RUN = "cannot run"


def changed_files(root, base):
    """[(status, path, mode changed)] for the working tree against base: status A, D, M or T, untracked files as A.
    No rename detection, so a rename is a delete and an add."""
    out = git(root, "diff", "--raw", "-z", "--no-renames", "--no-ext-diff", base, "--").split("\0")
    rows = []
    for meta, path in zip(out[0::2], out[1::2]):
        if meta.startswith(":"):
            old_mode, new_mode, _, _, status = meta[1:].split()
            rows.append((status[0], path, old_mode != new_mode))
    return rows + [("A", f["path"], False) for f in tier.untracked_files(root)]


def strip_docstrings(tree):
    """ast.dump of the tree with every module, class and function docstring removed. An emptied class or function
    body is `pass`; an emptied module stays empty."""
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)) and node.body \
                and isinstance(node.body[0], ast.Expr) and isinstance(node.body[0].value, ast.Constant) \
                and isinstance(node.body[0].value.value, str):
            node.body = node.body[1:] or ([] if isinstance(node, ast.Module) else [ast.Pass()])
    return ast.dump(tree)


def docstrings_read(tree):
    """[(name, docstring)] for each def and class the file reads as `name.__doc__`: argparse can take --help text
    from any of them. A read through anything else (self, cls, getattr) takes every def and class."""
    defs = [n for n in ast.walk(tree) if isinstance(n, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef))]
    names = {n.name for n in defs}
    bases = {n.value.id if isinstance(n.value, ast.Name) else None
             for n in ast.walk(tree) if isinstance(n, ast.Attribute) and n.attr == "__doc__"}
    module_read = any(isinstance(n, ast.Name) and n.id == "__doc__" for n in ast.walk(tree))
    every = any(b not in names for b in bases) or not bases and not module_read
    return [(n.name, ast.get_docstring(n, clean=False)) for n in defs if every or n.name in bases]


def python_differences(old, new):
    """The differences, or None when BASE did not parse either: that file is left to the suite."""
    try:
        old_tree = ast.parse(old)
    except (SyntaxError, ValueError):
        return None
    try:
        new_tree = ast.parse(new)
    except (SyntaxError, ValueError) as e:
        return [f"does not parse ({e.__class__.__name__}: {e})"]
    out = []
    if "__doc__" in old or "__doc__" in new:
        if ast.get_docstring(old_tree, clean=False) != ast.get_docstring(new_tree, clean=False):
            out.append("module docstring changed in a file that reads __doc__")
        changed = set(docstrings_read(old_tree)) ^ set(docstrings_read(new_tree))
        out += [f"{name} docstring changed in a file that reads __doc__ (it can be --help text)"
                for name in sorted({name for name, _ in changed})]
    if strip_docstrings(old_tree) != strip_docstrings(new_tree):
        out.append("code changed (the AST without docstrings differs from BASE)")
    return out


def directives(text):
    """The shebang and encoding lines (lines 1 and 2): comments that change how a file runs."""
    head = text_lines(text)[:2]
    return [l for n, l in enumerate(head, 1)
            if n == 1 and l.startswith("#!") or re.match(r"[ \t\f]*#.*" + CODING.pattern, l)]


def shell_code(path, text):
    """A shell file's lines with its comments cut out. A line that held only a comment drops, unless the line before
    ends in a backslash (dropping it would join two commands). Every other line, blank ones too, must match: a
    heredoc or string can hold them."""
    lines = text_lines(text)
    cut = set()
    for c in comments_in(path, text):
        for k, row in enumerate(c.text.split("\n")):
            i = c.line + k - 1
            line = lines[i].rstrip()
            if line.endswith(row.rstrip()):
                lines[i] = line[:len(line) - len(row.rstrip())].rstrip()
                cut.add(i)
    return [l for i, l in enumerate(lines)
            if not (i in cut and not l and not (i and lines[i - 1].endswith("\\")))]


def syntax_error(shell, text):
    try:
        r = subprocess.run([shell, "-n"], input=text, capture_output=True, text=True)
    except OSError as e:
        return f"{CANNOT_RUN} {shell}: {e}"
    return None if r.returncode == 0 else (r.stderr.strip().splitlines() or [""])[0]


def shell_differences(path, old, new):
    """Code outside comments must match BASE, and the file must pass `-n` with the shell its shebang or extension
    names, unless BASE already failed it."""
    out = [] if shell_code(path, old) == shell_code(path, new) else \
        ["code changed (the text without comments differs from BASE)"]
    wants_zsh = path.endswith(".zsh") or "zsh" in text_lines(new)[0] and new.startswith("#!")
    shell = "zsh" if wants_zsh and shutil.which("zsh") else "bash"
    error = syntax_error(shell, new)
    if error is not None and (error.startswith(CANNOT_RUN) or syntax_error(shell, old) is None):
        out.append(f"fails {shell} -n: {error}")
    return out


JSX = (".tsx", ".jsx", ".js", ".mjs", ".cjs")


def is_jsx(path):
    return os.path.splitext(path)[1].lower() in JSX

WORD = re.compile(r"[\w$]+")
JSX_AFTER = set("(,=:?[{;&|!") | {"return", "yield", "await", "default", "else", "do"}
NOT_IN_TAG = set(",();")
FUSES = set("+-*/%<>=!&|^?:.")


C_DIRECTIVE = re.compile(r"^///\s*<(?:reference|amd-)|@dart\s*=\s*[\d.]*"
                         r"|@jsx(?:ImportSource|Runtime|Frag)?\b(?:[ \t]+[^\s*]+)?"
                         r"|@ts-(?:nocheck|check|ignore|expect-error)\b|@flow\b")
MAX_DIFF_TOKENS = 10000


def jsx_comments(tokens):
    """The brace pairs of each `{/* note */}` JSX child that holds only comments: deleting the whole expression is a
    comment change, leaving `{}` behind is not."""
    out = []
    for k, t in enumerate(tokens):
        if t[1] == "{" and t[3:] == ["child"]:
            j = k + 1
            while j < len(tokens) and tokens[j][1] is None:
                j += 1
            if j > k + 1 and j < len(tokens) and tokens[j][1] == "}":
                out.append((k, j))
    return out


def parts_text_lines(tokens, left, right):
    """True when the `{/* note */}` at tokens[left..right] has JSX text on both sides and a line break beside it:
    deleting it would join two text lines into one with a space."""
    before = next((t for t in reversed(tokens[:left]) if t[1] is not None), None)
    after = next((t for t in tokens[right + 1:] if t[1] is not None), None)
    if not before or not after or before[1] in (">", "}") or after[1] in ("<", "{"):
        return False
    return "\n" in tokens[left][2] + after[2]


def c_code(path, text):
    """[(line, token, separator)] of a Kotlin, Dart, TypeScript or JavaScript file outside its comments. The
    separator is "\n" after a line break (ASI and Kotlin end statements there), " " between two operator characters
    (`+ +` is not `++`), else "". A dropped JSX comment expression passes the gap before it on to the next token.
    JSX text is code (scan reads it as text)."""
    tokens = []
    jsx = is_jsx(path)
    scan(text, language(path, text), tokens, jsx)
    drop = {k for pair in jsx_comments(tokens) if not parts_text_lines(tokens, *pair) for k in pair}
    out, gap, prev = [], "", None
    for k, (line, t, g, *_) in enumerate(tokens):
        if k in drop and t == "}":
            continue
        gap = max(gap, g, key=GAPS.index)
        if t is None or k in drop:
            continue
        punct = t in FUSES
        sep = "" if prev is None else "\n" if gap == "\n" else " " if gap and punct and prev else ""
        out.append((line, t, sep))
        gap, prev = "", punct
    return out


def c_directives(path, text):
    """The compiler directives in the comments of a Kotlin, Dart, TypeScript or JavaScript file: a whole triple-slash
    reference line, or the directive alone (`@ts-expect-error`, `@dart=2.9`, a JSX pragma, `@flow`), so the reason
    after a suppression may change."""
    out = []
    for c in scan(text, language(path, text), jsx=is_jsx(path)):
        for row in c.text.splitlines():
            m = C_DIRECTIVE.search(row.strip())
            if m:
                out.append(row.strip() if row.strip().startswith("///") else " ".join(m.group(0).split()))
    return out


def c_differences(path, old, new):
    """[(line, difference)] for each run of tokens outside comments that differs from BASE, at its line in the
    working tree. The common ends are trimmed first; a middle over MAX_DIFF_TOKENS reports its first line only."""
    before, after = c_code(path, old), c_code(path, new)
    a, b = [t[1:] for t in before], [t[1:] for t in after]
    if a == b:
        return []
    head = next((k for k, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    tail = 0
    while tail < min(len(a), len(b)) - head and a[-1 - tail] == b[-1 - tail]:
        tail += 1
    a, b = a[head:len(a) - tail], b[head:len(b) - tail]
    row = lambda j: after[j][0] if 0 <= j < len(after) else after[-1][0] if after else 1
    if max(len(a), len(b)) > MAX_DIFF_TOKENS:
        return [(row(head), "code changed")]
    out = []
    for op, _, _, j1, _ in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if op != "equal":
            j = head + j1
            out.append((row(j - 1 if (op == "delete" and j > 0) or j >= len(after) else j), "code changed"))
    return out


def is_nousfx(root):
    return os.path.isfile(os.path.join(root, "scripts", "nousfx_sync.py"))


def adr_differences(root, path, text):
    out = []
    for c in comments_in(path, text):
        for m in ADR_POINTER.finditer(c.text):
            number = m.group(2)
            if m.group(1) and not is_nousfx(root):
                continue
            if not glob.glob(os.path.join(glob.escape(root), "docs", "adr", f"{number}-*.md")):
                out.append(f"ADR-{number} has no docs/adr/{number}-*.md")
            elif path.startswith(NOUSFX_ROOTS) and (not m.group(1) or "ADR " in m.group(0)) \
                    and is_nousfx(root):
                out.append(f"ADR-{number} must read NousFX ADR-{number} under claude/ and plugins/")
    return out


def differences(root, base):
    """([(path, line or None, difference)] for every change since base that is more than comments, the number of
    changed files verify left to the suite: other languages and file types). An extensionless file takes its
    language from BASE, since the edit may have deleted its shebang."""
    out, unchecked = [], 0
    for status, path, mode_changed in sorted(changed_files(root, base), key=lambda p: p[1]):
        if status == "M" and mode_changed:
            out.append((path, None, "mode changed (the executable bit)"))
        ext = os.path.splitext(path)[1].lower()
        if ext and ext not in EXTENSIONS:
            unchecked += 1
            continue
        if status == "D":
            if language(path, git(root, "show", f"{base}:{path}")):
                out.append((path, None, "deleted"))
            continue
        full = os.path.join(root, path)
        if status == "T" or os.path.islink(full):
            out.append((path, None, "a symlink changed or replaced a file"))
            continue
        try:
            new = read_text(full)
        except OSError as e:
            out.append((path, None, f"unreadable ({e.strerror})"))
            continue
        old = git(root, "show", f"{base}:{path}") if status != "A" else None
        lang = (old is not None and not ext and language(path, old)) or \
            (language(path, new) if new is not None else None)
        if lang is None:
            unchecked += 1
            continue
        found = []
        if status == "A":
            found.append("added")
        elif lang in C_LIKE:
            out += [(path, row, d) for row, d in c_differences(path, old, new)]
            if c_directives(path, old) != c_directives(path, new):
                found.append("a compiler directive changed")
        else:
            if directives(old) != directives(new):
                found.append("a shebang or encoding line changed")
            checks = python_differences(old, new) if lang == "python" else shell_differences(path, old, new)
            if checks is None:
                unchecked += 1
            found += checks or []
        found += adr_differences(root, path, new)
        out += [(path, None, d) for d in found]
    return out, unchecked


def deleted_lines(root, base):
    total = 0
    for row in git(root, "diff", "--numstat", "--no-renames", base, "--").splitlines():
        cols = row.split("\t", 2)
        total += int(cols[1]) if len(cols) == 3 and cols[1].isdigit() else 0
    return total


def verify_base(root, base):
    """`git merge-base BASE HEAD`, so commits BASE gained after the branch point are not counted as changes; with
    no BASE, review-loop's base (origin/HEAD, else origin/main). None, after saying why on stderr, when there is
    no common ancestor."""
    if base is None:
        try:
            return tier.merge_base(root)
        except tier.NoMergeBase:
            print("comment_check verify: no origin/HEAD or origin/main shares history with HEAD; give BASE",
                  file=sys.stderr)
            return None
    commit = git(root, "rev-parse", "--verify", "--end-of-options", f"{base}^{{commit}}").strip()
    try:
        return git(root, "merge-base", commit, "HEAD").strip()
    except tier.GitUnavailable:
        raise
    except RuntimeError:
        print(f"comment_check verify: {base} has no common ancestor with HEAD (a shallow clone or an unrelated "
              "ref); give a BASE on this branch's history", file=sys.stderr)
        return None


def verify_main(argv):
    parser = argparse.ArgumentParser(
        prog="comment_check.py verify", description="Prove that only comments changed since BASE (see comment_check.py -h).")
    parser.add_argument("base", metavar="BASE", nargs="?",
                        help="the commit the cleanup started from (default: review-loop's merge base)")
    args = parser.parse_args(argv)
    if args.base and args.base.startswith("-"):
        parser.error("give the BASE hash, not an option")
    try:
        root = tier.repo_top(os.getcwd())
        base = verify_base(root, args.base)
        if base is None:
            return 2
        print(f"comment_check verify: comparing with {base}, the merge base with HEAD")
        found, unchecked = differences(root, base)
        deleted = deleted_lines(root, base)
    except RuntimeError as e:
        print(f"comment_check: git failed: {e}", file=sys.stderr)
        return 2
    for path, row, difference in found:
        print(f"{path}:{row} {difference}" if row else f"{path}: {difference}")
    if deleted > DELETED_LINES_WARN:
        print(f"comment_check verify: warning: {deleted} lines deleted, "
              f"over the ~{DELETED_LINES_WARN} a PR should take")
    if found:
        print(f"comment_check verify: {len(found)} difference{'s' if len(found) != 1 else ''}")
        return 2
    print(f"comment_check verify: OK, Python, shell, Kotlin, Dart, TypeScript and JavaScript files changed only "
          f"comments ({deleted} lines deleted); "
          f"{unchecked} other changed file{'s' if unchecked != 1 else ''} left to the suite")
    return 0


def main(argv):
    if argv[1:2] == ["verify"]:
        return verify_main(argv[2:])
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("base", nargs="?", help="the merge base hash")
    parser.add_argument("--keep-list", action="store_true", help="print the keep list and exit")
    parser.add_argument("--all", metavar="PATH", help="inventory every comment under PATH and exit")
    args = parser.parse_args(argv[1:])
    if args.keep_list:
        for rule in KEEP:
            print(f"- {rule.name}: {rule.text}" + ("" if rule.match else " (the reviewer judges)"))
        return 0
    if args.all is not None:
        if not os.path.exists(args.all):
            parser.error(f"--all: no such path: {args.all}")
        found = inventory(args.all)
        for i in found:
            print(f"{i.path}:{i.line} {i.form} {i.verdict} {i.text}")
        print(inventory_summary(found))
        return 0
    if not args.base or args.base.startswith("-"):
        parser.error("give the base hash (not an option), or --keep-list")
    try:
        root = tier.repo_top(os.getcwd())
        found = flags(root, args.base)
    except RuntimeError as e:
        print(f"comment_check: git failed: {e}", file=sys.stderr)
        return 2
    for path, line, kind, text in found:
        print(f"{path}:{line} {kind} {text}")
    print(summary(found))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
