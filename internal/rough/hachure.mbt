// The sketchy fills of rough.js: lines drawn across a shape, a gap apart
// (`hachure`), or two such sets at right angles (`cross-hatch`). The
// lines come from the `hachure-fill` library's scan-line algorithm.
//
// Ported for ellipses, paths and rectangles (Venn circles and overlaps,
// Ishikawa heads); the other fill styles (`zigzag`, `dots`, `dashed`,
// `zigzag-line`) are not ported.

///|
/// `Math.round`: to the nearest integer, halves towards positive infinity.
fn js_round(value : Double) -> Double {
  let floor = value.floor()
  if value - floor >= 0.5 {
    floor + 1.0
  } else {
    floor
  }
}

///|
/// Sort in place, keeping items that compare equal in their order, as
/// JavaScript's `Array.prototype.sort` does.
fn[T] stable_sort(items : Array[T], compare : (T, T) -> Int32) -> Unit {
  for i in 1..<items.length() {
    let item = items[i]
    let mut j = i
    while j > 0 && compare(items[j - 1], item) > 0 {
      items[j] = items[j - 1]
      j -= 1
    }
    items[j] = item
  }
}

///|
/// `ellipseWithParams`: the outline of an ellipse, and the points it is
/// estimated by — those of its first stroke without the overlap at both
/// ends.
fn ellipse_with_estimate(
  x : Double,
  y : Double,
  o : Options,
  params : EllipseParams,
) -> (Array[Op], Array[(Double, Double)]) {
  let inner = o.offset(0.4, 1.0)
  let overlap = params.increment * o.offset(0.1, inner)
  let points = ellipse_points(
    params.increment,
    x,
    y,
    params.rx,
    params.ry,
    1.0,
    overlap,
    o,
  )
  // One point leads the core points in; two follow them on an exact
  // ellipse and three on a rough one.
  let trailing = if o.roughness == 0.0 { 2 } else { 3 }
  let estimated = points[1:points.length() - trailing].to_owned()
  let ops = curve_ops(points, o)
  if !o.disable_multi_stroke && o.roughness != 0.0 {
    ops.append(
      curve_ops(
        ellipse_points(
          params.increment,
          x,
          y,
          params.rx,
          params.ry,
          1.5,
          0.0,
          o,
        ),
        o,
      ),
    )
  }
  (ops, estimated)
}

