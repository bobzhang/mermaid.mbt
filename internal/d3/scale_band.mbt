///|
/// d3-scale's band scale: the values of a discrete domain spread over a
/// continuous range in bands of equal width.
pub struct BandScale {
  /// The position of each distinct domain value.
  priv positions : Map[String, Double]
  priv step : Double
  priv bandwidth : Double
}

///|
/// A band scale over `domain` and `range`. Values that occur more than
/// once in the domain count once, where they first appear.
pub fn BandScale::new(
  domain~ : Array[String],
  range~ : (Double, Double),
  padding_inner~ : Double = 0.0,
  padding_outer~ : Double = 0.0,
  align~ : Double = 0.5,
  round~ : Bool = false,
) -> BandScale {
  let distinct = []
  let seen : Map[String, Unit] = Map([])
  for value in domain {
    if !seen.contains(value) {
      seen[value] = ()
      distinct.push(value)
    }
  }
  // d3's `rescale`.
  let n = distinct.length().to_double()
  let (r0, r1) = range
  let reverse = r1 < r0
  let mut start = if reverse { r1 } else { r0 }
  let stop = if reverse { r0 } else { r1 }
  let mut step = (stop - start) /
    (n - padding_inner + padding_outer * 2.0).max(1.0)
  if round {
    step = step.floor()
  }
  start += (stop - start - step * (n - padding_inner)) * align
  let mut bandwidth = step * (1.0 - padding_inner)
  if round {
    start = js_round(start)
    bandwidth = js_round(bandwidth)
  }
  let positions : Map[String, Double] = Map([])
  let count = distinct.length()
  for i, value in distinct {
    // A descending range lays the values out from its far end.
    let k = if reverse { count - 1 - i } else { i }
    positions[value] = start + step * k.to_double()
  }
  { positions, step, bandwidth, }
}

///|
/// Where the band of `value` starts, or `None` for a value outside the
/// domain.
pub fn BandScale::apply(self : BandScale, value : String) -> Double? {
  self.positions.get(value)
}

///|
/// The distance between the starts of neighbouring bands.
pub fn BandScale::step(self : BandScale) -> Double {
  self.step
}

///|
/// The width of a band.
pub fn BandScale::bandwidth(self : BandScale) -> Double {
  self.bandwidth
}
