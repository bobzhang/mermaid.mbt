// The tokens of `cynefin.langium`, cut the way Chevrotain does: at every
// position the keywords (longest first) and then the terminals are tried
// in order and the first one that matches wins. Domain names are a
// terminal without a word boundary, so `complexity` is the token
// `complex` followed by text no terminal matches.

///|
priv enum Token {
  /// `cynefin-beta` or `cynefin-beta:`.
  Keyword
  Arrow
  Colon
  DomainName(String)
  AccDescr(String)
  AccTitle(String)
  Title(String)
  /// A quoted string, already unquoted.
  Str(String)
  Newline
}

///|
fn regex(source : String) -> @jsregex.Regex {
  try! @jsregex.Regex::compile(source)
}

///|
/// What the lexer tries, in order; `None` marks a hidden terminal.
let terminals : Array[(@jsregex.Regex, ((String) -> Token)?)] = [
  (regex("cynefin-beta:"), Some(_ => Keyword)),
  // Upstream's token builder forbids text right after the bare keyword.
  (regex("cynefin-beta(?:(?=%%)|(?!\\S))"), Some(_ => Keyword)),
  (regex("-->"), Some(_ => Arrow)),
  (regex(":"), Some(_ => Colon)),
  (
    regex("complex|complicated|clear|chaotic|confusion"),
    Some(text => DomainName(text)),
  ),
  (
    regex(
      "[\\t ]*accDescr(?:[\\t ]*:([^\\n\\r]*?(?=%%)|[^\\n\\r]*)|\\s*{([^}]*)})",
    ),
    Some(text => AccDescr(text)),
  ),
  (
    regex("[\\t ]*accTitle[\\t ]*:(?:[^\\n\\r]*?(?=%%)|[^\\n\\r]*)"),
    Some(text => AccTitle(text)),
  ),
  (
    regex("[\\t ]*title(?:[\\t ][^\\n\\r]*?(?=%%)|[\\t ][^\\n\\r]*|)"),
    Some(text => Title(text)),
  ),
  (
    regex("\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'"),
    Some(text => Str(unquote(text))),
  ),
  (regex("\\r?\\n"), Some(_ => Newline)),
  (regex("[\\t ]+"), None),
  (regex("---[\\t ]*\\r?\\n(?:[\\S\\s]*?\\r?\\n)?---(?:\\r?\\n|(?!\\S))"), None),
  (regex("[\\t ]*%%{[\\S\\s]*?}%%(?:\\r?\\n|(?!\\S))"), None),
  (regex("[\\t ]*%%[^\\n\\r]*"), None),
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

///|
fn tokenize(input : String) -> Array[Token] raise CynefinError {
  let tokens = []
  let n = input.length()
  let mut position = 0
  while position < n {
    let mut matched = false
    for terminal in terminals {
      let (pattern, make) = terminal
      guard pattern.match_prefix(input, from=position) is Some(found) else {
        continue
      }
      // An empty match is no token.
      guard found.end > position else { continue }
      if make is Some(make) {
        tokens.push(make(found.text()))
      }
      position = found.end
      matched = true
      break
    }
    if !matched {
      raise CynefinError(
        "Lexer error: unexpected character at offset: \{position}",
      )
    }
  }
  tokens
}
