///|
/// `Math.tan`: correctly rounded in V8 (llvm-libc), so evaluated as the
/// quotient of the double-double sine and cosine series and rounded once.
pub fn tan(x : Double) -> Double {
  if x == 0.0 || x != x {
    return x
  }
  if x.is_inf() {
    return x - x
  }
  let (n, r) = reduce(x)
  let sin = sin_series(r)
  let cos = cos_series(r)
  if n % 2 == 0 {
    sin.div(cos).to_double()
  } else {
    cos.div(sin).neg().to_double()
  }
}
