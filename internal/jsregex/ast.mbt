///|
/// A parsed regular expression.
priv enum Node {
  /// One literal code unit.
  Char(Int32)
  /// `.`: anything but a line terminator.
  Any
  /// A character class as inclusive ranges.
  Class(Array[(Int32, Int32)], negated~ : Bool)
  /// `^`
  Start
  /// `$`
  End
  /// `\b`, or `\B` when negated.
  WordBoundary(negated~ : Bool)
  /// A group; `capture` is its index when it captures.
  Group(Node, capture~ : Int32?)
  Seq(Array[Node])
  Alt(Array[Node])
  Repeat(Node, min~ : Int32, max~ : Int32?, greedy~ : Bool)
  /// `(?=...)`, or `(?!...)` when negated.
  Look(Node, negated~ : Bool)
  /// `\1` to `\9`: what the group of that number matched; nothing when
  /// it has not taken part in the match.
  Backref(Int32)
  Empty
}

///|
/// A pattern that cannot be compiled.
pub(all) suberror RegexError {
  RegexError(String)
} derive(Eq, Debug)

///|
/// The ranges `\d`, `\w` and `\s` stand for.
fn class_escape(c : Int32) -> Array[(Int32, Int32)]? {
  match c {
    'd' | 'D' => Some([('0', '9')])
    'w' | 'W' => Some([('0', '9'), ('A', 'Z'), ('_', '_'), ('a', 'z')])
    's' | 'S' =>
      Some([
        (0x09, 0x0d),
        (0x20, 0x20),
        (0xa0, 0xa0),
        (0x1680, 0x1680),
        (0x2000, 0x200a),
        (0x2028, 0x2029),
        (0x202f, 0x202f),
        (0x205f, 0x205f),
        (0x3000, 0x3000),
        (0xfeff, 0xfeff),
      ])
    _ => None
  }
}

///|
/// The complement of sorted, non-overlapping `ranges` over all code units.
fn complement(ranges : Array[(Int32, Int32)]) -> Array[(Int32, Int32)] {
  let sorted = ranges.copy()
  sorted.sort_by((a, b) => a.0.compare(b.0))
  let out = []
  let mut next = 0
  for range in sorted {
    if range.0 > next {
      out.push((next, range.0 - 1))
    }
    if range.1 + 1 > next {
      next = range.1 + 1
    }
  }
  if next <= 0xffff {
    out.push((next, 0xffff))
  }
  out
}
