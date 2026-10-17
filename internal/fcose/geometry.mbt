// layout-base 2.0.1's `IGeometry` and `IMath`, the parts the spring
// embedder uses.

///|
/// `IMath.sign`.
fn sign(value : Double) -> Double {
  if value > 0.0 {
    1.0
  } else if value < 0.0 {
    -1.0
  } else {
    0.0
  }
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
/// `IGeometry.getIntersection2`: where the line between the centres of two
/// rectangles leaves each of them, as `[ax, ay, bx, by]`, and whether the
/// rectangles intersect (then the centres).
fn intersection(a : Rect, b : Rect, result : FixedArray[Double]) -> Bool {
  let p1x = a.center_x()
  let p1y = a.center_y()
  let p2x = b.center_x()
  let p2y = b.center_y()
  if a.intersects(b) {
    result[0] = p1x
    result[1] = p1y
    result[2] = p2x
    result[3] = p2y
    return true
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
  let mut clip_a_found = false
  let mut clip_b_found = false
  if p1x == p2x {
    if p1y > p2y {
      result[0] = p1x
      result[1] = top_left_ay
      result[2] = p2x
      result[3] = bottom_left_by
      return false
    } else if p1y < p2y {
      result[0] = p1x
      result[1] = bottom_left_ay
      result[2] = p2x
      result[3] = top_left_by
      return false
    }
  } else if p1y == p2y {
    if p1x > p2x {
      result[0] = top_left_ax
      result[1] = p1y
      result[2] = top_right_bx
      result[3] = p2y
      return false
    } else if p1x < p2x {
      result[0] = top_right_ax
      result[1] = p1y
      result[2] = top_left_bx
      result[3] = p2y
      return false
    }
  } else {
    let slope_a = a.height / a.width
    let slope_b = b.height / b.width
    let slope_prime = (p2y - p1y) / (p2x - p1x)
    if -slope_a == slope_prime {
      if p1x > p2x {
        result[0] = bottom_left_ax
        result[1] = bottom_left_ay
        clip_a_found = true
      } else {
        result[0] = top_right_ax
        result[1] = top_left_ay
        clip_a_found = true
      }
    } else if slope_a == slope_prime {
      if p1x > p2x {
        result[0] = top_left_ax
        result[1] = top_left_ay
        clip_a_found = true
      } else {
        result[0] = bottom_right_ax
        result[1] = bottom_left_ay
        clip_a_found = true
      }
    }
    if -slope_b == slope_prime {
      if p2x > p1x {
        result[2] = bottom_left_bx
        result[3] = bottom_left_by
        clip_b_found = true
      } else {
        result[2] = top_right_bx
        result[3] = top_left_by
        clip_b_found = true
      }
    } else if slope_b == slope_prime {
      if p2x > p1x {
        result[2] = top_left_bx
        result[3] = top_left_by
        clip_b_found = true
      } else {
        result[2] = bottom_right_bx
        result[3] = bottom_left_by
        clip_b_found = true
      }
    }
    if clip_a_found && clip_b_found {
      return false
    }
    let (direction_a, direction_b) = if p1x > p2x {
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
    if !clip_a_found {
      match direction_a {
        1 => {
          result[0] = p1x + -half_height_a / slope_prime
          result[1] = top_left_ay
        }
        2 => {
          result[0] = bottom_right_ax
          result[1] = p1y + half_width_a * slope_prime
        }
        3 => {
          result[0] = p1x + half_height_a / slope_prime
          result[1] = bottom_left_ay
        }
        4 => {
          result[0] = bottom_left_ax
          result[1] = p1y + -half_width_a * slope_prime
        }
        _ => ()
      }
    }
    if !clip_b_found {
      match direction_b {
        1 => {
          result[2] = p2x + -half_height_b / slope_prime
          result[3] = top_left_by
        }
        2 => {
          result[2] = bottom_right_bx
          result[3] = p2y + half_width_b * slope_prime
        }
        3 => {
          result[2] = p2x + half_height_b / slope_prime
          result[3] = bottom_left_by
        }
        4 => {
          result[2] = bottom_left_bx
          result[3] = p2y + -half_width_b * slope_prime
        }
        _ => ()
      }
    }
  }
  false
}

///|
/// `IGeometry.calcSeparationAmount`: how far two overlapping rectangles
/// move apart, as `[x, y]` for `a`.
fn separation_amount(
  a : Rect,
  b : Rect,
  overlap : FixedArray[Double],
  separation_buffer : Double,
) -> Unit {
  // `decideDirectionsForOverlappingNodes`
  let direction_x = if a.center_x() < b.center_x() { -1.0 } else { 1.0 }
  let direction_y = if a.center_y() < b.center_y() { -1.0 } else { 1.0 }
  overlap[0] = js_min(a.right(), b.right()) - js_max(a.x, b.x)
  overlap[1] = js_min(a.bottom(), b.bottom()) - js_max(a.y, b.y)
  if a.x <= b.x && a.right() >= b.right() {
    overlap[0] += js_min(b.x - a.x, a.right() - b.right())
  } else if b.x <= a.x && b.right() >= a.right() {
    overlap[0] += js_min(a.x - b.x, b.right() - a.right())
  }
  if a.y <= b.y && a.bottom() >= b.bottom() {
    overlap[1] += js_min(b.y - a.y, a.bottom() - b.bottom())
  } else if b.y <= a.y && b.bottom() >= a.bottom() {
    overlap[1] += js_min(a.y - b.y, b.bottom() - a.bottom())
  }
  let mut slope = ((b.center_y() - a.center_y()) / (b.center_x() - a.center_x())).abs()
  if b.center_y() == a.center_y() && b.center_x() == a.center_x() {
    slope = 1.0
  }
  let mut move_by_y = slope * overlap[0]
  let mut move_by_x = overlap[1] / slope
  if overlap[0] < move_by_x {
    move_by_x = overlap[0]
  } else {
    move_by_y = overlap[1]
  }
  overlap[0] = -1.0 * direction_x * (move_by_x / 2.0 + separation_buffer)
  overlap[1] = -1.0 * direction_y * (move_by_y / 2.0 + separation_buffer)
}

///|
/// `Math.min` of two numbers.
fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a == 0.0 && 1.0 / a < 0.0 {
    // Of two zeros the negative one.
    a
  } else {
    b
  }
}

///|
/// `Math.max` of two numbers.
fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a == 0.0 && 1.0 / a > 0.0 {
    a
  } else {
    b
  }
}
