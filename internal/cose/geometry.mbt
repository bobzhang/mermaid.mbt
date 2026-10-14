// layout-base's `IGeometry`: where rectangles meet the line between their
// centres, and how far overlapping ones have to move apart.

///|
/// `IGeometry.getIntersection2`: the points where the line between the
/// centres of `a` and `b` leaves the two rectangles, as
/// `(ax, ay, bx, by)`. `None` when the rectangles intersect; upstream
/// then answers with the centres, which no caller reads.
fn clip_points(a : Rect, b : Rect) -> (Double, Double, Double, Double)? {
  let p1x = a.center_x()
  let p1y = a.center_y()
  let p2x = b.center_x()
  let p2y = b.center_y()
  if a.intersects(b) {
    return None
  }
  let top_left_ax = a.x
  let top_left_ay = a.y
  let top_right_ax = a.right()
  let bottom_left_ax = a.x
  let bottom_left_ay = a.bottom()
  let bottom_right_ax = a.right()
  let half_width_a = a.width / 2.0
  let half_height_a = a.height / 2.0
  let top_left_bx = b.x
  let top_left_by = b.y
  let top_right_bx = b.right()
  let bottom_left_bx = b.x
  let bottom_left_by = b.bottom()
  let bottom_right_bx = b.right()
  let half_width_b = b.width / 2.0
  let half_height_b = b.height / 2.0
  // Rectangles that do not intersect have different centres, so each of
  // the two special cases below decides.
  if p1x == p2x {
    return if p1y > p2y {
      Some((p1x, top_left_ay, p2x, bottom_left_by))
    } else {
      Some((p1x, bottom_left_ay, p2x, top_left_by))
    }
  }
  if p1y == p2y {
    return if p1x > p2x {
      Some((top_left_ax, p1y, top_right_bx, p2y))
    } else {
      Some((top_right_ax, p1y, top_left_bx, p2y))
    }
  }
  let slope_a = a.height / a.width
  let slope_b = b.height / b.width
  let slope_prime = (p2y - p1y) / (p2x - p1x)
  let mut ax = 0.0
  let mut ay = 0.0
  let mut bx = 0.0
  let mut by = 0.0
  let mut clip_point_a_found = false
  let mut clip_point_b_found = false
  // The line through a corner.
  if -slope_a == slope_prime {
    if p1x > p2x {
      ax = bottom_left_ax
      ay = bottom_left_ay
    } else {
      ax = top_right_ax
      ay = top_left_ay
    }
    clip_point_a_found = true
  } else if slope_a == slope_prime {
    if p1x > p2x {
      ax = top_left_ax
      ay = top_left_ay
    } else {
      ax = bottom_right_ax
      ay = bottom_left_ay
    }
    clip_point_a_found = true
  }
  if -slope_b == slope_prime {
    if p2x > p1x {
      bx = bottom_left_bx
      by = bottom_left_by
    } else {
      bx = top_right_bx
      by = top_left_by
    }
    clip_point_b_found = true
  } else if slope_b == slope_prime {
    if p2x > p1x {
      bx = top_left_bx
      by = top_left_by
    } else {
      bx = bottom_right_bx
      by = bottom_left_by
    }
    clip_point_b_found = true
  }
  if clip_point_a_found && clip_point_b_found {
    return Some((ax, ay, bx, by))
  }
  // The side the line leaves through: 1 top, 2 right, 3 bottom, 4 left.
  let (cardinal_direction_a, cardinal_direction_b) = if p1x > p2x {
    if p1y > p2y {
      (
        cardinal_direction(slope_a, slope_prime, 4),
        cardinal_direction(slope_b, slope_prime, 2),
      )
    } else {
      (
        cardinal_direction(-slope_a, slope_prime, 3),
        cardinal_direction(-slope_b, slope_prime, 1),
      )
    }
  } else if p1y > p2y {
    (
      cardinal_direction(-slope_a, slope_prime, 1),
      cardinal_direction(-slope_b, slope_prime, 3),
    )
  } else {
    (
      cardinal_direction(slope_a, slope_prime, 2),
      cardinal_direction(slope_b, slope_prime, 4),
    )
  }
  if !clip_point_a_found {
    match cardinal_direction_a {
      1 => {
        ay = top_left_ay
        ax = p1x + -half_height_a / slope_prime
      }
      2 => {
        ax = bottom_right_ax
        ay = p1y + half_width_a * slope_prime
      }
      3 => {
        ay = bottom_left_ay
        ax = p1x + half_height_a / slope_prime
      }
      _ => {
        ax = bottom_left_ax
        ay = p1y + -half_width_a * slope_prime
      }
    }
  }
  if !clip_point_b_found {
    match cardinal_direction_b {
      1 => {
        by = top_left_by
        bx = p2x + -half_height_b / slope_prime
      }
      2 => {
        bx = bottom_right_bx
        by = p2y + half_width_b * slope_prime
      }
      3 => {
        by = bottom_left_by
        bx = p2x + half_height_b / slope_prime
      }
      _ => {
        bx = bottom_left_bx
        by = p2y + -half_width_b * slope_prime
      }
    }
  }
  Some((ax, ay, bx, by))
}

