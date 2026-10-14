///|
/// d3-shape's `line()` with its defaults: straight segments through
/// `points`, coordinates rounded to three decimals. `None` when there is
/// nothing to draw, where d3 returns `null`.
pub fn line(points : Array[(Double, Double)]) -> String? {
  if points.is_empty() {
    return None
  }
  let path = Path::new(digits=3)
  for i, point in points {
    if i == 0 {
      path.move_to(point.0, point.1)
    } else {
      path.line_to(point.0, point.1)
    }
  }
  // The linear curve closes a line that is a single point.
  if points.length() == 1 {
    path.close()
  }
  Some(path.to_string())
}
