// Elliptical arcs of path data as cubic Bézier curves: the
// `arcToCubicCurves` of the `path-data-parser` package that rough.js
// normalizes paths with, transcribed operation by operation. It takes
// angles back from the endpoints with `Math.asin` of a value rounded to
// nine decimals, and the length of the control arms with `Math.tan`.

///|
const PI : Double = 3.141592653589793

///|
/// `rotate(x, y, angleRad)`
fn rotate_point(x : Double, y : Double, angle : Double) -> (Double, Double) {
  (
    x * @jsmath.cos(angle) - y * @jsmath.sin(angle),
    x * @jsmath.sin(angle) + y * @jsmath.cos(angle),
  )
}

///|
/// `parseFloat(value.toFixed(9))`
fn nine_decimals(value : Double) -> Double {
  @string.parse_double(@d3.to_fixed(value, 9)) catch {
    _ => value
  }
}

///|
/// The control points and ends of the curves of an arc from `(x1, y1)` to
/// `(x2, y2)`, three points per curve. `recursive` carries the angles and
/// centre of the arc being split, which then arrive in its own frame.
fn arc_to_cubic_curves(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  r1 : Double,
  r2 : Double,
  angle : Double,
  large_arc_flag : Double,
  sweep_flag : Double,
  recursive? : (Double, Double, Double, Double),
) -> Array[(Double, Double)] {
  let angle_rad = PI * angle / 180.0
  let mut params : Array[(Double, Double)] = []
  let mut x1 = x1
  let mut y1 = y1
  let mut x2 = x2
  let mut y2 = y2
  let mut r1 = r1
  let mut r2 = r2
  let mut f1 = 0.0
  let mut f2 = 0.0
  let mut cx = 0.0
  let mut cy = 0.0
  let sweep = sweep_flag != 0.0 && !sweep_flag.is_nan()
  match recursive {
    Some((a, b, c, d)) => {
      f1 = a
      f2 = b
      cx = c
      cy = d
    }
    None => {
      let p1 = rotate_point(x1, y1, -angle_rad)
      x1 = p1.0
      y1 = p1.1
      let p2 = rotate_point(x2, y2, -angle_rad)
      x2 = p2.0
      y2 = p2.1
      let x = (x1 - x2) / 2.0
      let y = (y1 - y2) / 2.0
      let mut h = x * x / (r1 * r1) + y * y / (r2 * r2)
      if h > 1.0 {
        h = h.sqrt()
        r1 = h * r1
        r2 = h * r2
      }
      let sr1 = r1 * r1
      let sr2 = r2 * r2
      let k = (if large_arc_flag == sweep_flag { -1.0 } else { 1.0 }) *
        ((sr1 * sr2 - sr1 * y * y - sr2 * x * x) / (sr1 * y * y + sr2 * x * x))
        .abs()
        .sqrt()
      cx = k * r1 * y / r2 + (x1 + x2) / 2.0
      cy = k * -r2 * x / r1 + (y1 + y2) / 2.0
      f1 = @jsmath.asin(nine_decimals((y1 - cy) / r2))
      f2 = @jsmath.asin(nine_decimals((y2 - cy) / r2))
      if x1 < cx {
        f1 = PI - f1
      }
      if x2 < cx {
        f2 = PI - f2
      }
      if f1 < 0.0 {
        f1 = PI * 2.0 + f1
      }
      if f2 < 0.0 {
        f2 = PI * 2.0 + f2
      }
      if sweep && f1 > f2 {
        f1 = f1 - PI * 2.0
      }
      if !sweep && f2 > f1 {
        f2 = f2 - PI * 2.0
      }
    }
  }
  let mut df = f2 - f1
  // More than 120 degrees: the rest of the arc is split off.
  if df.abs() > PI * 120.0 / 180.0 {
    let f2old = f2
    let x2old = x2
    let y2old = y2
    if sweep && f2 > f1 {
      f2 = f1 + PI * 120.0 / 180.0 * 1.0
    } else {
      f2 = f1 + PI * 120.0 / 180.0 * -1.0
    }
    x2 = cx + r1 * @jsmath.cos(f2)
    y2 = cy + r2 * @jsmath.sin(f2)
    params = arc_to_cubic_curves(
      x2,
      y2,
      x2old,
      y2old,
      r1,
      r2,
      angle,
      0.0,
      sweep_flag,
      recursive=(f2, f2old, cx, cy),
    )
  }
  df = f2 - f1
  let c1 = @jsmath.cos(f1)
  let s1 = @jsmath.sin(f1)
  let c2 = @jsmath.cos(f2)
  let s2 = @jsmath.sin(f2)
  let t = @jsmath.tan(df / 4.0)
  let hx = 4.0 / 3.0 * r1 * t
  let hy = 4.0 / 3.0 * r2 * t
  let m1 = (x1, y1)
  let m2 = (x1 + hx * s1, y1 - hy * c1)
  let m3 = (x2 + hx * s2, y2 - hy * c2)
  let m4 = (x2, y2)
  let m2 = (2.0 * m1.0 - m2.0, 2.0 * m1.1 - m2.1)
  let points = [m2, m3, m4]
  points.append(params)
  if recursive is Some(_) {
    return points
  }
  // Back from the frame of the ellipse.
  points.map(point => rotate_point(point.0, point.1, angle_rad))
}
