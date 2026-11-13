"""Find the `gh pr create` calls in a shell command, the directory each runs in, and its PR body.

create_calls() gives each create's directory and arguments; pr_body() reads the body flags from them.
create_calls() parses the shell text instead of matching it, so quoted text and heredocs that only
mention the command pass, while wrappers (`if`, `timeout`, `eval`, `bash -c`, `$(...)`) are seen.
It is a guardrail against mistakes, not a sandbox. PR creates through the GitHub API are found too:
`gh api`, `curl` and `wget` to `repos/<owner>/<repo>/pulls` that send data or POST, and a `gh api graphql`
`createPullRequest` mutation (NFX-102). Known limits: script files, `gh alias`, `python -c` and SDK calls
(requests, PyGithub), other HTTP clients (`Invoke-RestMethod`, httpie, and `curl` where PowerShell 5.1
aliases it to `Invoke-WebRequest`), an API URL or GraphQL query built at run time or read from a file
(`-F query=@q.graphql`, `--input`), shell functions, `find -exec`, `cmd /c`,
`iex`, `trap` and `ssh host "..."` are not looked into.
"""
import collections
import os
import posixpath
import re
import subprocess
import time

Word = collections.namedtuple("Word", "text dynamic")  # dynamic: holds a $ or backtick expansion

KEYWORDS = {"if", "then", "elif", "else", "do", "while", "until", "!", "{", "coproc"}
WRAPPERS = {"env", "command", "builtin", "exec", "time", "nohup", "timeout", "gtimeout", "nice", "ionice",
            "sudo", "doas", "xargs", "stdbuf", "setsid", "caffeinate", "unbuffer", "flock", "watch",
            "noglob", "nocorrect", "direnv", "op", "uv", "mise"}
PRINTERS = {"echo", "printf"}
HTTP_CLIENTS = {"curl", "wget"}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "fish", "pwsh", "powershell"}
CD_COMMANDS = {"cd", "pushd", "popd", "chdir", "set-location", "sl", "pop-location"}
BRANCH_KEYWORDS = {"then", "elif", "else", "do"}
ASSIGNMENT = re.compile(r"^\w+\+?=")
SHELL_C_FLAG = re.compile(r"^(?:-[a-zA-Z]*c[a-zA-Z]*|-command)$", re.I)
SHELL_S_FLAG = re.compile(r"^-[a-zA-Z]*s[a-zA-Z]*$")
CD_MENTION = re.compile(r"\b(?:cd|pushd|popd|chdir|set-location|sl|pop-location)\b", re.I)
HEREDOC_DELIM = re.compile(r"""'([^']*)'|"([^"]*)"|(\\?)([^\s;&|()<>]+)""")
GH_WORD = re.compile(r"\bgh\b")
PR_WORDS = re.compile(r"\bpr\b")
CREATE_WORDS = re.compile(r"\b(?:create|new)\b")
SUBSTITUTION = re.compile(r"\$\((?!\()|`|\$\{(?:[\s|]|$)")  # `$(...)`, a backtick, bash 5.3 `${ ...; }`; not `$((`
TOPLEVEL = re.compile(r"\$\(\s*git rev-parse --show-toplevel\s*\)|`\s*git rev-parse --show-toplevel\s*`")


def read_heredoc(s, i):
    """Read the `<<` operator at i. Return ((delim, literal, strip) or None, index after it)."""
    i += 2
    strip = s[i:i + 1] == "-"
    i += strip
    while s[i:i + 1] in (" ", "\t"):
        i += 1
    m = HEREDOC_DELIM.match(s, i)
    if not m:
        return None, i
    literal = m.group(1) is not None or m.group(2) is not None or bool(m.group(3))
    delim = next(g for g in (m.group(1), m.group(2), m.group(4)) if g is not None)
    return (delim, literal, strip), m.end()


