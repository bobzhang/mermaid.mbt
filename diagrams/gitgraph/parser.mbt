///|
/// A statement of the grammar, as Langium's AST holds it.
priv enum Statement {
  Commit(
    id~ : String?,
    message~ : String?,
    tags~ : Array[String],
    kind~ : CommitType?
  )
  Branch(name~ : String, order~ : Double?)
  Merge(
    branch~ : String,
    id~ : String?,
    tags~ : Array[String],
    kind~ : CommitType?
  )
  Checkout(String)
  CherryPick(id~ : String?, tags~ : Array[String], parent~ : String?)
}

///|
/// A recursive-descent parser over the token stream.
priv struct Parser {
  tokens : Array[Token]
  mut position : Int32
  /// The length of the input, where errors at the end are reported.
  end : Int32
}

///|
fn Parser::peek(self : Parser) -> TokenKind? {
  if self.position < self.tokens.length() {
    Some(self.tokens[self.position].kind)
  } else {
    None
  }
}

///|
fn[T] Parser::fail(
  self : Parser,
  expected : String,
) -> T raise @langium.ParseError {
  let (found, offset) = if self.position < self.tokens.length() {
    let token = self.tokens[self.position]
    ("'\{token.text}'", token.offset)
  } else {
    ("the end of the input", self.end)
  }
  raise @langium.ParseError(
    message="Expecting \{expected} but found \{found}.",
    offset~,
  )
}

///|
/// Consume the keyword `word` if it is next.
fn Parser::keyword(self : Parser, word : String) -> Bool {
  if self.peek() == Some(Keyword(word)) {
    self.position += 1
    true
  } else {
    false
  }
}

///|
/// Consume a token of `kind` if one is next, and return its text.
fn Parser::take(self : Parser, kind : TokenKind) -> String? {
  if self.peek() == Some(kind) {
    self.position += 1
    Some(self.tokens[self.position - 1].text)
  } else {
    None
  }
}

///|
/// STRING, converted: quotes removed and escapes resolved.
fn Parser::string(self : Parser) -> String raise @langium.ParseError {
  guard self.take(Str) is Some(text) else { self.fail("a quoted string") }
  // The token is a complete string literal, so this always converts.
  @langium.Lexer::new(text).string().unwrap_or("")
}

///|
/// `REFERENCE | STRING`: a branch name.
fn Parser::name(self : Parser) -> String raise @langium.ParseError {
  match self.take(Reference) {
    Some(name) => name
    None => self.string()
  }
}

///|
/// `'NORMAL' | 'REVERSE' | 'HIGHLIGHT'`
fn Parser::commit_type(self : Parser) -> CommitType raise @langium.ParseError {
  if self.keyword("NORMAL") {
    Normal
  } else if self.keyword("REVERSE") {
    Reverse
  } else if self.keyword("HIGHLIGHT") {
    Highlight
  } else {
    self.fail("one of NORMAL, REVERSE, HIGHLIGHT")
  }
}

///|
/// `EOL: NEWLINE+ | EOF`
fn Parser::eol(self : Parser) -> Unit raise @langium.ParseError {
  if self.peek() is None {
    return
  }
  if self.take(Newline) is None {
    self.fail("the end of the line")
  }
  while self.take(Newline) is Some(_) {

  }
}

///|
/// One of the five statements, or nothing when the next token starts none.
fn Parser::statement(self : Parser) -> Statement? raise @langium.ParseError {
  if self.keyword("commit") {
    let mut id = None
    let mut message = None
    let mut kind = None
    let tags = []
    while true {
      if self.keyword("id:") {
        id = Some(self.string())
      } else if self.keyword("msg:") {
        message = Some(self.string())
      } else if self.keyword("tag:") {
        tags.push(self.string())
      } else if self.keyword("type:") {
        kind = Some(self.commit_type())
      } else if self.peek() == Some(Str) {
        // `msg:` is optional before the message.
        message = Some(self.string())
      } else {
        break
      }
    }
    self.eol()
    Some(Commit(id~, message~, tags~, kind~))
  } else if self.keyword("branch") {
    let name = self.name()
    let mut order = None
    if self.keyword("order:") {
      guard self.take(Int) is Some(digits) else { self.fail("an integer") }
      order = Some(@string.parse_double(digits)) catch { _ => None }
    }
    self.eol()
    Some(Branch(name~, order~))
  } else if self.keyword("merge") {
    let branch = self.name()
    let mut id = None
    let mut kind = None
    let tags = []
    while true {
      if self.keyword("id:") {
        id = Some(self.string())
      } else if self.keyword("tag:") {
        tags.push(self.string())
      } else if self.keyword("type:") {
        kind = Some(self.commit_type())
      } else {
        break
      }
    }
    self.eol()
    Some(Merge(branch~, id~, tags~, kind~))
  } else if self.keyword("checkout") || self.keyword("switch") {
    let branch = self.name()
    self.eol()
    Some(Checkout(branch))
  } else if self.keyword("cherry-pick") {
    let mut id = None
    let mut parent = None
    let tags = []
    while true {
      if self.keyword("id:") {
        id = Some(self.string())
      } else if self.keyword("tag:") {
        tags.push(self.string())
      } else if self.keyword("parent:") {
        parent = Some(self.string())
      } else {
        break
      }
    }
    self.eol()
    Some(CherryPick(id~, tags~, parent~))
  } else {
    None
  }
}

