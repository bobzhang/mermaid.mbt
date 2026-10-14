// `Number.prototype.toFixed`, `toExponential`, `toPrecision` and
// `toString(radix)`, which d3-format builds on. JavaScript rounds the
// exact binary value of the number to the wanted decimal digits, a tie
// going up, so the digits are computed with integers.

///|
/// A finite, non-negative double as `mantissa * 2^exponent`.
fn decompose(x : Double) -> (BigInt, Int32) {
  let bits = x.reinterpret_as_uint64()
  let exponent = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0xfffffffffffffUL
  if exponent == 0 {
    (BigInt::from_uint64(fraction), -1074)
  } else {
    (BigInt::from_uint64(fraction | (1UL << 52)), exponent - 1075)
  }
}

///|
fn big_pow10(k : Int32) -> BigInt {
  BigInt::from_int(10).pow(BigInt::from_int(k))
}

///|
/// A finite, non-negative double times `10^k` as a fraction.
fn scaled(x : Double, k : Int32) -> (BigInt, BigInt) {
  let (mantissa, exponent) = decompose(x)
  let mut numerator = mantissa
  let mut denominator = BigInt::from_int(1)
  if exponent >= 0 {
    numerator = numerator << exponent
  } else {
    denominator = denominator << -exponent
  }
  if k >= 0 {
    numerator = numerator * big_pow10(k)
  } else {
    denominator = denominator * big_pow10(-k)
  }
  (numerator, denominator)
}

///|
/// `x * 10^k` rounded to an integer, a tie going up.
fn scaled_round(x : Double, k : Int32) -> BigInt {
  let (numerator, denominator) = scaled(x, k)
  let two = BigInt::from_int(2)
  (numerator * two + denominator) / (denominator * two)
}

///|
/// The `e` with `10^e <= x < 10^(e + 1)`, for a finite `x > 0`.
fn decimal_exponent(x : Double) -> Int32 {
  let (mantissa, exponent) = decompose(x)
  // log10(2) is about 0.30103: a first guess from the binary magnitude.
  let magnitude = mantissa.bit_length() + exponent - 1
  let mut e = (magnitude.to_double() * 0.30102999566398114).floor().to_int()
  let at_least = (e : Int32) => {
    // x >= 10^e
    let (numerator, denominator) = scaled(x, -e)
    numerator >= denominator
  }
  while !at_least(e) {
    e -= 1
  }
  while at_least(e + 1) {
    e += 1
  }
  e
}

///|
/// The `digits` significant digits of `x > 0` and its decimal exponent:
/// the integer `n` with that many digits for which `n * 10^(e - digits +
/// 1)` is closest to `x`, a tie going up.
fn significant(x : Double, digits : Int32) -> (String, Int32) {
  let mut e = decimal_exponent(x)
  let mut n = scaled_round(x, digits - 1 - e)
  if n == big_pow10(digits) {
    n = big_pow10(digits - 1)
    e += 1
  }
  (n.to_string(), e)
}

///|
/// The shortest digits that identify `x > 0`, and its decimal exponent:
/// those of `String(x)`.
fn shortest(x : Double) -> (String, Int32) {
  let text = number(x)
  let (mantissa, exponent) = match text.find("e") {
    Some(at) =>
      (
        text[:at].to_owned(),
        @string.parse_int(text[at + 1:].to_owned().replace(old="+", new="")) catch {
          _ => 0
        },
      )
    None => (text, 0)
  }
  let point = mantissa.find(".").unwrap_or(mantissa.length())
  let all = mantissa.replace(old=".", new="")
  // Leading zeros (of `0.00123`) are not significant.
  let mut zeros = 0
  while zeros < all.length() - 1 && all[zeros] == '0' {
    zeros += 1
  }
  let digits = all[zeros:].to_owned()
  let digits = digits.trim_end(chars="0").to_owned()
  (if digits == "" { "0" } else { digits }, exponent + point - 1 - zeros)
}

///|
fn exponent_suffix(e : Int32) -> String {
  if e >= 0 {
    "e+\{e}"
  } else {
    "e-\{-e}"
  }
}

///|
/// `Number.prototype.toFixed(digits)`.
pub fn to_fixed(x : Double, digits : Int32) -> String {
  if x.is_nan() {
    return "NaN"
  }
  if x.abs() >= 1.0e21 {
    return number(x)
  }
  let negative = x < 0.0
  let n = scaled_round(x.abs(), digits).to_string()
  let n = if n.length() <= digits {
    "0".repeat(digits + 1 - n.length()) + n
  } else {
    n
  }
  let whole = n.length() - digits
  let text = if digits > 0 {
    n[:whole].to_owned() + "." + n[whole:].to_owned()
  } else {
    n
  }
  if negative {
    "-" + text
  } else {
    text
  }
}

///|
/// `Number.prototype.toExponential(digits)`; without `digits`, as many as
/// are needed to identify the number.
pub fn to_exponential(x : Double, digits? : Int32) -> String {
  if x.is_nan() {
    return "NaN"
  }
  if x.is_inf() {
    return if x < 0.0 { "-Infinity" } else { "Infinity" }
  }
  let sign = if x < 0.0 { "-" } else { "" }
  let x = x.abs()
  let (mantissa, e) = if x == 0.0 {
    ("0".repeat(digits.unwrap_or(0) + 1), 0)
  } else {
    match digits {
      Some(digits) => significant(x, digits + 1)
      None => shortest(x)
    }
  }
  let mantissa = if mantissa.length() > 1 {
    mantissa[:1].to_owned() + "." + mantissa[1:].to_owned()
  } else {
    mantissa
  }
  sign + mantissa + exponent_suffix(e)
}

///|
/// `Number.prototype.toPrecision(precision)`.
pub fn to_precision(x : Double, precision : Int32) -> String {
  if x.is_nan() {
    return "NaN"
  }
  if x.is_inf() {
    return if x < 0.0 { "-Infinity" } else { "Infinity" }
  }
  let sign = if x < 0.0 { "-" } else { "" }
  let x = x.abs()
  let (digits, e) = if x == 0.0 {
    ("0".repeat(precision), 0)
  } else {
    significant(x, precision)
  }
  if e < -6 || e >= precision {
    let mantissa = if precision > 1 {
      digits[:1].to_owned() + "." + digits[1:].to_owned()
    } else {
      digits
    }
    return sign + mantissa + exponent_suffix(e)
  }
  if e == precision - 1 {
    return sign + digits
  }
  if e >= 0 {
    return sign + digits[:e + 1].to_owned() + "." + digits[e + 1:].to_owned()
  }
  sign + "0." + "0".repeat(-(e + 1)) + digits
}

///|
/// `Math.round(x).toString(radix)` for a non-negative `x`, in radix 2, 8
/// or 16: the digits of the integer, which is exact however large.
fn rounded_to_radix(x : Double, radix : Int32) -> String {
  let x = js_round(x)
  if x.is_nan() {
    return "NaN"
  }
  if x.is_inf() {
    return "Infinity"
  }
  let (mantissa, exponent) = decompose(x)
  let integer = if exponent >= 0 {
    mantissa << exponent
  } else {
    mantissa >> -exponent
  }
  integer.to_string(radix~).to_lower()
}

///|
/// `x.toLocaleString("en")` without its commas, for an integer of at
/// least `1e21`: the shortest digits that identify it, then zeros.
fn locale_digits(x : Double) -> String {
  if x.is_inf() {
    return "∞"
  }
  let (digits, e) = shortest(x)
  if digits.length() > e + 1 {
    digits
  } else {
    digits + "0".repeat(e + 1 - digits.length())
  }
}
