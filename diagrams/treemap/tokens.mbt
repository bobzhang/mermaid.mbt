///|
/// The token types of `treemap.langium`, in the order Langium's lexer
/// tries them. The grammar has no keywords and hides line breaks, so a
/// treemap is one stream of items; white space is an `INDENTATION` token
/// wherever it stands, at the start of a line or not.
let token_types : Array[@langium.TokenType] = [
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
  @langium.terminal_token("TREEMAP_KEYWORD", "treemap-beta|treemap"),
  @langium.terminal_token(
    "CLASS_DEF",
    (
      #|classDef\s+([a-zA-Z_][a-zA-Z0-9_]+)(?:\s+([^;\r\n]*))?(?:;)?
    ),
  ),
  @langium.terminal_token("STYLE_SEPARATOR", ":::"),
  @langium.terminal_token("SEPARATOR", ":"),
  @langium.terminal_token("COMMA", ","),
  @langium.terminal_token(
    "INDENTATION",
    (
      #|[ \t]{1,}
    ),
  ),
  @langium.terminal_token(
    "ML_COMMENT",
    (
      #|\%\%[^\n]*
    ),
    hidden=true,
  ),
  @langium.terminal_token(
    "NL",
    (
      #|\r?\n
    ),
    hidden=true,
  ),
  @langium.terminal_token("ID2", "[a-zA-Z_][a-zA-Z0-9_]*"),
  @langium.terminal_token(
    "NUMBER2",
    (
      #|[0-9_\.\,]+
    ),
  ),
  @langium.terminal_token(
    "STRING2",
    (
      #|"[^"]*"|'[^']*'
    ),
  ),
]
