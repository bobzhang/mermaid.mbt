// The hachure fill: parallel sketchy lines across a shape. rough.js's
// `HachureFiller` on top of the `hachure-fill` package, which finds the
// lines with a scan-line pass over the polygons rotated so that the
// hachures are horizontal.

///|
/// `Math.round`: halves go up.
fn js_round(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
/// `rotatePoints` about the origin, in place.
fn rotate_points(points : Array[P], degrees : Double) -> Unit {
  let angle = 3.141592653589793 / 180.0 * degrees
  let cos = @jsmath.cos(angle)
  let sin = @jsmath.sin(angle)
  for i, point in points {
    let (x, y) = point
    points[i] = (x * cos - y * sin, x * sin + y * cos)
  }
}

///|
/// An edge of a polygon as the scan line meets it.
priv struct Edge {
  ymin : Double
  ymax : Double
  /// Where the edge crosses the scan line.
  mut x : Double
  /// How far `x` moves per unit of y.
  islope : Double
}

///|
/// A stable sort, like JavaScript's: what compares equal keeps its order.
fn[T] stable_sort(items : Array[T], compare : (T, T) -> Double) -> Unit {
  for i in 1..<items.length() {
    let item = items[i]
    let mut j = i - 1
    while j >= 0 && compare(items[j], item) > 0.0 {
      items[j + 1] = items[j]
      j -= 1
    }
    items[j + 1] = item
  }
}

///|
/// `straightHachureLines`: horizontal segments inside the polygons, every
/// `step` units of y. When `step` is 1 only every `gap`-th scan line
/// draws; any other step draws on every line.
fn straight_hachure_lines(
  polygons : Array[Array[P]],
  gap : Double,
  step : Double,
) -> Array[(P, P)] {
  let lines : Array[(P, P)] = []
  let gap = if gap > 0.1 { gap } else { 0.1 }
  let edges : Array[Edge] = []
  for polygon in polygons {
    let vertices = polygon.copy()
    if vertices.is_empty() {
      continue
    }
    if vertices[0] != vertices[vertices.length() - 1] {
      vertices.push(vertices[0])
    }
    if vertices.length() <= 2 {
      continue
    }
    for i in 0..<(vertices.length() - 1) {
      let p1 = vertices[i]
      let p2 = vertices[i + 1]
      if p1.1 != p2.1 {
        let ymin = if p2.1 < p1.1 { p2.1 } else { p1.1 }
        edges.push({
          ymin,
          ymax: if p2.1 > p1.1 {
            p2.1
          } else {
            p1.1
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
      -1.0
    } else if e1.ymin > e2.ymin {
      1.0
    } else if e1.x < e2.x {
      -1.0
    } else if e1.x > e2.x {
      1.0
    } else if e1.ymax == e2.ymax {
      0.0
    } else {
      (e1.ymax - e2.ymax) / (e1.ymax - e2.ymax).abs()
    }
  })
  if edges.is_empty() {
    return lines
  }
  let mut active : Array[Edge] = []
  let mut pending = 0
  let mut y = edges[0].ymin
  let mut iteration = 0.0
  while !active.is_empty() || pending < edges.length() {
    // Edges that start at or above the scan line become active.
    while pending < edges.length() && !(edges[pending].ymin > y) {
      active.push(edges[pending])
      pending += 1
    }
    active = active.filter(edge => !(edge.ymax <= y))
    stable_sort(active, (e1, e2) => {
      if e1.x == e2.x {
        0.0
      } else {
        (e1.x - e2.x) / (e1.x - e2.x).abs()
      }
    })
    if (step != 1.0 || iteration % gap == 0.0) && active.length() > 1 {
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
    iteration += 1.0
  }
  lines
}

///|
/// `polygonHachureLines`: the hachure segments for `polygons` under the
/// options' gap and angle. With roughness of 1 or more, three times in
/// ten the scan steps by the gap instead of by one, which lets the lines
/// drift off the grid.
fn polygon_hachure_lines(
  polygons : Array[Array[P]],
  o : Options,
) -> Array[(P, P)] {
  let angle = o.hachure_angle + 90.0
  let mut gap = o.hachure_gap
  if gap < 0.0 {
    gap = 4.0 * o.stroke_width_number()
  }
  gap = js_round(if gap > 0.1 { gap } else { 0.1 })
  let mut step = 1.0
  if o.roughness >= 1.0 && o.random() > 0.7 {
    step = gap
  }
  // The polygons are turned so that the hachures run along x, and the
  // segments found are turned back.
  let polygons = polygons.map(polygon => polygon.copy())
  if angle != 0.0 {
    for polygon in polygons {
      rotate_points(polygon, angle)
    }
  }
  let lines = straight_hachure_lines(polygons, gap, step)
  if angle != 0.0 {
    let points : Array[P] = []
    for line in lines {
      points.push(line.0)
      points.push(line.1)
    }
    rotate_points(points, -angle)
    for i in 0..<lines.length() {
      lines[i] = (points[2 * i], points[2 * i + 1])
    }
  }
  lines
}

///|
/// `HachureFiller.fillPolygons`: every hachure segment as a sketchy line,
/// drawn twice unless multi-stroke is off for fills.
fn hachure_fill(polygons : Array[Array[P]], o : Options) -> Array[Op] {
  let ops = []
  for line in polygon_hachure_lines(polygons, o) {
    let ((x1, y1), (x2, y2)) = line
    ops.append(line_ops(x1, y1, x2, y2, o, true, false))
    if !o.disable_multi_stroke_fill {
      ops.append(line_ops(x1, y1, x2, y2, o, true, true))
    }
  }
  ops
}
