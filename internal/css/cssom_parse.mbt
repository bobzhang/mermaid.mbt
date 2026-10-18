// Parsing a style sheet into rules and component values (CSS Syntax
// Level 3), as Blink does for `replaceSync`.

///|
/// A component value: a token, a function with its arguments, or a
/// simple block (`[`, `(` or `{`) with its contents; each with the indexes
/// of its first and last token.
priv enum Component {
  Preserved(Token, Int32)
  Func(String, Array[Component], Int32, Int32)
  Block(Char, Array[Component], Int32, Int32)
} derive(Eq, Debug)

///|
fn Component::first(self : Component) -> Int32 {
  match self {
    Preserved(_, at) => at
    Func(_, _, first, _) | Block(_, _, first, _) => first
  }
}

///|
fn Component::last(self : Component) -> Int32 {
  match self {
    Preserved(_, at) => at
    Func(_, _, _, last) | Block(_, _, _, last) => last
  }
}

///|
/// The token of a preserved component.
fn Component::token(self : Component) -> Token? {
  match self {
    Preserved(token, _) => Some(token)
    _ => None
  }
}

///|
fn Component::is_whitespace(self : Component) -> Bool {
  self is Preserved(Whitespace, _)
}

///|
/// A rule of a style sheet or block.
priv enum RawRule {
  Qualified(Array[Component], Array[Component])
  At(String, Array[Component], Array[Component]?)
}

///|
priv struct ComponentParser {
  tokens : Array[Token]
  mut pos : Int32
}

///|
fn ComponentParser::block_contents(
  self : ComponentParser,
  end : Token,
) -> (Array[Component], Int32) {
  let contents = []
  while self.pos < self.tokens.length() {
    if self.tokens[self.pos] == end {
      self.pos += 1
      return (contents, self.pos - 1)
    }
    contents.push(self.component())
  }
  (contents, self.tokens.length() - 1)
}

///|
fn ComponentParser::component(self : ComponentParser) -> Component {
  let at = self.pos
  let token = self.tokens[at]
  self.pos += 1
  let block = (kind : Char, end : Token) => {
    let (contents, last) = self.block_contents(end)
    Block(kind, contents, at, last)
  }
  match token {
    LeftBracket => block('[', RightBracket)
    LeftParen => block('(', RightParen)
    LeftBrace => block('{', RightBrace)
    Function(name) => {
      let (contents, last) = self.block_contents(RightParen)
      Func(name, contents, at, last)
    }
    _ => Preserved(token, at)
  }
}

///|
/// The component values of a text.
fn components(tokens : Tokens) -> Array[Component] {
  let parser = { tokens: tokens.tokens, pos: 0, }
  let out = []
  while parser.pos < tokens.tokens.length() {
    out.push(parser.component())
  }
  out
}

///|
/// The rules of a list of component values: a style sheet's top level
/// (where `<!--` and `-->` are ignored) or the contents of a block.
fn parse_rules(items : Array[Component], top_level : Bool) -> Array[RawRule] {
  let rules = []
  let mut i = 0
  while i < items.length() {
    match items[i] {
      Preserved(Whitespace, _) => i += 1
      Preserved(CDO | CDC, _) if top_level => i += 1
      Preserved(AtKeyword(name), _) => {
        i += 1
        let prelude = []
        let mut block = None
        while i < items.length() {
          match items[i] {
            Preserved(Semicolon, _) => {
              i += 1
              break
            }
            Block('{', contents, _, _) => {
              block = Some(contents)
              i += 1
              break
            }
            item => {
              prelude.push(item)
              i += 1
            }
          }
        }
        rules.push(At(name, prelude, block))
      }
      _ => {
        let prelude = []
        let mut block = None
        while i < items.length() {
          match items[i] {
            Block('{', contents, _, _) => {
              block = Some(contents)
              i += 1
              break
            }
            item => {
              prelude.push(item)
              i += 1
            }
          }
        }
        // A prelude without a block is a parse error, and nothing.
        if block is Some(block) {
          rules.push(Qualified(prelude, block))
        }
      }
    }
  }
  rules
}

///|
/// An item of a declaration list: a declaration, or something else.
priv enum BlockItem {
  /// The name, the value (trimmed), and whether it is important.
  Declaration(String, Array[Component], Bool)
  /// A nested rule or at-rule, which the port does not read.
  NestedRule
  /// Neither: dropped.
  Dropped
}

///|
/// Without leading and trailing white space.
fn trim_components(items : ArrayView[Component]) -> Array[Component] {
  let mut start = 0
  let mut end = items.length()
  while start < end && items[start].is_whitespace() {
    start += 1
  }
  while end > start && items[end - 1].is_whitespace() {
    end -= 1
  }
  items[start:end].to_owned()
}

///|
/// The items of a style rule's block, as CSS Syntax's "consume a block's
/// contents" reads them.
fn parse_block_items(items : Array[Component]) -> Array[BlockItem] {
  let out = []
  let mut i = 0
  while i < items.length() {
    match items[i] {
      Preserved(Whitespace | Semicolon, _) => {
        i += 1
        continue
      }
      Preserved(AtKeyword(_), _) => {
        out.push(NestedRule)
        while i < items.length() &&
              !(items[i] is (Preserved(Semicolon, _) | Block('{', _, _, _))) {
          i += 1
        }
        i += 1
        continue
      }
      _ => ()
    }
    // Up to the next semicolon; a `{}` block outside a custom property
    // makes the item a nested rule.
    let start = i
    let mut block = false
    while i < items.length() && !(items[i] is Preserved(Semicolon, _)) {
      if items[i] is Block('{', _, _, _) {
        block = true
      }
      i += 1
    }
    let item = items[start:i]
    i += 1
    out.push(declaration_item(item, block))
  }
  out
}

///|
fn declaration_item(item : ArrayView[Component], block : Bool) -> BlockItem {
  guard item is [Preserved(Ident(name), _), .. rest] else {
    return if block { NestedRule } else { Dropped }
  }
  let mut at = 0
  while rest.get(at) is Some(Preserved(Whitespace, _)) {
    at += 1
  }
  guard rest.get(at) is Some(Preserved(Colon, _)) else {
    return if block { NestedRule } else { Dropped }
  }
  if block && !name.has_prefix("--") {
    return NestedRule
  }
  let mut value = trim_components(rest[at + 1:])
  // `!important` at the end, in any case, with white space allowed.
  let mut important = false
  let mut last = value.length() - 1
  if last >= 0 &&
    value[last] is Preserved(Ident(word), _) &&
    word.to_lower() == "important" {
    last -= 1
    while last >= 0 && value[last].is_whitespace() {
      last -= 1
    }
    if last >= 0 && value[last] is Preserved(Delim('!'), _) {
      important = true
      value = trim_components(value[:last])
    }
  }
  Declaration(name, value, important)
}
