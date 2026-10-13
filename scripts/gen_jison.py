#!/usr/bin/env python3
"""Turn one of mermaid's jison parsers into MoonBit tables.

`scripts/extract_jison.js` reads the generated parser out of the mermaid
bundle; this script writes its LALR table, productions and lexer rules as a
`@jison.Grammar` value. Lexer actions that only switch start conditions and
return a token are translated; anything else becomes a numbered `Custom`
hook, listed with its JavaScript in the generated file, to be implemented by
hand next to it. The parser's semantic actions are always ported by hand:
`--actions FILE` dumps their JavaScript for reference.

Usage: python3 scripts/gen_jison.py <grammar> <output.mbt> [--ident NAME]
                                    [--actions FILE] && moon fmt
"""

import argparse
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent


def mbt_string(text):
    out = []
    for char in text:
        if char == "\\":
            out.append("\\\\")
        elif char == '"':
            out.append('\\"')
        elif char == "\n":
            out.append("\\n")
        elif char == "\r":
            out.append("\\r")
        elif char == "\t":
            out.append("\\t")
        elif ord(char) < 0x20 or ord(char) == 0x7F:
            out.append("\\u{%x}" % ord(char))
        else:
            out.append(char)
    return '"' + "".join(out) + '"'


def split_cases(action):
    """Map each `case N:` of a generated switch to its body."""
    body = action[action.index("switch"):]
    parts = re.split(r"\n\s*case (\d+):", body)
    cases, pending = {}, []
    for index in range(1, len(parts), 2):
        number, text = int(parts[index]), parts[index + 1]
        pending.append(number)
        if text.strip():
            for label in pending:
                cases[label] = text
            pending = []
    return cases


def statements(body):
    """Split a case body into top-level statements."""
    out, depth, current = [], 0, ""
    quote = None
    for char in body:
        current += char
        if quote:
            if char == quote and not current.endswith("\\" + quote):
                quote = None
            continue
        if char in "\"'`":
            quote = char
        elif char in "({[":
            depth += 1
        elif char in ")}]":
            depth -= 1
            if depth == 0 and char == "}":
                out.append(current.strip())
                current = ""
        elif char == ";" and depth == 0:
            out.append(current.strip())
            current = ""
    if current.strip():
        out.append(current.strip())
    return [s for s in out if s and s != ";"]


class LexActions:
    def __init__(self, token_names):
        self.token_names = token_names
        self.customs = []

    def custom(self, javascript):
        self.customs.append(javascript)
        return f"Custom({len(self.customs) - 1})"

    def simple(self, statement):
        statement = statement.rstrip(";").strip()
        match = re.fullmatch(r'this\.(?:begin|pushState)\("([^"]*)"\)', statement)
        if match:
            return f"Push({mbt_string(match.group(1))})"
        if statement == "this.popState()":
            return "Pop"
        match = re.fullmatch(r"return (\d+)", statement)
        if match:
            return f"Return({mbt_string(self.token_names[int(match.group(1))])})"
        match = re.fullmatch(r"return (\"[^\"]*\"|'[^']*')", statement)
        if match:
            return f"Return({mbt_string(match.group(1)[1:-1])})"
        return None

    def translate(self, body):
        ops = []
        for statement in statements(body):
            bare = statement.rstrip(";").strip()
            if bare == "break" or bare.startswith("yy.getLogger()"):
                continue
            op = self.simple(statement)
            if op:
                ops.append(op)
                if op.startswith("Return"):
                    break
                continue
            # `if (test) { one simple statement }`: a hook decides whether
            # the statement runs.
            match = re.fullmatch(r"if \((.*)\) \{\s*(.*?);?\s*\}", bare, re.S)
            inner = self.simple(match.group(2)) if match else None
            if inner:
                ops.append(self.custom(f"if ({match.group(1)})  // SkipNext when false"))
                ops.append(inner)
                continue
            ops.append(self.custom(re.sub(r"\s+", " ", bare)))
        return ops


