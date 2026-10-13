// sin and cos as V8 computes them. Chrome's V8 uses the trigonometric
// functions of the IBM Accurate Mathematical Library, whose results are
// correctly rounded for all practical purposes, while the platform libm
// rounds a few percent of arguments the other way. d3 prints coordinates at
// full precision, so that last bit shows up in the output.
//
// Here the functions are evaluated in double-double arithmetic, about 106
// bits, and rounded once at the end.

///|
/// pi/2 as an expansion of four doubles.
let pio2 : FixedArray[Double] = [
  1.5707963267948966, 6.123233995736766e-17, -1.4973849048591698e-33, 5.562271104316826e-50,
]

///|
/// Reduce `x` modulo pi/2: returns `(n, r)` with `x = n * pi/2 + r` and
/// `|r| <= pi/4`. Only the low two bits of `n` matter.
fn reduce(x : Double) -> (Int32, DD) {
  let n = (x * 0.6366197723675814).round()
  if n == 0.0 {
    return (0, DD::from_double(x))
  }
  let mut r = DD::from_double(x)
  for part in pio2 {
    r = r.add(two_prod(n, part).neg())
  }
  // Keep the quadrant small enough for an Int whatever the magnitude.
  let quadrant = n - (n / 4.0).floor() * 4.0
  (quadrant.to_int(), r)
}

///|
/// The Taylor series of sine at `r`, `|r| <= pi/4`.
fn sin_series(r : DD) -> DD {
  let r2 = r.mul(r)
  let mut term = r
  let mut sum = r
  for k = 1; k < 20; k = k + 1 {
    term = term
      .mul(r2)
      .div_double(-((2 * k).to_double() * (2 * k + 1).to_double()))
    sum = sum.add(term)
    if term.hi.abs() < 1.0e-36 {
      break
    }
  }
  sum
}

///|
/// The Taylor series of cosine at `r`, `|r| <= pi/4`.
fn cos_series(r : DD) -> DD {
  let r2 = r.mul(r)
  let mut term = DD::from_double(1.0)
  let mut sum = term
  for k = 1; k < 20; k = k + 1 {
    term = term
      .mul(r2)
      .div_double(-((2 * k - 1).to_double() * (2 * k).to_double()))
    sum = sum.add(term)
    if term.hi.abs() < 1.0e-36 {
      break
    }
  }
  sum
}

///|
/// `Math.sin`.
pub fn sin(x : Double) -> Double {
  if x == 0.0 || x != x {
    return x
  }
  if x.is_inf() {
    return x - x
  }
  let (n, r) = reduce(x)
  match n & 3 {
    0 => sin_series(r).to_double()
    1 => cos_series(r).to_double()
    2 => -sin_series(r).to_double()
    _ => -cos_series(r).to_double()
  }
}

///|
/// `Math.cos`.
pub fn cos(x : Double) -> Double {
  if x != x {
    return x
  }
  if x.is_inf() {
    return x - x
  }
  let (n, r) = reduce(x)
  match n & 3 {
    0 => cos_series(r).to_double()
    1 => -sin_series(r).to_double()
    2 => -cos_series(r).to_double()
    _ => sin_series(r).to_double()
  }
}

///|
/// `10 ** n` for a small non-negative integer `n`, exact.
pub fn pow10(n : Int32) -> Double {
  let mut value = 1.0
  for _ in 0..<n {
    value = value * 10.0
  }
  value
}
