// The CSSOM side of mermaid's styles: a style sheet as the browser parses
// it (`new CSSStyleSheet().replaceSync(text)`) and serializes its rules
// back (`rule.cssText`), which is what becomes of `themeCSS` before stylis
// sees it. This file is the tokenizer of CSS Syntax Level 3.

///|
/// A token of CSS Syntax Level 3.
priv enum Token {
  Ident(String)
  Function(String)
  AtKeyword(String)
  /// The value, and whether it is an identifier (`type=id`).
  Hash(String, Bool)
  Str(String)
  BadString
  Url(String)
  BadUrl
  Delim(Char)
  /// The value, whether it is an integer, and the text it was written as.
  Number(Double, Bool, String)
  Percentage(Double)
  /// The value, whether it is an integer, the unit, and the text of the
  /// number.
  Dimension(Double, Bool, String, String)
  Whitespace
  CDO
  CDC
  Colon
  Semicolon
  Comma
  LeftBracket
  RightBracket
  LeftParen
  RightParen
  LeftBrace
  RightBrace
} derive(Eq, Debug)

///|
priv struct Tokenizer {
  chars : Array[Char]
  mut pos : Int32
}

///|
/// The input stream: newlines normalized, NUL and surrogates replaced.
fn preprocess(text : String) -> Array[Char] {
  let chars = []
  let mut previous_cr = false
  for c in text {
    match c {
      '\r' => {
        chars.push('\n')
        previous_cr = true
        continue
      }
      '\n' if previous_cr => ()
      '\u{0c}' => chars.push('\n')
      '\u{00}' => chars.push('\u{fffd}')
      _ => chars.push(c)
    }
    previous_cr = false
  }
  chars
}

///|
fn Tokenizer::at(self : Tokenizer, offset : Int32) -> Char? {
  self.chars.get(self.pos + offset)
}

///|
fn is_name_start_code_point(c : Char) -> Bool {
  c is ('a'..<='z' | 'A'..<='Z' | '_') || c.to_int() >= 0x80
}

///|
fn is_name_code_point(c : Char) -> Bool {
  is_name_start_code_point(c) || c is ('0'..<='9' | '-')
}

///|
fn is_css_whitespace(c : Char) -> Bool {
  c is (' ' | '\t' | '\n')
}

///|
/// Whether two code points start a valid escape.
fn valid_escape(first : Char?, second : Char?) -> Bool {
  first == Some('\\') && second != Some('\n') && second is Some(_)
}

///|
/// Whether three code points would start an identifier.
fn starts_identifier(first : Char?, second : Char?, third : Char?) -> Bool {
  match first {
    Some('-') =>
      (second is Some(c) && (is_name_start_code_point(c) || c == '-')) ||
      valid_escape(second, third)
    Some('\\') => valid_escape(first, second)
    Some(c) => is_name_start_code_point(c)
    None => false
  }
}

///|
/// Whether three code points would start a number.
fn starts_number(first : Char?, second : Char?, third : Char?) -> Bool {
  match first {
    Some('+' | '-') =>
      second is Some('0'..<='9') ||
      (second == Some('.') && third is Some('0'..<='9'))
    Some('.') => second is Some('0'..<='9')
    Some('0'..<='9') => true
    _ => false
  }
}

///|
/// An escaped code point, after the backslash.
fn Tokenizer::escape(self : Tokenizer) -> Char {
  guard self.at(0) is Some(c) else { return '\u{fffd}' }
  self.pos += 1
  guard c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F') else { return c }
  let mut value = hex_digit(c)
  let mut digits = 1
  while digits < 6 &&
        self.at(0) is Some('0'..<='9' | 'a'..<='f' | 'A'..<='F' as d) {
    value = value * 16 + hex_digit(d)
    digits += 1
    self.pos += 1
  }
  if self.at(0) is Some(w) && is_css_whitespace(w) {
    self.pos += 1
  }
  if value == 0 || (value >= 0xd800 && value <= 0xdfff) || value > 0x10ffff {
    '\u{fffd}'
  } else {
    value.unsafe_to_char()
  }
}

///|
fn hex_digit(c : Char) -> Int32 {
  match c {
    '0'..<='9' => c.to_int() - '0'.to_int()
    'a'..<='f' => c.to_int() - 'a'.to_int() + 10
    _ => c.to_int() - 'A'.to_int() + 10
  }
}

///|
fn Tokenizer::name(self : Tokenizer) -> String {
  let name = StringBuilder()
  while true {
    match self.at(0) {
      Some(c) if is_name_code_point(c) => {
        name.write_char(c)
        self.pos += 1
      }
      first if valid_escape(first, self.at(1)) => {
        self.pos += 1
        name.write_char(self.escape())
      }
      _ => break
    }
  }
  name.to_string()
}

