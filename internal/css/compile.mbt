// A port of the part of stylis (https://github.com/thysultan/stylis, MIT)
// that mermaid relies on: nested rules are flattened under their parent
// selector, whitespace and comments are dropped, and the result is printed
// in stylis's minified form. The scanner follows stylis's `parse` closely,
// because its whitespace rules decide the exact bytes of the stylesheet.

///|
/// A node of the compiled stylesheet.
priv enum Node {
  /// `property:value;`
  Declaration(String)
  /// Selectors with the declarations (and, inside an at-rule, nested rules)
  /// they hold.
  Rule(selectors~ : Array[String], children~ : Array[Node])
  /// `@media ...`, `@keyframes ...` and friends.
  AtRule(name~ : String, value~ : String, children~ : Array[Node])
}

///|
/// The character classes stylis uses to decide which whitespace to keep.
fn token(c : Int32) -> Int32 {
  match c {
    0 | 9 | 10 | 13 | 32 => 5
    33 | 43 | 44 | 47 | 62 | 64 | 126 | 59 | 123 | 125 => 4
    58 => 3
    34 | 39 | 40 | 91 => 2
    41 | 93 => 1
    _ => 0
  }
}

///|
priv struct Scanner {
  chars : Array[Char]
  mut position : Int32
}

///|
fn Scanner::peek(self : Scanner) -> Int32 {
  if self.position < self.chars.length() {
    self.chars[self.position].to_int()
  } else {
    0
  }
}

///|
fn Scanner::next(self : Scanner) -> Int32 {
  let c = self.peek()
  self.position += 1
  c
}

///|
/// Skip a run of whitespace; it survives as one space unless it borders a
/// character that never needs separating.
fn Scanner::whitespace(self : Scanner, previous : Int32) -> String {
  while self.peek() != 0 && self.peek() < 33 {
    self.position += 1
  }
  if token(previous) > 2 || token(self.peek()) > 3 {
    ""
  } else {
    " "
  }
}

///|
/// Copy a quoted string or bracketed group verbatim. `opener` has just been
/// consumed.
fn Scanner::delimit(self : Scanner, opener : Int32) -> String {
  let closer = match opener {
    40 => 41
    91 => 93
    other => other
  }
  let start = self.position - 1
  self.delimiter(closer)
  String::from_array(self.chars[start:self.position])
}

///|
fn Scanner::delimiter(self : Scanner, closer : Int32) -> Unit {
  while self.position < self.chars.length() {
    let c = self.next()
    if c == closer {
      return
    }
    match c {
      // Quotes nest only inside brackets.
      34 | 39 => if closer != 34 && closer != 39 { self.delimiter(c) }
      40 => if closer == 41 { self.delimiter(41) }
      92 => self.position += 1
      _ => ()
    }
  }
}

///|
/// Skip a comment; the `/` has been consumed and `kind` is the `*` or `/`
/// that follows it.
fn Scanner::comment(self : Scanner, kind : Int32) -> Unit {
  self.position += 1
  while self.position < self.chars.length() {
    let c = self.next()
    if kind == 47 {
      if c == 10 {
        return
      }
    } else if c == 42 && self.peek() == 47 {
      self.position += 1
      return
    }
  }
}

///|
/// Read the rest of an at-rule's name.
fn Scanner::identifier(self : Scanner) -> String {
  let start = self.position
  while token(self.peek()) == 0 {
    self.position += 1
  }
  String::from_array(self.chars[start:self.position])
}

///|
/// Resolve the selectors of a nested rule against the selectors of its
/// parent: `&` stands for the parent, and a selector without `&` becomes a
/// descendant of it.
fn resolve_selectors(text : String, parents : Array[String]) -> Array[String] {
  let resolved = []
  for part in split_selectors(text) {
    for parent in parents {
      let selector = if part.contains("&\u{0c}") {
        part.replace_all(old="&\u{0c}", new=parent)
      } else if parent == "" {
        part
      } else {
        parent + " " + part
      }
      let selector = selector.trim().to_owned()
      if selector != "" {
        resolved.push(selector)
      }
    }
  }
  resolved
}

///|
/// Split a selector list at its top-level commas. An escaped character
/// (`.a\,b`) is never a separator or a quote: stylis copies it with its
/// backslash without looking at it.
fn split_selectors(text : String) -> Array[String] {
  let parts = []
  let current = StringBuilder()
  let mut depth = 0
  let mut quote : Char? = None
  let mut escaped = false
  for c in text {
    if escaped || c == '\\' {
      escaped = !escaped
      current.write_char(c)
      continue
    }
    match quote {
      Some(q) => {
        if c == q {
          quote = None
        }
        current.write_char(c)
        continue
      }
      None => ()
    }
    match c {
      '"' | '\'' => {
        quote = Some(c)
        current.write_char(c)
      }
      '(' | '[' => {
        depth += 1
        current.write_char(c)
      }
      ')' | ']' => {
        depth -= 1
        current.write_char(c)
      }
      ',' if depth == 0 => {
        parts.push(current.to_string())
        current.reset()
      }
      _ => current.write_char(c)
    }
  }
  parts.push(current.to_string())
  parts
}

