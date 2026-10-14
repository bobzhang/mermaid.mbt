///|
/// An expression in the constructor notation, terminals as `"x"`,
/// references bare and special text in question marks.
fn shape(node : @railroad.Node) -> String {
  let list = (nodes : Array[@railroad.Node]) => nodes.map(shape).join(", ")
  match node {
    Terminal(value) => "\"\{value}\""
    NonTerminal(name) => name
    Special(text) => "?\{text}?"
    Sequence(elements) => "seq(\{list(elements)})"
    Choice(alternatives) => "alt(\{list(alternatives)})"
    Optional(element) => "opt(\{shape(element)})"
    Repetition(element, min~, ..) =>
      if min == 0.0 {
        "any(\{shape(element)})"
      } else {
        "some(\{shape(element)})"
      }
  }
}

///|
/// The rules of a diagram, or why it does not parse.
fn dump(diagram_type : String, source : String) -> Json {
  let railroad = @railroad.parse(diagram_type, source) catch {
    @langium.ParseError(message~, ..) =>
      return Json::string("syntax: " + message)
    @railroad.Unsupported(message) =>
      return Json::string("unsupported: " + message)
    _ => return Json::string("error")
  }
  let rules : Map[String, Json] = Map([])
  for rule in railroad.rules {
    rules[rule.name] = Json::string(shape(rule.definition))
  }
  Json::object(rules)
}

///|
test "constructors: one element is no sequence, one alternative no choice" {
  json_inspect(
    dump(
      "railroad", "railroad-beta\na = sequence(terminal(\"x\")) ;\nb = choice(nonterminal('y'), optional(special(\"z\"))) ;\nc = zeroOrMore(oneOrMore(terminal(\"q\\\"\\n\"))) ;\nterminals = terminal(\"t\") ;",
    ),
    content={
      "a": "\"x\"",
      "b": "alt(y, opt(?z?))",
      "c": "any(some(\"q\"\n\"))",
      "terminals": "\"t\"",
    },
  )
  json_inspect(
    dump("railroad", "railroad-beta\nterminal = terminal(\"x\") ;"),
    content="syntax: Expecting token of type 'ID' but found 'terminal'",
  )
}

///|
test "EBNF: both notations, postfixes and exceptions" {
  json_inspect(
    dump(
      "railroadEbnf", "railroad-ebnf-beta\na ::= b , \"c\" d | [ e ] { f } ( g ) ;\nb = c?*+ ;\nc = d - \"x\" - ( e f ) ;\nd = (* gone *) e /* gone */ ;",
    ),
    content={
      "a": "alt(seq(b, \"c\", d), seq(opt(e), any(f), g))",
      "b": "some(any(opt(c)))",
      "c": "seq(seq(d, \"-\", \"x\"), \"-\", seq(e, f))",
      "d": "e",
    },
  )
}

///|
test "EBNF: a question mark opens a special sequence when another follows" {
  json_inspect(
    dump(
      "railroadEbnf", "railroad-ebnf-beta\na = b? c? ;\nb = c? ;\nc = ?  any  thing ? ;",
    ),
    content={ "a": "seq(b, ?c?)", "b": "opt(c)", "c": "?any  thing?" },
  )
  // Not across a semicolon.
  json_inspect(dump("railroadEbnf", "railroad-ebnf-beta\na = b? ; c = d? ;"), content={
    "a": "opt(b)",
    "c": "opt(d)",
  })
}

///|
test "ABNF: repeat prefixes" {
  json_inspect(
    dump(
      "railroadAbnf", "railroad-abnf-beta\na = *b 1*c 2*4d 3e *1f 0g ;\nb = %x30-39 / \"it's\" / [ c d ] ;",
    ),
    content={
      "a": "seq(any(b), some(c), some(d), some(e), opt(f), any(g))",
      "b": "alt(\"%x30-39\", \"it's\", opt(seq(c, d)))",
    },
  )
}

///|
test "ABNF: a semicolon with anything after it on its line is a comment" {
  json_inspect(
    dump("railroadAbnf", "railroad-abnf-beta\n; about a\na = b ;\nc = d ;"),
    content={ "a": "b", "c": "d" },
  )
  json_inspect(
    dump("railroadAbnf", "railroad-abnf-beta\na = b ; c = d ;\n"),
    content="syntax: Expecting token of type ';' but found the end of the input",
  )
}

///|
test "PEG: predicates become special text" {
  json_inspect(
    dump(
      "railroadPeg", "railroad-peg-beta\nA <- !B &\"c\" !. &(D E) !F* ; # comment\nB <- (C / D)+ .? ;",
    ),
    content={
      "A": "seq(?!B?, ?&\"c\"?, ?!.?, ?&(...)?, ?!(...)?)",
      "B": "seq(some(alt(C, D)), opt(?.?))",
    },
  )
}

///|
test "a title takes the rest of its line, wherever it stands" {
  json_inspect(dump("railroadEbnf", "railroad-ebnf-beta\ntitle = b ;\n"), content={})
  json_inspect(
    dump("railroadEbnf", "railroad-ebnf-beta\na = b ;\ntitle Late\n"),
    content="syntax: Expecting token of type 'ID' but found 'title Late'",
  )
}

///|
test "text goes through the sanitizer" {
  json_inspect(
    dump("railroadEbnf", "railroad-ebnf-beta\na = \"<\" \"a & b\" \"<i>x\" ;"),
    content={ "a": "seq(\"&lt;\", \"a & b\", \"<i>x</i>\")" },
  )
  json_inspect(
    dump("railroadEbnf", "railroad-ebnf-beta\na = \"<digit>\" ;"),
    content="unsupported: sanitizing this markup is not ported: <digit>",
  )
}
