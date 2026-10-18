#!/usr/bin/env python3
"""Translate mermaid's theme classes into MoonBit.

Each `packages/mermaid/src/themes/theme-<name>.js` defines a `Theme` class
whose constructor and `updateColors` method are long runs of assignments in a
small JavaScript subset. This script parses that subset and emits
`theme/gen_<name>.mbt`, built on the dynamic helpers in `theme/js.mbt`.

Usage: python3 scripts/gen_themes.py [path/to/mermaid] && moon fmt
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
THEMES = [
    "base",
    "dark",
    "default",
    "forest",
    "neutral",
    "neo",
    "neo-dark",
    "redux",
    "redux-dark",
    "redux-color",
    "redux-dark-color",
]

# Constants the theme files import from erDiagram-oldHardcodedValues.ts.
CONSTANTS = {
    "oldAttributeBackgroundColorOdd": "#ffffff",
    "oldAttributeBackgroundColorEven": "#f2f2f2",
}

# Helper calls that can raise `@color.ColorError`.
RAISING = re.compile(r"\b(adjust|darken|lighten|invert|is_dark|mk_border|\w+_update_colors)\(")

TOKEN = re.compile(
    r"""
    (?P<ws>\s+|//[^\n]*|/\*.*?\*/)
  | (?P<num>\d+\.\d+|\.\d+|\d+)
  | (?P<str>'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")
  | (?P<id>[A-Za-z_$][A-Za-z0-9_$]*)
  | (?P<op>===|!==|=>|\?\?|\?\.|\|\||&&|\+\+|[-+*/%(){}\[\];,.:?=<>!])
    """,
    re.S | re.X,
)


def tokenize(src):
    out, pos = [], 0
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            raise SyntaxError(f"unexpected character {src[pos:pos + 20]!r}")
        pos = m.end()
        if m.lastgroup != "ws":
            out.append((m.lastgroup, m.group()))
    out.append(("eof", ""))
    return out


def mbt_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def mbt_number(value):
    text = repr(float(value))
    return text


class Parser:
    """Recursive-descent parser that emits MoonBit source directly."""

    def __init__(self, tokens, ident):
        self.toks = tokens
        self.ident = ident
        self.i = 0
        self.locals = [set()]

    # -- token helpers ------------------------------------------------------
    def peek(self, offset=0):
        return self.toks[self.i + offset]

    def at(self, value):
        return self.peek()[1] == value and self.peek()[0] in ("op", "id")

    def eat(self, value=None):
        tok = self.peek()
        if value is not None and tok[1] != value:
            context = " ".join(t[1] for t in self.toks[self.i:self.i + 8])
            raise SyntaxError(f"expected {value!r}, found {tok[1]!r} near: {context}")
        self.i += 1
        return tok

    def is_local(self, name):
        return any(name in scope for scope in self.locals)

    # -- statements ---------------------------------------------------------
    def block(self, indent):
        self.eat("{")
        self.locals.append(set())
        lines = []
        while not self.at("}"):
            lines.extend(self.statement(indent))
        self.eat("}")
        self.locals.pop()
        return lines

    def statement(self, indent):
        pad = "  " * indent
        if self.at("const") or self.at("let"):
            self.eat()
            name = self.eat()[1]
            self.eat("=")
            value = self.expr()
            self.eat(";")
            self.locals[-1].add(name)
            return [f"{pad}let {snake(name)} : Json = {value}"]
        if self.at("for"):
            self.eat()
            self.eat("(")
            self.eat("let")
            var = self.eat()[1]
            self.eat("=")
            start = self.expr()
            self.eat(";")
            self.eat(var)
            self.eat("<")
            end = self.expr()
            self.eat(";")
            self.eat(var)
            self.eat("++")
            self.eat(")")
            self.locals.append({var})
            body = self.block(indent + 1)
            self.locals.pop()
            name = snake(var)
            return [
                f"{pad}for {name}_ in to_int({start})..<loop_end({end}) {{",
                f"{pad}  let {name} = num({name}_.to_double())",
                *body,
                f"{pad}}}",
            ]
        if self.at("if"):
            self.eat()
            self.eat("(")
            cond = self.expr()
            self.eat(")")
            then = self.block(indent + 1)
            lines = [f"{pad}if truthy({cond}) {{", *then]
            if self.at("else"):
                self.eat()
                other = self.block(indent + 1)
                lines += [f"{pad}}} else {{", *other]
            return lines + [f"{pad}}}"]
        if self.at("this") and self.peek(1)[1] == "." and self.peek(3)[1] == "(":
            self.eat()
            self.eat(".")
            method = self.eat()[1]
            self.eat("(")
            self.eat(")")
            self.eat(";")
            if method != "updateColors":
                raise SyntaxError(f"unsupported method call {method}")
            return [f"{pad}{self.ident}_update_colors(t)"]
        if self.peek()[0] == "id" and self.is_local(self.peek()[1]) and self.peek(2)[1] == "forEach":
            array = snake(self.eat()[1])
            self.eat(".")
            self.eat("forEach")
            self.eat("(")
            self.eat("(")
            item = self.eat()[1]
            self.eat(",")
            index = self.eat()[1]
            self.eat(")")
            self.eat("=>")
            self.locals.append({item, index})
            body = self.block(indent + 1)
            self.locals.pop()
            self.eat(")")
            self.eat(";")
            return [
                f"{pad}for {snake(index)}_, {snake(item)} in to_array({array}) {{",
                f"{pad}  let {snake(index)} = num({snake(index)}_.to_double())",
                *body,
                f"{pad}}}",
            ]
        # Assignment to a theme variable.
        self.eat("this")
        key = self.property_key()
        self.eat("=")
        value = self.expr()
        self.eat(";")
        return [f"{pad}t.set({key}, {value})"]

    def property_key(self):
        """Parse `.name` or `[expr]` and return a MoonBit `String` expression."""
        if self.at("."):
            self.eat()
            return mbt_string(self.eat()[1])
        self.eat("[")
        key = self.expr()
        self.eat("]")
        return f"to_string({key})"

    # -- expressions --------------------------------------------------------
    def expr(self):
        cond = self.logical_or()
        if self.at("?"):
            self.eat()
            then = self.expr()
            self.eat(":")
            other = self.expr()
            return f"(if truthy({cond}) {{ {then} }} else {{ {other} }})"
        return cond

    def logical_or(self):
        left = self.logical_and()
        while self.at("||") or self.at("??"):
            op = self.eat()[1]
            right = self.logical_and()
            name = "or_else" if op == "||" else "nullish"
            left = f"{name}({left}, () => {right})"
        return left

    def logical_and(self):
        left = self.equality()
        while self.at("&&"):
            self.eat()
            right = self.equality()
            left = f"and_then({left}, () => {right})"
        return left

    def equality(self):
        left = self.additive()
        while self.at("===") or self.at("!=="):
            op = self.eat()[1]
            right = self.additive()
            test = "==" if op == "===" else "!="
            left = f"boolean({left} {test} {right})"
        return left

    def additive(self):
        left = self.multiplicative()
        while self.at("+") or self.at("-"):
            op = self.eat()[1]
            right = self.multiplicative()
            left = f"{'add' if op == '+' else 'sub'}({left}, {right})"
        return left

    def multiplicative(self):
        left = self.unary()
        while self.at("*") or self.at("%"):
            op = self.eat()[1]
            right = self.unary()
            left = f"{'mul' if op == '*' else 'rem'}({left}, {right})"
        return left

    def unary(self):
        if self.at("-") or self.at("+"):
            op = self.eat()[1]
            if self.peek()[0] == "num":
                value = self.eat()[1]
                return f"num({'-' if op == '-' else ''}{mbt_number(value)})"
            operand = self.unary()
            return f"neg({operand})" if op == "-" else operand
        return self.postfix()

    def postfix(self):
        value = self.primary()
        while True:
            if self.at("?.") or self.at("."):
                self.eat()
                name = self.eat()[1]
                value = f"length({value})" if name == "length" else f"field({value}, {mbt_string(name)})"
            elif self.at("["):
                self.eat()
                index = self.expr()
                self.eat("]")
                value = f"index({value}, {index})"
            else:
                return value

    def primary(self):
        kind, text = self.peek()
        if kind == "num":
            self.eat()
            return f"num({mbt_number(text)})"
        if kind == "str":
            self.eat()
            return f"str({mbt_string(js_unescape(text))})"
        if text == "(":
            self.eat()
            value = self.expr()
            self.eat(")")
            return f"({value})"
        if text == "{":
            return self.object_literal()
        if text == "[":
            self.eat()
            items = []
            while not self.at("]"):
                items.append(self.expr())
                if self.at(","):
                    self.eat()
            self.eat("]")
            return f"Json::array([{', '.join(items)}])"
        if text == "this":
            self.eat()
            return f"t.get({self.property_key()})"
        if kind == "id":
            self.eat()
            if text in ("true", "false"):
                return f"boolean({text})"
            if text == "undefined":
                return "Json::null()"
            if self.at("("):
                return self.call(text)
            if text in CONSTANTS:
                return f"str({mbt_string(CONSTANTS[text])})"
            if self.is_local(text):
                return snake(text)
            raise SyntaxError(f"unknown identifier {text}")
        raise SyntaxError(f"unexpected token {text!r}")

    def object_literal(self):
        self.eat("{")
        fields = []
        while not self.at("}"):
            key = self.eat()[1]
            self.eat(":")
            fields.append(f"{mbt_string(key)}: {self.expr()}")
            if self.at(","):
                self.eat()
        self.eat("}")
        return "Json::object({ " + ", ".join(fields) + " })"

    def call(self, name):
        self.eat("(")
        if name == "adjust":
            color = self.expr()
            self.eat(",")
            self.eat("{")
            deltas = []
            while not self.at("}"):
                channel = self.eat()[1]
                self.eat(":")
                deltas.append(f"{channel}={self.expr()}")
                if self.at(","):
                    self.eat()
            self.eat("}")
            self.eat(")")
            return f"adjust({color}, {', '.join(deltas)})"
        args = []
        while not self.at(")"):
            args.append(self.expr())
            if self.at(","):
                self.eat()
        self.eat(")")
        target = {
            "darken": "darken",
            "lighten": "lighten",
            "invert": "invert",
            "rgba": "rgba",
            "isDark": "is_dark",
            "mkBorder": "mk_border",
        }.get(name)
        if target is None:
            raise SyntaxError(f"unsupported function {name}")
        if name in ("darken", "lighten") and len(args) == 1:
            # khroma turns the missing amount into NaN.
            args.append("Json::null()")
        return f"{target}({', '.join(args)})"


def js_unescape(literal):
    body = literal[1:-1]
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), body)


def snake(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def method_body(src, header):
    """Return the text of the block that follows `header`, braces included."""
    start = src.index(header) + len(header) - 1
    depth = 0
    for pos in range(start, len(src)):
        if src[pos] == "{":
            depth += 1
        elif src[pos] == "}":
            depth -= 1
            if depth == 0:
                return src[start:pos + 1]
    raise SyntaxError(f"unterminated {header}")


def translate(name, src):
    ident = name.replace("-", "_")
    out = [
        f"// Generated by scripts/gen_themes.py from mermaid's theme-{name}.js.",
        "// Do not edit by hand.",
        "",
    ]
    for header, suffix in (("  constructor() {", "init"), ("  updateColors() {", "update_colors")):
        body = Parser(tokenize(method_body(src, header)), ident).block(1)
        raises = any(RAISING.search(line) for line in body)
        effect = " raise @color.ColorError" if raises else ""
        out += [
            "///|",
            f"fn {ident}_{suffix}(t : Theme) -> Unit{effect} {{",
            *body,
            "}",
            "",
        ]
    return "\n".join(out)


def main():
    upstream = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".repos" / "mermaid"
    themes = upstream / "packages" / "mermaid" / "src" / "themes"
    for name in THEMES:
        src = (themes / f"theme-{name}.js").read_text()
        target = ROOT / "theme" / f"gen_{name.replace('-', '_')}.mbt"
        target.write_text(translate(name, src))
        print(f"wrote {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
