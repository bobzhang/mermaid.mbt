///|
/// `railroad-peg.langium`:
///
/// ```text
/// RailroadPeg: "railroad-peg-beta" (TITLE | ACC_TITLE | ACC_DESCR)* Rule*
/// Rule: ID "<-" OrderedChoice ";"
/// OrderedChoice: Sequence ("/" Sequence)*
/// Sequence: Prefix+
/// Prefix: ("&" | "!")? Primary ("?" | "*" | "+")?
/// Primary: STRING | ID | "(" OrderedChoice ")" | "."
/// ```
fn parse_peg(tokens : @langium.TokenStream) -> (Header, Array[Rule]) raise {
  let header = header(tokens, "railroad-peg-beta", decode_escaped_string)
  let rules = []
  while !tokens.at("EOF") {
    let name = tokens.expect("ID").text
    tokens.expect("<-") |> ignore
    let definition = peg_choice(tokens)
    tokens.expect(";") |> ignore
    rules.push({ name, definition, })
  }
  (header, rules)
}

///|
fn peg_choice(tokens : @langium.TokenStream) -> Node raise {
  let alternatives = [peg_sequence(tokens)]
  while tokens.accept("/") is Some(_) {
    alternatives.push(peg_sequence(tokens))
  }
  choice_of(alternatives)
}

///|
fn peg_sequence(tokens : @langium.TokenStream) -> Node raise {
  let elements = [peg_prefix(tokens)]
  while tokens.peek() is ("&" | "!" | "STRING" | "ID" | "(" | ".") {
    elements.push(peg_prefix(tokens))
  }
  sequence_of(elements)
}

///|
/// What a predicate says of the expression it looks ahead for: only the
/// simple ones are spelled out.
fn peg_label(node : Node) -> String {
  match node {
    Terminal(value) => "\"\{value}\""
    NonTerminal(name) => name
    Special(text) => text
    _ => "(...)"
  }
}

///|
fn peg_prefix(tokens : @langium.TokenStream) -> Node raise {
  let predicate = match tokens.accept("&") {
    Some(token) => Some(token.text)
    None => tokens.accept("!").map(token => token.text)
  }
  let primary = peg_primary(tokens)
  let inner = match tokens.peek() {
    "?" => {
      tokens.expect("?") |> ignore
      Optional(primary)
    }
    "*" => {
      tokens.expect("*") |> ignore
      Repetition(primary, min=0.0, max=@double.infinity)
    }
    "+" => {
      tokens.expect("+") |> ignore
      Repetition(primary, min=1.0, max=@double.infinity)
    }
    _ => primary
  }
  match predicate {
    // The predicates consume nothing; they are drawn as special text.
    Some(operator) => Special(operator + peg_label(inner))
    None => inner
  }
}

///|
fn peg_primary(tokens : @langium.TokenStream) -> Node raise {
  match tokens.peek() {
    "STRING" => Terminal(decode_escaped_string(tokens.expect("STRING").text))
    "ID" => NonTerminal(tokens.expect("ID").text)
    "(" => {
      tokens.expect("(") |> ignore
      let element = peg_choice(tokens)
      tokens.expect(")") |> ignore
      element
    }
    "." => Special(tokens.expect(".").text)
    _ => tokens.fail("Expecting an expression")
  }
}
