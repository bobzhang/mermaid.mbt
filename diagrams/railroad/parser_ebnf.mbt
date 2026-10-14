///|
/// `railroad-ebnf.langium`:
///
/// ```text
/// RailroadEbnf: "railroad-ebnf-beta" (TITLE | ACC_TITLE | ACC_DESCR)* Rule*
/// Rule: ID ("=" | "::=") Choice ";"
/// Choice: Sequence ("|" Sequence)*
/// Sequence: Term (","? Term)*
/// Term: Primary ("?" | "*" | "+" | "-" Primary)*
/// Primary: STRING | SPECIAL_SEQUENCE | ID
///        | "(" Choice ")" | "[" Choice "]" | "{" Choice "}"
/// ```
fn parse_ebnf(tokens : @langium.TokenStream) -> Railroad raise {
  let header = header(tokens, "railroad-ebnf-beta", decode_escaped_string)
  let rules = []
  while !tokens.at("EOF") {
    let name = tokens.expect("ID").text
    if tokens.accept("=") is None {
      tokens.expect("::=") |> ignore
    }
    let definition = ebnf_choice(tokens)
    tokens.expect(";") |> ignore
    rules.push({ name, definition, })
  }
  header.diagram(rules)
}

///|
fn ebnf_choice(tokens : @langium.TokenStream) -> Node raise {
  let alternatives = [ebnf_sequence(tokens)]
  while tokens.accept("|") is Some(_) {
    alternatives.push(ebnf_sequence(tokens))
  }
  choice_of(alternatives)
}

///|
fn ebnf_sequence(tokens : @langium.TokenStream) -> Node raise {
  let elements = [ebnf_term(tokens)]
  while true {
    if tokens.accept(",") is Some(_) {
      elements.push(ebnf_term(tokens))
    } else if tokens.peek()
      is ("STRING" | "SPECIAL_SEQUENCE" | "ID" | "(" | "[" | "{") {
      elements.push(ebnf_term(tokens))
    } else {
      break
    }
  }
  sequence_of(elements)
}

///|
fn ebnf_term(tokens : @langium.TokenStream) -> Node raise {
  let mut node = ebnf_primary(tokens)
  while true {
    match tokens.peek() {
      "?" => {
        tokens.expect("?") |> ignore
        node = Optional(node)
      }
      "*" => {
        tokens.expect("*") |> ignore
        node = Repetition(node, min=0.0, max=@double.infinity)
      }
      "+" => {
        tokens.expect("+") |> ignore
        node = Repetition(node, min=1.0, max=@double.infinity)
      }
      "-" => {
        tokens.expect("-") |> ignore
        // An exception is drawn as what it is written as.
        node = Sequence([node, Terminal("-"), ebnf_primary(tokens)])
      }
      _ => break
    }
  }
  node
}

///|
fn ebnf_primary(tokens : @langium.TokenStream) -> Node raise {
  match tokens.peek() {
    "STRING" => Terminal(decode_escaped_string(tokens.expect("STRING").text))
    "SPECIAL_SEQUENCE" => {
      let text = tokens.expect("SPECIAL_SEQUENCE").text
      Special(@journeycommon.js_trim(text[1:text.length() - 1].to_owned()))
    }
    "ID" => NonTerminal(tokens.expect("ID").text)
    "(" => {
      tokens.expect("(") |> ignore
      let element = ebnf_choice(tokens)
      tokens.expect(")") |> ignore
      element
    }
    "[" => {
      tokens.expect("[") |> ignore
      let element = ebnf_choice(tokens)
      tokens.expect("]") |> ignore
      Optional(element)
    }
    "{" => {
      tokens.expect("{") |> ignore
      let element = ebnf_choice(tokens)
      tokens.expect("}") |> ignore
      Repetition(element, min=0.0, max=@double.infinity)
    }
    _ => tokens.fail("Expecting a term")
  }
}
