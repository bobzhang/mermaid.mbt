// Selectors as Blink parses and serializes them in a style sheet of an
// HTML document: type selectors and attribute names in lower case, the
// universal selector dropped before other simple selectors, attribute
// values as strings, legacy pseudo-elements with two colons, An+B in its
// canonical form, and an invalid selector making the whole list invalid
// (except inside `:is()` and `:where()`).

///|
/// Why a part of a style sheet is not serialized.
priv suberror CssomError {
  /// Invalid: the browser drops it.
  Invalid
  /// The port does not read it; what.
  Unported(String)
}

///|
/// Pseudo-classes without arguments that Chrome knows.
let simple_pseudo_classes : Set[String] = Set::from_array([
  "active", "any-link", "autofill", "-webkit-autofill", "checked", "current", "default",
  "defined", "disabled", "empty", "enabled", "first-child", "first-of-type", "focus",
  "focus-visible", "focus-within", "fullscreen", "-webkit-full-screen", "-webkit-full-screen-ancestor",
  "-webkit-full-page-media", "future", "hover", "in-range", "indeterminate", "invalid",
  "last-child", "last-of-type", "link", "modal", "only-child", "only-of-type", "open",
  "optional", "out-of-range", "past", "picture-in-picture", "placeholder-shown",
  "-internal-autofill-previewed", "read-only", "read-write", "required", "root",
  "scope", "target", "user-invalid", "user-valid", "valid", "visited", "window-inactive",
  "-webkit-any-link", "-webkit-drag", "horizontal", "vertical", "decrement", "increment",
  "start", "end", "double-button", "single-button", "no-button", "corner-present",
  "xr-overlay", "host", "active-view-transition", "target-current", "popover-open",
])

///|
/// Pseudo-elements without arguments that Chrome knows.
let simple_pseudo_elements : Set[String] = Set::from_array([
  "after", "before", "first-letter", "first-line", "marker", "placeholder", "selection",
  "backdrop", "file-selector-button", "cue", "grammar-error", "spelling-error", "target-text",
  "view-transition", "scroll-marker", "scroll-marker-group", "column", "details-content",
  "checkmark", "picker-icon", "search-text", "-webkit-scrollbar", "-webkit-input-placeholder",
])

///|
/// ASCII lower case, as HTML's case-insensitive names.
fn ascii_lower(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    out.write_char(
      if c is ('A'..<='Z') {
        (c.to_int() + 32).unsafe_to_char()
      } else {
        c
      },
    )
  }
  out.to_string()
}

///|
/// Component values split at top-level commas.
fn split_commas(items : ArrayView[Component]) -> Array[Array[Component]] {
  let parts = [[]]
  for item in items {
    if item is Preserved(Comma, _) {
      parts.push([])
    } else {
      parts[parts.length() - 1].push(item)
    }
  }
  parts
}

///|
/// A selector list. In a forgiving list (`:is()`, `:where()`) invalid
/// selectors are left out; otherwise one makes the list invalid.
/// `pseudo_elements` is whether its selectors may have them.
fn selector_list(
  items : ArrayView[Component],
  forgiving~ : Bool = false,
  pseudo_elements~ : Bool = true,
) -> String raise CssomError {
  let selectors = []
  for part in split_commas(items) {
    let selector = complex_selector(trim_components(part[:]), pseudo_elements) catch {
      Invalid if forgiving => continue
      error => raise error
    }
    selectors.push(selector)
  }
  if !forgiving && selectors.is_empty() {
    raise Invalid
  }
  selectors.join(", ")
}

