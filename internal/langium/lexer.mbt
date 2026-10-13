// The terminals shared by mermaid's Langium grammars
// (`packages/parser/src/language/common/common.langium`), as a hand-written
// scanner. Each `Lexer` method tries one terminal at the current position
// and consumes it on success, so a recursive-descent parser can follow the
// grammar rule by rule.

///|
/// A syntax error, with the offset it was detected at.
pub(all) suberror ParseError {
  ParseError(message~ : String, offset~ : Int32)
} derive(Eq, Debug)

///|
pub struct Lexer {
  priv input : String
  priv mut position : Int32
}

///|
pub fn Lexer::new(input : String) -> Lexer {
  { input, position: 0, }
}

///|
pub fn Lexer::offset(self : Lexer) -> Int32 {
  self.position
}

///|
pub fn Lexer::at_end(self : Lexer) -> Bool {
  self.skip_hidden()
  self.position >= self.input.length()
}

///|
/// Raise a syntax error at the current position.
pub fn[T] Lexer::fail(self : Lexer, message : String) -> T raise ParseError {
  raise ParseError(message~, offset=self.position)
}

///|
fn Lexer::unit(self : Lexer, at : Int32) -> UInt16 {
  if at < self.input.length() {
    self.input[at]
  } else {
    0
  }
}

///|
fn Lexer::looking_at(self : Lexer, text : String, at : Int32) -> Bool {
  if at + text.length() > self.input.length() {
    return false
  }
  for i in 0..<text.length() {
    if self.input[at + i] != text[i] {
      return false
    }
  }
  true
}

///|
fn is_blank(unit : UInt16) -> Bool {
  unit is (' ' | '\t')
}

///|
fn is_whitespace(unit : UInt16) -> Bool {
  unit is (' ' | '\t' | '\n' | '\r' | 0x0b | 0x0c | 0xa0 | 0xfeff)
}

///|
/// Skip the hidden terminals: blanks, a YAML frontmatter block, directives
/// and `%%` comments.
fn Lexer::skip_hidden(self : Lexer) -> Unit {
  while true {
    let start = self.position
    while is_blank(self.unit(self.position)) {
      self.position += 1
    }
    // DIRECTIVE: `%%{ ... }%%` up to the end of its line.
    if self.looking_at("%%{", self.position) {
      let mut end = self.position + 3
      while end < self.input.length() && !self.looking_at("}%%", end) {
        end += 1
      }
      if end < self.input.length() {
        end += 3
        if self.unit(end) == '\r' && self.unit(end + 1) == '\n' {
          end += 2
        } else if self.unit(end) == '\n' {
          end += 1
        }
        self.position = end
        continue
      }
    }
    // SINGLE_LINE_COMMENT: `%%` to the end of the line.
    if self.looking_at("%%", self.position) {
      while self.position < self.input.length() &&
            !(self.unit(self.position) is ('\n' | '\r')) {
        self.position += 1
      }
      continue
    }
    // YAML: `---`, a body, and a closing `---`.
    if self.looking_at("---", self.position) && self.skip_yaml() {
      continue
    }
    if self.position == start {
      break
    }
  }
}

///|
fn Lexer::skip_yaml(self : Lexer) -> Bool {
  let n = self.input.length()
  let mut cursor = self.position + 3
  while is_blank(self.unit(cursor)) {
    cursor += 1
  }
  if self.unit(cursor) == '\r' {
    cursor += 1
  }
  if self.unit(cursor) != '\n' {
    return false
  }
  // The closing fence starts a line.
  let mut line = cursor + 1
  while line <= n {
    if self.looking_at("---", line) {
      let mut end = line + 3
      if self.unit(end) == '\r' && self.unit(end + 1) == '\n' {
        end += 2
      } else if self.unit(end) == '\n' {
        end += 1
      } else if end < n && !is_whitespace(self.unit(end)) {
        end = -1
      }
      if end != -1 {
        self.position = end
        return true
      }
    }
    while line < n && self.unit(line) != '\n' {
      line += 1
    }
    line += 1
  }
  false
}

