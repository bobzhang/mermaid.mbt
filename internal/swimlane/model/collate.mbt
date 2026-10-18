// `String.prototype.localeCompare` as Chrome evaluates it in the oracle's
// locale (en-US): ICU's root collation at tertiary strength. Upstream sorts
// node ids with it. Only ASCII is covered (see `collatable`): there the
// collation compares the strings by primary weight (punctuation, then
// symbols, digits and letters regardless of case; controls are ignored),
// and on a tie by case, lowercase first.

///|
/// ASCII in the order of its primary weights, measured in Chrome by sorting
/// every character with `localeCompare`. Letters appear in lowercase only;
/// their capitals share the weight. Characters 1-8 and 14-31 are ignored.
let primary_order : String = "\t\n\u{0B}\u{0C}\r _-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~$0123456789abcdefghijklmnopqrstuvwxyz"

///|
/// The primary weight of each ASCII code unit; 0 for the ignored ones.
let primary_weights : FixedArray[Int32] = {
  let weights = FixedArray::make(128, 0)
  for i in 0..<primary_order.length() {
    weights[primary_order.code_unit_at(i).to_int()] = i + 1
  }
  for c in 65..<=90 {
    weights[c] = weights[c + 32]
  }
  weights
}

///|
/// Whether `localeCompare` on this string is covered: ASCII without NUL
/// and DEL.
pub fn collatable(s : String) -> Bool {
  for i in 0..<s.length() {
    let c = s.code_unit_at(i).to_int()
    if c == 0 || c >= 127 {
      return false
    }
  }
  true
}

///|
fn collation_keys(s : String) -> (Array[Int32], Array[Int32]) {
  let primary = []
  let tertiary = []
  for i in 0..<s.length() {
    let c = s.code_unit_at(i).to_int()
    let weight = if c < 128 { primary_weights[c] } else { 0 }
    if weight == 0 {
      continue
    }
    primary.push(weight)
    tertiary.push(if c >= 65 && c <= 90 { 1 } else { 0 })
  }
  (primary, tertiary)
}

///|
fn compare_keys(a : Array[Int32], b : Array[Int32]) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return if a[i] < b[i] { -1 } else { 1 }
    }
  }
  a.length().compare(b.length())
}

///|
/// `a.localeCompare(b)`: -1, 0 or 1.
pub fn locale_compare(a : String, b : String) -> Double {
  let (pa, ta) = collation_keys(a)
  let (pb, tb) = collation_keys(b)
  let by_primary = compare_keys(pa, pb)
  let order = if by_primary != 0 { by_primary } else { compare_keys(ta, tb) }
  order.to_double()
}
