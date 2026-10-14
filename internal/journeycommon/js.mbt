///|
/// Whether JavaScript's `trim` and `Number` treat `c` as blank: white
/// space and line terminators.
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
/// `String.prototype.trim`.
pub fn js_trim(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_js_space(chars[start]) {
    start += 1
  }
  while end > start && is_js_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// `Number(text)`: the numeric value of a string. Blank is zero, a
/// decimal, hexadecimal, octal or binary literal is its value, anything
/// else is `NaN`.
pub fn js_number(text : String) -> Double {
  let text = js_trim(text)
  if text == "" {
    return 0.0
  }
  let radix_value = (digits : StringView, radix : Int32) => {
    if digits.length() == 0 {
      return @double.not_a_number
    }
    let mut value = 0.0
    for c in digits {
      let digit = match c {
        '0'..<='9' => c.to_int() - '0'
        'a'..<='z' => c.to_int() - 'a' + 10
        'A'..<='Z' => c.to_int() - 'A' + 10
        _ => 99
      }
      if digit >= radix {
        return @double.not_a_number
      }
      value = value * radix.to_double() + digit.to_double()
    }
    value
  }
  match text {
    [.. "0x", .. digits] | [.. "0X", .. digits] =>
      return radix_value(digits, 16)
    [.. "0o", .. digits] | [.. "0O", .. digits] => return radix_value(digits, 8)
    [.. "0b", .. digits] | [.. "0B", .. digits] => return radix_value(digits, 2)
    _ => ()
  }
  let (negative, body) = match text {
    [.. "-", .. rest] => (true, rest)
    [.. "+", .. rest] => (false, rest)
    rest => (false, rest)
  }
  if body == "Infinity" {
    return if negative { @double.neg_infinity } else { @double.infinity }
  }
  // StrDecimalLiteral: digits, an optional fraction, an optional exponent,
  // with digits on at least one side of the point.
  let chars = body.to_array()
  let n = chars.length()
  let mut i = 0
  let mut mantissa_digits = 0
  while i < n && chars[i] is ('0'..<='9') {
    i += 1
    mantissa_digits += 1
  }
  if i < n && chars[i] == '.' {
    i += 1
    while i < n && chars[i] is ('0'..<='9') {
      i += 1
      mantissa_digits += 1
    }
  }
  if mantissa_digits == 0 {
    return @double.not_a_number
  }
  if i < n && chars[i] is ('e' | 'E') {
    i += 1
    if i < n && chars[i] is ('+' | '-') {
      i += 1
    }
    let exponent_start = i
    while i < n && chars[i] is ('0'..<='9') {
      i += 1
    }
    if i == exponent_start {
      return @double.not_a_number
    }
  }
  if i != n {
    return @double.not_a_number
  }
  // A leading or trailing point is not something every parser takes.
  let normalized = StringBuilder()
  if chars[0] == '.' {
    normalized.write_char('0')
  }
  for index, c in chars {
    normalized.write_char(c)
    if c == '.' && (index + 1 == n || !(chars[index + 1] is ('0'..<='9'))) {
      normalized.write_char('0')
    }
  }
  let value = @string.parse_double(normalized.to_string()) catch {
    _ => return @double.not_a_number
  }
  if negative {
    -value
  } else {
    value
  }
}
