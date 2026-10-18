///|
/// A number as the CSSOM serializes it: `%.6g`, six significant digits of
/// the exact binary value with ties going to the even digit, trailing
/// zeros dropped, and an exponent outside 1e-5 to 1e6.
fn css_number(value : Double) -> String {
  if value == 0.0 || value.is_nan() || value.is_inf() {
    return number(value)
  }
  let negative = value < 0.0
  let bits = value.abs().reinterpret_as_uint64()
  let raw_exponent = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0xfffffffffffffUL
  // value = mantissa * 2^exponent
  let (mantissa, exponent) = if raw_exponent == 0 {
    (fraction, -1074)
  } else {
    (fraction | 0x10000000000000UL, raw_exponent - 1075)
  }
  let ten = @bigint.BigInt::from_int(10)
  let two = @bigint.BigInt::from_int(2)
  let mut numerator = @bigint.BigInt::from_uint64(mantissa)
  let mut denominator = @bigint.BigInt::from_int(1)
  if exponent >= 0 {
    numerator = numerator * two.pow(@bigint.BigInt::from_int(exponent))
  } else {
    denominator = two.pow(@bigint.BigInt::from_int(-exponent))
  }
  // The decimal exponent: 10^k <= value < 10^(k + 1).
  let at_least = (power : Int32) => {
    if power >= 0 {
      numerator >= denominator * ten.pow(@bigint.BigInt::from_int(power))
    } else {
      numerator * ten.pow(@bigint.BigInt::from_int(-power)) >= denominator
    }
  }
  let mut k = 0
  while at_least(k + 1) {
    k += 1
  }
  while !at_least(k) {
    k -= 1
  }
  // Six digits: value * 10^(5 - k), rounded.
  let shift = 5 - k
  if shift >= 0 {
    numerator = numerator * ten.pow(@bigint.BigInt::from_int(shift))
  } else {
    denominator = denominator * ten.pow(@bigint.BigInt::from_int(-shift))
  }
  let mut digits = numerator / denominator
  let twice = (numerator - digits * denominator) * two
  if twice > denominator ||
    (twice == denominator && digits % two != @bigint.BigInt::from_int(0)) {
    digits = digits + @bigint.BigInt::from_int(1)
  }
  let mut text = digits.to_string()
  if text.length() > 6 {
    // Rounded up to the next power of ten.
    text = text[:6].to_owned()
    k += 1
  }
  let strip = (text : String) => {
    if text.contains(".") {
      text.trim_end(chars="0").trim_end(chars=".").to_owned()
    } else {
      text
    }
  }
  let sign = if negative { "-" } else { "" }
  if k < -4 || k >= 6 {
    let exponent_text = k.abs().to_string()
    let padded = if exponent_text.length() < 2 {
      "0" + exponent_text
    } else {
      exponent_text
    }
    let mantissa_text = strip(text[:1].to_owned() + "." + text[1:].to_owned())
    return "\{sign}\{mantissa_text}e\{if k < 0 { "-" } else { "+" }}\{padded}"
  }
  let fixed = if k >= 0 {
    text[:k + 1].to_owned() + "." + text[k + 1:].to_owned()
  } else {
    "0." + "0".repeat(-k - 1) + text
  }
  sign + strip(fixed)
}

///|
/// A pixel length as the CSSOM serializes it, when `value` is one.
fn css_length(value : String) -> String? {
  // The number as CSS writes one: `+2px` is `2px`, `1e1px` is `10px`.
  guard css_dimension(value) is Some((parsed, "px")) else { return None }
  Some(css_number(parsed) + "px")
}

///|
/// A CSS dimension at the start of `text`: its number, as CSS writes one
/// (an optional sign, digits with an optional fraction, an optional
/// exponent: `+12`, `.5`, `1e1`), and what follows it, the unit. `None`
/// when no number starts `text`.
pub fn css_dimension(text : String) -> (Double, String)? {
  let n = text.length()
  let digits = (from : Int32) => {
    let mut at = from
    while at < n && text[at] is ('0'..<='9') {
      at += 1
    }
    at
  }
  let mut at = if n > 0 && text[0] is ('+' | '-') { 1 } else { 0 }
  let whole = digits(at)
  let mut end = whole
  if end + 1 < n && text[end] == '.' && text[end + 1] is ('0'..<='9') {
    end = digits(end + 1)
  }
  if end == at {
    return None
  }
  at = end
  // An exponent only where digits follow the `e` and its sign.
  if at < n && text[at] is ('e' | 'E') {
    let sign = if at + 1 < n && text[at + 1] is ('+' | '-') { 1 } else { 0 }
    if at + 1 + sign < n && text[at + 1 + sign] is ('0'..<='9') {
      end = digits(at + 1 + sign)
    }
  }
  let number = @string.parse_double(text[:end]) catch { _ => return None }
  Some((number, text[end:].to_owned()))
}
