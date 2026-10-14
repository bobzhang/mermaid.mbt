// d3-array's tick arithmetic: "nice" steps of 1, 2 or 5 times a power of
// ten.

///|
/// `Math.pow(10, power)` for the result of a `Math.floor`.
fn pow10(power : Double) -> Double {
  if power.is_nan() {
    power
  } else if power == @double.infinity {
    power
  } else if power == @double.neg_infinity {
    0.0
  } else {
    @jsmath.pow10(power.to_int())
  }
}

///|
/// d3's `tickSpec`: the indexes of the first and last tick and the
/// increment between ticks — negative when it stands for its reciprocal,
/// so that steps below one stay exact.
fn tick_spec(
  start : Double,
  stop : Double,
  count : Double,
) -> (Double, Double, Double) {
  let step = (stop - start) / count.max(0.0)
  let power = @jsmath.floor_log10(step)
  let error = step / pow10(power)
  let factor = if error >= 50.0.sqrt() {
    10.0
  } else if error >= 10.0.sqrt() {
    5.0
  } else if error >= 2.0.sqrt() {
    2.0
  } else {
    1.0
  }
  let mut i1 = 0.0
  let mut i2 = 0.0
  let mut inc = 0.0
  if power < 0.0 {
    inc = pow10(-power) / factor
    i1 = js_round(start * inc)
    i2 = js_round(stop * inc)
    if i1 / inc < start {
      i1 += 1.0
    }
    if i2 / inc > stop {
      i2 -= 1.0
    }
    inc = -inc
  } else {
    inc = pow10(power) * factor
    i1 = js_round(start / inc)
    i2 = js_round(stop / inc)
    if i1 * inc < start {
      i1 += 1.0
    }
    if i2 * inc > stop {
      i2 -= 1.0
    }
  }
  if i2 < i1 && 0.5 <= count && count < 2.0 {
    return tick_spec(start, stop, count * 2.0)
  }
  (i1, i2, inc)
}

///|
/// d3's `ticks(start, stop, count)`: about `count` round values covering
/// the interval.
pub fn ticks(start : Double, stop : Double, count : Double) -> Array[Double] {
  if !(count > 0.0) {
    return []
  }
  if start == stop {
    return [start]
  }
  let reverse = stop < start
  let (i1, i2, inc) = if reverse {
    tick_spec(stop, start, count)
  } else {
    tick_spec(start, stop, count)
  }
  if !(i2 >= i1) {
    return []
  }
  let n = (i2 - i1 + 1.0).to_int()
  let result = []
  for i in 0..<n {
    let i = i.to_double()
    result.push(
      if reverse {
        if inc < 0.0 {
          (i2 - i) / -inc
        } else {
          (i2 - i) * inc
        }
      } else if inc < 0.0 {
        (i1 + i) / -inc
      } else {
        (i1 + i) * inc
      },
    )
  }
  result
}

///|
/// d3's `tickIncrement`.
pub fn tick_increment(start : Double, stop : Double, count : Double) -> Double {
  tick_spec(start, stop, count).2
}

///|
/// d3's `tickStep`: the distance between the ticks `ticks` would return.
pub fn tick_step(start : Double, stop : Double, count : Double) -> Double {
  let reverse = stop < start
  let inc = if reverse {
    tick_increment(stop, start, count)
  } else {
    tick_increment(start, stop, count)
  }
  (if reverse { -1.0 } else { 1.0 }) *
  (if inc < 0.0 { 1.0 / -inc } else { inc })
}
