///|
/// What the port cannot reproduce exactly and therefore refuses.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// An expression of a grammar rule, as the renderer draws it. The four
/// notations (the constructors of `railroad-beta`, EBNF, ABNF and PEG) all
/// come down to this.
pub(all) enum Node {
  /// A literal, in a rounded box.
  Terminal(String)
  /// A reference to a rule, in a box.
  NonTerminal(String)
  /// One after the other.
  Sequence(Array[Node])
  /// One of several, stacked.
  Choice(Array[Node])
  /// With a track that passes it by.
  Optional(Node)
  /// With a track that leads back; `min` zero adds one that passes it by.
  Repetition(Node, min~ : Double, max~ : Double)
  /// Text that stands for what the notation cannot say, in a dashed box.
  Special(String)
} derive(Eq, Debug)

///|
/// A rule of the grammar: a name and what it stands for.
pub(all) struct Rule {
  name : String
  definition : Node
} derive(Eq, Debug)

///|
/// A parsed railroad diagram.
pub struct Railroad {
  /// Kept as the database does, though nothing draws it.
  title : String
  acc_title : String
  acc_description : String
  rules : Array[Rule]
}

///|
/// The elements in a row; one alone is itself.
fn sequence_of(elements : Array[Node]) -> Node {
  if elements.length() == 1 {
    elements[0]
  } else {
    Sequence(elements)
  }
}

///|
/// One of the alternatives; one alone is itself.
fn choice_of(alternatives : Array[Node]) -> Node {
  if alternatives.length() == 1 {
    alternatives[0]
  } else {
    Choice(alternatives)
  }
}

///|
/// The parsers' `decodeEscapedString`: the text between the quotes, where
/// a backslash stands for the character after it, or for a line feed, a
/// carriage return or a tab before `n`, `r` and `t`.
fn decode_escaped_string(input : StringView) -> String {
  let content = input[1:input.length() - 1]
  let out = StringBuilder()
  let mut escaped = false
  let mut last = '\u{0}'
  for c in content {
    last = c
    if escaped {
      escaped = false
      out.write_char(
        match c {
          'n' => '\n'
          'r' => '\r'
          't' => '\t'
          _ => c
        },
      )
    } else if c == '\\' {
      escaped = true
    } else {
      out.write_char(c)
    }
  }
  // A backslash at the very end stands for itself.
  if escaped {
    out.write_char(last)
  }
  out.to_string()
}