///|
/// `rotatePoints(points, center, degrees)`: in place, as rough.js does —
/// the polygons are turned for the scan and turned back afterwards, and
/// keep what the two rotations do to their last bits.
fn rotate_points(
  points : Array[(Double, Double)],
  center : (Double, Double),
  degrees : Double,
) -> Unit {
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
/// An edge of a polygon for the scan: where it starts and ends, where it
/// crosses the current scan line, and how fast that moves.
priv struct Edge {
  ymin : Double
  ymax : Double
  mut x : Double
  islope : Double
}

///|
/// `straightHachureLines(polygons, gap, hachureStepOffset)`: horizontal
/// lines across the polygons, between the edges they cross in pairs.
fn straight_hachure_lines(
  polygons : Array[Array[(Double, Double)]],
  gap : Double,
  step : Double,
) -> Array[Array[(Double, Double)]] {
  let vertex_array = []
  for polygon in polygons {
    let vertices = polygon.copy()
    if vertices.length() > 0 && vertices[0] != vertices[vertices.length() - 1] {
      vertices.push(vertices[0])
    }
    if vertices.length() > 2 {
      vertex_array.push(vertices)
    }
  }
  let lines = []
  let gap = if gap > 0.1 { gap } else { 0.1 }
  let edges : Array[Edge] = []
  for vertices in vertex_array {
    for i in 0..<(vertices.length() - 1) {
      let p1 = vertices[i]
      let p2 = vertices[i + 1]
      if p1.1 != p2.1 {
        let ymin = if p1.1 < p2.1 { p1.1 } else { p2.1 }
        edges.push({
          ymin,
          ymax: if p1.1 > p2.1 {
            p1.1
          } else {
            p2.1
          },
          x: if ymin == p1.1 {
            p1.0
          } else {
            p2.0
          },
          islope: (p2.0 - p1.0) / (p2.1 - p1.1),
        })
      }
    }
  }
  stable_sort(edges, (e1, e2) => {
    if e1.ymin < e2.ymin {
      -1
    } else if e1.ymin > e2.ymin {
      1
    } else if e1.x < e2.x {
      -1
    } else if e1.x > e2.x {
      1
    } else if e1.ymax == e2.ymax {
      0
    } else if e1.ymax < e2.ymax {
      -1
    } else {
      1
    }
  })
  if edges.length() == 0 {
    return lines
  }
  let mut active : Array[Edge] = []
  let mut first = 0
  let mut y = edges[0].ymin
  let mut iteration = 0.0
  while active.length() > 0 || first < edges.length() {
    while first < edges.length() && !(edges[first].ymin > y) {
      active.push(edges[first])
      first += 1
    }
    active = active.filter(edge => !(edge.ymax <= y))
    stable_sort(active, (e1, e2) => {
      if e1.x == e2.x {
        0
      } else if e1.x < e2.x {
        -1
      } else {
        1
      }
    })
    // Every line when the scan steps by the gap; every `gap`th otherwise.
    if (step != 1.0 || iteration % gap == 0.0) && active.length() > 1 {
      let mut i = 0
      while i + 1 < active.length() {
        lines.push([(js_round(active[i].x), y), (js_round(active[i + 1].x), y)])
        i += 2
      }
    }
    y += step
    for edge in active {
      edge.x = edge.x + step * edge.islope
    }
    iteration += 1.0
  }
  lines
}

///|
/// `hachureLines(polygons, gap, angle, skipOffset)`: the lines of a
/// hachure at `angle` degrees: the polygons are turned, scanned with
/// horizontal lines and turned back, with the lines.
fn hachure_lines(
  polygons : Array[Array[(Double, Double)]],
  gap : Double,
  angle : Double,
  skip_offset : Double,
) -> Array[Array[(Double, Double)]] {
  let gap = if gap > 0.1 { gap } else { 0.1 }
  let center = (0.0, 0.0)
  let turned = angle != 0.0 && !angle.is_nan()
  if turned {
    for polygon in polygons {
      rotate_points(polygon, center, angle)
    }
  }
  let lines = straight_hachure_lines(polygons, gap, skip_offset)
  if turned {
    for polygon in polygons {
      rotate_points(polygon, center, -angle)
    }
    for line in lines {
      rotate_points(line, center, -angle)
    }
  }
  lines
}

///|
/// rough.js's `HachureFiller`: the lines of the hachure, each drawn as a
/// rough double line.
fn hachure_fill(
  polygons : Array[Array[(Double, Double)]],
  o : Options,
) -> Array[Op] {
  let angle = o.hachure_angle + 90.0
  let mut gap = o.hachure_gap
  if gap < 0.0 {
    gap = 4.0 * o.stroke_width_number()
  }
  gap = js_round(if gap > 0.1 { gap } else { 0.1 })
  // A rough enough fill sometimes scans gap by gap instead of line by
  // line.
  let mut skip_offset = 1.0
  if o.roughness >= 1.0 && o.random() > 0.7 {
    skip_offset = gap
  }
  if skip_offset == 0.0 {
    skip_offset = 1.0
  }
  let ops = []
  for line in hachure_lines(polygons, gap, angle, skip_offset) {
    // `doubleLineOps`: two strokes unless multi-stroke is off for fills.
    let (x1, y1) = line[0]
    let (x2, y2) = line[1]
    ops.append(line_ops(x1, y1, x2, y2, o, true, false))
    if !o.disable_multi_stroke_fill {
      ops.append(line_ops(x1, y1, x2, y2, o, true, true))
    }
  }
  ops
}

///|
/// `patternFillPolygons(polygons, o)`: the sketched fill of some
/// polygons, or nothing for the fill styles that are not ported.
fn pattern_fill_polygons(
  polygons : Array[Array[(Double, Double)]],
  o : Options,
) -> Array[Op]? {
  match o.fill_style {
    "zigzag" | "dots" | "dashed" | "zigzag-line" => None
    "cross-hatch" => {
      let ops = hachure_fill(polygons, o)
      ops.append(
        hachure_fill(polygons, { ..o, hachure_angle: o.hachure_angle + 90.0, }),
      )
      Some(ops)
    }
    // `hachure`, and any name rough.js does not know.
    _ => Some(hachure_fill(polygons, o))
  }
}
