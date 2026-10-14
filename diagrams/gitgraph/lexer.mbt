// The token stream of the git graph grammar, cut the way Langium's lexer
// (chevrotain) cuts it: at every position the token types are tried in a
// fixed order and the first one that matches wins, whatever its length.
// That order is what makes `branch 1abc` or `branch title-fix` a syntax
// error upstream, so it is reproduced rather than approximated.

///|
priv enum TokenKind {
  Keyword(String)
  AccDescr
  AccTitle
  Title
  Int
  Str
  Newline
  Reference
} derive(Eq)

///|
priv struct Token {
  kind : TokenKind
  text : String
  offset : Int32
}

///|
/// The grammar's keywords, longest first, as Langium orders them. Keywords
/// that are also references give way to a longer reference: `commits` is
/// a branch name, not `commit` followed by `s`.
let keywords : Array[String] = [
  "cherry-pick", "HIGHLIGHT", "gitGraph:", "checkout", "gitGraph", "REVERSE", "parent:",
  "commit", "NORMAL", "branch", "switch", "order:", "merge", "type:", "msg:", "tag:",
  "id:", "LR", "TB", "BT", ":",
]

///|
priv struct Terminals {
  /// `gitGraph` must be followed by whitespace, a comment or the end.
  git_graph : @jsregex.Regex
  acc_descr : @jsregex.Regex
  acc_title : @jsregex.Regex
  title : @jsregex.Regex
  int : @jsregex.Regex
  string : @jsregex.Regex
  newline : @jsregex.Regex
  whitespace : @jsregex.Regex
  yaml : @jsregex.Regex
  directive : @jsregex.Regex
  comment : @jsregex.Regex
  reference : @jsregex.Regex
}

///|
/// The terminals of `gitGraph.langium` and `common.langium`.
let terminals : Terminals = {
  let regex = (source : String) => try! @jsregex.Regex::compile(source)
  let git_graph =
    #|gitGraph(?:(?=%%)|(?!\S))
  let acc_descr =
    #|[\t ]*accDescr(?:[\t ]*:([^\n\r]*?(?=%%)|[^\n\r]*)|\s*{([^}]*)})
  let acc_title =
    #|[\t ]*accTitle[\t ]*:(?:[^\n\r]*?(?=%%)|[^\n\r]*)
  let title =
    #|[\t ]*title(?:[\t ][^\n\r]*?(?=%%)|[\t ][^\n\r]*|)
  let int =
    #|0|[1-9][0-9]*(?!\.)
  let string =
    #|"([^"\\]|\\.)*"|'([^'\\]|\\.)*'
  let newline =
    #|\r?\n
  let whitespace =
    #|[\t ]+
  let yaml =
    #|---[\t ]*\r?\n(?:[\S\s]*?\r?\n)?---(?:\r?\n|(?!\S))
  let directive =
    #|[\t ]*%%{[\S\s]*?}%%(?:\r?\n|(?!\S))
  let comment =
    #|[\t ]*%%[^\n\r]*
  let reference =
    #|\w([-\./\w]*[-\w])?
  {
    git_graph: regex(git_graph),
    acc_descr: regex(acc_descr),
    acc_title: regex(acc_title),
    title: regex(title),
    int: regex(int),
    string: regex(string),
    newline: regex(newline),
    whitespace: regex(whitespace),
    yaml: regex(yaml),
    directive: regex(directive),
    comment: regex(comment),
    reference: regex(reference),
  }
}

///|
/// The end of the match of `regex` at `at`, if it matches there.
fn match_end(regex : @jsregex.Regex, input : String, at : Int32) -> Int32? {
  match regex.match_prefix(input, from=at) {
    Some(found) => Some(found.end)
    None => None
  }
}

///|
/// Whether `input` continues with `word` at `at`.
fn has_word(input : String, at : Int32, word : String) -> Bool {
  if at + word.length() > input.length() {
    return false
  }
  for i in 0..<word.length() {
    if input[at + i] != word[i] {
      return false
    }
  }
  true
}

///|
/// Cut `input` into tokens, hidden ones dropped. A position where no
/// token type matches is an error, as it is for mermaid's parser.
fn tokenize(input : String) -> Array[Token] raise @langium.ParseError {
  let t = terminals
  let tokens = []
  let mut at = 0
  let push = (kind : TokenKind, start : Int32, end : Int32) => {
    tokens.push({ kind, text: input[start:end].to_owned(), offset: start, })
  }
  while at < input.length() {
    let start = at
    // Keywords come first.
    let mut keyword : String? = None
    for word in keywords {
      let found = if word == "gitGraph" {
        match_end(t.git_graph, input, at) is Some(_)
      } else {
        has_word(input, at, word)
      }
      if found {
        keyword = Some(word)
        break
      }
    }
    if keyword is Some(word) {
      let end = at + word.length()
      // A keyword made of reference characters yields to a longer
      // reference.
      if !word.contains(":") &&
        match_end(t.reference, input, at) is Some(longer) &&
        longer > end {
        push(Reference, start, longer)
        at = longer
      } else {
        push(Keyword(word), start, end)
        at = end
      }
      continue
    }
    // Then the terminals, in the order of the grammar.
    let visible : Array[(@jsregex.Regex, TokenKind)] = [
      (t.acc_descr, AccDescr),
      (t.acc_title, AccTitle),
      (t.title, Title),
      (t.int, Int),
      (t.string, Str),
      (t.newline, Newline),
    ]
    let mut matched = false
    for entry in visible {
      if match_end(entry.0, input, at) is Some(end) {
        push(entry.1, start, end)
        at = end
        matched = true
        break
      }
    }
    if matched {
      continue
    }
    for hidden in [t.whitespace, t.yaml, t.directive, t.comment] {
      if match_end(hidden, input, at) is Some(end) {
        at = end
        matched = true
        break
      }
    }
    if matched {
      continue
    }
    guard match_end(t.reference, input, at) is Some(end) else {
      raise @langium.ParseError(
        message="unexpected character at offset: \{at}",
        offset=at,
      )
    }
    push(Reference, start, end)
    at = end
  }
  tokens
}
