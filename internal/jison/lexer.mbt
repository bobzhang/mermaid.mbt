///|
/// A syntax or lexical error, worded as jison words it.
pub(all) suberror ParseError {
  ParseError(message~ : String, line~ : Int32)
} derive(Eq, Debug)

///|
/// The end-of-input token.
const EOF : Int32 = 1

///|
/// The lexer of a running parse. Custom hooks get it to read and change
/// the matched text and the start conditions.
pub struct Lexer {
  priv grammar : Grammar
  priv input : String
  priv mut position : Int32
  priv mut done : Bool
  priv mut yytext : String
  /// Zero-based line of the end of the last match.
  priv mut yylineno : Int32
  priv states : Array[String]
  /// An error a hook asked for, raised once the hook returns.
  priv mut failure : String?
}

///|
/// The text of the current token; a hook may replace it.
pub fn Lexer::text(self : Lexer) -> String {
  self.yytext
}

///|
pub fn Lexer::set_text(self : Lexer, text : String) -> Unit {
  self.yytext = text
}

///|
/// The current line, counting from one.
pub fn Lexer::line(self : Lexer) -> Int32 {
  self.yylineno + 1
}

///|
/// The start condition in effect.
pub fn Lexer::state(self : Lexer) -> String {
  self.states[self.states.length() - 1]
}

///|
pub fn Lexer::push_state(self : Lexer, state : String) -> Unit {
  self.states.push(state)
}

///|
/// Leave the current start condition. The initial one is never popped.
pub fn Lexer::pop_state(self : Lexer) -> Unit {
  if self.states.length() > 1 {
    ignore(self.states.pop())
  }
}

///|
/// Give the last `count` characters of the current token back to the
/// input, as jison's `unput` does with the text they spell.
pub fn Lexer::unput(self : Lexer, count : Int32) -> Unit {
  let text = self.yytext
  let kept = text.length() - count
  guard count > 0 && kept >= 0 else { return }
  for c in text[kept:] {
    if c == '\n' {
      self.yylineno -= 1
    }
  }
  self.position -= count
  self.yytext = text[:kept].to_owned()
}

///|
/// Make the parse fail with `message`: a rule whose code throws.
pub fn Lexer::fail(self : Lexer, message : String) -> Unit {
  self.failure = Some(message)
}

///|
/// What is left of the input.
pub fn Lexer::remaining(self : Lexer) -> StringView {
  self.input[self.position:]
}

///|
/// The part of the current line before and after the cursor, with a caret
/// under the cursor, as jison's `showPosition` prints it.
fn Lexer::show_position(self : Lexer) -> String {
  let before_start = if self.position > 20 { self.position - 20 } else { 0 }
  let before = (if before_start > 0 { "..." } else { "" }) +
    self.input[before_start:self.position]
    .to_owned()
    .replace_all(old="\n", new="")
  let after_end = if self.position + 20 < self.input.length() {
    self.position + 20
  } else {
    self.input.length()
  }
  let after = self.input[self.position:after_end]
    .to_owned()
    .replace_all(old="\n", new="") +
    (if after_end < self.input.length() { "..." } else { "" })
  before + after + "\n" + "-".repeat(before.length()) + "^"
}

///|
/// One attempt to produce a token: match a rule and run its operations.
/// `None` means the rule produced no token and lexing should go on.
fn Lexer::next(
  self : Lexer,
  hook : (Int32, Lexer) -> HookResult,
) -> Int32? raise ParseError {
  if self.done {
    return Some(EOF)
  }
  if self.position >= self.input.length() {
    self.done = true
  }
  let grammar = self.grammar
  let candidates = match grammar.conditions.get(self.state()) {
    Some(condition) => condition.rules
    None => []
  }
  let mut matched : (Int32, @jsregex.Match)? = None
  for rule in candidates {
    guard grammar.rules[rule].match_prefix(self.input, from=self.position)
      is Some(found) else {
      continue
    }
    match matched {
      Some((_, best)) if found.end <= best.end => ()
      _ => matched = Some((rule, found))
    }
    if !grammar.flex {
      break
    }
  }
  guard matched is Some((rule, found)) else {
    if self.position >= self.input.length() {
      return Some(EOF)
    }
    raise ParseError(
      message="Lexical error on line \{self.line()}. Unrecognized text.\n\{self.show_position()}",
      line=self.line(),
    )
  }
  let text = found.text()
  for c in text {
    if c == '\n' {
      self.yylineno += 1
    }
  }
  self.yytext = text
  self.position = found.end
  let mut token : Int32? = None
  let ops = grammar.lex_ops[rule]
  let mut index = 0
  while index < ops.length() {
    match ops[index] {
      Push(state) => self.push_state(state)
      Pop => self.pop_state()
      Return(name) => {
        token = Some(grammar.symbol_ids.get(name).unwrap_or(-1))
        break
      }
      Custom(id) =>
        match hook(id, self) {
          Continue => ()
          SkipNext => index += 1
          Stop => break
        }
    }
    index += 1
  }
  if self.failure is Some(message) {
    raise ParseError(message~, line=self.line())
  }
  if self.done && self.position < self.input.length() {
    self.done = false
  }
  token
}

///|
/// The next token.
fn Lexer::lex(
  self : Lexer,
  hook : (Int32, Lexer) -> HookResult,
) -> Int32 raise ParseError {
  while true {
    if self.next(hook) is Some(token) {
      return token
    }
  }
  EOF
}
