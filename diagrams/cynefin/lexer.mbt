// The token types of `cynefin.langium`, in the order the lexer tries
// them: the keywords, longest first, then the grammar's own terminal and
// the common ones. Domain names are a terminal without a word boundary,
// so `complexity` is the token `complex` followed by text no terminal
// matches.

///|
fn regex(source : String) -> @jsregex.Regex {
  try! @jsregex.Regex::compile(source)
}

///|
let token_types : Array[@langium.TokenType] = [
  @langium.keyword_token("cynefin-beta:"),
  // Upstream's token builder forbids text right after the bare keyword.
  @langium.terminal_token("cynefin-beta", "cynefin-beta(?:(?=%%)|(?!\\S))"),
  @langium.keyword_token("-->"),
  @langium.keyword_token(":"),
  @langium.terminal_token(
    "DOMAIN_NAME", "complex|complicated|clear|chaotic|confusion",
  ),
  @langium.terminal_token(
    "ACC_DESCR", "[\\t ]*accDescr(?:[\\t ]*:([^\\n\\r]*?(?=%%)|[^\\n\\r]*)|\\s*{([^}]*)})",
  ),
  @langium.terminal_token(
    "ACC_TITLE", "[\\t ]*accTitle[\\t ]*:(?:[^\\n\\r]*?(?=%%)|[^\\n\\r]*)",
  ),
  @langium.terminal_token(
    "TITLE", "[\\t ]*title(?:[\\t ][^\\n\\r]*?(?=%%)|[\\t ][^\\n\\r]*|)",
  ),
  @langium.terminal_token(
    "STRING", "\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'",
  ),
  @langium.terminal_token("NEWLINE", "\\r?\\n"),
  @langium.terminal_token("WHITESPACE", "[\\t ]+", hidden=true),
  @langium.terminal_token(
    "YAML",
    "---[\\t ]*\\r?\\n(?:[\\S\\s]*?\\r?\\n)?---(?:\\r?\\n|(?!\\S))",
    hidden=true,
  ),
  @langium.terminal_token(
    "DIRECTIVE",
    "[\\t ]*%%{[\\S\\s]*?}%%(?:\\r?\\n|(?!\\S))",
    hidden=true,
  ),
  @langium.terminal_token(
    "SINGLE_LINE_COMMENT",
    "[\\t ]*%%[^\\n\\r]*",
    hidden=true,
  ),
]

///|
/// The value of a STRING token: without its quotes, escapes resolved.
fn unquote(token : String) -> String {
  let out = StringBuilder()
  let mut i = 1
  while i < token.length() - 1 {
    let unit = token[i]
    if unit == '\\' {
      i += 1
      match token[i] {
        'b' => out.write_char('\b')
        'f' => out.write_char('\u{0c}')
        'n' => out.write_char('\n')
        'r' => out.write_char('\r')
        't' => out.write_char('\t')
        'v' => out.write_char('\u{0b}')
        '0' => out.write_char('\u{00}')
        _ => out.write_view(token[i:i + 1])
      }
    } else {
      out.write_view(token[i:i + 1])
    }
    i += 1
  }
  out.to_string()
}
