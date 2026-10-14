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
  guard value.has_suffix("px") else { return None }
  let digits = value[:value.length() - 2].to_owned()
  guard digits != "" && digits.iter().all(c => c is ('0'..<='9' | '.' | '-')) else {
    return None
  }
  let parsed = @string.parse_double(digits) catch { _ => return None }
  Some(css_number(parsed) + "px")
}
