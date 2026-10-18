///|
priv struct Parser {
  source : String
  mut position : Int32
  mut groups : Int32
}

///|
fn Parser::peek(self : Parser) -> Int32 {
  if self.position < self.source.length() {
    self.source[self.position].to_int()
  } else {
    -1
  }
}

///|
fn Parser::eat(self : Parser, c : Int32) -> Bool {
  if self.peek() == c {
    self.position += 1
    true
  } else {
    false
  }
}

///|
fn Parser::looking_at(self : Parser, text : String) -> Bool {
  if self.position + text.length() > self.source.length() {
    return false
  }
  for i in 0..<text.length() {
    if self.source[self.position + i] != text[i] {
      return false
    }
  }
  true
}

///|
fn Parser::disjunction(self : Parser) -> Node raise RegexError {
  let alternatives = [self.alternative()]
  while self.eat('|') {
    alternatives.push(self.alternative())
  }
  if alternatives.length() == 1 {
    alternatives[0]
  } else {
    Alt(alternatives)
  }
}

///|
fn Parser::alternative(self : Parser) -> Node raise RegexError {
  let terms = []
  while self.peek() != -1 && self.peek() != '|' && self.peek() != ')' {
    terms.push(self.term())
  }
  match terms {
    [] => Empty
    [single] => single
    _ => Seq(terms)
  }
}

///|
fn Parser::term(self : Parser) -> Node raise RegexError {
  let c = self.peek()
  if c == '^' {
    self.position += 1
    return Start
  }
  if c == '$' {
    self.position += 1
    return End
  }
  if self.looking_at("\\b") {
    self.position += 2
    return WordBoundary(negated=false)
  }
  if self.looking_at("\\B") {
    self.position += 2
    return WordBoundary(negated=true)
  }
  if self.looking_at("(?=") || self.looking_at("(?!") {
    let negated = self.source[self.position + 2] == '!'
    self.position += 3
    let body = self.disjunction()
    if !self.eat(')') {
      raise RegexError("unterminated group")
    }
    // Annex B lets a lookahead take a quantifier.
    return self.quantified(Look(body, negated~))
  }
  self.quantified(self.atom())
}

///|
fn Parser::quantified(self : Parser, atom : Node) -> Node {
  let (min, max) : (Int32, Int32?) = match self.peek() {
    '*' => {
      self.position += 1
      (0, None)
    }
    '+' => {
      self.position += 1
      (1, None)
    }
    '?' => {
      self.position += 1
      (0, Some(1))
    }
    '{' =>
      match self.braces() {
        Some(bounds) => bounds
        None => return atom
      }
    _ => return atom
  }
  let greedy = !self.eat('?')
  Repeat(atom, min~, max~, greedy~)
}

///|
/// `{n}`, `{n,}` or `{n,m}`. Anything else leaves the brace a literal.
fn Parser::braces(self : Parser) -> (Int32, Int32?)? {
  let start = self.position
  self.position += 1
  let number = () => {
    let mut value = 0
    let mut digits = 0
    while self.peek() >= '0' && self.peek() <= '9' {
      value = value * 10 + (self.peek() - '0')
      digits += 1
      self.position += 1
    }
    if digits == 0 {
      None
    } else {
      Some(value)
    }
  }
  guard number() is Some(min) else {
    self.position = start
    return None
  }
  if self.eat('}') {
    return Some((min, Some(min)))
  }
  if !self.eat(',') {
    self.position = start
    return None
  }
  let max = number()
  if !self.eat('}') {
    self.position = start
    return None
  }
  Some((min, max))
}

///|
fn Parser::atom(self : Parser) -> Node raise RegexError {
  let c = self.peek()
  self.position += 1
  match c {
    '.' => Any
    '(' => {
      let capture = if self.looking_at("?:") {
        self.position += 2
        None
      } else {
        self.groups += 1
        Some(self.groups)
      }
      let body = self.disjunction()
      if !self.eat(')') {
        raise RegexError("unterminated group")
      }
      Group(body, capture~)
    }
    '[' => self.class()
    '\\' => {
      let escaped = self.peek()
      if escaped == -1 {
        raise RegexError("\\ at end of pattern")
      }
      self.position += 1
      match class_escape(escaped) {
        Some(ranges) => Class(ranges, negated=escaped is ('D' | 'W' | 'S'))
        None if escaped >= '1' && escaped <= '9' => Backref(escaped - '0')
        None => Char(self.escape(escaped))
      }
    }
    _ => Char(c)
  }
}

///|
/// The code unit an escape denotes; the escaped character has been
/// consumed.
fn Parser::escape(self : Parser, escaped : Int32) -> Int32 {
  let hex = (digits : Int32) => {
    let mut value = 0
    for i in 0..<digits {
      let digit = match
        self.source.get(self.position + i).map(u => u.to_int()) {
        Some(d) if d >= '0' && d <= '9' => d - '0'
        Some(d) if d >= 'a' && d <= 'f' => d - 'a' + 10
        Some(d) if d >= 'A' && d <= 'F' => d - 'A' + 10
        _ => return None
      }
      value = value * 16 + digit
    }
    self.position += digits
    Some(value)
  }
  match escaped {
    't' => 0x09
    'n' => 0x0a
    'v' => 0x0b
    'f' => 0x0c
    'r' => 0x0d
    '0' => 0
    'x' => hex(2).unwrap_or('x')
    'u' => hex(4).unwrap_or('u')
    'c' => {
      let letter = self.peek()
      if (letter >= 'a' && letter <= 'z') || (letter >= 'A' && letter <= 'Z') {
        self.position += 1
        letter % 32
      } else {
        '\\'
      }
    }
    other => other
  }
}

///|
/// A bracketed class; the `[` has been consumed.
fn Parser::class(self : Parser) -> Node raise RegexError {
  let negated = self.eat('^')
  let ranges : Array[(Int32, Int32)] = []
  // One class member: a single code unit, or the ranges of `\d` and friends.
  let item = () => {
    let c = self.peek()
    self.position += 1
    if c != '\\' {
      return (Some(c), [])
    }
    let escaped = self.peek()
    self.position += 1
    match class_escape(escaped) {
      Some(set) =>
        (None, if escaped is ('D' | 'W' | 'S') { complement(set) } else { set })
      None =>
        if escaped == 'b' {
          (Some(0x08), [])
        } else {
          (Some(self.escape(escaped)), [])
        }
    }
  }
  while self.peek() != ']' {
    if self.peek() == -1 {
      raise RegexError("unterminated character class")
    }
    let (low, set) = item()
    guard low is Some(low) else {
      ranges.append(set)
      continue
    }
    if self.peek() == '-' &&
      self.position + 1 < self.source.length() &&
      self.source[self.position + 1] != ']' {
      self.position += 1
      match item() {
        (Some(high), _) => ranges.push((low, high))
        (None, set) => {
          // `a-\d`: the dash is literal.
          ranges.push((low, low))
          ranges.push(('-', '-'))
          ranges.append(set)
        }
      }
    } else {
      ranges.push((low, low))
    }
  }
  self.position += 1
  Class(ranges, negated~)
}
