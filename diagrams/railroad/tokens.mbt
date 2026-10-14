// The token types of the four grammars, in the order Langium's lexer
// tries them, read out of the bundle
// (`createRailroadServices().Railroad.parser.Lexer.definition` and its
// three siblings): keywords longest first, then the terminals in grammar
// order. The first type that matches wins, unless one of its longer
// alternatives matches more.

///|
/// The diagram's keyword, which white space, a comment or the end must
/// follow; an identifier that goes on is an identifier.
fn diagram_keyword(keyword : String, identifier : String) -> @langium.TokenType {
  @langium.terminal_token(
    keyword,
    keyword +
    (
      #|(?:(?=%%)|(?!\S))
    ),
    longer_alt=[identifier],
  )
}

///|
/// The terminals every grammar starts with: the title and the
/// accessibility texts. Unlike those of the common grammar they take no
/// white space before them.
fn common_terminals() -> Array[@langium.TokenType] {
  [
    @langium.terminal_token(
      "TITLE",
      (
        #|title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|)
      ),
    ),
    @langium.terminal_token(
      "ACC_TITLE",
      (
        #|accTitle[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)
      ),
    ),
    @langium.terminal_token(
      "ACC_DESCR",
      (
        #|accDescr(?:[\t ]*:([^\n\r]*?(?=%%)|[^\n\r]*)|\s*{([^}]*)})
      ),
    ),
  ]
}

///|
/// The hidden terminals every grammar has: white space, line breaks
/// included, frontmatter, directives and `%%` comments.
fn hidden_terminals() -> Array[@langium.TokenType] {
  [
    @langium.terminal_token(
      "WHITESPACE",
      (
        #|[\t \r\n]+
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
}

///|
/// An identifier of the constructor, EBNF and PEG notations.
const IDENTIFIER : String =
  #|[A-Z_a-z][\w-]*

///|
/// A string in either kind of quotes, with backslash escapes.
const QUOTED : String =
  #|"([^"\\]|\\.)*"|'([^'\\]|\\.)*'

///|
/// A `/* ... */` comment.
const BLOCK_COMMENT : String =
  #|\/\*[\s\S]*?\*\/

///|
/// `railroad.langium`: the constructors are keywords.
let ir_tokens : Array[@langium.TokenType] = [
  diagram_keyword("railroad-beta", "ID"),
  @langium.keyword_token("nonterminal", longer_alt=["ID"]),
  @langium.keyword_token("zeroOrMore", longer_alt=["ID"]),
  @langium.keyword_token("oneOrMore", longer_alt=["ID"]),
  @langium.keyword_token("sequence", longer_alt=["ID"]),
  @langium.keyword_token("optional", longer_alt=["ID"]),
  @langium.keyword_token("terminal", longer_alt=["ID"]),
  @langium.keyword_token("special", longer_alt=["ID"]),
  @langium.keyword_token("choice", longer_alt=["ID"]),
  @langium.keyword_token("="),
  @langium.keyword_token(";"),
  @langium.keyword_token("("),
  @langium.keyword_token(","),
  @langium.keyword_token(")"),
  ..common_terminals(),
  @langium.terminal_token("ID", IDENTIFIER),
  @langium.terminal_token("STRING", QUOTED),
  ..hidden_terminals(),
  @langium.terminal_token("BLOCK_COMMENT", BLOCK_COMMENT, hidden=true),
]

///|
/// `railroad-ebnf.langium`. An opening parenthesis gives way to an ISO
/// comment `(* ... *)`, a question mark to a special sequence `? ... ?`
/// and a minus to frontmatter.
let ebnf_tokens : Array[@langium.TokenType] = [
  diagram_keyword("railroad-ebnf-beta", "ID"),
  @langium.keyword_token("::="),
  @langium.keyword_token("="),
  @langium.keyword_token(";"),
  @langium.keyword_token("|"),
  @langium.keyword_token(","),
  @langium.keyword_token("(", longer_alt=["ISO_COMMENT"]),
  @langium.keyword_token(")"),
  @langium.keyword_token("["),
  @langium.keyword_token("]"),
  @langium.keyword_token("{"),
  @langium.keyword_token("}"),
  @langium.keyword_token("?", longer_alt=["SPECIAL_SEQUENCE"]),
  @langium.keyword_token("*"),
  @langium.keyword_token("+"),
  @langium.keyword_token("-", longer_alt=["YAML"]),
  ..common_terminals(),
  @langium.terminal_token("ID", IDENTIFIER),
  @langium.terminal_token("STRING", QUOTED),
  // At least one character that is not white space between the question
  // marks, and no semicolon: a special sequence stays within its rule.
  @langium.terminal_token(
    "SPECIAL_SEQUENCE",
    (
      #|\?(?=[^?;]*[^?\s;][^?;]*\?)[^?;]*\?
    ),
  ),
  ..hidden_terminals(),
  @langium.terminal_token("BLOCK_COMMENT", BLOCK_COMMENT, hidden=true),
  @langium.terminal_token(
    "ISO_COMMENT",
    (
      #|\(\*[\s\S]*?\*\)
    ),
    hidden=true,
  ),
]

///|
/// `railroad-abnf.langium`. A semicolon gives way to a comment, which
/// runs to the end of the line: the semicolon that ends a rule must be
/// the last character of its line.
let abnf_tokens : Array[@langium.TokenType] = [
  diagram_keyword("railroad-abnf-beta", "RULENAME"),
  @langium.keyword_token("="),
  @langium.keyword_token(";", longer_alt=["COMMENT"]),
  @langium.keyword_token("/"),
  @langium.keyword_token("("),
  @langium.keyword_token(")"),
  @langium.keyword_token("["),
  @langium.keyword_token("]"),
  ..common_terminals(),
  @langium.terminal_token("RULENAME", "[A-Za-z][A-Za-z0-9-]*"),
  @langium.terminal_token(
    "STRING",
    (
      #|"[^"]*"
    ),
  ),
  @langium.terminal_token(
    "NUMVAL",
    (
      #|%[xXdDbB][0-9A-Fa-f]+(?:-[0-9A-Fa-f]+|\.[0-9A-Fa-f]+)*
    ),
  ),
  @langium.terminal_token(
    "REPEAT",
    (
      #|[0-9]*\*[0-9]*
    ),
  ),
  @langium.terminal_token("EXACT_REPEAT", "[0-9]+"),
  ..hidden_terminals(),
  @langium.terminal_token("COMMENT", ";[^\\n\\r]*", hidden=true),
]

///|
/// `railroad-peg.langium`.
let peg_tokens : Array[@langium.TokenType] = [
  diagram_keyword("railroad-peg-beta", "ID"),
  @langium.keyword_token("<-"),
  @langium.keyword_token(";"),
  @langium.keyword_token("/"),
  @langium.keyword_token("&"),
  @langium.keyword_token("!"),
  @langium.keyword_token("?"),
  @langium.keyword_token("*"),
  @langium.keyword_token("+"),
  @langium.keyword_token("("),
  @langium.keyword_token(")"),
  @langium.keyword_token("."),
  ..common_terminals(),
  @langium.terminal_token("ID", IDENTIFIER),
  @langium.terminal_token("STRING", QUOTED),
  ..hidden_terminals(),
  @langium.terminal_token("LINE_COMMENT", "#[^\\n\\r]*", hidden=true),
]
