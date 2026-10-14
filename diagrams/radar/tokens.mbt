///|
/// The token types of `radar.langium`, in the order Langium's lexer tries
/// them: keywords longest first, then the grammar's own terminal, then
/// those of `common.langium`. Keywords made of identifier characters give
/// way to a longer identifier.
let token_types : Array[@langium.TokenType] = [
  @langium.keyword_token("radar-beta:"),
  // `radar-beta` must be followed by white space, a comment or the end.
  @langium.terminal_token(
    "radar-beta",
    (
      #|radar-beta(?:(?=%%)|(?!\S))
    ),
    longer_alt=["ID"],
  ),
  @langium.keyword_token("showLegend", longer_alt=["ID"]),
  @langium.keyword_token("graticule", longer_alt=["ID"]),
  @langium.keyword_token("curve", longer_alt=["ID"]),
  @langium.keyword_token("ticks", longer_alt=["ID"]),
  @langium.keyword_token("axis", longer_alt=["ID"]),
  @langium.keyword_token("max", longer_alt=["ID"]),
  @langium.keyword_token("min", longer_alt=["ID"]),
  @langium.keyword_token(":"),
  @langium.keyword_token(","),
  @langium.keyword_token("["),
  @langium.keyword_token("]"),
  @langium.keyword_token("{"),
  @langium.keyword_token("}"),
  @langium.terminal_token("GRATICULE", "circle|polygon"),
  @langium.terminal_token("BOOLEAN", "true|false"),
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
    "NUMBER",
    (
      #|(?:[0-9]+\.[0-9]+(?!\.))|(?:0|[1-9][0-9]*(?!\.))
    ),
  ),
  @langium.terminal_token(
    "STRING",
    (
      #|"([^"\\]|\\.)*"|'([^'\\]|\\.)*'
    ),
  ),
  @langium.terminal_token(
    "ID",
    (
      #|[\w]([-\w]*\w)?
    ),
  ),
  @langium.terminal_token(
    "NEWLINE",
    (
      #|\r?\n
    ),
  ),
  @langium.terminal_token(
    "WHITESPACE",
    (
      #|[\t ]+
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
]
