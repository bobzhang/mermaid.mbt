///|
/// The token types of `wardley.langium`, in the order Langium's lexer
/// tries them (read out of the bundle): punctuation, the grammar's own
/// terminals, then those of `common.langium`.
///
/// The keywords are regular-expression terminals here, not Langium
/// keywords, so none gives way to a longer name: a name that starts with
/// `size`, `note`, `build`, ... is cut after the keyword, and upstream
/// then rejects the line. `NAME_WITH_SPACES` comes after them and takes
/// the words of a name, spaces included, as one token.
let token_types : Array[@langium.TokenType] = [
  @langium.keyword_token("["),
  @langium.keyword_token(","),
  @langium.keyword_token("]"),
  @langium.keyword_token("@"),
  @langium.keyword_token("/"),
  @langium.keyword_token("("),
  @langium.keyword_token(")"),
  @langium.keyword_token("-", longer_alt=["ARROW", "LINK_ARROW", "YAML"]),
  @langium.keyword_token("{"),
  @langium.keyword_token("}"),
  @langium.terminal_token(
    "WARDLEY_NUMBER",
    (
      #|[0-9]+\.[0-9]+
    ),
  ),
  @langium.terminal_token("ARROW", "->"),
  @langium.terminal_token(
    "LINK_PORT",
    (
      #|\+<>|\+>|\+<
    ),
  ),
  @langium.terminal_token(
    "LINK_ARROW",
    (
      #|-->|-\.->|>|\+'[^']*'<>|\+'[^']*'<|\+'[^']*'>
    ),
  ),
  @langium.terminal_token(
    "LINK_LABEL",
    (
      #|;[^\n\r]+
    ),
  ),
  @langium.terminal_token("STRATEGY", "build|buy|outsource|market"),
  @langium.terminal_token("KW_WARDLEY", "wardley-beta"),
  @langium.terminal_token("KW_SIZE", "size"),
  @langium.terminal_token("KW_EVOLUTION", "evolution"),
  @langium.terminal_token("KW_ANCHOR", "anchor"),
  @langium.terminal_token("KW_COMPONENT", "component"),
  @langium.terminal_token("KW_LABEL", "label"),
  @langium.terminal_token("KW_INERTIA", "inertia"),
  @langium.terminal_token("KW_EVOLVE", "evolve"),
  @langium.terminal_token("KW_PIPELINE", "pipeline"),
  @langium.terminal_token("KW_NOTE", "note"),
  @langium.terminal_token("KW_ANNOTATIONS", "annotations"),
  @langium.terminal_token("KW_ANNOTATION", "annotation"),
  @langium.terminal_token("KW_ACCELERATOR", "accelerator"),
  @langium.terminal_token("KW_DEACCELERATOR", "deaccelerator"),
  @langium.terminal_token(
    "NAME_WITH_SPACES",
    (
      #|(?!title\s|accTitle|accDescr)[A-Za-z](?:[A-Za-z0-9_()&]|-(?!>))*(?:[ \t]+[A-Za-z(](?:[A-Za-z0-9_()&]|-(?!>))*)*
    ),
  ),
  @langium.terminal_token(
    "WS",
    (
      #|[ \t]+
    ),
    hidden=true,
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
    "INT",
    (
      #|0|[1-9][0-9]*(?!\.)
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
