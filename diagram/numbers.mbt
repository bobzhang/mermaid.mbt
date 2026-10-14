///|
/// Whether JavaScript's `\s` (and `String.prototype.trim`) takes `c` for
/// white space.
pub fn is_js_space(c : Char) -> Bool {
  c
  is ('\t'
  | '\n'
  | '\u{0b}'
  | '\u{0c}'
  | '\r'
  | ' '
  | '\u{a0}'
  | '\u{1680}'
  | '\u{2000}'..<='\u{200a}'
  | '\u{2028}'
  | '\u{2029}'
  | '\u{202f}'
  | '\u{205f}'
  | '\u{3000}'
  | '\u{feff}')
}

///|
/// JavaScript's `parseFloat`: the number the longest numeric prefix of
/// the text stands for, `NaN` without one.
pub fn parse_float(text : String) -> Double {
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && is_js_space(chars[i]) {
    i += 1
  }
  let start = i
  let mut negative = false
  if i < n && chars[i] is ('+' | '-') {
    negative = chars[i] == '-'
    i += 1
  }
  if String::from_array(chars[i:]).has_prefix("Infinity") {
    return if negative { @double.neg_infinity } else { @double.infinity }
  }
  let is_digit = (k : Int32) => k < n && chars[k] is ('0'..<='9')
  let mut digits = 0
  while is_digit(i) {
    i += 1
    digits += 1
  }
  if i < n && chars[i] == '.' && (digits > 0 || is_digit(i + 1)) {
    i += 1
    while is_digit(i) {
      i += 1
      digits += 1
    }
  }
  if digits == 0 {
    return @double.not_a_number
  }
  if i < n && chars[i] is ('e' | 'E') {
    let mut j = i + 1
    if j < n && chars[j] is ('+' | '-') {
      j += 1
    }
    if is_digit(j) {
      while is_digit(j) {
        j += 1
      }
      i = j
    }
  }
  let literal = String::from_array(chars[start:i])
  // A trailing point is part of the number in JavaScript.
  let literal = if literal.has_suffix(".") { literal + "0" } else { literal }
  let literal = literal
    .replace(old="+.", new="+0.")
    .replace(old="-.", new="-0.")
  let literal = if literal.has_prefix(".") { "0" + literal } else { literal }
  let literal = literal
    .replace(old=".e", new=".0e")
    .replace(old=".E", new=".0E")
  @string.parse_double(literal) catch {
    _ => @double.not_a_number
  }
}
