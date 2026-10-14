///|
/// `10 ** n` to about 106 bits.
fn pow10_dd(n : Int32) -> DD {
  let mut power = DD::from_double(1.0)
  let ten = DD::from_double(10.0)
  let count = if n < 0 { -n } else { n }
  for _ in 0..<count {
    power = power.mul(ten)
  }
  if n >= 0 {
    return power
  }
  // The reciprocal: a first quotient, then one correction from what the
  // quotient leaves of 1.
  let q = 1.0 / power.hi
  let rest = DD::from_double(1.0).add(power.mul(DD::from_double(q)).neg())
  quick_two_sum(q, rest.hi / power.hi)
}

///|
/// `Math.pow(10, n)` for an integer `n`: the double nearest to the power
/// of ten, as in V8 (where `Math.pow(10, n) === Number("1e" + n)` for
/// every `n`, measured in Chrome).
pub fn pow10(n : Int32) -> Double {
  if n >= 0 && n <= 22 {
    // Exact, and so is every product on the way.
    let mut value = 1.0
    for _ in 0..<n {
      value = value * 10.0
    }
    value
  } else if n > 308 {
    @double.infinity
  } else if n < -400 {
    0.0
  } else {
    @string.parse_double("1e\{n}") catch {
      _ => @double.not_a_number
    }
  }
}

///|
/// `2 ** n` for a non-negative `n`.
fn two_to_the(n : Int32) -> Double {
  let mut value = 1.0
  for _ in 0..<n {
    value = value * 2.0
  }
  value
}

///|
/// The neighbour of a positive double, one unit in the last place up or
/// down.
fn neighbour(value : Double, up~ : Bool) -> Double {
  let bits = value.reinterpret_as_int64()
  (if up { bits + 1L } else { bits - 1L }).reinterpret_as_double()
}

///|
/// `Math.floor(Math.log10(x))`.
///
/// V8's `Math.log10` is correctly rounded (measured in Chrome around every
/// power of ten), so the floor is the number of digits one expects except
/// just below a power of ten: the logarithm of the few doubles under
/// `10 ** n` is nearer to `n` than to the double before `n`, and rounds up
/// to it. For 1000, that is the four doubles before it.
pub fn floor_log10(x : Double) -> Double {
  if x.is_nan() || x < 0.0 {
    return @double.not_a_number
  }
  if x == 0.0 {
    return @double.neg_infinity
  }
  if x.is_inf() {
    return x
  }
  // Near the ends of the range the comparisons below would overflow or
  // lose bits; there, x and the powers of ten are both scaled by a power
  // of two, which changes nothing else.
  let (shift, split) = if x < 1.0e-250 {
    (two_to_the(600), 200)
  } else if x > 1.0e250 {
    (1.0 / two_to_the(600), -200)
  } else {
    (1.0, 0)
  }
  let power = (n : Int32) => {
    if split == 0 {
      pow10_dd(n)
    } else {
      let part = pow10_dd(-split)
      pow10_dd(n + split).mul({ hi: part.hi * shift, lo: part.lo * shift, })
    }
  }
  // A first guess from the binary exponent, then exact comparisons with
  // the powers of ten around it.
  let exponent = ((x.reinterpret_as_int64() >> 52) & 0x7ffL).to_int() - 1023
  let mut e = (exponent.to_double() * 0.30102999566398114).floor().to_int()
  let x = x * shift
  let at_least = (power : DD) => {
    let d = x - power.hi
    d > power.lo || d == power.lo
  }
  while !at_least(power(e)) {
    e -= 1
  }
  while at_least(power(e + 1)) {
    e += 1
  }
  let n = e + 1
  if n == 0 {
    // Next to zero every logarithm is a double of its own.
    return e.to_double()
  }
  let power = power(n)
  // How far the logarithm falls short of n, to first order.
  let short = (power.hi - x + power.lo) / power.hi / 2.302585092994046
  let target = n.to_double().abs()
  let half_gap = if n > 0 {
    (target - neighbour(target, up=false)) / 2.0
  } else {
    (neighbour(target, up=true) - target) / 2.0
  }
  if short < half_gap {
    n.to_double()
  } else {
    e.to_double()
  }
}
