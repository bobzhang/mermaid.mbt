// A style sheet as Chrome reads `new CSSStyleSheet().replaceSync(text)`
// and writes each rule's `cssText`: what mermaid's `createCssStyles` makes
// of `themeCSS` before stylis compiles it.

///|
/// A style sheet the port cannot serialize as Chrome would: what in it.
pub(all) suberror CssUnsupported {
  CssUnsupported(String)
} derive(Eq, Debug)

///|
/// The `cssText` of each rule Chrome keeps of a style sheet given to
/// `replaceSync`: invalid rules and declarations dropped, selectors and
/// values in their canonical forms.
pub fn serialize_style_sheet(
  text : String,
) -> Array[String] raise CssUnsupported {
  let source = tokenize(text)
  let rules = parse_rules(components(source), true)
  let out = []
  for rule in rules {
    let text = serialize_rule(rule, source, top_level=true) catch {
      Unported(what) => raise CssUnsupported(what)
      Invalid => raise CssUnsupported("an invalid rule")
    }
    if text is Some(text) {
      out.push(text)
    }
  }
  out
}

///|
/// A rule's `cssText`, or `None` when Chrome drops it.
fn serialize_rule(
  rule : RawRule,
  source : Tokens,
  top_level~ : Bool,
) -> String? raise CssomError {
  match rule {
    Qualified(prelude, block) => {
      let selector = selector_list(trim_components(prelude[:])[:]) catch {
        Invalid => return None
        error => raise error
      }
      Some("\{selector} { \{declaration_block(block, source)}}")
    }
    At(name, prelude, block) =>
      match ascii_lower(name) {
        // `replaceSync` ignores imports.
        "import" if top_level => None
        "media" =>
          match block {
            Some(block) => Some(media_rule(prelude, block, source))
            None => None
          }
        "keyframes" | "-webkit-keyframes" as kind =>
          match block {
            Some(block) => keyframes_rule(kind, prelude, block, source)
            None => None
          }
        "charset" => None
        "namespace"
        | "font-face"
        | "supports"
        | "layer"
        | "container"
        | "page"
        | "property"
        | "counter-style"
        | "scope"
        | "starting-style"
        | "font-feature-values"
        | "font-palette-values"
        | "position-try"
        | "view-transition"
        | "function" as kind => raise Unported("@\{kind} rules")
        _ => None
      }
  }
}

///|
/// The declarations of a block as Blink keeps and writes them, each
/// followed by a space: `name: value;` or `name: value !important;`.
fn declaration_block(
  block : Array[Component],
  source : Tokens,
  keyframe~ : Bool = false,
) -> String raise CssomError {
  // Name, value, importance.
  let parsed : Array[(String, String, Bool)] = []
  for item in parse_block_items(block) {
    guard item is Declaration(name, value, important) else {
      if item is NestedRule {
        raise Unported("nested rules")
      }
      continue
    }
    // Keyframes drop important declarations.
    if keyframe && important {
      continue
    }
    let (name, text) = if name.has_prefix("--") {
      let text = match (value.get(0), value.last()) {
        // The text as written, without white space around it (an escape
        // may end in a space).
        (Some(first), Some(last)) =>
          source
          .source(first.first(), last.last())
          .trim(chars=" \t\n")
          .to_owned()
        _ => ""
      }
      (name, text)
    } else {
      let name = ascii_lower(name)
      guard property_names.contains(name) else { continue }
      let text = match spaced_values(value) {
        [Preserved(Ident(word), _)] if ascii_lower(word)
          is ("initial" | "inherit" | "unset" | "revert" | "revert-layer") =>
          ascii_lower(word)
        _ => {
          guard property_grammars.get(name) is Some(grammar) else {
            raise Unported("the property \{name}")
          }
          property_value(grammar, value, source) catch {
            Invalid => continue
            error => raise error
          }
        }
      }
      (name, text)
    }
    parsed.push((name, text, important))
  }
  // Blink keeps the last declaration of each property, an important one
  // over any that is not, the important ones after the others.
  let declarations : Array[(String, String, Bool)] = []
  for important in [false, true] {
    for index, declaration in parsed {
      let (name, _, is_important) = declaration
      if is_important != important {
        continue
      }
      let overridden = parsed[index + 1:]
        .iter()
        .any(later => later.0 == name && later.2 == important) ||
        (!important && parsed.iter().any(other => other.0 == name && other.2))
      if !overridden {
        declarations.push(declaration)
      }
    }
  }
  // Blink writes a shorthand in place of all its longhands, and sorts out
  // shorthands that overlap; the port does neither.
  let names = declarations.map(declaration => declaration.0)
  for shorthand, longhands in shorthands {
    let present = longhands.filter(longhand => names.contains(longhand))
    if (names.contains(shorthand) && !present.is_empty()) ||
      present.length() == longhands.length() {
      raise Unported("the longhands of \{shorthand} together")
    }
  }
  for shorthand in names {
    if shorthands.get(shorthand) is Some(longhands) {
      for other in names {
        if other != shorthand &&
          shorthands.get(other) is Some(others) &&
          others.iter().any(longhand => longhands.contains(longhand)) {
          raise Unported("\{shorthand} with \{other}")
        }
      }
    }
  }
  let out = StringBuilder()
  for declaration in declarations {
    let (name, text, important) = declaration
    let priority = if important { " !important" } else { "" }
    out.write_string("\{name}: \{text}\{priority}; ")
  }
  out.to_string()
}