///|
/// Parse a git graph and replay its statements on a fresh database:
///
/// ```text
/// GitGraph: NEWLINE*
///   ("gitGraph" | "gitGraph" ":" | "gitGraph:" | "gitGraph" Direction ":")
///   (NEWLINE | TitleAndAccessibilities | Statement)*
/// Direction: "LR" | "TB" | "BT"
/// Commit: "commit" ("id:" STRING | "msg:"? STRING | "tag:" STRING
///                  | "type:" ("NORMAL" | "REVERSE" | "HIGHLIGHT"))* EOL
/// Branch: "branch" (REFERENCE | STRING) ("order:" INT)? EOL
/// Merge: "merge" (REFERENCE | STRING) ("id:" STRING | "tag:" STRING
///                  | "type:" (...))* EOL
/// Checkout: ("checkout" | "switch") (REFERENCE | STRING) EOL
/// CherryPicking: "cherry-pick" ("id:" STRING | "tag:" STRING
///                  | "parent:" STRING)* EOL
/// ```
///
/// Raises `@langium.ParseError` for text the grammar rejects, `GitError`
/// for an operation the history does not allow, and `Unsupported` for
/// text the port cannot sanitize exactly.
pub fn parse(source : String, config : @config.Config) -> GitGraph raise {
  let parser = { tokens: tokenize(source), position: 0, end: source.length(), }
  while parser.take(Newline) is Some(_) {

  }
  let mut direction = None
  if !parser.keyword("gitGraph:") {
    if !parser.keyword("gitGraph") {
      parser.fail("keyword 'gitGraph'")
    }
    if !parser.keyword(":") {
      for candidate in ["LR", "TB", "BT"] {
        if parser.keyword(candidate) {
          direction = Some(candidate)
          // A direction is only one with its colon.
          if !parser.keyword(":") {
            parser.fail("token of type ':'")
          }
          break
        }
      }
    }
  }
  let statements = []
  let mut title = None
  let mut acc_title = None
  let mut acc_description = None
  while parser.peek() is Some(kind) {
    match kind {
      Newline => parser.position += 1
      AccDescr | AccTitle | Title => {
        let text = parser.tokens[parser.position].text
        parser.position += 1
        // The shared lexer converts the token's text to its value.
        let lexer = @langium.Lexer::new(text)
        match kind {
          AccDescr => acc_description = lexer.acc_descr()
          AccTitle => acc_title = lexer.acc_title()
          _ => title = lexer.title()
        }
        parser.eol()
      }
      _ =>
        match parser.statement() {
          Some(statement) => statements.push(statement)
          None => parser.fail("a statement")
        }
    }
  }
  // The whole text is parsed before anything reaches the database.
  let graph = GitGraph::new(config)
  if acc_description is Some(text) && text != "" {
    graph.acc_description = sanitize_common(text)
  }
  if acc_title is Some(text) && text != "" {
    graph.acc_title = sanitize_common(text)
  }
  if title is Some(text) && text != "" {
    graph.title = sanitize_common(text)
  }
  if direction is Some(direction) {
    graph.direction = direction
  }
  for statement in statements {
    match statement {
      Commit(id~, message~, tags~, kind~) =>
        graph.commit(id, message.unwrap_or(""), kind.unwrap_or(Normal), tags)
      Branch(name~, order~) => graph.branch(name, order.unwrap_or(0.0))
      Merge(branch~, id~, tags~, kind~) =>
        graph.merge(branch, id.unwrap_or(""), kind, tags)
      Checkout(branch) => graph.checkout(branch)
      CherryPick(id~, tags~, parent~) =>
        graph.cherry_pick(
          id,
          if tags.is_empty() {
            None
          } else {
            Some(tags)
          },
          parent,
        )
    }
  }
  graph
}
