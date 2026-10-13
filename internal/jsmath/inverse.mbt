// atan2 and acos as V8 computes them. Like sin and cos they come from
// llvm-libc and are correctly rounded, so they are evaluated here in
// double-double arithmetic and rounded once. (llvm-libc's atan is not
// correctly rounded and is not ported.)

///|
let dd_pi : DD = { hi: 3.141592653589793, lo: 1.2246467991473532e-16, }

///|
let dd_pio2 : DD = { hi: 1.5707963267948966, lo: 6.123233995736766e-17, }

///|
fn DD::div(self : DD, other : DD) -> DD {
  let q1 = self.hi / other.hi
  let r = self.add(other.mul(DD::from_double(q1)).neg())
  let q2 = r.hi / other.hi
  let r = r.add(other.mul(DD::from_double(q2)).neg())
  let q3 = r.hi / other.hi
  quick_two_sum(q1, q2).add(DD::from_double(q3))
}

///|
fn DD::sqrt(self : DD) -> DD {
  if self.hi <= 0.0 {
    return DD::from_double(0.0)
  }
  let x = 1.0 / self.hi.sqrt()
  let ax = self.hi * x
  let rest = self.add(two_prod(ax, ax).neg()).hi * (x * 0.5)
  // One more Newton step keeps the full 106 bits.
  let first = two_sum(ax, rest)
  let correction = self.add(first.mul(first).neg()).hi * (x * 0.5)
  first.add(DD::from_double(correction))
}

///|
/// The arctangent of `t`, `0 <= t <= 1`.
fn atan_unit(t : DD) -> DD {
  // Halve the angle three times, then sum the Taylor series.
  let one = DD::from_double(1.0)
  let mut t = t
  for _ in 0..<3 {
    t = t.div(one.add(one.add(t.mul(t)).sqrt()))
  }
  let square = t.mul(t).neg()
  let mut term = t
  let mut sum = t
  for k = 1; k < 40; k = k + 1 {
    term = term.mul(square)
    let part = term.div_double((2 * k + 1).to_double())
    sum = sum.add(part)
    if part.hi.abs() < 1.0e-36 * sum.hi.abs() {
      break
    }
  }
  sum.mul(DD::from_double(8.0))
}

///|
/// The arctangent of `numerator / denominator` for non-negative arguments
/// that are not both zero: an angle in `[0, pi/2]`.
fn atan_ratio(numerator : DD, denominator : DD) -> DD {
  if numerator.hi <= denominator.hi {
    atan_unit(numerator.div(denominator))
  } else {
    dd_pio2.add(atan_unit(denominator.div(numerator)).neg())
  }
}

///|
/// `Math.atan2` as V8 computes it.
pub fn atan2(y : Double, x : Double) -> Double {
  if x.is_nan() || y.is_nan() {
    return x + y
  }
  let y_negative = y.reinterpret_as_int64() < 0L
  let x_negative = x.reinterpret_as_int64() < 0L
  let signed = (angle : Double) => if y_negative { -angle } else { angle }
  if y == 0.0 {
    return if x_negative { signed(dd_pi.to_double()) } else { y }
  }
  if x == 0.0 {
    return signed(dd_pio2.to_double())
  }
  if x.is_inf() {
    return if y.is_inf() {
      signed(if x_negative { 2.356194490192345 } else { 0.7853981633974483 })
    } else if x_negative {
      signed(dd_pi.to_double())
    } else {
      signed(0.0)
    }
  }
  if y.is_inf() {
    return signed(dd_pio2.to_double())
  }
  let angle = atan_ratio(DD::from_double(y.abs()), DD::from_double(x.abs()))
  let angle = if x_negative { dd_pi.add(angle.neg()) } else { angle }
  signed(angle.to_double())
}

///|
/// `Math.acos` as V8 computes it.
pub fn acos(x : Double) -> Double {
  if x.is_nan() || x.abs() > 1.0 {
    return 0x7ff8000000000000L.reinterpret_as_double()
  }
  if x == 1.0 {
    return 0.0
  }
  if x == -1.0 {
    return dd_pi.to_double()
  }
  if x == 0.0 {
    return dd_pio2.to_double()
  }
  // sqrt(1 - x^2) from the two exact factors.
  let sine = two_sum(1.0, -x).mul(two_sum(1.0, x)).sqrt()
  let angle = atan_ratio(sine, DD::from_double(x.abs()))
  let angle = if x < 0.0 { dd_pi.add(angle.neg()) } else { angle }
  angle.to_double()
}

///|
/// `Math.hypot` of two numbers as V8 computes it: scaled by the larger
/// magnitude and summed with Kahan compensation.
pub fn hypot(a : Double, b : Double) -> Double {
  if a.is_inf() || b.is_inf() {
    return 0x7ff0000000000000L.reinterpret_as_double()
  }
  if a.is_nan() || b.is_nan() {
    return 0x7ff8000000000000L.reinterpret_as_double()
  }
  let a = a.abs()
  let b = b.abs()
  let max = if a > b { a } else { b }
  if max == 0.0 {
    return 0.0
  }
  let mut sum = 0.0
  let mut compensation = 0.0
  for value in [a, b] {
    let n = value / max
    let summand = n * n - compensation
    let preliminary = sum + summand
    compensation = preliminary - sum - summand
    sum = preliminary
  }
  sum.sqrt() * max
}
