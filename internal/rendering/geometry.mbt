// Clipping an edge against the nodes it joins: mermaid's ELK `geometry.ts`.

///|
/// A box given by its centre and size.
priv struct Bounds {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
fn on_border(bounds : Bounds, p : Point, tol~ : Double = 0.5) -> Bool {
  let half_w = bounds.width / 2.0
  let half_h = bounds.height / 2.0
  let left = bounds.x - half_w
  let right = bounds.x + half_w
  let top = bounds.y - half_h
  let bottom = bounds.y + half_h
  let within_y = p.y >= top - tol && p.y <= bottom + tol
  let within_x = p.x >= left - tol && p.x <= right + tol
  ((p.x - left).abs() <= tol && within_y) ||
  ((p.x - right).abs() <= tol && within_y) ||
  ((p.y - top).abs() <= tol && within_x) ||
  ((p.y - bottom).abs() <= tol && within_x)
}

///|
/// Where the segment from `inside` to `outside` crosses the box.
fn box_intersection(node : Bounds, outside : Point, inside : Point) -> Point {
  let x = node.x
  let y = node.y
  let w = node.width / 2.0
  let h = node.height / 2.0
  let q_len = (outside.y - inside.y).abs()
  let r_len = (outside.x - inside.x).abs()
  if (y - outside.y).abs() * w > (x - outside.x).abs() * h {
    let q = if inside.y < outside.y {
      outside.y - h - y
    } else {
      y - h - outside.y
    }
    let r = r_len * q / q_len
    let rx = if inside.x < outside.x {
      inside.x + r
    } else {
      inside.x - r_len + r
    }
    let ry = if inside.y < outside.y {
      inside.y + q_len - q
    } else {
      inside.y - q_len + q
    }
    {
      x: if r_len == 0.0 {
        outside.x
      } else {
        rx
      },
      y: if q_len == 0.0 {
        outside.y
      } else {
        ry
      },
    }
  } else {
    let r = if inside.x < outside.x {
      outside.x - w - x
    } else {
      x - w - outside.x
    }
    let q = q_len * r / r_len
    let rx = if inside.x < outside.x {
      inside.x + r_len - r
    } else {
      inside.x - r_len + r
    }
    let ry = if inside.y < outside.y { inside.y + q } else { inside.y - q }
    {
      x: if r_len == 0.0 {
        outside.x
      } else {
        rx
      },
      y: if q_len == 0.0 {
        outside.y
      } else {
        ry
      },
    }
  }
}

///|
fn outside_node(node : Bounds, point : Point) -> Bool {
  (point.x - node.x).abs() >= node.width / 2.0 ||
  (point.y - node.y).abs() >= node.height / 2.0
}

///|
/// Push a point that sits on the border a little further out.
fn ensure_truly_outside(bounds : Bounds, p : Point) -> Point {
  let dx = (p.x - bounds.x).abs()
  let dy = (p.y - bounds.y).abs()
  let w = bounds.width / 2.0
  let h = bounds.height / 2.0
  if (dx - w).abs() < 1.0 || (dy - h).abs() < 1.0 {
    let dir_x = p.x - bounds.x
    let dir_y = p.y - bounds.y
    let len = (dir_x * dir_x + dir_y * dir_y).sqrt()
    if len > 0.0 {
      return {
        x: bounds.x + dir_x / len * (len + 10.0),
        y: bounds.y + dir_y / len * (len + 10.0),
      }
    }
  }
  p
}

///|
fn make_inside_point(bounds : Bounds, outside : Point, center : Point) -> Point {
  let is_vertical = (outside.x - bounds.x).abs() < 1.0
  let is_horizontal = (outside.y - bounds.y).abs() < 1.0
  {
    x: if is_vertical {
      outside.x
    } else if outside.x < bounds.x {
      bounds.x - bounds.width / 4.0
    } else {
      bounds.x + bounds.width / 4.0
    },
    y: if is_horizontal {
      outside.y
    } else {
      center.y
    },
  }
}

///|
fn try_node_intersect(
  intersect : ((Point) -> Point)?,
  bounds : Bounds,
  outside : Point,
) -> Point? {
  guard intersect is Some(intersect) else { return None }
  let res = intersect(outside)
  let wrong_side = (outside.x < bounds.x && res.x > bounds.x) ||
    (outside.x > bounds.x && res.x < bounds.x)
  if wrong_side {
    return None
  }
  if @jsmath.hypot(outside.x - res.x, outside.y - res.y) <= 1.0 {
    return None
  }
  Some(res)
}

///|
/// Whether `probe` lies inside the shape's outline, on the ray from its
/// centre.
fn inside_outline(
  intersect : (Point) -> Point,
  centre : Point,
  probe : Point,
) -> Bool {
  let crossing = intersect(probe)
  let probe_dist = @jsmath.hypot(probe.x - centre.x, probe.y - centre.y)
  let outline_dist = @jsmath.hypot(crossing.x - centre.x, crossing.y - centre.y)
  probe_dist <= outline_dist + 1.0e-9
}

///|
/// Where an axis-aligned edge leaving `port` towards `next` meets the
/// shape's outline, found by bisection along that axis.
fn outline_attach_point(
  intersect : ((Point) -> Point)?,
  bounds : Bounds,
  port : Point,
  next : Point,
) -> Point? {
  guard intersect is Some(intersect) else { return None }
  let dx = next.x - port.x
  let dy = next.y - port.y
  if dx == 0.0 && dy == 0.0 {
    return None
  }
  if dx.abs() > 1.0e-6 && dy.abs() > 1.0e-6 {
    return None
  }
  let centre = { x: bounds.x, y: bounds.y, }
  let horizontal = dx.abs() > dy.abs()
  let along = (t : Double) => {
    if horizontal {
      { x: t, y: port.y, }
    } else {
      { x: port.x, y: t, }
    }
  }
  let mut inner = if horizontal { centre.x } else { centre.y }
  let mut outer = if horizontal { port.x } else { port.y }
  if !inside_outline(intersect, centre, along(inner)) {
    return None
  }
  if inside_outline(intersect, centre, along(outer)) {
    return Some(port)
  }
  for _ in 0..<20 {
    let mid = (inner + outer) / 2.0
    if inside_outline(intersect, centre, along(mid)) {
      inner = mid
    } else {
      outer = mid
    }
  }
  Some(along(inner))
}

///|
fn compute_node_intersection(
  intersect : ((Point) -> Point)?,
  bounds : Bounds,
  outside : Point,
  center : Point,
) -> Point {
  let outside = ensure_truly_outside(bounds, outside)
  match try_node_intersect(intersect, bounds, outside) {
    Some(point) => point
    None =>
      box_intersection(
        bounds,
        outside,
        make_inside_point(bounds, outside, center),
      )
  }
}

///|
/// Replace the first or last point; drop it instead when it already is
/// `value`.
fn replace_endpoint(
  points : Array[Point],
  at_start : Bool,
  value : Point,
) -> Unit {
  if points.is_empty() {
    return
  }
  let index = if at_start { 0 } else { points.length() - 1 }
  let current = points[index]
  if (current.x - value.x).abs() < 0.1 && (current.y - value.y).abs() < 0.1 {
    points.remove(index) |> ignore
  } else {
    points[index] = value
  }
}

///|
/// Where the line from a rectangle's centre to `point` leaves it: mermaid's
/// `intersect.rect`.
fn intersect_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  point : Point,
) -> Point {
  let dx = point.x - x
  let dy = point.y - y
  let mut w = width / 2.0
  let mut h = height / 2.0
  if dy.abs() * w > dx.abs() * h {
    if dy < 0.0 {
      h = -h
    }
    { x: x + (if dy == 0.0 { 0.0 } else { h * dx / dy }), y: y + h, }
  } else {
    if dx < 0.0 {
      w = -w
    }
    { x: x + w, y: y + (if dx == 0.0 { 0.0 } else { w * dy / dx }), }
  }
}