def generate(grammar, ident):
    symbols = grammar["symbols"]
    count = max(symbols.values()) + 1
    names = [""] * count
    for name, number in symbols.items():
        names[number] = name
    terminals = sorted(int(number) for number in grammar["terminals"])
    for number, name in grammar["terminals"].items():
        names[int(number)] = name

    productions = []
    for production in grammar["productions"]:
        productions += production if isinstance(production, list) else [0, 0]

    table = []
    for state in grammar["table"]:
        cells = sorted((int(symbol), action) for symbol, action in state.items())
        table.append(len(cells))
        for symbol, action in cells:
            if isinstance(action, list):
                table += [symbol, action[0], action[1] if len(action) > 1 else 0]
            else:
                table += [symbol, 0, action]

    defaults = []
    for state, action in sorted((int(s), a) for s, a in grammar["defaultActions"].items()):
        defaults += [state, action[1]]

    lexer = grammar["lexer"]
    actions = LexActions(names)
    cases = split_cases(lexer["action"])
    lex_ops = [actions.translate(cases.get(index, "")) for index in range(len(lexer["rules"]))]

    def ints(values, indent="    ", width=24):
        rows = [", ".join(str(v) for v in values[i:i + width]) for i in range(0, len(values), width)]
        return "\n".join(f"{indent}{row}," for row in rows)

    lines = [
        f"// Generated by scripts/gen_jison.py from mermaid's {grammar['name']}.jison.",
        "// Do not edit by hand.",
    ]
    if actions.customs:
        lines += ["//", "// Custom lexer hooks, with the JavaScript they stand for:"]
        lines += [f"//   {index}: {javascript}" for index, javascript in enumerate(actions.customs)]
    lines += [
        "",
        "///|",
        f"let {ident} : @jison.Grammar = @jison.Grammar::new(",
        "  symbols=[",
        *[f"    {mbt_string(name)}," for name in names],
        "  ],",
        "  terminals=[",
        ints(terminals),
        "  ],",
        "  productions=[",
        ints(productions),
        "  ],",
        "  table=[",
        ints(table),
        "  ],",
        "  default_actions=[",
        ints(defaults),
        "  ],",
        "  rules=[",
        *[f"    ({mbt_string(rule['source'])}, {mbt_string(rule['flags'])})," for rule in lexer["rules"]],
        "  ],",
        "  conditions={",
        *[f"    {mbt_string(name)}: [{', '.join(str(r) for r in condition['rules'])}],"
          for name, condition in lexer["conditions"].items()],
        "  },",
        "  lex_ops=[",
        *[f"    [{', '.join(ops)}]," for ops in lex_ops],
        "  ],",
        f"  flex={'true' if lexer['options'].get('flex') else 'false'},",
        ")",
        "",
    ]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("grammar")
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--ident", help="name of the generated value (default: <grammar>_grammar)")
    parser.add_argument("--actions", type=pathlib.Path, help="write the JavaScript semantic actions here")
    args = parser.parse_args()

    out = subprocess.run(["node", str(ROOT / "scripts" / "extract_jison.js"), args.grammar],
                         capture_output=True, text=True, check=True).stdout
    grammar = json.loads(out)
    ident = args.ident or re.sub(r"\W", "_", args.grammar).lower() + "_grammar"
    args.output.write_text(generate(grammar, ident))
    print(f"wrote {args.output}")
    if args.actions:
        names = {number: name for name, number in grammar["symbols"].items()}
        rules = []
        for index, production in enumerate(grammar["productions"]):
            if isinstance(production, list):
                rules.append(f"// {index}: {names.get(production[0], production[0])} ({production[1]} symbols)")
        args.actions.write_text("\n".join(rules) + "\n\n" + grammar["action"] + "\n")
        print(f"wrote {args.actions}")


if __name__ == "__main__":
    main()
