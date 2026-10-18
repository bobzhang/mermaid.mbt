///|
/// A compiled regular expression with JavaScript semantics: backtracking,
/// leftmost match, alternatives tried in order. It works on UTF-16 code
/// units, like a JavaScript pattern without the `u` flag.
pub struct Regex {
  priv node : Node
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
    node,
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
  captures : FixedArray[Int32]
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
fn is_single(node : Node) -> Bool {
  match node {
    Char(_) | Any | Class(_, ..) => true
    Group(inner, capture=None) => is_single(inner)
    _ => false
  }
}

///|
/// Match `node` at `at`, then call `k` with the position after it.
/// Returns whether the whole continuation succeeded.
fn Run::step(self : Run, node : Node, at : Int32, k : (Int32) -> Bool) -> Bool {
  let n = self.input.length()
  match node {
    Empty => k(at)
    Char(_) | Any | Class(_, ..) =>
      at < n && self.single(node, at) is Some(true) && k(at + 1)
    Start =>
      (
        at == self.base ||
        (self.multiline && is_line_terminator(self.unit(at - 1)))
      ) &&
      k(at)
    End =>
      (at == n || (self.multiline && is_line_terminator(self.unit(at)))) &&
      k(at)
    WordBoundary(negated~) => {
      let before = at > self.base && is_word(self.unit(at - 1))
      let after = at < n && is_word(self.unit(at))
      (before != after) != negated && k(at)
    }
    Backref(index) => {
      let start = if 2 * index + 1 < self.captures.length() {
        self.captures[2 * index]
      } else {
        -1
      }
      let end = if start >= 0 { self.captures[2 * index + 1] } else { -1 }
      if start < 0 || end < 0 {
        return k(at)
      }
      let length = end - start
      guard at + length <= n else { return false }
      for i in 0..<length {
        let a = self.unit(start + i)
        let b = self.unit(at + i)
        guard a == b || (self.ignore_case && canonical(a) == canonical(b)) else {
          return false
        }
      }
      k(at + length)
    }
    Group(inner, capture=None) => self.step(inner, at, k)
    Group(inner, capture=Some(index)) => {
      let old_start = self.captures[2 * index]
      let old_end = self.captures[2 * index + 1]
      let matched = self.step(inner, at, end => {
        let saved_start = self.captures[2 * index]
        let saved_end = self.captures[2 * index + 1]
        self.captures[2 * index] = at
        self.captures[2 * index + 1] = end
        if k(end) {
          true
        } else {
          self.captures[2 * index] = saved_start
          self.captures[2 * index + 1] = saved_end
          false
        }
      })
      if !matched {
        self.captures[2 * index] = old_start
        self.captures[2 * index + 1] = old_end
      }
      matched
    }
    Seq(items) => self.sequence(items, 0, at, k)
    Alt(alternatives) => {
      for alternative in alternatives {
        if self.step(alternative, at, k) {
          return true
        }
      }
      false
    }
    Look(inner, negated~) => {
      let saved = self.captures.copy()
      let found = self.step(inner, at, _ => true)
      if negated {
        // Nothing captured inside a failed or negated lookahead survives.
        saved.blit_to(self.captures, len=saved.length())
        !found && k(at)
      } else if found {
        if k(at) {
          true
        } else {
          saved.blit_to(self.captures, len=saved.length())
          false
        }
      } else {
        false
      }
    }
    Repeat(inner, min~, max~, greedy~) =>
      if is_single(inner) {
        self.repeat_single(inner, min, max, greedy, at, k)
      } else if !has_capture(inner) {
        self.repeat_stack(inner, min, max, greedy, at, k)
      } else {
        self.repeat(inner, min, max, greedy, 0, at, k)
      }
  }
}

///|
fn Run::sequence(
  self : Run,
  items : Array[Node],
  index : Int32,
  at : Int32,
  k : (Int32) -> Bool,
) -> Bool {
  if index == items.length() {
    k(at)
  } else {
    self.step(items[index], at, next => self.sequence(items, index + 1, next, k))
  }
}

///|
/// Repetition of something that consumes one code unit: count how far it
/// can go, then try the continuation from the preferred end.
fn Run::repeat_single(
  self : Run,
  inner : Node,
  min : Int32,
  max : Int32?,
  greedy : Bool,
  at : Int32,
  k : (Int32) -> Bool,
) -> Bool {
  let n = self.input.length()
  let limit = match max {
    Some(max) => if at + max < n { at + max } else { n }
    None => n
  }
  let mut reach = at
  while reach < limit && self.single(inner, reach) is Some(true) {
    reach += 1
  }
  if reach - at < min {
    return false
  }
  if greedy {
    for end = reach; end >= at + min; end = end - 1 {
      if k(end) {
        return true
      }
    }
  } else {
    for end = at + min; end <= reach; end = end + 1 {
      if k(end) {
        return true
      }
    }
  }
  false
}

///|
/// Whether a match of `node` can leave captures behind: a capture group
/// in it, except in a negative lookahead, which keeps none.
fn has_capture(node : Node) -> Bool {
  match node {
    Group(_, capture=Some(_)) => true
    Look(_, negated=true) => false
    Group(inner, ..) | Repeat(inner, ..) | Look(inner, ..) => has_capture(inner)
    Seq(items) | Alt(items) => items.iter().any(has_capture)
    _ => false
  }
}

///|
/// A repetition's place in `repeat_stack`: the iterations so far, where
/// they ended, and where the next one can end, in the order backtracking
/// tries them.
priv struct RepeatFrame {
  count : Int32
  at : Int32
  ends : Array[Int32]
  mut next : Int32
}

///|
/// `repeat` for something that leaves no captures, with the iterations on
/// an explicit stack rather than one call deeper each, which long subjects
/// cannot afford. The search is the same: each iteration's ends in order,
/// the deeper iterations before the continuation when greedy, after it
/// when lazy. Without captures an iteration is done once its ends are
/// known, and the continuation depends on the position only.
fn Run::repeat_stack(
  self : Run,
  inner : Node,
  min : Int32,
  max : Int32?,
  greedy : Bool,
  at : Int32,
  k : (Int32) -> Bool,
) -> Bool {
  let frames : Array[RepeatFrame] = []
  // Start the iteration after `count` at `at`; whether a lazy
  // continuation succeeded there.
  let enter = (count : Int32, at : Int32) => {
    if !greedy && count >= min && k(at) {
      return true
    }
    let ends = []
    if !(max is Some(max) && count >= max) {
      let _ = self.step(inner, at, end => {
        // An iteration that matches nothing past the minimum ends the
        // loop.
        if !(end == at && count >= min) {
          ends.push(end)
        }
        false
      })
    }
    frames.push({ count, at, ends, next: 0, })
    false
  }
  if enter(0, at) {
    return true
  }
  while frames.last() is Some(top) {
    if top.next < top.ends.length() {
      let end = top.ends[top.next]
      top.next += 1
      if enter(top.count + 1, end) {
        return true
      }
    } else {
      frames.unsafe_pop() |> ignore
      if greedy && top.count >= min && k(top.at) {
        return true
      }
    }
  }
  false
}

///|
fn Run::repeat(
  self : Run,
  inner : Node,
  min : Int32,
  max : Int32?,
  greedy : Bool,
  count : Int32,
  at : Int32,
  k : (Int32) -> Bool,
) -> Bool {
  let can_stop = count >= min
  let can_continue = !(max is Some(max) && count >= max)
  let more = () => {
    can_continue &&
    self.step(inner, at, next => {
      // An iteration that matches nothing past the minimum ends the loop.
      if next == at && count >= min {
        false
      } else {
        self.repeat(inner, min, max, greedy, count + 1, next, k)
      }
    })
  }
  if greedy {
    more() || (can_stop && k(at))
  } else {
    (can_stop && k(at)) || more()
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
    captures: FixedArray::make(2 * (self.groups + 1), -1),
  }
  let mut end = -1
  if run.step(self.node, at, position => {
      end = position
      true
    }) {
    Some({ input, start: at, end, captures: run.captures, })
  } else {
    None
  }
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