///|
/// A keyword. Like upstream's token builder, it only matches when followed
/// by whitespace, a comment or the end of input.
pub fn Lexer::keyword(self : Lexer, word : String) -> Bool {
  self.skip_hidden()
  let end = self.position + word.length()
  if self.looking_at(word, self.position) &&
    (
      end >= self.input.length() ||
      is_whitespace(self.unit(end)) ||
      self.looking_at("%%", end)
    ) {
    self.position = end
    true
  } else {
    false
  }
}

///|
/// A punctuation token such as `:`.
pub fn Lexer::symbol(self : Lexer, text : String) -> Bool {
  self.skip_hidden()
  if self.looking_at(text, self.position) {
    self.position += text.length()
    true
  } else {
    false
  }
}

///|
/// NEWLINE: one line break.
pub fn Lexer::newline(self : Lexer) -> Bool {
  self.skip_hidden()
  if self.unit(self.position) == '\r' && self.unit(self.position + 1) == '\n' {
    self.position += 2
    true
  } else if self.unit(self.position) == '\n' {
    self.position += 1
    true
  } else {
    false
  }
}

///|
/// EOL: one or more line breaks, or the end of input.
pub fn Lexer::eol(self : Lexer) -> Bool {
  if self.newline() {
    while self.newline() {

    }
    true
  } else {
    self.at_end()
  }
}

///|
/// The rest of the current line, up to a `%%` comment.
fn Lexer::rest_of_line(self : Lexer) -> String {
  let start = self.position
  while self.position < self.input.length() &&
        !(self.unit(self.position) is ('\n' | '\r')) &&
        !self.looking_at("%%", self.position) {
    self.position += 1
  }
  self.input[start:self.position].to_owned()
}

///|
/// Replace every run of two or more blanks with one space.
fn collapse_blanks(text : String) -> String {
  let out = StringBuilder()
  let run = StringBuilder()
  let flush = () => {
    let blanks = run.to_string()
    if blanks.length() > 1 {
      out.write_char(' ')
    } else {
      out.write_string(blanks)
    }
    run.reset()
  }
  for c in text {
    if c is (' ' | '\t') {
      run.write_char(c)
    } else {
      flush()
      out.write_char(c)
    }
  }
  flush()
  out.to_string()
}

///|
/// TITLE: `title` followed by the rest of the line. Returns the title text,
/// trimmed, with runs of blanks collapsed.
pub fn Lexer::title(self : Lexer) -> String? {
  self.skip_hidden()
  if !self.looking_at("title", self.position) {
    return None
  }
  let after = self.position + 5
  if is_blank(self.unit(after)) {
    self.position = after
    Some(collapse_blanks(self.rest_of_line().trim().to_owned()))
  } else {
    self.position = after
    Some("")
  }
}

///|
/// ACC_TITLE: `accTitle: text`.
pub fn Lexer::acc_title(self : Lexer) -> String? {
  self.skip_hidden()
  if !self.looking_at("accTitle", self.position) {
    return None
  }
  let mut cursor = self.position + 8
  while is_blank(self.unit(cursor)) {
    cursor += 1
  }
  if self.unit(cursor) != ':' {
    return None
  }
  self.position = cursor + 1
  Some(collapse_blanks(self.rest_of_line().trim().to_owned()))
}

