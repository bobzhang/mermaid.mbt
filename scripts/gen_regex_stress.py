#!/usr/bin/env python3
"""Write internal/jsregex/gen_patterns_test.mbt: every regular expression the
port compiles from a literal (the lexer rules of the jison and chevrotain
grammars, Langium terminals, marked's rules, the diagrams' own patterns) and
instances of those marked builds at run time, each matched against long
repetitive subjects. The matcher has no recursion that grows with the subject;
the test checks that on every backend.

Usage: scripts/gen_regex_stress.py
Needs node, to leave out what V8 does not compile (text the extraction takes
for a pattern by mistake).
"""

import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "internal" / "jsregex" / "gen_patterns_test.mbt"
STRING = r'"((?:[^"\\\n]|\\.)*)"'
# What compiles its first argument as a pattern; `multiline` adds `gm`.
CALLS = r'(?:Regex::compile|md_rule|\bRegex|\bregex|\bmultiline)\(|terminal_token\(\s*"[^"]*",'


def unescape(body):
    """The value of a MoonBit string literal's body."""
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        n = body[i + 1]
        if n in "ntrb":
            out.append({"n": "\n", "t": "\t", "r": "\r", "b": "\b"}[n])
            i += 2
        elif n == "u" and body[i + 2] == "{":
            j = body.index("}", i)
            out.append(chr(int(body[i + 3:j], 16)))
            i = j + 1
        elif n == "x":
            out.append(chr(int(body[i + 2:i + 4], 16)))
            i += 4
        else:
            out.append(n)
            i += 2
    return "".join(out)


def literal_at(text, pos):
    """A string literal at `pos`: `"..."`, `#|` lines, either in parentheses.
    Returns its value and where it ends, or None when the argument is an
    expression (a pattern built at run time)."""
    pos = re.compile(r"\s*").match(text, pos).end()
    if text.startswith("(", pos):
        value, end = literal_at(text, pos + 1)
        if value is None:
            return None, pos
        closing = re.compile(r"\s*,?\s*\)").match(text, end)
        return (value, closing.end()) if closing else (None, pos)
    if text.startswith("#|", pos):
        lines = []
        while m := re.compile(r"[ \t]*#\|([^\n]*)\n?").match(text, pos):
            lines.append(m.group(1))
            pos = m.end()
        return "\n".join(lines), pos
    m = re.compile(STRING).match(text, pos)
    if not m:
        return None, pos
    after = re.compile(r"\s*\+").match(text, m.end())
    if after:
        return None, pos
    return unescape(m.group(1)), m.end()


def extract():
    pairs = set()
    for path in sorted(ROOT.rglob("*.mbt")):
        parts = path.relative_to(ROOT).parts
        if parts[0] in (".repos", "_build", "target") or path.name.endswith("test.mbt"):
            continue
        text = path.read_text()
        for m in re.finditer(CALLS, text):
            value, end = literal_at(text, m.end())
            if value is None:
                continue
            flags = "gm" if m.group(0).startswith("multiline") else ""
            given = re.compile(r"\s*,\s*(?:flags\s*=\s*)?" + STRING).match(text, end)
            if given:
                flags = unescape(given.group(1))
            pairs.add((value, flags))
        for block in re.finditer(r"rules=\[(.*?)\n  \]", text, re.S):
            for rule in re.finditer(r"\(\s*" + STRING + r",\s*" + STRING + r"\s*\)", block.group(1)):
                pairs.add((unescape(rule.group(1)), unescape(rule.group(2))))
    # marked's list tokenizer builds these from the bullet and the indent.
    for marker in ("\\-", "\\*", "\\d{1,9}\\.", "\\d{1,9}\\)"):
        pairs.add(("^( {0,3}" + marker + ")((?:[\t ][^\\n]*)?(?:\\n|$))", ""))
    for up_to in "0123":
        pairs.add(("^ {0," + up_to + "}(?:[*+-]|\\d{1,9}[.)])((?:[ \t][^\\n]*)?(?:\\n|$))", ""))
        pairs.add(("^ {0," + up_to + "}((?:- *){3,}|(?:_ *){3,}|(?:\\* *){3,})(?:\\n+|$)", ""))
        pairs.add(("^ {0," + up_to + "}(?:```|~~~)", ""))
        pairs.add(("^ {0," + up_to + "}#", ""))
        pairs.add(("^ {0," + up_to + "}<(?:[a-z].*>|!--)", "i"))
    return sorted(pairs)


def valid(pairs):
    script = r"""
const ps = JSON.parse(require("fs").readFileSync(0, "utf8"));
console.log(JSON.stringify(ps.map(([s, f]) => {
  try { new RegExp(s, f.replace("g", "")); return true; } catch (e) { return false; }
})));"""
    done = subprocess.run(["node", "-e", script], input=json.dumps(pairs), capture_output=True, text=True, check=True)
    return [pair for pair, ok in zip(pairs, json.loads(done.stdout)) if ok]


def mbt(text):
    """A MoonBit string literal for `text`."""
    out = []
    for c in text:
        if c in "\\\"":
            out.append("\\" + c)
        elif c in "\n\r\t":
            out.append({"\n": "\\n", "\r": "\\r", "\t": "\\t"}[c])
        elif ord(c) < 0x20 or 0x7f <= ord(c) < 0xa0 or c in "\u2028\u2029":
            out.append("\\u{%x}" % ord(c))
        else:
            out.append(c)
    return '"' + "".join(out) + '"'


def main():
    pairs = valid(extract())
    lines = [
        "// Generated by scripts/gen_regex_stress.py, DON'T EDIT IT",
        "",
        "///|",
        "/// Every pattern the port compiles from a literal, with its flags.",
        "let patterns : Array[(String, String)] = [",
    ]
    for source, flags in pairs:
        lines.append(f"  ({mbt(source)}, {mbt(flags)}),")
    lines += ["]", ""]
    OUT.write_text("\n".join(lines))
    print(f"{len(pairs)} patterns written to {OUT.relative_to(ROOT)}")


main()
