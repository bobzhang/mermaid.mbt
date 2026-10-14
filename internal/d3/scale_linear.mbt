///|
/// d3-scale's linear scale between two domain values and two range
/// values, without clamping or rounding.
pub struct LinearScale {
  priv domain : (Double, Double)
  priv range : (Double, Double)
}

///|
pub fn LinearScale::new(
  domain~ : (Double, Double),
  range~ : (Double, Double),
) -> LinearScale {
  { domain, range, }
}

///|
/// d3's `normalize(a, b)` applied to `x`: where `x` lies between `a` and
/// `b`. A domain of no extent puts everything in the middle.
fn normalize(a : Double, b : Double, x : Double) -> Double {
  let extent = b - a
  if extent.is_nan() {
    @double.not_a_number
  } else if extent == 0.0 {
    0.5
  } else {
    (x - a) / extent
  }
}

///|
/// The range value for `x`, or `None` (d3's `unknown`, `undefined` by
/// default) when `x` is not a number.
pub fn LinearScale::apply(self : LinearScale, x : Double) -> Double? {
  if x.is_nan() {
    return None
  }
  let (d0, d1) = self.domain
  let (r0, r1) = self.range
  // d3's `bimap`: a descending domain is turned around with its range.
  // The interpolation is `interpolateNumber`, written as d3 has it.
  Some(
    if d1 < d0 {
      let t = normalize(d1, d0, x)
      r1 * (1.0 - t) + r0 * t
    } else {
      let t = normalize(d0, d1, x)
      r0 * (1.0 - t) + r1 * t
    },
  )
}

///|
/// d3's `scale.ticks(count)`: round values within the domain, in the
/// domain's direction.
pub fn LinearScale::ticks(
  self : LinearScale,
  count~ : Double = 10.0,
) -> Array[Double] {
  ticks(self.domain.0, self.domain.1, count)
}
