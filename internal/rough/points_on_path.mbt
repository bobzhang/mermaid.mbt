// The polygons a path covers: the `points-on-path` and `points-on-curve`
// libraries rough.js bundles.

///|
type P = (Double, Double)

///|
fn lerp(a : P, b : P, t : Double) -> P {
  (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t)
}

///|
fn distance_sq(a : P, b : P) -> Double {
  (a.0 - b.0) * (a.0 - b.0) + (a.1 - b.1) * (a.1 - b.1)
}

///|
/// How far a cubic is from a straight line.
fn flatness(points : Array[P], offset : Int32) -> Double {
  let p1 = points[offset]
  let p2 = points[offset + 1]
  let p3 = points[offset + 2]
  let p4 = points[offset + 3]
  let mut ux = 3.0 * p2.0 - 2.0 * p1.0 - p4.0
  ux = ux * ux
  let mut uy = 3.0 * p2.1 - 2.0 * p1.1 - p4.1
  uy = uy * uy
  let mut vx = 3.0 * p3.0 - 2.0 * p4.0 - p1.0
  vx = vx * vx
  let mut vy = 3.0 * p3.1 - 2.0 * p4.1 - p1.1
  vy = vy * vy
  if ux < vx {
    ux = vx
  }
  if uy < vy {
    uy = vy
  }
  ux + uy
}

///|
/// Points along one cubic, splitting it until each part is flat.
fn points_on_curve(
  points : Array[P],
  offset : Int32,
  tolerance : Double,
  out : Array[P],
) -> Unit {
  if flatness(points, offset) < tolerance {
    let p0 = points[offset]
    if out.last() is Some(last) {
      if distance_sq(last, p0).sqrt() > 1.0 {
        out.push(p0)
      }
    } else {
      out.push(p0)
    }
    out.push(points[offset + 3])
  } else {
    let p1 = points[offset]
    let p2 = points[offset + 1]
    let p3 = points[offset + 2]
    let p4 = points[offset + 3]
    let q1 = lerp(p1, p2, 0.5)
    let q2 = lerp(p2, p3, 0.5)
    let q3 = lerp(p3, p4, 0.5)
    let r1 = lerp(q1, q2, 0.5)
    let r2 = lerp(q2, q3, 0.5)
    let red = lerp(r1, r2, 0.5)
    points_on_curve([p1, q1, r1, red], 0, tolerance, out)
    points_on_curve([red, r2, q3, p4], 0, tolerance, out)
  }
}

///|
fn distance_to_segment_sq(p : P, v : P, w : P) -> Double {
  let l2 = distance_sq(v, w)
  if l2 == 0.0 {
    return distance_sq(p, v)
  }
  let t = ((p.0 - v.0) * (w.0 - v.0) + (p.1 - v.1) * (w.1 - v.1)) / l2
  let t = 0.0.max(t.min(1.0))
  distance_sq(p, lerp(v, w, t))
}

///|
/// Ramer-Douglas-Peucker simplification.
fn simplify(
  points : Array[P],
  start : Int32,
  end : Int32,
  epsilon : Double,
  out : Array[P],
) -> Unit {
  let s = points[start]
  let e = points[end - 1]
  let mut max_dist_sq = 0.0
  let mut max_index = 1
  for i in (start + 1)..<(end - 1) {
    let dist_sq = distance_to_segment_sq(points[i], s, e)
    if dist_sq > max_dist_sq {
      max_dist_sq = dist_sq
      max_index = i
    }
  }
  if max_dist_sq.sqrt() > epsilon {
    simplify(points, start, max_index + 1, epsilon, out)
    simplify(points, max_index, end, epsilon, out)
  } else {
    if out.is_empty() {
      out.push(s)
    }
    out.push(e)
  }
}

///|
/// The polygon of every subpath of path data: `pointsOnPath` with a
/// curve tolerance of 1.
fn points_on_path(d : String, distance : Double) -> Array[Array[P]] {
  let sets : Array[Array[P]] = []
  let mut current : Array[P] = []
  let mut start : P = (0.0, 0.0)
  let mut pending : Array[P] = []
  let append_pending_curve = () => {
    if pending.length() >= 4 {
      let count = (pending.length() - 1) / 3
      for i in 0..<count {
        points_on_curve(pending, 3 * i, 1.0, current)
      }
    }
    pending = []
  }
  let append_pending_points = () => {
    append_pending_curve()
    if !current.is_empty() {
      sets.push(current)
      current = []
    }
  }
  for segment in normalize(absolutize(parse_path(d))) {
    let data = segment.data
    match segment.key {
      'M' => {
        append_pending_points()
        start = (data[0], data[1])
        current.push(start)
      }
      'L' => {
        append_pending_curve()
        current.push((data[0], data[1]))
      }
      'C' => {
        if pending.is_empty() {
          pending.push(current.last().unwrap_or(start))
        }
        pending.push((data[0], data[1]))
        pending.push((data[2], data[3]))
        pending.push((data[4], data[5]))
      }
      _ => {
        append_pending_curve()
        current.push(start)
      }
    }
  }
  append_pending_points()
  if distance == 0.0 {
    return sets
  }
  let out = []
  for set in sets {
    let simplified = []
    simplify(set, 0, set.length(), distance, simplified)
    if !simplified.is_empty() {
      out.push(simplified)
    }
  }
  out
}
