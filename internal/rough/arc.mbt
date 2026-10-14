// Elliptical arcs as cubic curves: the `arcToCubicCurves` of the
// `path-data-parser` that rough.js bundles, which its `normalize` calls.

///|
/// `parseFloat(value.toFixed(9))`: the value rounded to nine decimals as
/// its exact decimal expansion rounds (halves away from zero), read back.
fn to_fixed_9(value : Double) -> Double {
  if value.is_nan() || value.is_inf() || value.abs() >= 1.0e21 {
    return value
  }
  let negative = value < 0.0
  let magnitude = value.abs()
  if magnitude == 0.0 {
    return if negative { -0.0 } else { 0.0 }
  }
  // magnitude = mantissa * 2^exponent exactly.
  let bits = magnitude.reinterpret_as_uint64()
  let biased = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0xfffffffffffffUL
  let (mantissa, exponent) = if biased == 0 {
    (fraction, -1074)
  } else {
    (fraction | 0x10000000000000UL, biased - 1075)
  }
  let scaled = @bigint.BigInt::from_uint64(mantissa) *
    @bigint.BigInt::from_int(1000000000)
  // The nearest integer to `scaled * 2^exponent`, halves up.
  let n = if exponent >= 0 {
    scaled << exponent
  } else {
    (scaled + (@bigint.BigInt::from_int(1) << (-exponent - 1))) >> -exponent
  }
  let result = @string.parse_double(n.to_string()) catch { _ => 0.0 }
  let result = result / 1.0e9
  if negative {
    -result
  } else {
    result
  }
}

///|
/// A point turned by `angle` radians about the origin.
fn rotate_point(x : Double, y : Double, angle : Double) -> (Double, Double) {
  (
    x * @jsmath.cos(angle) - y * @jsmath.sin(angle),
    x * @jsmath.sin(angle) + y * @jsmath.cos(angle),
  )
}

///|
/// The control and end points of the cubic curves that draw an arc from
/// `(x1, y1)` to `(x2, y2)`, three points per curve: `arcToCubicCurves`.
/// Arcs of more than 120 degrees are split, the rest drawn by a
/// recursive call that knows the angles and centre (`recursive`).
fn arc_to_cubic_points(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  r1 : Double,
  r2 : Double,
  angle : Double,
  large_arc : Double,
  sweep : Double,
  recursive : (Double, Double, Double, Double)?,
) -> Array[(Double, Double)] {
  let pi = 3.141592653589793
  let rad = pi * angle / 180.0
  // The end points turned so that the ellipse is upright, the radii
  // grown to reach, the angles of the ends and the centre.
  let (x1, y1, x2_start, y2_start, r1, r2, f1, f2_start, cx, cy) = match
    recursive {
    Some((f1, f2, cx, cy)) => (x1, y1, x2, y2, r1, r2, f1, f2, cx, cy)
    None => {
      let (x1, y1) = rotate_point(x1, y1, -rad)
      let (x2, y2) = rotate_point(x2, y2, -rad)
      let x = (x1 - x2) / 2.0
      let y = (y1 - y2) / 2.0
      let mut h = x * x / (r1 * r1) + y * y / (r2 * r2)
      let mut r1 = r1
      let mut r2 = r2
      if h > 1.0 {
        h = h.sqrt()
        r1 = h * r1
        r2 = h * r2
      }
      let sr1 = r1 * r1
      let sr2 = r2 * r2
      let left = sr1 * sr2 - sr1 * y * y - sr2 * x * x
      let right = sr1 * y * y + sr2 * x * x
      let k = (if large_arc == sweep { -1.0 } else { 1.0 }) *
        (left / right).abs().sqrt()
      let cx = k * r1 * y / r2 + (x1 + x2) / 2.0
      let cy = k * -r2 * x / r1 + (y1 + y2) / 2.0
      let mut f1 = @jsmath.asin(to_fixed_9((y1 - cy) / r2))
      let mut f2 = @jsmath.asin(to_fixed_9((y2 - cy) / r2))
      if x1 < cx {
        f1 = pi - f1
      }
      if x2 < cx {
        f2 = pi - f2
      }
      if f1 < 0.0 {
        f1 = pi * 2.0 + f1
      }
      if f2 < 0.0 {
        f2 = pi * 2.0 + f2
      }
      if sweep != 0.0 && f1 > f2 {
        f1 = f1 - pi * 2.0
      }
      if sweep == 0.0 && f2 > f1 {
        f2 = f2 - pi * 2.0
      }
      (x1, y1, x2, y2, r1, r2, f1, f2, cx, cy)
    }
  }
  let mut x2 = x2_start
  let mut y2 = y2_start
  let mut f2 = f2_start
  let mut rest = []
  if (f2 - f1).abs() > 120.0 * pi / 180.0 {
    let f2_old = f2
    let x2_old = x2
    let y2_old = y2
    f2 = if sweep != 0.0 && f2 > f1 {
      f1 + 120.0 * pi / 180.0 * 1.0
    } else {
      f1 + 120.0 * pi / 180.0 * -1.0
    }
    x2 = cx + r1 * @jsmath.cos(f2)
    y2 = cy + r2 * @jsmath.sin(f2)
    rest = arc_to_cubic_points(
      x2,
      y2,
      x2_old,
      y2_old,
      r1,
      r2,
      angle,
      0.0,
      sweep,
      Some((f2, f2_old, cx, cy)),
    )
  }
  let df = f2 - f1
  let c1 = @jsmath.cos(f1)
  let s1 = @jsmath.sin(f1)
  let c2 = @jsmath.cos(f2)
  let s2 = @jsmath.sin(f2)
  let t = @jsmath.tan(df / 4.0)
  let hx = 4.0 / 3.0 * r1 * t
  let hy = 4.0 / 3.0 * r2 * t
  let m2 = (x1 + hx * s1, y1 - hy * c1)
  let m3 = (x2 + hx * s2, y2 - hy * c2)
  let m4 = (x2, y2)
  let m2 = (2.0 * x1 - m2.0, 2.0 * y1 - m2.1)
  let points = [m2, m3, m4, ..rest]
  if recursive is Some(_) {
    return points
  }
  points.map(p => rotate_point(p.0, p.1, rad))
}