def close_paren(s, i):
    """Index of the ) matching a ( opened just before i. ValueError if unbalanced (the gate then
    falls back to the raw-text check, so text it cannot read never hides a create)."""
    depth, heredocs = 1, []
    while i < len(s):
        c = s[i]
        if c == "\\":
            i += 1
        elif c == "'":
            i = close_ansi_quote(s, i + 1) if s[i - 1] == "$" else s.find("'", i + 1)
            if i < 0:
                raise ValueError("unclosed quote")
        elif c == '"':
            i = close_double_quote(s, i + 1)
        elif c == "#" and s[i - 1] in " \t\n;&|(":
            j = s.find("\n", i)
            i = len(s) if j < 0 else j - 1
        elif c == "<" and s[i + 1:i + 2] == "<" and s[i + 2:i + 3] != "<":
            heredoc, j = read_heredoc(s, i)
            if heredoc:
                heredocs.append(heredoc)
            i = j - 1
        elif c == "\n":
            for delim, _, strip in heredocs:
                found = heredoc_end(s, i + 1, delim, strip)
                if found:
                    i = found[1]
            heredocs = []
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unclosed $(")


def close_ansi_quote(s, i):
    """Index of the ' closing a $' opened just before i, where \\' does not close it. ValueError if unbalanced."""
    while i < len(s):
        if s[i] == "\\":
            i += 2
        elif s[i] == "'":
            return i
        else:
            i += 1
    raise ValueError("unclosed quote")


def close_double_quote(s, i):
    """Index of the " closing one opened just before i. ValueError if unbalanced."""
    while i < len(s):
        if s[i] == "\\":
            i += 2
        elif s[i] == '"':
            return i
        elif s.startswith("$(", i):
            i = close_paren(s, i + 2) + 1
        elif s[i] == "`":
            i = close_backtick(s, i + 1) + 1
        else:
            i += 1
    raise ValueError("unclosed quote")


def close_backtick(s, i):
    """Index of the backtick closing one opened just before i. ValueError if unbalanced."""
    while i < len(s) and s[i] != "`":
        i += 2 if s[i] == "\\" else 1
    if i >= len(s):
        raise ValueError("unclosed backtick")
    return i


def heredoc_end(s, start, delim, strip):
    """(body end, terminator line end) for a heredoc body starting at start, or None if unterminated."""
    k = start
    while k <= len(s):
        e = s.find("\n", k)
        e = len(s) if e < 0 else e
        line = s[k:e]
        if (line.lstrip("\t") if strip else line) == delim:
            return k, e
        k = e + 1
    return None


def parse(s, ps=False):
    """Split shell text into events: a list of Words per simple command, "(" and ")" around subshells,
    and the separators between commands (; & | && ||, a newline counts as ;).

    Substitutions come out before the command holding them, since they run first. ps: PowerShell,
    where backtick is the escape and backslash is a plain path character.
    """
    events, words, heredocs = [], [], []
    buf, quoted, dynamic, in_dq, drop_next = [], False, False, False, False
    escape = "`" if ps else "\\"

    def end_word():
        nonlocal buf, quoted, dynamic, drop_next
        if buf or quoted:
            if drop_next:  # a redirect target, not an argument
                drop_next = False
            else:
                words.append(Word("".join(buf), dynamic))
        buf, quoted, dynamic = [], False, False

    def end_command():
        nonlocal words, drop_next
        end_word()
        drop_next = False
        if words:
            events.append(words)
        words = []

    def nested(inner):
        events.extend(["(", *parse(inner, ps), ")"])

    def substitutions(body):
        k = 0
        while k < len(body):
            if body[k] == "\\":
                k += 2
            elif body.startswith("$(", k):
                j = close_paren(body, k + 2)
                nested(body[k + 2:j])
                k = j + 1
            elif body[k] == "`":
                j = close_backtick(body, k + 1)
                nested(body[k + 1:j])
                k = j + 1
            else:
                k += 1

    i, n = 0, len(s)
    while i < n:
        c = s[i]
        nxt = s[i + 1] if i + 1 < n else ""
        if c == escape:
            if nxt == "\n":
                i += 2
            elif in_dq and not ps and nxt not in '$`"\\':
                buf.append(c)
                i += 1
            else:
                buf.append(nxt)
                i += 2
        elif c == "'" and not in_dq:
            j = s.find("'", i + 1)
            if j < 0:
                raise ValueError("unclosed quote")
            buf.append(s[i + 1:j])
            quoted = True
            i = j + 1
        elif c == '"':
            in_dq = not in_dq
            quoted = True
            i += 1
        elif c == "`":
            j = close_backtick(s, i + 1)
            nested(s[i + 1:j].replace("\\`", "`"))
            buf.append(s[i:j + 1])
            dynamic = True
            i = j + 1
        elif c == "$" and nxt == "(":
            j = close_paren(s, i + 2)
            nested(s[i + 2:j])
            buf.append(s[i:j + 1])
            dynamic = True
            i = j + 1
        elif c == "$" and nxt == "'" and not in_dq and not ps:
            j = close_ansi_quote(s, i + 2)
            buf.append(s[i + 2:j].replace("\\'", "'"))
            quoted = True
            i = j + 1
        elif c == "$" and nxt == '"' and not in_dq:
            i += 1  # $"...": the quote branch takes it from here
        elif c == "$":
            if nxt and (nxt.isalnum() or nxt in "_{@*#?!-"):
                dynamic = True
            buf.append(c)
            i += 1
        elif in_dq:
            buf.append(c)
            i += 1
        elif c == "#" and not buf and not quoted:
            j = s.find("\n", i)
            i = n if j < 0 else j
        elif c == "<" and nxt == "<" and s[i + 2:i + 3] != "<":
            end_word()
            heredoc, i = read_heredoc(s, i)
            if heredoc:
                heredocs.append(heredoc)
        elif c in "<>" or (c == "&" and nxt == ">"):
            if "".join(buf).isdigit() and not quoted:  # the 2 in 2>&1
                buf = []
            end_word()
            i += 1
            while s[i:i + 1] and s[i:i + 1] in "<>&|":
                i += 1
            drop_next = True
        elif c in ";&|()\n":
            end_command()
            if c in "()":
                events.append(c)
            elif c in "&|" and nxt == c:
                events.append(c + c)
                i += 1
            elif c != "\n":
                events.append(c)
            elif not (events and events[-1] in ("&&", "||", "&", "|")):  # those carry over a newline
                events.append(";")
            i += 1
            if c == "\n":
                for delim, literal, strip in heredocs:
                    found = heredoc_end(s, i, delim, strip)
                    if found:  # unterminated: leave the lines to be read as commands
                        if not literal:
                            substitutions(s[i:found[0]])
                        i = found[1] + 1
                heredocs = []
        elif c.isspace():
            end_word()
            i += 1
        else:
            buf.append(c)
            i += 1
    if in_dq:
        raise ValueError("unclosed quote")
    end_command()
    return events


def command_name(text):
    name = re.split(r"[/\\]", text)[-1].lower()
    return name[:-4] if name.endswith(".exe") else name


def is_pr_create(args, counts=None):
    """Whether the arguments after `gh` mean `pr create`. An expansion could be anything, so it counts.
    With counts given, an expansion before `pr` counts only when counts(args, its index) is true."""
    want = ["pr", {"create", "new"}]
    after_flag = False
    for i, w in enumerate(args):
        if after_flag and w.dynamic:  # `-R "$REPO"`: the flag's value
            after_flag = False
        elif w.text.startswith("-"):  # also `--repo="$R"`
            after_flag = True
        elif w.dynamic:
            return counts is None or want[0] != "pr" or bool(counts(args, i))
        elif w.text == want[0] or (isinstance(want[0], set) and w.text in want[0]):
            want.pop(0)
            if not want:
                return True
            after_flag = False
        elif after_flag:  # the flag's value
            after_flag = False
        else:
            return False
    return False


def change_dir(args, cwd):
    """Directory after a cd: the target, cwd if it does not exist, None if it cannot be worked out."""
    args = [a for a in args if not (a.text.startswith("-") and len(a.text) > 1)]
    if not args:
        return os.path.expanduser("~")
    target = args[0].text
    if target == "-":
        return None
    if args[0].dynamic:
        if TOPLEVEL.search(target):
            if cwd is None:
                return None
            try:
                root = git_toplevel(cwd)
            except Exception:
                return None
            target = TOPLEVEL.sub(lambda _: root, target)
        target = os.path.expandvars(target)
        if "$" in target or "`" in target:
            return None
    target = os.path.expanduser(target)
    if not os.path.isabs(target) and cwd is None:
        return None
    new = os.path.normpath(os.path.join(cwd or "", target))
    return new if os.path.isdir(new) else cwd


def mentions_create(text):
    """Raw-text check, only for text run in a way the parser cannot follow (`$CMD`, piped into a shell)."""
    for part in re.split(r"[;&|\n]", text.replace("\\\n", " ")):
        at = 0
        for word in (GH_WORD, PR_WORDS, CREATE_WORDS):
            m = word.search(part, at)
            if not m:
                break
            at = m.end()
        else:
            return True
    return False


HIDDEN = "hidden"  # create_calls: a create that may hide in shell code the parser cannot read
API = "api"  # create_calls: a PR create through the GitHub API, whose body the gate cannot read
DEADLINE = None  # time.monotonic() by which git must answer; the gate sets it from its --budget

API_MENTION = re.compile(r"(?:repos|repositories)/\S*?pull|createPullRequest")  # raw text: loose on purpose
PULLS_PATH = re.compile(r"/(?:repos/[^/]+/[^/]+|repositories/[^/]+)/pulls/?")
Client = collections.namedtuple("Client", "method_short method_long data_short data_long value_short value_long abbrev")
REQUESTS = {  # how each client sets its method and sends data. value_short/value_long: the other flags that take
    # a value (gh's whole list, so a GET in a flag's value is never read as a flag); abbrev: the client takes a
    # long flag's unambiguous prefix (`--meth=POST`)
    "gh": Client("X", ("--method",), "fF", ("--field", "--raw-field", "--input"), "Hpqt",
                 ("--header", "--preview", "--jq", "--template", "--hostname", "--cache"), False),
    "curl": Client("X", ("--request",), "dFT", ("--data", "--json", "--form", "--upload-file", "--expand-data"),
                   "AbcCDeEHKmortuUwxyYzQ", (), True),
    "wget": Client("", ("--method",), "", ("--post-data", "--post-file", "--body-data", "--body-file"), "", (),
                   True),
}


def mentions_api_create(text):
    """Raw-text check, as mentions_create, for code the parser cannot read: a pulls endpoint or a GraphQL create."""
    return bool(API_MENTION.search(text))


def is_pulls(text):
    """Whether a URL or endpoint names a PR collection (`repos/o/r/pulls`, `repositories/<id>/pulls`), after the
    dot segments and doubled slashes curl and wget resolve. A curl glob (`{pulls}`, `pull[s-s]`) counts; gh's
    own placeholders (`{owner}`, `{repo}`, `{branch}`) are plain segments."""
    m = re.search(r"(?:^|/)(?:repos|repositories)/", text)
    if not m:
        return False
    path = re.split(r"[?#]", text[m.start():].lstrip("/"), maxsplit=1)[0]
    path = re.sub(r"\{(?:owner|repo|branch)\}", "x", path)
    if re.search(r"[{\[]", path):
        return True
    return bool(PULLS_PATH.fullmatch(posixpath.normpath("/" + path)))


def long_flag(flag, names, abbrev):
    """Whether flag (`--x`, before any `=`) is one of names, or with abbrev a prefix of one."""
    return any(flag == n or (abbrev and len(flag) >= 4 and n.startswith(flag)) for n in names)


def request(name, args):
    """(methods, sends_data) for a gh api, curl or wget request: every method Word it sets and whether it sends
    data. A value flag's next word is skipped, so it is never read as a flag."""
    c = REQUESTS[name]
    methods, data = [], False
    k = 0
    while k < len(args):
        w = args[k]
        t, following, takes_next = w.text, (args[k + 1] if k + 1 < len(args) else None), False
        if t.startswith("--"):
            flag, eq, value = t.partition("=")
            if long_flag(flag, c.method_long, c.abbrev):
                methods.append(Word(value, w.dynamic) if eq else following)
                takes_next = not eq
            elif flag.startswith(c.data_long) or long_flag(flag, c.data_long, c.abbrev):
                data, takes_next = True, not eq
            elif long_flag(flag, c.value_long, False):
                takes_next = not eq
        elif t.startswith("-") and len(t) > 1:  # a short flag or a cluster (`-sSXPOST`)
            for i, ch in enumerate(t[1:], 1):
                rest = t[i + 1:].removeprefix("=")  # gh's flag parser takes `-X=POST` as POST
                if c.method_short and ch == c.method_short:
                    methods.append(Word(rest, w.dynamic) if rest else following)
                elif ch in c.data_short:
                    data = True
                elif ch not in c.value_short:
                    continue
                takes_next = not rest  # the rest of the word, or the next word, is this flag's value
                break
        k += 1 + takes_next
    return [m for m in methods if m is not None], data


def api_create(name, args):
    """Whether gh api (args after `api`), curl or wget creates a PR. Fail closed: any method but GET or HEAD
    (one set at run time too) counts, and so does data, except gh's fields with an explicit GET (a query)."""
    if any("createPullRequest" in a.text for a in args):  # GraphQL mutation
        return True
    if not any(is_pulls(a.text) for a in args):
        return False
    methods, data = request(name, args)
    if any(m.dynamic or m.text.upper() not in ("GET", "HEAD") for m in methods):
        return True  # curl's --next groups each set their own: any one that creates counts
    return data and not (name == "gh" and methods)


def count_creates(text):
    """How many parts of the raw text (split at ; & | and newlines) mention a create, as mentions_create
    reads them."""
    return sum(mentions_create(part) for part in re.split(r"[;&|\n]", text.replace("\\\n", " ")))


def create_calls(command, cwd, ps=False):
    """(directory, args) for each `gh pr create` in command. The directory is None when it cannot be worked
    out; args (the Words after `gh`) is HIDDEN for shell code the parser cannot read (`eval "$X"`,
    `bash -c "$X"`, a pipe into a shell) and None for an unknown program (`"$EDITOR" x`), each only when the
    raw text mentions a create. args is API for a create through the GitHub API (`gh api`, curl, wget)."""
    found = []
    hidden = []  # directories of shell code the parser cannot read
    bare = re.sub(r"[\"'\\`]", "", command)  # the text with quotes and escapes removed, for the word check
    read_mentions = [0]  # API mentions inside calls the parser read as API reads

    def opaque(cwd, args=None):
        if args == HIDDEN:
            hidden.append(cwd)
        if mentions_create(command):
            found.append((cwd, args))

    def api_call(cwd, name, args):
        if api_create(name, args):
            found.append((cwd, API))
        else:
            read_mentions[0] += sum(len(API_MENTION.findall(a.text)) for a in args)

    def walk(events, cwd):
        stack = []
        chained = False  # the current command runs only if an && or || before it allowed it
        unsure = False  # a cd that may not have run: true only to the end of this && chain
        case_depth = 0
        for k, event in enumerate(events):
            if event == "(":
                stack.append((cwd, chained, unsure))
                chained = unsure = False
            elif event == ")":
                if stack:
                    cwd, chained, unsure = stack.pop()
            elif event in ("&&", "||"):
                chained = True
            elif isinstance(event, str):
                if unsure:
                    cwd = None
                chained = unsure = False
            else:
                head = next((w.text for w in event if w.text not in KEYWORDS), "")
                case_depth = max(0, case_depth + (head == "case") - (head == "esac"))
                before = cwd
                cwd = visit(event, cwd)
                if cwd != before:
                    if k + 1 < len(events) and events[k + 1] in ("&", "|"):  # ran in a subshell
                        cwd = before
                    elif chained or case_depth > 0 or event[0].text in BRANCH_KEYWORDS:
                        unsure = True
        return None if unsure else cwd

    def visit(words, cwd):
        """Handle one simple command; return the directory the next one runs in."""
        while True:
            while words and (words[0].text in KEYWORDS or ASSIGNMENT.match(words[0].text)):
                words = words[1:]
            if not words:
                return cwd
            if command_name(words[0].text) not in WRAPPERS:
                break
            rest = words[1:]
            if command_name(words[0].text) == "command" and rest and rest[0].text in ("-v", "-V"):
                return cwd  # only looks the name up
            # A cd counts only as the wrapped command itself: in `time make cd` it is an argument.
            first = next((k for k, w in enumerate(rest) if not w.text.startswith("-")), None)
            words = next((rest[k:] for k, w in enumerate(rest)
                          if w.dynamic or command_name(w.text) in {"gh", "eval"} | SHELLS | HTTP_CLIENTS
                          or (k == first and command_name(w.text) in CD_COMMANDS)), [])
        name, args = command_name(words[0].text), words[1:]
        if name == "gh":
            if is_pr_create(args):
                found.append((cwd, args))
            elif args and args[0].text == "api":
                api_call(cwd, name, args[1:])
        elif name in HTTP_CLIENTS:
            api_call(cwd, name, args)
        elif name == "eval":
            if any(a.dynamic for a in args):
                opaque(cwd, HIDDEN)
            return walk(parse(" ".join(a.text for a in args), ps), cwd)
        elif name in SHELLS:
            for k, a in enumerate(args):
                if SHELL_C_FLAG.match(a.text) and k + 1 < len(args):
                    script = [w for w in args[k + 1:] if w.text != "--"]
                    is_ps = name in ("pwsh", "powershell")  # takes the rest as the script; others one word
                    script = script if is_ps else script[:1]
                    if any(w.dynamic for w in script):
                        opaque(cwd, HIDDEN)
                    walk(parse(" ".join(w.text for w in script), is_ps), cwd)
                    return cwd
            if all(a.text.startswith("-") for a in args) or any(SHELL_S_FLAG.match(a.text) for a in args):
                opaque(cwd, HIDDEN)  # reads its script from stdin
        elif name in ("popd", "pop-location"):
            return None
        elif name in CD_COMMANDS:
            return change_dir(args, cwd)
        elif words[0].dynamic:  # `$CMD ...`: unknown command. `$VENV/bin/x` names a program.
            if "/" not in words[0].text:
                opaque(cwd)
            # `"$CURL" -d x .../pulls`: the program is unknown, so read its args as each client would
            if (api_create("gh", args[1:]) if args and args[0].text == "api"
                    else any(api_create(client, args) for client in REQUESTS)):
                found.append((cwd, API))
            # `$GH pr create`: the program is unknown, its args are not. `$S/inst.sh` names a file that is
            # not gh. For `$ADB $DEV shell ...`, see unknown_args.
            program = command_name(words[0].text)
            if (program == "gh" or not re.fullmatch(r"[\w.+-]+", program)) and is_pr_create(
                    args, counts=lambda a, i: unknown_args(words[0], a, i)):
                found.append((cwd, args))
            carried_shell(args, cwd)
        elif name not in PRINTERS:
            carried_shell(args, cwd)
        return cwd

    def unknown_args(program, args, i):
        """Whether the expansion args[i], run by an unknown program, may hold `pr create`. It does when the text
        names gh or a shell, has pr and create or new (read unquoted), or the word runs a command. Otherwise a
        plain word after it that is not a flag's value (`$ADB $DEV shell ...`) shows it is not `gh pr create`,
        which takes no such words; without one, it may be. A word that may vanish (`{,}`, `no*`) shows nothing."""
        if GH_WORD.search(bare) or (PR_WORDS.search(bare) and CREATE_WORDS.search(bare)):
            return True
        if SUBSTITUTION.search(program.text) or SUBSTITUTION.search(args[i].text):
            return True
        if any(command_name(t) in SHELLS or SHELL_C_FLAG.match(t) for t in re.findall(r"[^\s;&|()<>]+", bare)):
            return True  # `X="sh -c"; $X "$CMD" name`: the plain word may be $0
        after_flag = False
        for w in args[i + 1:]:
            if w.text.startswith("-"):
                after_flag = "=" not in w.text
            elif after_flag:  # the flag's value
                after_flag = False
            elif not w.dynamic and w.text and not re.search(r"[*?\[{]", w.text):
                return w.text in ("pr", "create", "new")
        return True

    def carried_shell(args, cwd):
        """A runner this gate does not know, such as `docker exec c sh -c "..."`."""
        for k, a in enumerate(args[:-1]):
            if command_name(a.text) in SHELLS and SHELL_C_FLAG.match(args[k + 1].text):
                visit(args[k:], cwd)
                return

    walk(parse(command, ps), cwd)
    # Code the parser cannot read may build an API create from text anywhere in the command (`X='curl -d x
    # .../pulls'; eval "$X"`). Mentions the parser already read as API reads do not count.
    if hidden and len(API_MENTION.findall(command)) > read_mentions[0]:
        found.append((hidden[0], API))
    return found


BODY_FLAGS = {"--body": "text", "-b": "text", "--body-file": "file", "-F": "file"}
FILL_FLAGS = {"--fill", "-f", "--fill-first", "--fill-verbose"}
VALUE_FLAGS = {"-t", "--title", "-B", "--base", "-H", "--head", "-R", "--repo", "-a", "--assignee", "-l", "--label",
               "-m", "--milestone", "-p", "--project", "-r", "--reviewer", "-T", "--template"}
# The body can still change after the hook runs: in the browser, in $EDITOR, or from a recover file.
INTERACTIVE_FLAGS = {"-w", "--web", "-e", "--editor", "--recover"}


BOOL_SHORT = set("df")  # gh pr create's shorthands that take no value (w and e: INTERACTIVE_FLAGS)
VALUE_SHORT = {f[1] for f in VALUE_FLAGS if len(f) == 2}


def body_flag(text):
    """(kind, value text or None) for a body flag word (`--body`, `--body=x`, `-b`, `-bx`, `-b=x`, and the
    same for --body-file and -F), else (None, None). A None value means the value is the next word.
    A cluster of shorthands is walked as gh's flag parser does: `-db x` is `-d -b x`. A cluster ending in
    another flag that takes a value gives ("value", rest or None); one with a letter gh would refuse, or one
    the parser cannot place, gives ("unknown", None)."""
    name, eq, rest = text.partition("=")
    if text.startswith("--") and eq and name in BODY_FLAGS:
        return BODY_FLAGS[name], rest
    if text in BODY_FLAGS:
        return BODY_FLAGS[text], None
    if text.startswith("-") and not text.startswith("--") and len(text) > 2:
        for k, ch in enumerate(text[1:], 1):
            tail = text[k + 1:]
            tail = tail[1:] if tail.startswith("=") else tail
            if ch in ("b", "F"):
                return BODY_FLAGS["-" + ch], tail or None
            if ch in VALUE_SHORT:
                return "value", tail or None
            if ch in ("w", "e"):
                return "interactive", None
            if ch not in BOOL_SHORT:
                return "unknown", None
        return None, None  # only switches (`-dw`)
    return None, None


def pr_body(args):
    """Where a create's PR body comes from: {"kind": K} plus "value" (a Word) for text and file.

    K: "text" (--body/-b), "file" (--body-file/-F), "stdin" (--body-file -), "fill" (--fill and no body flag),
    "none" (no body flag), or "unknown" (args is None, or an argument that expands at run time outside a flag's
    value, since it could become another body flag). gh reads --body-file after --body and keeps it, so a body file wins; among flags of one kind the last wins.
    The value of another flag (`--title '-bx'`) is skipped, as gh's flag parser gives it to that flag.
    """
    if args is None:
        return {"kind": "unknown"}
    last, fill, dynamic, interactive = {}, False, False, False
    k = 0
    while k < len(args):
        word = args[k]
        kind, value = body_flag(word.text)
        if kind == "interactive" or word.text in INTERACTIVE_FLAGS or word.text.startswith("--recover="):
            interactive = True
            k += word.text == "--recover"  # its file
        elif kind == "unknown":
            dynamic = True  # a cluster gh would read in a way the parser does not follow
        elif kind == "value":
            k += value is None  # another flag's value, in this word or the next
        elif kind:
            if value is None and k + 1 < len(args):
                k += 1
                value = args[k]
            elif value is not None:
                value = Word(value, word.dynamic)
            if value is None:
                last.pop(kind, None)  # a body flag with no value: gh refuses it
            elif kind == "file" and value.text == "-" and not value.dynamic:
                last[kind] = {"kind": "stdin"}
            else:
                last[kind] = {"kind": kind, "value": value}
        elif word.text in FILL_FLAGS:
            fill = True
        elif word.text in VALUE_FLAGS:
            k += 1  # its value, whatever it looks like
        elif word.dynamic and not (word.text.startswith("-") and "=" in word.text
                                   and not re.search(r"[$`]", word.text.partition("=")[0])):  # `--label=$L`
            dynamic = True  # `$EXTRA` could expand to another body flag at run time
        k += 1
    if interactive:
        return {"kind": "interactive"}
    if dynamic:
        return {"kind": "unknown"}
    return last.get("file") or last.get("text") or {"kind": "fill" if fill else "none"}


def git_toplevel(cwd):
    timeout = 30 if DEADLINE is None else max(0.01, min(30, DEADLINE - time.monotonic()))
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=cwd, capture_output=True,
                       text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout.strip()