///|
/// A complex selector: compounds and combinators.
fn complex_selector(
  items : Array[Component],
  pseudo_elements : Bool,
) -> String raise CssomError {
  guard !items.is_empty() else { raise Invalid }
  let out = StringBuilder()
  let mut at = 0
  let mut ended = false
  while true {
    let (compound, next, has_pseudo_element) = compound_selector(items, at)
    guard !ended else { raise Invalid }
    if has_pseudo_element {
      guard pseudo_elements else { raise Invalid }
      ended = true
    }
    out.write_string(compound)
    at = next
    if at >= items.length() {
      break
    }
    // A combinator, white space around it optional; white space alone is
    // the descendant combinator.
    let spaced = items[at].is_whitespace()
    while at < items.length() && items[at].is_whitespace() {
      at += 1
    }
    let combinator = match items.get(at) {
      Some(Preserved(Delim('>' | '+' | '~' as c), _)) => {
        at += 1
        while at < items.length() && items[at].is_whitespace() {
          at += 1
        }
        " \{c} "
      }
      Some(Preserved(Delim('|'), _)) => raise Unported("the column combinator")
      _ if spaced => " "
      _ => raise Invalid
    }
    guard at < items.length() else { raise Invalid }
    out.write_string(combinator)
  }
  out.to_string()
}

///|
/// A compound selector starting at `at`: its serialization, where it ends,
/// and whether it has a pseudo-element.
fn compound_selector(
  items : Array[Component],
  at : Int32,
) -> (String, Int32, Bool) raise CssomError {
  let mut at = at
  let token = (offset : Int32) => {
    items.get(at + offset).bind(item => item.token())
  }
  // A type or universal selector, with a namespace prefix.
  let name_part = (token : Token?) => {
    match token {
      Some(Ident(name)) => Some(ascii_lower(name))
      Some(Delim('*')) => Some("*")
      _ => None
    }
  }
  let mut element = None
  if name_part(token(0)) is Some(name) && token(1) == Some(Delim('|')) {
    guard name_part(token(2)) is Some(local_name) else { raise Invalid }
    // Only the any-namespace prefix is known without `@namespace`.
    guard name == "*" else { raise Invalid }
    element = Some((local_name, ""))
    at += 3
  } else if token(0) == Some(Delim('|')) {
    guard name_part(token(1)) is Some(local_name) else { raise Invalid }
    element = Some((local_name, "|"))
    at += 2
  } else if name_part(token(0)) is Some(name) {
    element = Some((name, ""))
    at += 1
  }
  let subclasses = StringBuilder()
  let mut has_subclass = false
  let mut pseudo_element = false
  while at < items.length() {
    let part = match items[at] {
      Preserved(Hash(value, true), _) => {
        at += 1
        "#" + serialize_identifier(value)
      }
      Preserved(Hash(_, false), _) => raise Invalid
      Preserved(Delim('.'), _) =>
        match token(1) {
          Some(Ident(name)) => {
            at += 2
            "." + serialize_identifier(name)
          }
          _ => raise Invalid
        }
      Preserved(Delim('&'), _) => {
        at += 1
        "&"
      }
      Block('[', contents, _, _) => {
        at += 1
        attribute_selector(trim_components(contents[:]))
      }
      Preserved(Colon, _) => {
        let (text, next, element) = pseudo_selector(items, at)
        at = next
        if element {
          guard !pseudo_element else { raise Invalid }
          pseudo_element = true
        } else if pseudo_element {
          raise Invalid
        }
        text
      }
      _ => break
    }
    // Nothing but pseudo-classes may follow a pseudo-element, and Chrome
    // takes none of those the port reads.
    if pseudo_element && !part.has_prefix("::") {
      raise Invalid
    }
    subclasses.write_string(part)
    has_subclass = true
  }
  let element_text = match element {
    Some(("*", "")) if has_subclass => ""
    Some((name, prefix)) => prefix + name
    None => ""
  }
  guard element is Some(_) || has_subclass else { raise Invalid }
  (element_text + subclasses.to_string(), at, pseudo_element)
}

