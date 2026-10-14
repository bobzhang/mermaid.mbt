// d3-shape's `line()` generator with the curves mermaid draws edges in.

///|
/// A cubic Bézier segment from the current point.
pub fn Path::bezier_curve_to(
  self : Path,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.current = Some((x, y))
  let c = (value : Double) => self.coordinate(value)
  self.out.write_string("C\{c(x1)},\{c(y1)},\{c(x2)},\{c(y2)},\{c(x)},\{c(y)}")
}

///|
/// `d3.line().curve(curve)(points)` for the curve d3 calls
/// `curve<Name>`: `linear`, `basis`, `step`, `stepBefore`, `stepAfter`,
/// `bumpX`, `bumpY`, `cardinal`, `catmullRom`, `monotoneX`, `monotoneY`
/// or `natural`, each with d3's defaults. `None` for no points, where d3
/// returns `null`, and for a name that is none of these.
pub fn line(curve : String, points : Array[(Double, Double)]) -> String? {
  guard points.length() > 0 else { return None }
  let path = Path::new(digits=3)
  match curve {
    "linear" => linear(path, points)
    "basis" => basis(path, points)
    "step" => step(path, points, 0.5)
    "stepBefore" => step(path, points, 0.0)
    "stepAfter" => step(path, points, 1.0)
    "bumpX" => bump(path, points, true)
    "bumpY" => bump(path, points, false)
    "cardinal" => cardinal(path, points)
    "catmullRom" => catmull_rom(path, points)
    "monotoneX" => monotone(path, points, false)
    "monotoneY" => monotone(path, points, true)
    "natural" => natural(path, points)
    _ => return None
  }
  // A line of a single point is closed.
  if points.length() == 1 {
    path.close()
  }
  Some(path.to_string())
}

///|
/// `d3.line().curve(d3.curveLinear)(points)`: a polyline. `None` for no
/// points.
pub fn line_linear(points : Array[(Double, Double)]) -> String? {
  line("linear", points)
}

///|
/// `d3.line().curve(d3.curveBasis)(points)`: a cubic basis spline that
/// starts and ends at the first and last points. `None` for no points.
pub fn line_basis(points : Array[(Double, Double)]) -> String? {
  line("basis", points)
}

///|
fn linear(path : Path, points : Array[(Double, Double)]) -> Unit {
  for i, point in points {
    if i == 0 {
      path.move_to(point.0, point.1)
    } else {
      path.line_to(point.0, point.1)
    }
  }
}

///|
fn basis(path : Path, points : Array[(Double, Double)]) -> Unit {
  // The two points before the current one; read only once both are set.
  let mut x0 = 0.0
  let mut x1 = 0.0
  let mut y0 = 0.0
  let mut y1 = 0.0
  let segment = (
    x0 : Double,
    y0 : Double,
    x1 : Double,
    y1 : Double,
    x : Double,
    y : Double,
  ) => {
    path.bezier_curve_to(
      (2.0 * x0 + x1) / 3.0,
      (2.0 * y0 + y1) / 3.0,
      (x0 + 2.0 * x1) / 3.0,
      (y0 + 2.0 * y1) / 3.0,
      (x0 + 4.0 * x1 + x) / 6.0,
      (y0 + 4.0 * y1 + y) / 6.0,
    )
  }
  for i, point in points {
    let (x, y) = point
    match i {
      0 => path.move_to(x, y)
      1 => ()
      _ => {
        if i == 2 {
          path.line_to((5.0 * x0 + x1) / 6.0, (5.0 * y0 + y1) / 6.0)
        }
        segment(x0, y0, x1, y1, x, y)
      }
    }
    x0 = x1
    x1 = x
    y0 = y1
    y1 = y
  }
  match points.length() {
    1 => ()
    2 => path.line_to(x1, y1)
    _ => {
      segment(x0, y0, x1, y1, x1, y1)
      path.line_to(x1, y1)
    }
  }
}

///|
/// Steps that change `y` at the share `t` of the way between two points:
/// d3's `Step`.
fn step(path : Path, points : Array[(Double, Double)], t : Double) -> Unit {
  let mut px = 0.0
  let mut py = 0.0
  for i, point in points {
    let (x, y) = point
    if i == 0 {
      path.move_to(x, y)
    } else if t <= 0.0 {
      path.line_to(px, y)
      path.line_to(x, y)
    } else {
      let x1 = px * (1.0 - t) + x * t
      path.line_to(x1, py)
      path.line_to(x1, y)
    }
    px = x
    py = y
  }
  if 0.0 < t && t < 1.0 && points.length() >= 2 {
    path.line_to(px, py)
  }
}

