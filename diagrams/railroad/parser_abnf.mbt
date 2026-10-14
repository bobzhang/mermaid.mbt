///|
/// `railroad-abnf.langium`:
///
/// ```text
/// RailroadAbnf: "railroad-abnf-beta" (TITLE | ACC_TITLE | ACC_DESCR)* Rule*
/// Rule: RULENAME "=" Alternation ";"
/// Alternation: Concatenation ("/" Concatenation)*
/// Concatenation: Element+
/// Element: (REPEAT | EXACT_REPEAT)? Primary
/// Primary: STRING | NUMVAL | RULENAME
///        | "(" Alternation ")" | "[" Alternation "]"
/// ```
fn parse_abnf(tokens : @langium.TokenStream) -> Railroad raise {
  // A title in quotes loses them; nothing is an escape in this notation.
  let header = header(tokens, "railroad-abnf-beta", quoted => {
    quoted[1:quoted.length() - 1].to_owned()
  })
  let rules = []
  while !tokens.at("EOF") {
    let name = tokens.expect("RULENAME").text
    tokens.expect("=") |> ignore
    let definition = abnf_alternation(tokens)
    tokens.expect(";") |> ignore
    rules.push({ name, definition, })
  }
  header.diagram(rules)
}

///|
fn abnf_alternation(tokens : @langium.TokenStream) -> Node raise {
  let alternatives = [abnf_concatenation(tokens)]
  while tokens.accept("/") is Some(_) {
    alternatives.push(abnf_concatenation(tokens))
  }
  choice_of(alternatives)
}

///|
fn abnf_concatenation(tokens : @langium.TokenStream) -> Node raise {
  let elements = [abnf_element(tokens)]
  while tokens.peek()
        is ("REPEAT"
        | "EXACT_REPEAT"
        | "STRING"
        | "NUMVAL"
        | "RULENAME"
        | "("
        | "[") {
    elements.push(abnf_element(tokens))
  }
  sequence_of(elements)
}

///|
/// JavaScript's `parseInt` of a run of digits.
fn digits_value(digits : StringView) -> Double {
  let mut value = 0.0
  for c in digits {
    value = value * 10.0 + (c.to_int() - '0').to_double()
  }
  value
}

///|
/// The bounds a repeat prefix stands for: `min*max`, either of which may
/// be left out, or a number for exactly that many.
fn repeat_bounds(repeat : String) -> (Double, Double) {
  match repeat.find("*") {
    Some(star) => {
      let min = repeat[:star]
      let max = repeat[star + 1:]
      (
        if min.is_empty() {
          0.0
        } else {
          digits_value(min)
        },
        if max.is_empty() {
          @double.infinity
        } else {
          digits_value(max)
        },
      )
    }
    None => {
      let exact = digits_value(repeat)
      (exact, exact)
    }
  }
}

///|
fn abnf_element(tokens : @langium.TokenStream) -> Node raise {
  let repeat = match tokens.accept("REPEAT") {
    Some(token) => Some(token.text)
    None => tokens.accept("EXACT_REPEAT").map(token => token.text)
  }
  let inner = abnf_primary(tokens)
  guard repeat is Some(repeat) else { return inner }
  let (min, max) = repeat_bounds(repeat)
  if min == 0.0 && max == 1.0 {
    Optional(inner)
  } else {
    Repetition(inner, min~, max~)
  }
}

///|
fn abnf_primary(tokens : @langium.TokenStream) -> Node raise {
  match tokens.peek() {
    "STRING" => {
      let text = tokens.expect("STRING").text
      Terminal(text[1:text.length() - 1].to_owned())
    }
    "NUMVAL" => Terminal(tokens.expect("NUMVAL").text)
    "RULENAME" => NonTerminal(tokens.expect("RULENAME").text)
    "(" => {
      tokens.expect("(") |> ignore
      let element = abnf_alternation(tokens)
      tokens.expect(")") |> ignore
      element
    }
    "[" => {
      tokens.expect("[") |> ignore
      let element = abnf_alternation(tokens)
      tokens.expect("]") |> ignore
      Optional(element)
    }
    _ => tokens.fail("Expecting an element")
  }
}
