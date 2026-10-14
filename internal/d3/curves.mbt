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
/// `d3.line().curve(d3.curveLinear)(points)`: a polyline. `None` for no
/// points, where d3 returns `null`.
pub fn line_linear(points : Array[(Double, Double)]) -> String? {
  guard points.length() > 0 else { return None }
  let path = Path::new(digits=3)
  for i, point in points {
    if i == 0 {
      path.move_to(point.0, point.1)
    } else {
      path.line_to(point.0, point.1)
    }
  }
  // A line of a single point is closed.
  if points.length() == 1 {
    path.close()
  }
  Some(path.to_string())
}

///|
/// `d3.line().curve(d3.curveBasis)(points)`: a cubic basis spline that
/// starts and ends at the first and last points. `None` for no points.
pub fn line_basis(points : Array[(Double, Double)]) -> String? {
  guard points.length() > 0 else { return None }
  let path = Path::new(digits=3)
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
    1 => path.close()
    2 => path.line_to(x1, y1)
    _ => {
      segment(x0, y0, x1, y1, x1, y1)
      path.line_to(x1, y1)
    }
  }
  Some(path.to_string())
}