///|
/// Parse the body of a block.
///
/// - `parents` are the selectors nested rules resolve against.
/// - `declarations` receives this block's own declarations.
/// - `rules` receives nested rules and at-rules. For an ordinary rule that
///   is the list its own node sits in, which is what flattens nesting.
fn Scanner::parse(
  self : Scanner,
  parents : Array[String],
  declarations : Array[Node],
  rules : Array[Node],
) -> Unit {
  let characters = StringBuilder()
  // Position just past the `:` of the declaration being read, or 0.
  let mut property_end = 0
  // The character before that `:`.
  let mut property = 0
  // The name of the at-rule being read, or "".
  let mut at_rule = ""
  // Inside a custom property, braces are part of the value.
  let mut variable = true
  let mut previous = 0
  while true {
    let character = self.next()
    match character {
      34 | 39 | 91 | 40 => {
        let group = self.delimit(character)
        if character == 40 && previous != 108 && property_end > 0 {
          characters.write_string(group.replace_all(old="&", new="&\u{0c}"))
        } else {
          characters.write_string(group)
        }
      }
      9 | 10 | 13 | 32 => characters.write_string(self.whitespace(previous))
      92 => {
        characters.write_char('\\')
        if self.peek() != 0 {
          characters.write_char(Int32::unsafe_to_char(self.next()))
        }
      }
      47 if self.peek() == 42 || self.peek() == 47 => {
        self.comment(self.peek())
        let text = characters.to_string()
        if (token(previous) == 5 || token(self.peek()) == 5) &&
          text != "" &&
          !text.has_suffix(" ") {
          characters.write_char(' ')
        }
      }
      123 if variable => {
        let header = characters.to_string()
        characters.reset()
        if at_rule != "" {
          let children = []
          let value = header.trim().to_owned()
          let node = Node::AtRule(name=at_rule, value~, children~)
          rules.push(node)
          if at_rule == "@keyframes" || at_rule.has_suffix("keyframes") {
            // Keyframe selectors stand alone.
            self.parse([""], children, children)
          } else if at_rule
            is ("@media" | "@supports" | "@document" | "@container" | "@layer") {
            // Declarations placed directly inside go to a copy of the
            // enclosing rule.
            let own = []
            let wrapper = Node::Rule(selectors=parents, children=own)
            children.push(wrapper)
            self.parse(parents, own, children)
          } else {
            self.parse([""], children, children)
          }
        } else {
          let selectors = resolve_selectors(header, parents)
          let own = []
          rules.push(Node::Rule(selectors~, children=own))
          self.parse(selectors, own, rules)
        }
        property_end = 0
        property = 0
        at_rule = ""
        variable = true
        previous = 0
        continue
      }
      0 | 59 | 125 => {
        if !(character == 125 && !variable) {
          let text = characters.to_string().replace_all(old="\u{0c}", new="")
          if at_rule != "" {
            if character == 59 {
              rules.push(Node::Declaration(text + ";"))
            }
          } else if property_end > 0 && text.length() > property_end {
            // A space before the colon is dropped along with it.
            let text = if property > 32 {
              text
            } else {
              text.replace(old=" ", new="")
            }
            declarations.push(Node::Declaration(text + ";"))
          }
          characters.reset()
          property_end = 0
          property = 0
          at_rule = ""
          variable = true
          previous = 0
          if character != 59 {
            return
          }
          continue
        }
        characters.write_char('}')
        variable = true
      }
      58 => {
        characters.write_char(':')
        if property_end == 0 {
          property_end = characters.to_string().length()
          property = previous
        }
      }
      64 => {
        characters.write_char('@')
        if self.peek() == 45 {
          characters.write_char('-')
          self.position += 1
        }
        characters.write_string(self.identifier())
        at_rule = characters.to_string().trim().to_owned()
        // The name ends in a letter, so whitespace after it is kept.
        previous = 65
        continue
      }
      _ => {
        characters.write_char(Int32::unsafe_to_char(character))
        match character {
          38 => characters.write_char('\u{0c}')
          45 =>
            if previous == 45 && characters.to_string() == "--" {
              variable = false
            }
          _ => ()
        }
      }
    }
    previous = character
  }
}

///|
fn serialize(nodes : Array[Node], out : StringBuilder) -> Unit {
  for node in nodes {
    match node {
      Declaration(text) => out.write_string(text)
      Rule(selectors~, children~) => {
        let body = StringBuilder()
        serialize(children, body)
        if selectors.length() > 0 && !body.is_empty() {
          out.write_string(selectors.join(","))
          out.write_char('{')
          out.write_string(body.to_string())
          out.write_char('}')
        }
      }
      AtRule(name~, value~, children~) => {
        let body = StringBuilder()
        serialize(children, body)
        if name.has_suffix("keyframes") || !body.is_empty() {
          out.write_string(value)
          out.write_char('{')
          out.write_string(body.to_string())
          out.write_char('}')
        }
      }
    }
  }
}

///|
/// Compile `css` as the content of the rule `scope { ... }`, the way
/// mermaid scopes a diagram's stylesheet to its `<svg>` element: every rule
/// ends up under `scope`, minified.
pub fn compile(scope : String, css : String) -> String {
  let scanner = { chars: css.to_array(), position: 0, }
  let rules = []
  let own = []
  rules.push(Node::Rule(selectors=[scope], children=own))
  scanner.parse([scope], own, rules)
  let out = StringBuilder()
  serialize(rules, out)
  out.to_string()
}
