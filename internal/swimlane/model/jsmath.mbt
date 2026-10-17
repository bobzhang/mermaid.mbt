// The arithmetic of JavaScript that has no exact counterpart in MoonBit.

///|
/// `Math.min(a, b)`: NaN wins, and -0 is less than 0.
pub fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    return @double.not_a_number
  }
  if a == b {
    // Only the zeros differ among equal values.
    return if is_neg_zero(a) { a } else { b }
  }
  if a < b {
    a
  } else {
    b
  }
}

///|
/// `Math.max(a, b)`: NaN wins, and 0 is greater than -0.
pub fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    return @double.not_a_number
  }
  if a == b {
    return if is_neg_zero(a) { b } else { a }
  }
  if a > b {
    a
  } else {
    b
  }
}

///|
/// `Math.round`: halves go up, towards +∞.
pub fn js_round(x : Double) -> Double {
  if x.is_nan() || x.is_inf() {
    return x
  }
  let floor = x.floor()
  let rounded = if x - floor >= 0.5 { floor + 1.0 } else { floor }
  // `Math.round(-0.4)` is -0.
  if rounded == 0.0 && (x < 0.0 || is_neg_zero(x)) {
    -0.0
  } else {
    rounded
  }
}

///|
/// The `<` of two JavaScript strings: by UTF-16 code units.
pub fn code_unit_less(a : String, b : String) -> Bool {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let x = a.code_unit_at(i)
    let y = b.code_unit_at(i)
    if x != y {
      return x < y
    }
  }
  a.length() < b.length()
}

///|
/// The default comparator of `Array.prototype.sort` on strings.
pub fn code_unit_compare(a : String, b : String) -> Double {
  if code_unit_less(a, b) {
    -1.0
  } else if code_unit_less(b, a) {
    1.0
  } else {
    0.0
  }
}

///|
/// Whether `x` is -0.
pub fn is_neg_zero(x : Double) -> Bool {
  x == 0.0 && x.reinterpret_as_uint64() != 0UL
}
