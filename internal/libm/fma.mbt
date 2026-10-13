// Fused multiply-add in software. The library routines ported here use it
// throughout, and WebAssembly has no instruction for it.

///|
/// The exact sum of two doubles as `(sum, error)`.
fn two_sum(a : Double, b : Double) -> (Double, Double) {
  let s = a + b
  let bb = s - a
  (s, a - (s - bb) + (b - bb))
}

///|
/// Split a double into two halves of 26 bits each (Dekker).
fn split(a : Double) -> (Double, Double) {
  let t = 134217729.0 * a
  let hi = t - (t - a)
  (hi, a - hi)
}

///|
/// The exact product of two doubles as `(product, error)`.
fn two_prod(a : Double, b : Double) -> (Double, Double) {
  let p = a * b
  let (ah, al) = split(a)
  let (bh, bl) = split(b)
  (p, ah * bh - p + ah * bl + al * bh + al * bl)
}

///|
/// `a * b + c` rounded once, as the `fmadd` instruction computes it.
///
/// The product and the sum are taken exactly; the two error terms are
/// added with rounding to odd, which keeps enough of what they lose for
/// the final addition to round as the exact result would (Boldo and
/// Melquiond, "Emulation of a FMA and correctly rounded sums"). Operands
/// are assumed far from overflow and underflow, as they are in the
/// routines here.
fn fma(a : Double, b : Double, c : Double) -> Double {
  let (p, e) = two_prod(a, b)
  let (s, t) = two_sum(p, c)
  let (u, v) = two_sum(t, e)
  if v == 0.0 || u.reinterpret_as_int64().land(1L) != 0L {
    return s + u
  }
  // The exact sum of the errors lies between two doubles and `u` is the
  // even one: take the odd one on the side of the remainder.
  let bits = u.reinterpret_as_int64()
  let away = (v > 0.0) == (u > 0.0)
  let odd = if away { bits + 1L } else { bits - 1L }
  s + odd.reinterpret_as_double()
}

///|
/// Round to the nearest integer, ties to even: the `frintn` instruction.
fn round_even(x : Double) -> Double {
  let magic = 4503599627370496.0
  if x.abs() >= magic || x != x {
    x
  } else if x < 0.0 {
    x - magic + magic
  } else {
    x + magic - magic
  }
}