///|
/// An attribute selector, from the contents of its brackets.
fn attribute_selector(items : Array[Component]) -> String raise CssomError {
  let token = (at : Int32) => items.get(at).bind(item => item.token())
  let mut at = 0
  // The name, with a namespace prefix.
  let name = match (token(0), token(1), token(2)) {
    (Some(Delim('*')), Some(Delim('|')), Some(Ident(name))) => {
      at = 3
      "*|" + serialize_identifier(ascii_lower(name))
    }
    (Some(Delim('|')), Some(Ident(name)), _) => {
      at = 2
      serialize_identifier(ascii_lower(name))
    }
    (Some(Ident(_)), Some(Delim('|')), Some(Ident(_))) => raise Invalid
    (Some(Ident(name)), _, _) => {
      at = 1
      serialize_identifier(ascii_lower(name))
    }
    _ => raise Invalid
  }
  let skip = () => {
    while at < items.length() && items[at].is_whitespace() {
      at += 1
    }
  }
  skip()
  if at >= items.length() {
    return "[\{name}]"
  }
  let operator = match (token(at), token(at + 1)) {
    (Some(Delim('=')), _) => {
      at += 1
      "="
    }
    (Some(Delim('~' | '|' | '^' | '$' | '*' as c)), Some(Delim('='))) => {
      at += 2
      "\{c}="
    }
    _ => raise Invalid
  }
  skip()
  let value = match token(at) {
    Some(Ident(value) | Str(value)) => {
      at += 1
      value
    }
    _ => raise Invalid
  }
  skip()
  let flag = match token(at) {
    Some(Ident(flag)) if ascii_lower(flag) == "i" => {
      at += 1
      " i"
    }
    Some(Ident(_)) => raise Invalid
    _ => ""
  }
  skip()
  guard at == items.length() else { raise Invalid }
  "[\{name}\{operator}\{serialize_string(value)}\{flag}]"
}

///|
/// A pseudo-class or pseudo-element at `at` (its first colon): its
/// serialization, where it ends, and whether it is a pseudo-element.
fn pseudo_selector(
  items : Array[Component],
  at : Int32,
) -> (String, Int32, Bool) raise CssomError {
  let double = items.get(at + 1).bind(item => item.token()) == Some(Colon)
  let start = if double { at + 2 } else { at + 1 }
  match items.get(start) {
    Some(Preserved(Ident(name), _)) => {
      let name = ascii_lower(name)
      if double {
        if simple_pseudo_elements.contains(name) {
          ("::" + name, start + 1, true)
        } else if name.has_prefix("-webkit-") {
          raise Unported("the pseudo-element ::\{name}")
        } else {
          raise Invalid
        }
      } else if name is ("before" | "after" | "first-line" | "first-letter") {
        ("::" + name, start + 1, true)
      } else if simple_pseudo_classes.contains(name) {
        (":" + name, start + 1, false)
      } else {
        raise Invalid
      }
    }
    Some(Func(name, arguments, _, _)) => {
      let name = ascii_lower(name)
      if double {
        if name
          is ("slotted"
          | "part"
          | "highlight"
          | "picker"
          | "scroll-button"
          | "cue"
          | "view-transition-group"
          | "view-transition-old"
          | "view-transition-new"
          | "view-transition-image-pair") {
          raise Unported("the pseudo-element ::\{name}()")
        }
        raise Invalid
      }
      (":" + functional_pseudo_class(name, arguments), start + 1, false)
    }
    _ => raise Invalid
  }
}

///|
/// A functional pseudo-class: its name and arguments as serialized.
fn functional_pseudo_class(
  name : String,
  arguments : Array[Component],
) -> String raise CssomError {
  let arguments = trim_components(arguments[:])
  match name {
    "not" => "not(\{selector_list(arguments[:], pseudo_elements=false)})"
    "is" | "where" =>
      "\{name}(\{selector_list(arguments[:], forgiving=true, pseudo_elements=false)})"
    "nth-child" | "nth-last-child" | "nth-of-type" | "nth-last-of-type" => {
      // `An+B`, then `of` and a selector list for the child forms.
      let mut end = arguments.length()
      let mut of_list = ""
      for i, item in arguments {
        if item is Preserved(Ident(word), _) &&
          ascii_lower(word) == "of" &&
          i > 0 &&
          arguments[i - 1].is_whitespace() {
          guard name is ("nth-child" | "nth-last-child") else { raise Invalid }
          let list = trim_components(arguments[i + 1:])
          guard i + 1 < arguments.length() && arguments[i + 1].is_whitespace() else {
            raise Invalid
          }
          of_list = " of " + selector_list(list[:], pseudo_elements=false)
          end = i
          break
        }
      }
      "\{name}(\{an_plus_b(trim_components(arguments[:end]))}\{of_list})"
    }
    "lang" | "dir" =>
      match arguments {
        [Preserved(Ident(value), _)] =>
          "\{name}(\{serialize_identifier(value)})"
        _ => raise Invalid
      }
    "has"
    | "host"
    | "host-context"
    | "-webkit-any"
    | "state"
    | "active-view-transition-type" =>
      raise Unported("the pseudo-class :\{name}()")
    _ => raise Invalid
  }
}

