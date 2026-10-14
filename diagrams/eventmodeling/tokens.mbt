///|
/// A keyword, which gives way to an identifier that goes on.
fn word(text : String) -> @langium.TokenType {
  @langium.keyword_token(text, longer_alt=["ID"])
}

///|
/// The token types of `event-modeling.langium`, in the order Langium's
/// lexer tries them, read out of the bundle
/// (`createEventModelingServices().EventModel.parser.Lexer.definition`):
/// keywords longest first, then the terminals in grammar order.
///
/// The order has consequences. An identifier comes before the title and
/// the accessibility texts, so `title` at the start of a line is an
/// identifier, and white space comes after them: they are only seen
/// behind another token of their line, with the blanks before them.
let token_types : Array[@langium.TokenType] = [
  // `eventmodeling` must be followed by white space, a comment or the end.
  @langium.terminal_token(
    "eventmodeling",
    (
      #|eventmodeling(?:(?=%%)|(?!\S))
    ),
    longer_alt=["ID"],
  ),
  word("resetframe"),
  word("readmodel"),
  word("processor"),
  word("timeframe"),
  word("command"),
  word("entity"),
  word("event"),
  word("jsobj"),
  word("figma"),
  word("given"),
  word("json"),
  word("salt"),
  word("html"),
  word("text"),
  word("data"),
  word("note"),
  word("when"),
  word("then"),
  word("rmo"),
  word("cmd"),
  word("evt"),
  word("pcr"),
  word("uri"),
  @langium.keyword_token("->>"),
  word("gwt"),
  word("ui"),
  word("md"),
  word("tf"),
  @langium.keyword_token("[["),
  @langium.keyword_token("]]"),
  word("rf"),
  @langium.keyword_token("`"),
  @langium.keyword_token("."),
  @langium.terminal_token(
    "ID",
    (
      #|[_a-zA-Z][\w_]*
    ),
  ),
  @langium.terminal_token(
    "FID",
    (
      #|\d{1,3}
    ),
  ),
  // Data on one line: in braces, or a string in either kind of quotes,
  // each up to the last closing one of the line.
  @langium.terminal_token(
    "DATA_INLINE",
    (
      #|\{(.*)\}|"(.*)"|'(.*)'
    ),
  ),
  // Data over several lines: the opening brace ends its line and the
  // closing one starts its own.
  @langium.terminal_token(
    "DATA_BLOCK",
    (
      #|\{[\t ]*\r?\n(?:[\S\s]*?\r?\n)?\}(?:\r?\n|(?!\S))
    ),
  ),
  @langium.terminal_token(
    "ACC_DESCR",
    (
      #|[\t ]*accDescr(?:[\t ]*:([^\n\r]*?(?=%%)|[^\n\r]*)|\s*{([^}]*)})
    ),
  ),
  @langium.terminal_token(
    "ACC_TITLE",
    (
      #|[\t ]*accTitle[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)
    ),
  ),
  @langium.terminal_token(
    "TITLE",
    (
      #|[\t ]*title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|)
    ),
  ),
  @langium.terminal_token(
    "WS",
    (
      #|\s+
    ),
    hidden=true,
  ),
  @langium.terminal_token(
    "YAML",
    (
      #|---[\t ]*\r?\n(?:[\S\s]*?\r?\n)?---(?:\r?\n|(?!\S))
    ),
    hidden=true,
  ),
  @langium.terminal_token(
    "DIRECTIVE",
    (
      #|[\t ]*%%{[\S\s]*?}%%(?:\r?\n|(?!\S))
    ),
    hidden=true,
  ),
  @langium.terminal_token(
    "SINGLE_LINE_COMMENT",
    (
      #|[\t ]*%%[^\n\r]*
    ),
    hidden=true,
  ),
  @langium.terminal_token(
    "ML_COMMENT",
    (
      #|\/\*[\s\S]*?\*\/
    ),
    hidden=true,
  ),
  @langium.terminal_token(
    "SL_COMMENT",
    (
      #|\/\/[^\n\r]*
    ),
    hidden=true,
  ),
]
