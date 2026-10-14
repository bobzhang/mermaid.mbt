///|
/// A semantic value of venn.jison.
priv enum Value {
  Nothing
  /// A token, or a style value.
  Text(String)
  /// Identifiers, or the tokens of a style value.
  List(Array[String])
  /// A style property and its value.
  Field(String, String)
  Fields(Array[(String, String)])
}

///|
/// The grammar's custom lexer code, by number (see the head of
/// `gen_venn_grammar.mbt`).
fn Venn::lexer_hook(
  self : Venn,
  hook : Int32,
  lexer : @jison.Lexer,
) -> @jison.HookResult {
  let text = lexer.text()
  match hook {
    // Indentation before `text`, after a `set` or `union`: a token that
    // attaches the text to that statement.
    0 =>
      if self.indent_mode {
        self.consume_indent_text = true
        lexer.push_state("INITIAL")
        return Token("INDENT_TEXT")
      }
    // The first character of a line that is not indented.
    1 => self.indent_mode = false
    2 => lexer.unput(text.length())
    3 =>
      if self.consume_indent_text {
        self.consume_indent_text = false
        return SkipNext
      }
    4 => return Token("TEXT")
    5 => lexer.set_text(text[2:text.length() - 2].to_owned())
    6 => lexer.set_text(js_trim(text[1:text.length() - 1]))
    _ => ()
  }
  Continue
}

///|
/// jison's `performAction` for venn.jison: run the semantic action of one
/// production. `None` keeps the default value, that of the first symbol.
fn Venn::reduce(
  self : Venn,
  reduction : @jison.Reduction[Value],
) -> Value? raise VennError {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let s = (k : Int32) => {
    match v(k) {
      Text(text) => text
      _ => ""
    }
  }
  let list = (k : Int32) => {
    match v(k) {
      List(items) => items
      _ => []
    }
  }
  let number = (k : Int32) => Some(@diagram.parse_float(s(k)))
  let union = (identifiers : Array[String], label : String?, size : Double?) => {
    if identifiers.length() < 2 {
      raise Invalid("union requires multiple identifiers")
    }
    self.validate_union(identifiers)
    self.add_subset(identifiers, label, size)
    self.indent_mode = true
  }
  let indented_text = (id : String, label : String?) => {
    guard self.current_sets is Some(sets) else {
      raise Invalid("text requires set")
    }
    self.add_text(sets, id, label)
  }
  match reduction.production {
    2 | 3 | 4 | 6 => Some(Nothing)
    // `title` and the white space after it are six characters.
    8 => {
      let title = s(0)
      let title = if title.length() > 6 { title[6:].to_owned() } else { "" }
      self.title = title
      Some(Text(title))
    }
    9 => {
      self.add_subset([s(0)], None, None)
      self.indent_mode = true
      None
    }
    10 => {
      self.add_subset([s(1)], Some(s(0)), None)
      self.indent_mode = true
      None
    }
    11 => {
      self.add_subset([s(2)], None, number(0))
      self.indent_mode = true
      None
    }
    12 => {
      self.add_subset([s(3)], Some(s(2)), number(0))
      self.indent_mode = true
      None
    }
    13 => {
      union(list(0), None, None)
      None
    }
    14 => {
      union(list(1), Some(s(0)), None)
      None
    }
    15 => {
      union(list(2), None, number(0))
      None
    }
    16 => {
      union(list(3), Some(s(2)), number(0))
      None
    }
    17 | 18 | 19 => {
      self.add_text(list(1), s(0), None)
      None
    }
    20 | 21 => {
      self.add_text(list(2), s(1), Some(s(0)))
      None
    }
    22 => Some(v(0))
    23 => {
      let fields = match v(0) {
        Fields(fields) => fields
        _ => []
      }
      self.add_style(list(1), fields)
      None
    }
    24 | 25 | 26 => {
      indented_text(s(0), None)
      None
    }
    27 | 28 => {
      indented_text(s(1), Some(s(0)))
      None
    }
    29 =>
      match v(0) {
        Field(key, value) => Some(Fields([(key, value)]))
        _ => Some(Fields([]))
      }
    30 => {
      let fields = match v(2) {
        Fields(fields) => fields.copy()
        _ => []
      }
      if v(0) is Field(key, value) {
        fields.push((key, value))
      }
      Some(Fields(fields))
    }
    31 => Some(Field(s(2), s(0)))
    33 => Some(Text(list(0).join(" ")))
    34 | 41 => Some(List([s(0)]))
    35 => {
      let tokens = list(1)
      tokens.push(s(0))
      Some(List(tokens))
    }
    42 => {
      let identifiers = list(2).copy()
      identifiers.push(s(0))
      Some(List(identifiers))
    }
    _ => None
  }
}

///|
/// Parse the source of a Venn diagram with venn.jison:
///
/// ```text
/// start: NEWLINE* VENN (NEWLINE | statement)* EOF
/// statement: TITLE
///          | SET identifier BRACKET_LABEL? (COLON NUMERIC)?
///          | UNION identifierList BRACKET_LABEL? (COLON NUMERIC)?
///          | TEXT identifierList (IDENTIFIER | STRING | NUMERIC)
///          | TEXT identifierList (IDENTIFIER | STRING) BRACKET_LABEL
///          | INDENT_TEXT (IDENTIFIER | STRING | NUMERIC)
///          | INDENT_TEXT (IDENTIFIER | STRING) BRACKET_LABEL
///          | STYLE identifierList styleField (COMMA styleField)*
/// ```
pub fn parse(source : String) -> Venn raise {
  let venn = Venn::new()
  venn_grammar.parse(
    source,
    empty=Nothing,
    token=text => Text(text),
    reduce=reduction => venn.reduce(reduction),
    hook=(hook, lexer) => venn.lexer_hook(hook, lexer),
  )
  |> ignore
  venn
}