///|
/// A number: its value, whether it is an integer, and its text.
fn Tokenizer::number(self : Tokenizer) -> (Double, Bool, String) {
  let start = self.pos
  let mut integer = true
  if self.at(0) is Some('+' | '-') {
    self.pos += 1
  }
  while self.at(0) is Some('0'..<='9') {
    self.pos += 1
  }
  if self.at(0) == Some('.') && self.at(1) is Some('0'..<='9') {
    integer = false
    self.pos += 2
    while self.at(0) is Some('0'..<='9') {
      self.pos += 1
    }
  }
  if self.at(0) is Some('e' | 'E') &&
    (
      self.at(1) is Some('0'..<='9') ||
      (self.at(1) is Some('+' | '-') && self.at(2) is Some('0'..<='9'))
    ) {
    integer = false
    self.pos += 2
    while self.at(0) is Some('0'..<='9') {
      self.pos += 1
    }
  }
  let text = String::from_array(self.chars[start:self.pos])
  let digits = if text.has_prefix("+") { text[1:].to_owned() } else { text }
  let digits = if digits.has_prefix(".") {
    "0" + digits
  } else if digits.has_prefix("-.") {
    "-0" + digits[1:].to_owned()
  } else {
    digits
  }
  let value = @string.parse_double(digits) catch {
    _ =>
      if digits.find("e-") is Some(_) || digits.find("E-") is Some(_) {
        0.0
      } else if digits.has_prefix("-") {
        -@double.infinity
      } else {
        @double.infinity
      }
  }
  (value, integer, text)
}

///|
fn Tokenizer::numeric(self : Tokenizer) -> Token {
  let (value, integer, text) = self.number()
  if starts_identifier(self.at(0), self.at(1), self.at(2)) {
    Dimension(value, integer, self.name(), text)
  } else if self.at(0) == Some('%') {
    self.pos += 1
    Percentage(value)
  } else {
    Number(value, integer, text)
  }
}

///|
fn Tokenizer::string(self : Tokenizer, quote : Char) -> Token {
  let text = StringBuilder()
  while true {
    match self.at(0) {
      None => break
      Some(c) if c == quote => {
        self.pos += 1
        break
      }
      Some('\n') => return BadString
      Some('\\') => {
        self.pos += 1
        match self.at(0) {
          None => ()
          Some('\n') => self.pos += 1
          Some(_) => text.write_char(self.escape())
        }
      }
      Some(c) => {
        text.write_char(c)
        self.pos += 1
      }
    }
  }
  Str(text.to_string())
}

///|
/// The rest of a bad URL, up to its parenthesis.
fn Tokenizer::bad_url_remnants(self : Tokenizer) -> Unit {
  while self.at(0) is Some(c) {
    if c == ')' {
      self.pos += 1
      return
    }
    if valid_escape(Some(c), self.at(1)) {
      self.pos += 1
      self.escape() |> ignore
    } else {
      self.pos += 1
    }
  }
}

///|
fn Tokenizer::url(self : Tokenizer) -> Token {
  let text = StringBuilder()
  while self.at(0) is Some(c) && is_css_whitespace(c) {
    self.pos += 1
  }
  while true {
    match self.at(0) {
      None => break
      Some(')') => {
        self.pos += 1
        break
      }
      Some(c) if is_css_whitespace(c) => {
        while self.at(0) is Some(w) && is_css_whitespace(w) {
          self.pos += 1
        }
        if self.at(0) is (None | Some(')')) {
          if self.at(0) is Some(_) {
            self.pos += 1
          }
          break
        }
        self.bad_url_remnants()
        return BadUrl
      }
      Some('"' | '\'' | '(') => {
        self.bad_url_remnants()
        return BadUrl
      }
      Some(c) if c.to_int() < 0x20 || c.to_int() == 0x7f => {
        self.bad_url_remnants()
        return BadUrl
      }
      Some('\\') =>
        if valid_escape(self.at(0), self.at(1)) {
          self.pos += 1
          text.write_char(self.escape())
        } else {
          self.bad_url_remnants()
          return BadUrl
        }
      Some(c) => {
        text.write_char(c)
        self.pos += 1
      }
    }
  }
  Url(text.to_string())
}