///|
/// Where two segments meet, if they do: mermaid's `intersectLine`.
fn intersect_line(p1 : Point, p2 : Point, q1 : Point, q2 : Point) -> Point? {
  let a1 = p2.y - p1.y
  let b1 = p1.x - p2.x
  let c1 = p2.x * p1.y - p1.x * p2.y
  let r3 = a1 * q1.x + b1 * q1.y + c1
  let r4 = a1 * q2.x + b1 * q2.y + c1
  if r3 != 0.0 && r4 != 0.0 && r3 * r4 > 0.0 {
    return None
  }
  let a2 = q2.y - q1.y
  let b2 = q1.x - q2.x
  let c2 = q2.x * q1.y - q1.x * q2.y
  let r1 = a2 * p1.x + b2 * p1.y + c2
  let r2 = a2 * p2.x + b2 * p2.y + c2
  if r1.abs() < 1.0e-6 && r2.abs() < 1.0e-6 && r1 * r2 > 0.0 {
    return None
  }
  let denom = a1 * b2 - a2 * b1
  if denom == 0.0 {
    return None
  }
  Some({ x: (b1 * c2 - b2 * c1) / denom, y: (a2 * c1 - a1 * c2) / denom, })
}

///|
/// Where the line from a node's centre to `point` crosses its polygonal
/// outline: mermaid's `intersect.polygon`. The polygon is given in its own
/// coordinates and placed so that its box is the node's.
fn intersect_polygon(node : Node, poly : Array[Point], point : Point) -> Point {
  let centre = { x: node.x, y: node.y, }
  let infinity = 0x7ff0000000000000L.reinterpret_as_double()
  let mut min_x = infinity
  let mut min_y = infinity
  for entry in poly {
    min_x = min_x.min(entry.x)
    min_y = min_y.min(entry.y)
  }
  let left = node.x - node.width.unwrap_or(0.0) / 2.0 - min_x
  let top = node.y - node.height.unwrap_or(0.0) / 2.0 - min_y
  let intersections = []
  for i, p1 in poly {
    let p2 = poly[if i < poly.length() - 1 { i + 1 } else { 0 }]
    let hit = intersect_line(
      centre,
      point,
      { x: left + p1.x, y: top + p1.y, },
      { x: left + p2.x, y: top + p2.y, },
    )
    if hit is Some(hit) {
      intersections.push(hit)
    }
  }
  if intersections.is_empty() {
    return centre
  }
  // The nearest to the point; the first of equals, as a stable sort keeps.
  let distance = (p : Point) => {
    let dx = p.x - point.x
    let dy = p.y - point.y
    (dx * dx + dy * dy).sqrt()
  }
  let mut best = intersections[0]
  let mut best_distance = distance(best)
  for candidate in intersections {
    let d = distance(candidate)
    if d < best_distance {
      best = candidate
      best_distance = d
    }
  }
  best
}

///|
/// Where the line from a node's centre to `point` crosses an ellipse
/// around the centre: mermaid's `intersect.ellipse`.
fn intersect_ellipse(
  node : Node,
  rx : Double,
  ry : Double,
  point : Point,
) -> Point {
  let cx = node.x
  let cy = node.y
  let px = cx - point.x
  let py = cy - point.y
  let det = (rx * rx * py * py + ry * ry * px * px).sqrt()
  let mut dx = (rx * ry * px / det).abs()
  if point.x < cx {
    dx = -dx
  }
  let mut dy = (rx * ry * py / det).abs()
  if point.y < cy {
    dy = -dy
  }
  { x: cx + dx, y: cy + dy, }
}