///|
/// `IGeometry.getCardinalDirection`.
fn cardinal_direction(
  slope : Double,
  slope_prime : Double,
  line : Int32,
) -> Int32 {
  if slope > slope_prime {
    line
  } else {
    1 + line % 4
  }
}

///|
/// `IGeometry.calcSeparationAmount`: how far the intersecting rectangles
/// `a` and `b` are to be pushed apart along each axis, `separation_buffer`
/// included; the signs are those of the push on `b`.
fn separation_amount(
  a : Rect,
  b : Rect,
  separation_buffer : Double,
) -> (Double, Double) {
  // `decideDirectionsForOverlappingNodes`
  let direction_x = if a.center_x() < b.center_x() { -1.0 } else { 1.0 }
  let direction_y = if a.center_y() < b.center_y() { -1.0 } else { 1.0 }
  let mut overlap_x = js_min(a.right(), b.right()) - js_max(a.x, b.x)
  let mut overlap_y = js_min(a.bottom(), b.bottom()) - js_max(a.y, b.y)
  // One rectangle spans the other: add what gets the nearer sides clear.
  if a.x <= b.x && a.right() >= b.right() {
    overlap_x += js_min(b.x - a.x, a.right() - b.right())
  } else if b.x <= a.x && b.right() >= a.right() {
    overlap_x += js_min(a.x - b.x, b.right() - a.right())
  }
  if a.y <= b.y && a.bottom() >= b.bottom() {
    overlap_y += js_min(b.y - a.y, a.bottom() - b.bottom())
  } else if b.y <= a.y && b.bottom() >= a.bottom() {
    overlap_y += js_min(a.y - b.y, b.bottom() - a.bottom())
  }
  let mut slope = ((b.center_y() - a.center_y()) / (b.center_x() - a.center_x())).abs()
  if b.center_y() == a.center_y() && b.center_x() == a.center_x() {
    slope = 1.0
  }
  let mut move_by_y = slope * overlap_x
  let mut move_by_x = overlap_y / slope
  if overlap_x < move_by_x {
    move_by_x = overlap_x
  } else {
    move_by_y = overlap_y
  }
  (
    -1.0 * direction_x * (move_by_x / 2.0 + separation_buffer),
    -1.0 * direction_y * (move_by_y / 2.0 + separation_buffer),
  )
}

///|
/// `Math.min` of two numbers that are not NaN.
fn js_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else if b < a {
    b
  } else if a == 0.0 && a.reinterpret_as_uint64() != 0UL {
    // Of the two zeros the negative one is the smaller.
    a
  } else {
    b
  }
}

///|
/// `Math.max` of two numbers that are not NaN.
fn js_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else if b > a {
    b
  } else if a == 0.0 && a.reinterpret_as_uint64() == 0UL {
    a
  } else {
    b
  }
}