///|
fn Tokenizer::ident_like(self : Tokenizer) -> Token {
  let name = self.name()
  if name.to_lower() == "url" && self.at(0) == Some('(') {
    self.pos += 1
    while self.at(0) is Some(w) &&
          is_css_whitespace(w) &&
          self.at(1) is Some(next) &&
          is_css_whitespace(next) {
      self.pos += 1
    }
    let quoted = match (self.at(0), self.at(1)) {
      (Some('"' | '\''), _) => true
      (Some(w), Some('"' | '\'')) if is_css_whitespace(w) => true
      _ => false
    }
    if quoted {
      Function(name)
    } else {
      self.url()
    }
  } else if self.at(0) == Some('(') {
    self.pos += 1
    Function(name)
  } else {
    Ident(name)
  }
}

///|
fn Tokenizer::skip_comments(self : Tokenizer) -> Unit {
  while self.at(0) == Some('/') && self.at(1) == Some('*') {
    self.pos += 2
    while self.at(0) is Some(_) &&
          !(self.at(0) == Some('*') && self.at(1) == Some('/')) {
      self.pos += 1
    }
    if self.at(0) is Some(_) {
      self.pos += 2
    }
  }
}

///|
/// The next token, or `None` at the end.
fn Tokenizer::next(self : Tokenizer) -> Token? {
  self.skip_comments()
  guard self.at(0) is Some(c) else { return None }
  let token = match c {
    _ if is_css_whitespace(c) => {
      while self.at(0) is Some(w) && is_css_whitespace(w) {
        self.pos += 1
      }
      Whitespace
    }
    '"' | '\'' => {
      self.pos += 1
      self.string(c)
    }
    '#' =>
      if (self.at(1) is Some(n) && is_name_code_point(n)) ||
        valid_escape(self.at(1), self.at(2)) {
        self.pos += 1
        let id = starts_identifier(self.at(0), self.at(1), self.at(2))
        Hash(self.name(), id)
      } else {
        self.pos += 1
        Delim('#')
      }
    '(' => {
      self.pos += 1
      LeftParen
    }
    ')' => {
      self.pos += 1
      RightParen
    }
    '+' | '.' =>
      if starts_number(self.at(0), self.at(1), self.at(2)) {
        self.numeric()
      } else {
        self.pos += 1
        Delim(c)
      }
    ',' => {
      self.pos += 1
      Comma
    }
    '-' =>
      if starts_number(self.at(0), self.at(1), self.at(2)) {
        self.numeric()
      } else if self.at(1) == Some('-') && self.at(2) == Some('>') {
        self.pos += 3
        CDC
      } else if starts_identifier(self.at(0), self.at(1), self.at(2)) {
        self.ident_like()
      } else {
        self.pos += 1
        Delim('-')
      }
    ':' => {
      self.pos += 1
      Colon
    }
    ';' => {
      self.pos += 1
      Semicolon
    }
    '<' =>
      if self.at(1) == Some('!') &&
        self.at(2) == Some('-') &&
        self.at(3) == Some('-') {
        self.pos += 4
        CDO
      } else {
        self.pos += 1
        Delim('<')
      }
    '@' =>
      if starts_identifier(self.at(1), self.at(2), self.at(3)) {
        self.pos += 1
        AtKeyword(self.name())
      } else {
        self.pos += 1
        Delim('@')
      }
    '[' => {
      self.pos += 1
      LeftBracket
    }
    '\\' =>
      if valid_escape(self.at(0), self.at(1)) {
        self.ident_like()
      } else {
        self.pos += 1
        Delim('\\')
      }
    ']' => {
      self.pos += 1
      RightBracket
    }
    '{' => {
      self.pos += 1
      LeftBrace
    }
    '}' => {
      self.pos += 1
      RightBrace
    }
    '0'..<='9' => self.numeric()
    _ if is_name_start_code_point(c) => self.ident_like()
    _ => {
      self.pos += 1
      Delim(c)
    }
  }
  Some(token)
}

///|
/// A text as tokens, with where each token starts and ends in the
/// preprocessed text (comments before a token are not part of it).
priv struct Tokens {
  chars : Array[Char]
  tokens : Array[Token]
  starts : Array[Int32]
  ends : Array[Int32]
}

///|
fn tokenize(text : String) -> Tokens {
  let tokenizer = { chars: preprocess(text), pos: 0, }
  let tokens = []
  let starts = []
  let ends = []
  while true {
    tokenizer.skip_comments()
    let start = tokenizer.pos
    guard tokenizer.next() is Some(token) else { break }
    tokens.push(token)
    starts.push(start)
    ends.push(tokenizer.pos)
  }
  { chars: tokenizer.chars, tokens, starts, ends, }
}

///|
/// The source text from the start of token `first` to the end of token
/// `last`.
fn Tokens::source(self : Tokens, first : Int32, last : Int32) -> String {
  String::from_array(self.chars[self.starts[first]:self.ends[last]])
}
