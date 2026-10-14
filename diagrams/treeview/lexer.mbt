// The token types of `treeView.langium`, in the order the lexer tries
// them: at every position the first one that matches wins, whatever its
// length. Line breaks are hidden, so the structure of the tree rests on
// the INDENTATION tokens alone, and on which terminal swallows a run of
// blanks first.

///|
/// `WS` is left out: it never matches, INDENTATION being the same pattern
/// ahead of it.
let token_types : Array[@langium.TokenType] = [
  // The keyword must not run into other text (upstream's token builder
  // adds the lookahead), and gives way to a bare name that reads
  // further: `treeView-beta.md` is a name.
  @langium.terminal_token("treeView-beta", "treeView-beta(?:(?=%%)|(?!\\S))", longer_alt=[
    "BARE_NAME",
  ]),
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
    "CLASS_ANNOTATION", "[ \\t]+:::[ \\t]*[A-Za-z_][\\w-]*",
  ),
  @langium.terminal_token(
    "ICON_ANNOTATION", "[ \\t]+icon\\([\\w-]*(?::[\\w-]+)?\\)",
  ),
  @langium.terminal_token("DESC_ANNOTATION", "[ \\t]+##[^\\n\\r]*"),
  @langium.terminal_token("INDENTATION", "[ \\t]{1,}"),
  @langium.terminal_token("QUOTED_NAME", "\"[^\"]*\"|'[^']*'"),
  @langium.terminal_token("ML_COMMENT", "%%[^\\n]*", hidden=true),
  @langium.terminal_token("NL", "\\r?\\n", hidden=true),
  @langium.terminal_token(
    "BARE_NAME", "(?!:::|icon\\(|##)[^ \\t\\n\\r\"'](?:(?![ \\t]+:::[ \\t]*[A-Za-z_]|[ \\t]+icon\\(|[ \\t]+##)[^\\n\\r])*",
  ),
]
