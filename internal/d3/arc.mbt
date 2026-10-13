///|
/// One slice computed by `pie`: the datum's index, its value and its
/// angular extent, with angle zero at twelve o'clock.
pub(all) struct PieArc {
  index : Int32
  value : Double
  start_angle : Double
  end_angle : Double
} derive(Debug)

///|
/// d3's `pie()` with no sorting and no padding: consecutive slices around
/// the full circle, each proportional to its value.
pub fn pie(values : Array[Double]) -> Array[PieArc] {
  let mut sum = 0.0
  for value in values {
    if value > 0.0 {
      sum += value
    }
  }
  let k = if sum != 0.0 { TAU / sum } else { 0.0 }
  let arcs = []
  let mut a0 = 0.0
  for index, value in values {
    let a1 = a0 + (if value > 0.0 { value * k } else { 0.0 })
    arcs.push({ index, value, start_angle: a0, end_angle: a1, })
    a0 = a1
  }
  arcs
}

///|
/// d3's `arc()` generator without padding or rounded corners: the path of
/// a circular or annular sector.
pub fn arc_path(
  inner_radius~ : Double,
  outer_radius~ : Double,
  start_angle~ : Double,
  end_angle~ : Double,
) -> String {
  let path = Path::new(digits=3)
  let (r0, r1) = if outer_radius < inner_radius {
    (outer_radius, inner_radius)
  } else {
    (inner_radius, outer_radius)
  }
  let a0 = start_angle - PI / 2.0
  let a1 = end_angle - PI / 2.0
  let da = (a1 - a0).abs()
  let cw = a1 > a0
  if !(r1 > EPSILON) {
    path.move_to(0.0, 0.0)
  } else if da > TAU - EPSILON {
    path.move_to(r1 * @jsmath.cos(a0), r1 * @jsmath.sin(a0))
    path.arc(0.0, 0.0, r1, a0, a1, counterclockwise=!cw)
    if r0 > EPSILON {
      path.move_to(r0 * @jsmath.cos(a1), r0 * @jsmath.sin(a1))
      path.arc(0.0, 0.0, r0, a1, a0, counterclockwise=cw)
    }
  } else {
    let x01 = r1 * @jsmath.cos(a0)
    let y01 = r1 * @jsmath.sin(a0)
    let x10 = r0 * @jsmath.cos(a1)
    let y10 = r0 * @jsmath.sin(a1)
    if !(da > EPSILON) {
      path.move_to(x01, y01)
    } else {
      path.move_to(x01, y01)
      path.arc(0.0, 0.0, r1, a0, a1, counterclockwise=!cw)
    }
    if !(r0 > EPSILON) || !(da > EPSILON) {
      path.line_to(x10, y10)
    } else {
      path.arc(0.0, 0.0, r0, a1, a0, counterclockwise=cw)
    }
  }
  path.close()
  path.to_string()
}

///|
/// d3's `arc.centroid`: the midpoint of the sector, halfway between the
/// radii and the angles.
pub fn arc_centroid(
  inner_radius~ : Double,
  outer_radius~ : Double,
  start_angle~ : Double,
  end_angle~ : Double,
) -> (Double, Double) {
  let r = (inner_radius + outer_radius) / 2.0
  let a = (start_angle + end_angle) / 2.0 - PI / 2.0
  (@jsmath.cos(a) * r, @jsmath.sin(a) * r)
}
