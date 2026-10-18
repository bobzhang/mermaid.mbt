///|
/// A compiled regular expression with JavaScript semantics: backtracking,
/// leftmost match, alternatives tried in order. It works on UTF-16 code
/// units, like a JavaScript pattern without the `u` flag.
pub struct Regex {
  priv program : Program
  priv groups : Int32
  priv ignore_case : Bool
  priv multiline : Bool
}

///|
/// Compile `source`, the text between the slashes of a JavaScript regex
/// literal. `flags` may contain `i` and `m`; `g` is accepted and ignored,
/// since the methods here say whether they search once or repeatedly.
pub fn Regex::compile(
  source : String,
  flags~ : String = "",
) -> Regex raise RegexError {
  let parser = { source, position: 0, groups: 0, }
  let node = parser.disjunction()
  if parser.position < source.length() {
    raise RegexError("unmatched )")
  }
  {
    program: compile_program(node, parser.groups),
    groups: parser.groups,
    ignore_case: flags.contains("i"),
    multiline: flags.contains("m"),
  }
}

///|
/// One match: where it starts and ends, and the capture groups.
pub struct Match {
  priv input : String
  start : Int32
  end : Int32
  priv captures : FixedArray[Int32]
}

///|
/// The matched text.
pub fn Match::text(self : Match) -> String {
  self.input[self.start:self.end].to_owned()
}

///|
/// The text of capture group `index` (1-based), or `None` if it did not
/// take part in the match.
pub fn Match::group(self : Match, index : Int32) -> String? {
  if index < 1 || 2 * index + 1 >= self.captures.length() {
    return None
  }
  let start = self.captures[2 * index]
  let end = self.captures[2 * index + 1]
  if start < 0 || end < 0 {
    None
  } else {
    Some(self.input[start:end].to_owned())
  }
}

///|
/// The state of one match attempt.
priv struct Run {
  input : String
  /// Where the subject string starts: `^` matches here, and nothing before
  /// it is visible to `\b`.
  base : Int32
  ignore_case : Bool
  multiline : Bool
  /// The captures, then the program's other registers.
  registers : FixedArray[Int32]
}

///|
fn is_line_terminator(c : Int32) -> Bool {
  c == 0x0a || c == 0x0d || c == 0x2028 || c == 0x2029
}

///|
fn is_word(c : Int32) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
/// Case folding for `i`: JavaScript compares upper-cased code units.
fn canonical(c : Int32) -> Int32 {
  if c >= 'a' && c <= 'z' {
    c - 32
  } else if (c >= 0xe0 && c <= 0xfe && c != 0xf7) ||
    (c >= 0x430 && c <= 0x44f) ||
    (c >= 0x3b1 && c <= 0x3c9 && c != 0x3c2) {
    c - 32
  } else {
    c
  }
}

///|
fn Run::unit(self : Run, at : Int32) -> Int32 {
  self.input[at].to_int()
}

///|
fn Run::in_class(
  self : Run,
  c : Int32,
  ranges : Array[(Int32, Int32)],
  negated : Bool,
) -> Bool {
  let mut found = false
  for range in ranges {
    if c >= range.0 && c <= range.1 {
      found = true
      break
    }
  }
  if !found && self.ignore_case {
    // Compare both cases of the subject character against the class.
    let upper = canonical(c)
    let lower = if c >= 'A' && c <= 'Z' { c + 32 } else { c }
    for range in ranges {
      if (upper >= range.0 && upper <= range.1) ||
        (lower >= range.0 && lower <= range.1) {
        found = true
        break
      }
    }
  }
  found != negated
}

///|
/// Whether `node` consumes exactly one code unit, and if so whether the
/// unit at `at` satisfies it. Used to run simple repetitions in a loop.
fn Run::single(self : Run, node : Node, at : Int32) -> Bool? {
  match node {
    Char(c) => {
      let unit = self.unit(at)
      Some(unit == c || (self.ignore_case && canonical(unit) == canonical(c)))
    }
    Any => Some(!is_line_terminator(self.unit(at)))
    Class(ranges, negated~) =>
      Some(self.in_class(self.unit(at), ranges, negated))
    Group(inner, capture=None) => self.single(inner, at)
    _ => None
  }
}

///|
/// Try to match at exactly `at`, with the subject string taken to start at
/// `base`.
fn Regex::attempt(
  self : Regex,
  input : String,
  base : Int32,
  at : Int32,
) -> Match? {
  let run = {
    input,
    base,
    ignore_case: self.ignore_case,
    multiline: self.multiline,
    registers: FixedArray::make(self.program.registers, -1),
  }
  guard run.execute(self.program, at) is Some(end) else { return None }
  let captures = FixedArray::make(2 * (self.groups + 1), -1)
  run.registers.blit_to(captures, len=captures.length())
  Some({ input, start: at, end, captures, })
}

///|
/// Match against the tail of `input` starting at `from`, as if that tail
/// were the whole string: the match must begin there, and `^` and `\b` see
/// nothing before it. This is how a lexer applies its rules.
pub fn Regex::match_prefix(
  self : Regex,
  input : String,
  from~ : Int32 = 0,
) -> Match? {
  self.attempt(input, from, from)
}

///|
/// The first match at or after `from`, like `RegExp.prototype.exec`.
pub fn Regex::exec(self : Regex, input : String, from~ : Int32 = 0) -> Match? {
  for at in from..<=input.length() {
    if self.attempt(input, 0, at) is Some(found) {
      return Some(found)
    }
  }
  None
}

///|
/// Whether the pattern matches anywhere in `input`.
pub fn Regex::matches(self : Regex, input : String) -> Bool {
  self.exec(input) is Some(_)
}

///|
/// Replace every match, like `String.prototype.replace` with a `g` regex
/// and a function: `replacement` receives each match.
pub fn Regex::replace_all(
  self : Regex,
  input : String,
  replacement : (Match) -> String,
) -> String {
  let out = StringBuilder()
  let mut position = 0
  let mut last = 0
  while position <= input.length() {
    guard self.exec(input, from=position) is Some(found) else { break }
    out.write_view(input[last:found.start])
    out.write_string(replacement(found))
    last = found.end
    // An empty match must not be found again at the same place.
    position = if found.end == found.start { found.end + 1 } else { found.end }
  }
  out.write_view(input[last:])
  out.to_string()
}

///|
/// Replace the first match only, like `String.prototype.replace` without
/// the `g` flag.
pub fn Regex::replace(
  self : Regex,
  input : String,
  replacement : (Match) -> String,
) -> String {
  guard self.exec(input) is Some(found) else { return input }
  let out = StringBuilder()
  out.write_view(input[:found.start])
  out.write_string(replacement(found))
  out.write_view(input[found.end:])
  out.to_string()
}

///|
/// Split `input` at every match, like `String.prototype.split`.
pub fn Regex::split(self : Regex, input : String) -> Array[String] {
  let parts = []
  let mut last = 0
  let mut position = 0
  while position < input.length() {
    guard self.exec(input, from=position) is Some(found) else { break }
    if found.end == found.start {
      position += 1
      continue
    }
    parts.push(input[last:found.start].to_owned())
    last = found.end
    position = found.end
  }
  parts.push(input[last:].to_owned())
  parts
}
