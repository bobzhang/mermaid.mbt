///|
/// `railroad.langium`:
///
/// ```text
/// Railroad: "railroad-beta" (TITLE | ACC_TITLE | ACC_DESCR)* Rule*
/// Rule: ID "=" Expression ";"
/// Expression: ("sequence" | "choice") "(" Expression ("," Expression)* ")"
///           | ("optional" | "oneOrMore" | "zeroOrMore") "(" Expression ")"
///           | ("terminal" | "nonterminal" | "special") "(" STRING ")"
/// ```
fn parse_ir(tokens : @langium.TokenStream) -> Railroad raise {
  let header = header(tokens, "railroad-beta", decode_escaped_string)
  let rules = []
  while !tokens.at("EOF") {
    let name = tokens.expect("ID").text
    tokens.expect("=") |> ignore
    let definition = ir_expression(tokens)
    tokens.expect(";") |> ignore
    rules.push({ name, definition, })
  }
  header.diagram(rules)
}

///|
fn ir_expression(tokens : @langium.TokenStream) -> Node raise {
  let kind = tokens.peek()
  match kind {
    "sequence" | "choice" => {
      tokens.expect(kind) |> ignore
      tokens.expect("(") |> ignore
      let items = [ir_expression(tokens)]
      while tokens.accept(",") is Some(_) {
        items.push(ir_expression(tokens))
      }
      tokens.expect(")") |> ignore
      if kind == "sequence" {
        sequence_of(items)
      } else {
        choice_of(items)
      }
    }
    "optional" | "oneOrMore" | "zeroOrMore" => {
      tokens.expect(kind) |> ignore
      tokens.expect("(") |> ignore
      let element = ir_expression(tokens)
      tokens.expect(")") |> ignore
      match kind {
        "optional" => Optional(element)
        "oneOrMore" => Repetition(element, min=1.0, max=@double.infinity)
        _ => Repetition(element, min=0.0, max=@double.infinity)
      }
    }
    "terminal" | "nonterminal" | "special" => {
      tokens.expect(kind) |> ignore
      tokens.expect("(") |> ignore
      let text = decode_escaped_string(tokens.expect("STRING").text)
      tokens.expect(")") |> ignore
      match kind {
        "terminal" => Terminal(text)
        "nonterminal" => NonTerminal(text)
        _ => Special(text)
      }
    }
    _ => tokens.fail("Expecting an expression")
  }
}
