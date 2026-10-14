// The hachure fill: rough.js's `HachureFiller` and the `hachure-fill`
// library it bundles. Parallel lines at an angle, a gap apart, clipped to
// the polygons of the shape, each drawn as a sketchy line.

///|
/// The stroke width as a number, as JavaScript's arithmetic reads the
/// text it is kept as.
fn stroke_width(o : Options) -> Double {
  @string.parse_double(o.stroke_width.trim().to_owned()) catch {
    _ => @double.not_a_number
  }
}

///|
/// `Math.round`: halves go up.
fn js_round(x : Double) -> Double {
  let floor = x.floor()
  if x - floor >= 0.5 {
    floor + 1.0
  } else {
    floor
  }
}

///|
/// Turn points about `center` by `degrees`, in place: `rotatePoints`.
fn rotate_points(points : Array[P], center : P, degrees : Double) -> Unit {
  guard !points.is_empty() else { return }
  let (cx, cy) = center
  let angle = 3.141592653589793 / 180.0 * degrees
  let cos = @jsmath.cos(angle)
  let sin = @jsmath.sin(angle)
  for i, point in points {
    let (x, y) = point
    points[i] = (
      (x - cx) * cos - (y - cy) * sin + cx,
      (x - cx) * sin + (y - cy) * cos + cy,
    )
  }
}

///|
/// An edge of a polygon as the scan line meets it.
priv struct Edge {
  ymin : Double
  ymax : Double
  mut x : Double
  islope : Double
}

///|
/// A stable insertion sort by `compare`, as `Array.prototype.sort` is
/// stable in V8 (the comparators here may answer `NaN`, which counts as
/// equal).
fn[T] stable_sort(items : Array[T], compare : (T, T) -> Double) -> Unit {
  for i in 1..<items.length() {
    let item = items[i]
    let mut j = i
    while j > 0 && compare(items[j - 1], item) > 0.0 {
      items[j] = items[j - 1]
      j -= 1
    }
    items[j] = item
  }
}

///|
/// The sign of a difference as the comparators of `hachure-fill` compute
/// it: `(a - b) / Math.abs(a - b)`.
fn signum(difference : Double) -> Double {
  difference / difference.abs()
}

///|
/// Horizontal lines `gap` apart across the polygons, scanning down one
/// unit at a time: `straightHachureLines`. With a `step` other than one,
/// every scan line is drawn.
fn straight_hachure_lines(
  polygons : Array[Array[P]],
  gap : Double,
  step : Double,
) -> Array[(P, P)] {
  let vertex_arrays = []
  for polygon in polygons {
    let vertices = polygon.copy()
    guard vertices is [first, ..] else { continue }
    if vertices.last() is Some(last) && last != first {
      vertices.push(first)
    }
    if vertices.length() > 2 {
      vertex_arrays.push(vertices)
    }
  }
  let lines = []
  let gap = gap.max(0.1)
  let edges : Array[Edge] = []
  for vertices in vertex_arrays {
    for i in 0..<(vertices.length() - 1) {
      let (x1, y1) = vertices[i]
      let (x2, y2) = vertices[i + 1]
      if y1 != y2 {
        let ymin = y1.min(y2)
        edges.push({
          ymin,
          ymax: y1.max(y2),
          x: if ymin == y1 {
            x1
          } else {
            x2
          },
          islope: (x2 - x1) / (y2 - y1),
        })
      }
    }
  }
  stable_sort(edges, (a, b) => {
    if a.ymin < b.ymin {
      -1.0
    } else if a.ymin > b.ymin {
      1.0
    } else if a.x < b.x {
      -1.0
    } else if a.x > b.x {
      1.0
    } else if a.ymax == b.ymax {
      0.0
    } else {
      signum(a.ymax - b.ymax)
    }
  })
  guard !edges.is_empty() else { return lines }
  let mut active : Array[Edge] = []
  let mut y = edges[0].ymin
  let mut iteration = 0
  let mut pending = edges[:]
  while !active.is_empty() || !pending.is_empty() {
    if !pending.is_empty() {
      let mut last = -1
      for i, edge in pending {
        if edge.ymin > y {
          break
        }
        last = i
      }
      for edge in pending[:last + 1] {
        active.push(edge)
      }
      pending = pending[last + 1:]
    }
    active = active.filter(edge => !(edge.ymax <= y))
    stable_sort(active, (a, b) => {
      if a.x == b.x {
        0.0
      } else {
        signum(a.x - b.x)
      }
    })
    if (step != 1.0 || iteration.to_double() % gap == 0.0) &&
      active.length() > 1 {
      let mut i = 0
      while i + 1 < active.length() {
        lines.push(((js_round(active[i].x), y), (js_round(active[i + 1].x), y)))
        i += 2
      }
    }
    y += step
    for edge in active {
      edge.x = edge.x + step * edge.islope
    }
    iteration += 1
  }
  lines
}

///|
/// The hachure lines across the polygons at an angle: `hachureLines`.
/// The polygons are turned so that the lines run level, and the lines
/// turned back.
fn hachure_lines(
  polygons : Array[Array[P]],
  gap : Double,
  angle : Double,
  step : Double,
) -> Array[(P, P)] {
  let center = (0.0, 0.0)
  if angle != 0.0 {
    for polygon in polygons {
      rotate_points(polygon, center, angle)
    }
  }
  let lines = straight_hachure_lines(polygons, gap.max(0.1), step)
  if angle != 0.0 {
    for polygon in polygons {
      rotate_points(polygon, center, -angle)
    }
    let points = []
    for line in lines {
      points.push(line.0)
      points.push(line.1)
    }
    rotate_points(points, center, -angle)
    for i in 0..<lines.length() {
      lines[i] = (points[2 * i], points[2 * i + 1])
    }
  }
  lines
}

///|
/// The sketched lines of a hachure fill of the polygons: the
/// `HachureFiller` of rough.js with `polygonHachureLines`.
fn hachure_fill(polygons : Array[Array[P]], o : Options) -> Array[Op] {
  let angle = o.hachure_angle + 90.0
  let mut gap = o.hachure_gap
  if gap < 0.0 {
    gap = 4.0 * stroke_width(o)
  }
  gap = js_round(gap.max(0.1))
  let mut step = 1.0
  if o.roughness >= 1.0 && o.random() > 0.7 {
    step = gap
  }
  // `skipOffset || 1`
  if step == 0.0 || step.is_nan() {
    step = 1.0
  }
  let ops = []
  for line in hachure_lines(polygons, gap, angle, step) {
    let ((x1, y1), (x2, y2)) = line
    ops.append(double_line(x1, y1, x2, y2, o, fill=true))
  }
  ops
}