///|
/// A curve that leaves and enters its points horizontally (`along_x`) or
/// vertically: d3's `Bump`.
fn bump(path : Path, points : Array[(Double, Double)], along_x : Bool) -> Unit {
  let mut x0 = 0.0
  let mut y0 = 0.0
  for i, point in points {
    let (x, y) = point
    if i == 0 {
      path.move_to(x, y)
    } else if along_x {
      let middle = (x0 + x) / 2.0
      path.bezier_curve_to(middle, y0, middle, y, x, y)
    } else {
      let middle = (y0 + y) / 2.0
      path.bezier_curve_to(x0, middle, x, middle, x, y)
    }
    x0 = x
    y0 = y
  }
}

///|
/// A cardinal spline of tension 0: d3's `Cardinal`.
fn cardinal(path : Path, points : Array[(Double, Double)]) -> Unit {
  let k = (1.0 - 0.0) / 6.0
  let nan = @double.not_a_number
  let mut x0 = nan
  let mut x1 = nan
  let mut x2 = nan
  let mut y0 = nan
  let mut y1 = nan
  let mut y2 = nan
  let segment = (
    x0 : Double,
    y0 : Double,
    x1 : Double,
    y1 : Double,
    x2 : Double,
    y2 : Double,
    x : Double,
    y : Double,
  ) => {
    path.bezier_curve_to(
      x1 + k * (x2 - x0),
      y1 + k * (y2 - y0),
      x2 + k * (x1 - x),
      y2 + k * (y1 - y),
      x2,
      y2,
    )
  }
  for i, point in points {
    let (x, y) = point
    match i {
      0 => path.move_to(x, y)
      1 => {
        x1 = x
        y1 = y
      }
      _ => segment(x0, y0, x1, y1, x2, y2, x, y)
    }
    x0 = x1
    x1 = x2
    x2 = x
    y0 = y1
    y1 = y2
    y2 = y
  }
  match points.length() {
    1 => ()
    2 => path.line_to(x2, y2)
    _ => segment(x0, y0, x1, y1, x2, y2, x1, y1)
  }
}

///|
/// A centripetal Catmull–Rom spline (alpha 0.5): d3's `CatmullRom`.
fn catmull_rom(path : Path, points : Array[(Double, Double)]) -> Unit {
  let epsilon = 1.0e-12
  let nan = @double.not_a_number
  let mut x0 = nan
  let mut x1 = nan
  let mut x2 = nan
  let mut y0 = nan
  let mut y1 = nan
  let mut y2 = nan
  // Distances between consecutive points to the powers alpha and 2 alpha.
  let mut l01_a = 0.0
  let mut l12_a = 0.0
  let mut l23_a = 0.0
  let mut l01_2a = 0.0
  let mut l12_2a = 0.0
  let mut l23_2a = 0.0
  let mut count = 0
  let add = (x : Double, y : Double) => {
    if count > 0 {
      let x23 = x2 - x
      let y23 = y2 - y
      // `Math.pow(d, 0.5)`, which is the square root in the reference
      // browser (200000 samples).
      l23_2a = (x23 * x23 + y23 * y23).sqrt()
      l23_a = l23_2a.sqrt()
    }
    match count {
      0 => {
        count = 1
        path.move_to(x, y)
      }
      1 => count = 2
      _ => {
        count = 3
        let mut cx1 = x1
        let mut cy1 = y1
        let mut cx2 = x2
        let mut cy2 = y2
        if l01_a > epsilon {
          let a = 2.0 * l01_2a + 3.0 * l01_a * l12_a + l12_2a
          let n = 3.0 * l01_a * (l01_a + l12_a)
          cx1 = (cx1 * a - x0 * l12_2a + x2 * l01_2a) / n
          cy1 = (cy1 * a - y0 * l12_2a + y2 * l01_2a) / n
        }
        if l23_a > epsilon {
          let b = 2.0 * l23_2a + 3.0 * l23_a * l12_a + l12_2a
          let m = 3.0 * l23_a * (l23_a + l12_a)
          cx2 = (cx2 * b + x1 * l23_2a - x * l12_2a) / m
          cy2 = (cy2 * b + y1 * l23_2a - y * l12_2a) / m
        }
        path.bezier_curve_to(cx1, cy1, cx2, cy2, x2, y2)
      }
    }
    l01_a = l12_a
    l12_a = l23_a
    l01_2a = l12_2a
    l12_2a = l23_2a
    x0 = x1
    x1 = x2
    x2 = x
    y0 = y1
    y1 = y2
    y2 = y
  }
  for point in points {
    add(point.0, point.1)
  }
  match count {
    2 => path.line_to(x2, y2)
    3 => add(x2, y2)
    _ => ()
  }
}