///|
/// `@media`: the query list, then each rule on a line of its own.
fn media_rule(
  prelude : Array[Component],
  block : Array[Component],
  source : Tokens,
) -> String raise CssomError {
  let query = media_query_list(trim_components(prelude[:]))
  let out = StringBuilder()
  out.write_string("@media \{query} {\n")
  for rule in parse_rules(block, false) {
    if serialize_rule(rule, source, top_level=false) is Some(text) {
      out.write_string("  \{text}\n")
    }
  }
  out.write_string("}")
  out.to_string()
}

///|
/// A media query list the port reads: media types, `not` and `only`,
/// and features with simple values, joined by `and`.
fn media_query_list(items : Array[Component]) -> String raise CssomError {
  let queries = []
  for part in split_commas(items[:]) {
    let words = []
    for item in trim_components(part[:]) {
      match item {
        Preserved(Whitespace, _) => ()
        Preserved(Ident(word), _) => words.push(ascii_lower(word))
        Block('(', contents, _, _) => words.push(media_feature(contents))
        _ => raise Unported("this media query")
      }
    }
    guard !words.is_empty() else { raise Unported("an empty media query") }
    queries.push(words.join(" "))
  }
  queries.join(", ")
}

///|
fn media_feature(contents : Array[Component]) -> String raise CssomError {
  let values = spaced_values(contents)
  match values {
    [Preserved(Ident(name), _)] => "(\{ascii_lower(name)})"
    [Preserved(Ident(name), _), Preserved(Colon, _), value] => {
      let value = match value {
        Preserved(Ident(word), _) => ascii_lower(word)
        Preserved(Number(number, _, _), _) => number_text(number)
        Preserved(Dimension(number, _, unit, _), _) =>
          number_text(number) + ascii_lower(unit)
        _ => raise Unported("this media feature")
      }
      "(\{ascii_lower(name)}: \{value})"
    }
    _ => raise Unported("this media feature")
  }
}

///|
/// `@keyframes`: the name, then each keyframe on a line of its own, its
/// selectors as percentages.
fn keyframes_rule(
  kind : String,
  prelude : Array[Component],
  block : Array[Component],
  source : Tokens,
) -> String? raise CssomError {
  let name = match spaced_values(prelude) {
    [Preserved(Ident(name), _)] if !(ascii_lower(name)
      is ("none"
      | "initial"
      | "inherit"
      | "unset"
      | "default"
      | "revert"
      | "revert-layer")) => serialize_identifier(name)
    [Preserved(Str(name), _)] =>
      if is_single_identifier(name) {
        serialize_identifier(name)
      } else {
        serialize_string(name)
      }
    _ => return None
  }
  let out = StringBuilder()
  out.write_string("@\{kind} \{name} { \n")
  for rule in parse_rules(block, false) {
    guard rule is Qualified(prelude, declarations) else { continue }
    let selectors = []
    let mut valid = true
    for part in split_commas(prelude[:]) {
      match spaced_values(part) {
        [Preserved(Ident(word), _)] if ascii_lower(word) == "from" =>
          selectors.push("0%")
        [Preserved(Ident(word), _)] if ascii_lower(word) == "to" =>
          selectors.push("100%")
        [Preserved(Percentage(value), _)] if value >= 0.0 && value <= 100.0 =>
          selectors.push(number_text(value) + "%")
        _ => valid = false
      }
    }
    if valid && !selectors.is_empty() {
      let body = declaration_block(declarations, source, keyframe=true)
      out.write_string("  \{selectors.join(", ")} { \{body}}\n")
    }
  }
  out.write_string("}")
  Some(out.to_string())
}
