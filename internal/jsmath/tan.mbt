// `Math.tan` as V8 computes it: llvm-libc's `tan`, which is correctly
// rounded (a fast double-double pass, and a 128-bit pass when Ziv's test
// fails). Here the quotient of the double-double sine and cosine of
// `sin` and `cos` is rounded once, which gives the same double except in
// hard cases far rarer than the samples it was checked on. Like `sin`
// and `cos`, it is only exact for arguments small enough for `reduce`
// (checked up to 1e15).

///|
/// `Math.tan`.
pub fn tan(x : Double) -> Double {
  // Zeros keep their sign; NaN stays NaN.
  if x == 0.0 || x != x {
    return x
  }
  if x.is_inf() {
    return x - x
  }
  let (n, r) = reduce(x)
  let s = sin_series(r)
  let c = cos_series(r)
  // tan(r + pi/2) = -cos(r) / sin(r).
  if (n & 1) == 0 {
    s.div(c).to_double()
  } else {
    c.div(s).neg().to_double()
  }
}