///|
/// A cubic spline that keeps the order of its points along x, or along y
/// when `reflect`ed: d3's `MonotoneX` and `MonotoneY`.
fn monotone(
  path : Path,
  points : Array[(Double, Double)],
  reflect : Bool,
) -> Unit {
  let nan = @double.not_a_number
  let mut x0 = nan
  let mut x1 = nan
  let mut y0 = nan
  let mut y1 = nan
  let mut t0 = nan
  let mut count = 0
  let sign = (x : Double) => if x < 0.0 { -1.0 } else { 1.0 }
  // `a || b` for numbers.
  let either = (a : Double, b : Double) => {
    if a != 0.0 && !a.is_nan() {
      a
    } else {
      b
    }
  }
  // The slope at the middle one of three points (Steffen).
  let slope3 = (x2 : Double, y2 : Double) => {
    let h0 = x1 - x0
    let h1 = x2 - x1
    let s0 = (y1 - y0) / either(h0, if h1 < 0.0 { -0.0 } else { 0.0 })
    let s1 = (y2 - y1) / either(h1, if h0 < 0.0 { -0.0 } else { 0.0 })
    let p = (s0 * h1 + s1 * h0) / (h0 + h1)
    let smallest = js_min3(s0.abs(), s1.abs(), 0.5 * p.abs())
    either((sign(s0) + sign(s1)) * smallest, 0.0)
  }
  // The slope at an end, from the slope `t` at the point next to it.
  let slope2 = (t : Double) => {
    let h = x1 - x0
    if h != 0.0 && !h.is_nan() {
      (3.0 * (y1 - y0) / h - t) / 2.0
    } else {
      t
    }
  }
  let segment = (t0 : Double, t1 : Double) => {
    let dx = (x1 - x0) / 3.0
    let (ax, ay) = (x0 + dx, y0 + dx * t0)
    let (bx, by) = (x1 - dx, y1 - dx * t1)
    if reflect {
      path.bezier_curve_to(ay, ax, by, bx, y1, x1)
    } else {
      path.bezier_curve_to(ax, ay, bx, by, x1, y1)
    }
  }
  for point in points {
    let (x, y) = if reflect { (point.1, point.0) } else { point }
    // A point on top of the one before it is skipped.
    if x == x1 && y == y1 {
      continue
    }
    let mut t1 = nan
    match count {
      0 => {
        count = 1
        if reflect {
          path.move_to(y, x)
        } else {
          path.move_to(x, y)
        }
      }
      1 => count = 2
      2 => {
        count = 3
        t1 = slope3(x, y)
        segment(slope2(t1), t1)
      }
      _ => {
        t1 = slope3(x, y)
        segment(t0, t1)
      }
    }
    x0 = x1
    x1 = x
    y0 = y1
    y1 = y
    t0 = t1
  }
  match count {
    2 => if reflect { path.line_to(y1, x1) } else { path.line_to(x1, y1) }
    3 => segment(t0, slope2(t0))
    _ => ()
  }
}

///|
/// `Math.min` of three numbers, which is NaN when any of them is.
fn js_min3(a : Double, b : Double, c : Double) -> Double {
  if a.is_nan() || b.is_nan() || c.is_nan() {
    @double.not_a_number
  } else {
    a.min(b).min(c)
  }
}

///|
/// The control points of the natural cubic spline through `x`: d3's
/// `controlPoints`.
fn control_points(x : Array[Double]) -> (Array[Double], Array[Double]) {
  let n = x.length() - 1
  let a = Array::make(n, 0.0)
  let b = Array::make(n, 0.0)
  let r = Array::make(n, 0.0)
  a[0] = 0.0
  b[0] = 2.0
  r[0] = x[0] + 2.0 * x[1]
  for i in 1..<(n - 1) {
    a[i] = 1.0
    b[i] = 4.0
    r[i] = 4.0 * x[i] + 2.0 * x[i + 1]
  }
  a[n - 1] = 2.0
  b[n - 1] = 7.0
  r[n - 1] = 8.0 * x[n - 1] + x[n]
  for i in 1..<n {
    let m = a[i] / b[i - 1]
    b[i] = b[i] - m
    r[i] = r[i] - m * r[i - 1]
  }
  a[n - 1] = r[n - 1] / b[n - 1]
  for i = n - 2; i >= 0; i = i - 1 {
    a[i] = (r[i] - a[i + 1]) / b[i]
  }
  b[n - 1] = (x[n] + a[n - 1]) / 2.0
  for i in 0..<(n - 1) {
    b[i] = 2.0 * x[i + 1] - a[i + 1]
  }
  (a, b)
}

///|
/// A natural cubic spline: d3's `Natural`.
fn natural(path : Path, points : Array[(Double, Double)]) -> Unit {
  let n = points.length()
  path.move_to(points[0].0, points[0].1)
  if n == 2 {
    path.line_to(points[1].0, points[1].1)
  } else if n > 2 {
    let (ax, bx) = control_points(points.map(point => point.0))
    let (ay, by) = control_points(points.map(point => point.1))
    for i in 1..<n {
      path.bezier_curve_to(
        ax[i - 1],
        ay[i - 1],
        bx[i - 1],
        by[i - 1],
        points[i].0,
        points[i].1,
      )
    }
  }
}