///|
/// The An+B microsyntax, serialized canonically.
fn an_plus_b(items : Array[Component]) -> String raise CssomError {
  let tokens = items.map(item => item.token())
  guard !tokens.contains(None) else { raise Invalid }
  let tokens = tokens.map(token => token.unwrap())
  let integer_text = fn(text : String) -> Int32 raise CssomError {
    @string.parse_int(if text.has_prefix("+") { text[1:] } else { text[:] }) catch {
      _ => raise Invalid
    }
  }
  // B after `An` (or `n`): nothing, a signed integer, or a sign and a
  // signless integer, white space around allowed.
  let rest_b = fn(rest : ArrayView[Token]) -> Int32 raise CssomError {
    let rest = rest.to_owned().filter(token => token != Whitespace)
    match rest {
      [] => 0
      [Number(_, true, text)] if text.has_prefix("+") || text.has_prefix("-") =>
        integer_text(text)
      [Delim('+'), Number(_, true, text)] if !(text.has_prefix("+") ||
        text.has_prefix("-")) => integer_text(text)
      [Delim('-'), Number(_, true, text)] if !(text.has_prefix("+") ||
        text.has_prefix("-")) => -integer_text(text)
      _ => raise Invalid
    }
  }
  // B after `An-`: a signless integer, negated.
  let dash_b = fn(rest : ArrayView[Token]) -> Int32 raise CssomError {
    match rest.to_owned().filter(token => token != Whitespace) {
      [Number(_, true, text)] if !(text.has_prefix("+") || text.has_prefix("-")) =>
        -integer_text(text)
      _ => raise Invalid
    }
  }
  // A unit or identifier `n...`: B from what follows the `n`.
  let after_n = fn(
    suffix : String,
    rest : ArrayView[Token],
  ) -> Int32 raise CssomError {
    if suffix == "" {
      rest_b(rest)
    } else if suffix == "-" {
      dash_b(rest)
    } else if suffix.has_prefix("-") &&
      suffix[1:].iter().all(c => c is ('0'..<='9')) &&
      rest.to_owned().filter(token => token != Whitespace).is_empty() {
      -integer_text(suffix[1:].to_owned())
    } else {
      raise Invalid
    }
  }
  let (a, b) = match tokens {
    [Ident(word)] if ascii_lower(word) == "odd" => (2, 1)
    [Ident(word)] if ascii_lower(word) == "even" => (2, 0)
    [Number(_, true, text)] => (0, integer_text(text))
    [Dimension(_, true, unit, text), .. rest] => {
      let unit = ascii_lower(unit)
      guard unit.has_prefix("n") else { raise Invalid }
      (integer_text(text), after_n(unit[1:].to_owned(), rest))
    }
    [Delim('+'), Ident(word), .. rest] => {
      let word = ascii_lower(word)
      guard word.has_prefix("n") else { raise Invalid }
      (1, after_n(word[1:].to_owned(), rest))
    }
    [Ident(word), .. rest] => {
      let word = ascii_lower(word)
      if word.has_prefix("-n") {
        (-1, after_n(word[2:].to_owned(), rest))
      } else if word.has_prefix("n") {
        (1, after_n(word[1:].to_owned(), rest))
      } else {
        raise Invalid
      }
    }
    _ => raise Invalid
  }
  if a == 0 {
    return b.to_string()
  }
  let a_text = match a {
    1 => "n"
    -1 => "-n"
    _ => "\{a}n"
  }
  if b > 0 {
    "\{a_text}+\{b}"
  } else if b < 0 {
    "\{a_text}\{b}"
  } else {
    a_text
  }
}
