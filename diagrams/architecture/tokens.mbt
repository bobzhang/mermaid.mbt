///|
/// A keyword, which gives way to an identifier that goes on.
fn word(text : String) -> @langium.TokenType {
  @langium.keyword_token(text, longer_alt=["ID"])
}

///|
/// The token types of `architecture.langium`, in the order Langium's lexer
/// tries them, read out of the bundle
/// (`createArchitectureServices().Architecture.parser.Lexer.definition`):
/// keywords longest first, then the terminals in grammar order, the
/// imported `arch.langium` ones last.
///
/// The order has consequences. A side of an edge (`L`, `R`, `T`, `B`) is
/// tried before an identifier and has no longer alternative, so an
/// identifier cannot start with one of those letters; and a title starts
/// wherever `title` is written, before an identifier could take it.
let token_types : Array[@langium.TokenType] = [
  word("architecture-beta"),
  word("junction"),
  word("service"),
  word("column"),
  word("group"),
  word("align"),
  word("row"),
  @langium.keyword_token("--", longer_alt=["YAML"]),
  word("in"),
  @langium.keyword_token(":"),
  @langium.keyword_token("-", longer_alt=["YAML"]),
  @langium.terminal_token("ARROW_DIRECTION", "L|R|T|B"),
  @langium.terminal_token(
    "ARROW_GROUP",
    (
      #|\{group\}
    ),
  ),
  @langium.terminal_token("ARROW_INTO", "<|>"),
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
  @langium.terminal_token(
    "ARCH_ICON",
    (
      #|\([\w-:]+\)
    ),
  ),
  @langium.terminal_token(
    "ARCH_TITLE",
    (
      #|\[(?:"([^"\\]|\\.)*"|'([^'\\]|\\.)*'|[^\[\]\r\n]+)\]
    ),
  ),
]
