// Langium's lexer (chevrotain) as a table-driven tokenizer, for grammars
// whose token order matters: at every position the token types are tried
// in a fixed order and the first that matches wins, whatever its length.
// The order and the patterns of a grammar can be read out of the bundle
// with `createXServices().X.parser.Lexer.definition`.

///|
/// How a token type matches.
pub(all) enum TokenPattern {
  /// The text itself.
  Literal(String)
  /// A JavaScript regular expression, matched at the current position.
  Pattern(@jsregex.Regex)
}

///|
/// A token type of a grammar.
pub(all) struct TokenType {
  name : String
  pattern : TokenPattern
  /// Skipped and hidden tokens never reach the parser.
  hidden : Bool
  /// Token types (by name) that take over when they match more text at
  /// the same position: chevrotain's `LONGER_ALT`, which makes `axisX` an
  /// identifier rather than the keyword `axis` and an `X`.
  longer_alt : Array[String]
}

///|
/// A keyword or punctuation token, named after its text.
pub fn keyword_token(
  text : String,
  longer_alt~ : Array[String] = [],
) -> TokenType {
  { name: text, pattern: Literal(text), hidden: false, longer_alt, }
}

///|
/// A terminal given by a JavaScript regular expression.
pub fn terminal_token(
  name : String,
  source : String,
  hidden~ : Bool = false,
  longer_alt~ : Array[String] = [],
) -> TokenType {
  let regex = try! @jsregex.Regex::compile(source)
  { name, pattern: Pattern(regex), hidden, longer_alt, }
}

///|
/// A token: the name of its type, its text and where it starts.
pub(all) struct Token {
  kind : String
  text : String
  offset : Int32
} derive(Debug)

///|
/// The end of the match of a token type at `at`, if it matches there.
fn TokenType::match_at(self : TokenType, input : String, at : Int32) -> Int32? {
  match self.pattern {
    Literal(text) => {
      if at + text.length() > input.length() {
        return None
      }
      for i in 0..<text.length() {
        if input[at + i] != text[i] {
          return None
        }
      }
      Some(at + text.length())
    }
    Pattern(regex) =>
      match regex.match_prefix(input, from=at) {
        Some(found) => Some(found.end)
        None => None
      }
  }
}

///|
/// Cut `input` into the tokens the parser sees. A position where no token
/// type matches is an error, as it is for mermaid's parsers (chevrotain
/// would skip the character and report it).
pub fn tokenize(
  input : String,
  types : Array[TokenType],
) -> Array[Token] raise ParseError {
  let by_name : Map[String, TokenType] = Map([])
  for token_type in types {
    by_name[token_type.name] = token_type
  }
  let tokens = []
  let mut at = 0
  while at < input.length() {
    let mut found : (TokenType, Int32)? = None
    for token_type in types {
      // A pattern that matches nothing is no match.
      guard token_type.match_at(input, at) is Some(end) && end > at else {
        continue
      }
      let mut winner = (token_type, end)
      for name in token_type.longer_alt {
        guard by_name.get(name) is Some(alternative) else { continue }
        if alternative.match_at(input, at) is Some(longer) && longer > end {
          winner = (alternative, longer)
          break
        }
      }
      found = Some(winner)
      break
    }
    guard found is Some((token_type, end)) else {
      let character = input.get_char(at).map(c => c.to_string()).unwrap_or("")
      raise ParseError(
        message="unexpected character: ->\{character}<- at offset: \{at}",
        offset=at,
      )
    }
    if !token_type.hidden {
      tokens.push({
        kind: token_type.name,
        text: input[at:end].to_owned(),
        offset: at,
      })
    }
    at = end
  }
  tokens
}

///|
/// A cursor over tokens, for recursive-descent parsers.
pub struct TokenStream {
  priv tokens : Array[Token]
  priv mut position : Int32
  priv length : Int32
}

///|
/// `length` is that of the input, for errors at its end.
pub fn TokenStream::new(tokens : Array[Token], length : Int32) -> TokenStream {
  { tokens, position: 0, length, }
}

///|
/// The kind of the next token, `"EOF"` at the end.
pub fn TokenStream::peek(self : TokenStream, ahead~ : Int32 = 0) -> String {
  if self.position + ahead < self.tokens.length() {
    self.tokens[self.position + ahead].kind
  } else {
    "EOF"
  }
}

///|
/// Whether the next token is of `kind`.
pub fn TokenStream::at(self : TokenStream, kind : String) -> Bool {
  self.peek() == kind
}

///|
/// Consume the next token when it is of `kind`.
pub fn TokenStream::accept(self : TokenStream, kind : String) -> Token? {
  if self.position < self.tokens.length() &&
    self.tokens[self.position].kind == kind {
    self.position += 1
    Some(self.tokens[self.position - 1])
  } else {
    None
  }
}

///|
/// Consume the next token, which must be of `kind`.
pub fn TokenStream::expect(
  self : TokenStream,
  kind : String,
) -> Token raise ParseError {
  match self.accept(kind) {
    Some(token) => token
    None => self.fail("Expecting token of type '\{kind}'")
  }
}

///|
/// Raise a syntax error at the next token.
pub fn[T] TokenStream::fail(
  self : TokenStream,
  message : String,
) -> T raise ParseError {
  let (found, offset) = if self.position < self.tokens.length() {
    let token = self.tokens[self.position]
    ("'\{token.text}'", token.offset)
  } else {
    ("the end of the input", self.length)
  }
  raise ParseError(message="\{message} but found \{found}", offset~)
}
