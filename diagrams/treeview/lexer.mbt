// The tokens of `treeView.langium`, cut the way Chevrotain does: at every
// position the terminals are tried in the order of the grammar and the
// first one that matches wins, whatever its length. Line breaks are hidden,
// so the structure of the tree rests on the INDENTATION tokens alone, and
// on which terminal swallows a run of blanks first.

///|
priv enum TokenKind {
  Keyword
  AccDescr
  AccTitle
  Title
  ClassAnnotation
  IconAnnotation
  DescAnnotation
  Indentation
  QuotedName
  BareName
} derive(Eq)

///|
priv struct Token {
  kind : TokenKind
  text : String
}

///|
/// The keyword must not run into other text: upstream's token builder adds
/// the lookahead.
let keyword_pattern : @jsregex.Regex = regex("treeView-beta(?:(?=%%)|(?!\\S))")

///|
let bare_name_pattern : @jsregex.Regex = regex(
  "(?!:::|icon\\(|##)[^ \\t\\n\\r\"'](?:(?![ \\t]+:::[ \\t]*[A-Za-z_]|[ \\t]+icon\\(|[ \\t]+##)[^\\n\\r])*",
)

///|
/// The terminals after the keyword, in the order the lexer tries them.
/// `None` marks a hidden terminal. `WS` never matches, INDENTATION being
/// the same pattern ahead of it.
let terminals : Array[(@jsregex.Regex, TokenKind?)] = [
  (
    regex(
      "[\\t ]*accDescr(?:[\\t ]*:([^\\n\\r]*?(?=%%)|[^\\n\\r]*)|\\s*{([^}]*)})",
    ),
    Some(AccDescr),
  ),
  (
    regex("[\\t ]*accTitle[\\t ]*:(?:[^\\n\\r]*?(?=%%)|[^\\n\\r]*)"),
    Some(AccTitle),
  ),
  (
    regex("[\\t ]*title(?:[\\t ][^\\n\\r]*?(?=%%)|[\\t ][^\\n\\r]*|)"),
    Some(Title),
  ),
  (regex("[ \\t]+:::[ \\t]*[A-Za-z_][\\w-]*"), Some(ClassAnnotation)),
  (regex("[ \\t]+icon\\([\\w-]*(?::[\\w-]+)?\\)"), Some(IconAnnotation)),
  (regex("[ \\t]+##[^\\n\\r]*"), Some(DescAnnotation)),
  (regex("[ \\t]{1,}"), Some(Indentation)),
  (regex("\"[^\"]*\"|'[^']*'"), Some(QuotedName)),
  (regex("%%[^\\n]*"), None),
  (regex("\\r?\\n"), None),
  (bare_name_pattern, Some(BareName)),
]

///|
fn tokenize(input : String) -> Array[Token] raise TreeViewError {
  let tokens = []
  let n = input.length()
  let mut position = 0
  while position < n {
    // The keyword gives way to a bare name that reads further (its
    // "longer alternative"): `treeView-beta.md` is a name.
    if keyword_pattern.match_prefix(input, from=position) is Some(found) {
      let longer = match bare_name_pattern.match_prefix(input, from=position) {
        Some(name) if name.end > found.end => Some(name)
        _ => None
      }
      match longer {
        Some(name) => {
          tokens.push({ kind: BareName, text: name.text(), })
          position = name.end
        }
        None => {
          tokens.push({ kind: Keyword, text: found.text(), })
          position = found.end
        }
      }
      continue
    }
    let mut matched = false
    for terminal in terminals {
      let (pattern, kind) = terminal
      guard pattern.match_prefix(input, from=position) is Some(found) else {
        continue
      }
      // An empty match is no token.
      guard found.end > position else { continue }
      if kind is Some(kind) {
        tokens.push({ kind, text: found.text(), })
      }
      position = found.end
      matched = true
      break
    }
    if !matched {
      raise TreeViewError(
        "Lexer error: unexpected character at offset: \{position}",
      )
    }
  }
  tokens
}