///|
/// ACC_DESCR: `accDescr: text`, or the multi-line `accDescr { text }`.
pub fn Lexer::acc_descr(self : Lexer) -> String? {
  self.skip_hidden()
  if !self.looking_at("accDescr", self.position) {
    return None
  }
  let mut cursor = self.position + 8
  while is_blank(self.unit(cursor)) {
    cursor += 1
  }
  if self.unit(cursor) == ':' {
    self.position = cursor + 1
    return Some(collapse_blanks(self.rest_of_line().trim().to_owned()))
  }
  while is_whitespace(self.unit(cursor)) {
    cursor += 1
  }
  if self.unit(cursor) != '{' {
    return None
  }
  let mut close = cursor + 1
  while close < self.input.length() && self.unit(close) != '}' {
    close += 1
  }
  if close >= self.input.length() {
    return None
  }
  let body = self.input[cursor + 1:close].to_owned()
  self.position = close + 1
  // Each line is trimmed, blanks collapse, and blank lines disappear.
  let lines = []
  for line in body.split("\n") {
    let line = collapse_blanks(
      line.trim(chars=" \t\r\u{0b}\u{0c}\u{a0}\u{feff}").to_owned(),
    )
    if line != "" {
      lines.push(line)
    }
  }
  Some(lines.join("\n"))
}

///|
/// STRING: a single- or double-quoted string with backslash escapes.
/// Returns its value with quotes removed and escapes resolved.
pub fn Lexer::string(self : Lexer) -> String? {
  self.skip_hidden()
  let quote = self.unit(self.position)
  if !(quote is ('"' | '\'')) {
    return None
  }
  let out = StringBuilder()
  let mut cursor = self.position + 1
  while cursor < self.input.length() {
    let unit = self.unit(cursor)
    if unit == quote {
      self.position = cursor + 1
      return Some(out.to_string())
    }
    if unit == '\\' {
      guard cursor + 1 < self.input.length() else { return None }
      let escaped = self.unit(cursor + 1)
      out.write_char(
        match escaped {
          'b' => '\b'
          'f' => '\u{0c}'
          'n' => '\n'
          'r' => '\r'
          't' => '\t'
          'v' => '\u{0b}'
          '0' => '\u{00}'
          _ => Int32::unsafe_to_char(escaped.to_int())
        },
      )
      cursor += 2
    } else {
      out.write_view(self.input[cursor:cursor + 1])
      cursor += 1
    }
  }
  None
}

///|
/// A number: an optional minus sign when `signed`, then `0` or a non-zero
/// digit run, optionally followed by a fraction. It must not be followed
/// by another `.`.
pub fn Lexer::number(self : Lexer, signed~ : Bool = false) -> Double? {
  self.skip_hidden()
  let start = self.position
  let mut cursor = start
  if signed && self.unit(cursor) == '-' {
    cursor += 1
  }
  let digits_start = cursor
  while self.unit(cursor) is ('0'..<='9') {
    cursor += 1
  }
  if cursor == digits_start {
    return None
  }
  let integer_end = cursor
  if self.unit(cursor) == '.' && self.unit(cursor + 1) is ('0'..<='9') {
    cursor += 1
    while self.unit(cursor) is ('0'..<='9') {
      cursor += 1
    }
    if self.unit(cursor) == '.' {
      return None
    }
  } else {
    // An integer has no leading zeros and no trailing dot.
    if self.unit(cursor) == '.' {
      return None
    }
    if integer_end - digits_start > 1 && self.unit(digits_start) == '0' {
      return None
    }
  }
  let value = @string.parse_double(self.input[start:cursor]) catch {
    _ => return None
  }
  self.position = cursor
  Some(value)
}

///|
/// INT: `0`, or a digit run without a leading zero, not followed by a `.`.
pub fn Lexer::int(self : Lexer) -> Int32? {
  self.skip_hidden()
  let start = self.position
  let mut cursor = start
  let mut value = 0
  while self.unit(cursor) is ('0'..<='9') {
    value = value * 10 + (self.unit(cursor).to_int() - '0')
    cursor += 1
  }
  if cursor == start || self.unit(cursor) == '.' {
    return None
  }
  if cursor - start > 1 && self.unit(start) == '0' {
    // `0` is a complete token; what follows is another one.
    cursor = start + 1
    value = 0
  }
  self.position = cursor
  Some(value)
}
