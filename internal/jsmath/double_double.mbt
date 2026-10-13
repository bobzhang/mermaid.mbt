///|
/// An unevaluated sum `hi + lo` of two doubles with `|lo|` at most half a
/// unit in the last place of `hi`: about 106 bits of precision.
priv struct DD {
  hi : Double
  lo : Double
}

///|
/// The exact sum of two doubles.
fn two_sum(a : Double, b : Double) -> DD {
  let s = a + b
  let bb = s - a
  { hi: s, lo: a - (s - bb) + (b - bb), }
}

///|
/// The exact sum of two doubles when `|a| >= |b|`.
fn quick_two_sum(a : Double, b : Double) -> DD {
  let s = a + b
  { hi: s, lo: b - (s - a), }
}

///|
/// Split a double into two halves of 26 bits each (Dekker).
fn split(a : Double) -> (Double, Double) {
  let t = 134217729.0 * a
  let hi = t - (t - a)
  (hi, a - hi)
}

///|
/// The exact product of two doubles.
fn two_prod(a : Double, b : Double) -> DD {
  let p = a * b
  let (ah, al) = split(a)
  let (bh, bl) = split(b)
  { hi: p, lo: ah * bh - p + ah * bl + al * bh + al * bl, }
}

///|
fn DD::from_double(value : Double) -> DD {
  { hi: value, lo: 0.0, }
}

///|
fn DD::add(self : DD, other : DD) -> DD {
  let s = two_sum(self.hi, other.hi)
  let t = two_sum(self.lo, other.lo)
  let s = quick_two_sum(s.hi, s.lo + t.hi)
  quick_two_sum(s.hi, s.lo + t.lo)
}

///|
fn DD::neg(self : DD) -> DD {
  { hi: -self.hi, lo: -self.lo, }
}

///|
fn DD::mul(self : DD, other : DD) -> DD {
  let p = two_prod(self.hi, other.hi)
  quick_two_sum(p.hi, p.lo + (self.hi * other.lo + self.lo * other.hi))
}

///|
fn DD::div_double(self : DD, divisor : Double) -> DD {
  let q1 = self.hi / divisor
  let r = self.add(two_prod(q1, divisor).neg())
  let q2 = r.hi / divisor
  let r = r.add(two_prod(q2, divisor).neg())
  let q3 = r.hi / divisor
  let q = quick_two_sum(q1, q2)
  q.add(DD::from_double(q3))
}

///|
fn DD::to_double(self : DD) -> Double {
  self.hi + self.lo
}
