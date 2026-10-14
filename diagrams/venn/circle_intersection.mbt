// `circleintersection.js` of venn.js: the area shared by circles and the
// arcs that bound it.

///|
const SMALL : Double = 1.0e-10

///|
const PI : Double = 3.141592653589793

///|
/// A circle of a layout. venn.js passes the same objects around and
/// changes them in place, which the mutable fields keep.
priv struct Circle {
  mut x : Double
  mut y : Double
  radius : Double
  /// The name of its set, once `fromObjectNotation` has seen it.
  mut setid : String
  /// The area of the set; only the greedy layout knows it.
  size : Double
  /// The disjoint-set forest of `disjointCluster`.
  mut parent : Circle?
}

///|
fn Circle::new(
  x : Double,
  y : Double,
  radius : Double,
  setid~ : String = "",
  size~ : Double = 0.0,
) -> Circle {
  { x, y, radius, setid, size, parent: None, }
}

///|
/// A point where two circles cross; `parent_index` says which two.
priv struct Point {
  x : Double
  y : Double
  parent_index : Array[Int32]
  mut angle : Double
}

///|
/// A stretch of a circle on the boundary of an intersection, from `p2`
/// to `p1`.
priv struct Arc {
  circle : Circle
  width : Double
  p1 : Point
  p2 : Point
  large : Bool
}

///|
/// `distance(p1, p2)`
fn distance(x1 : Double, y1 : Double, x2 : Double, y2 : Double) -> Double {
  ((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)).sqrt()
}

///|
/// `circleArea(r, width)`: the area of a segment `width` deep of a circle
/// of radius `r`.
fn circle_area(r : Double, width : Double) -> Double {
  r * r * @jsmath.acos(1.0 - width / r) -
  (r - width) * (width * (2.0 * r - width)).sqrt()
}

///|
/// `circleOverlap(r1, r2, d)`: the area two circles `d` apart share.
fn circle_overlap(r1 : Double, r2 : Double, d : Double) -> Double {
  if d >= r1 + r2 {
    return 0.0
  }
  if d <= (r1 - r2).abs() {
    return PI * js_min(r1, r2) * js_min(r1, r2)
  }
  let w1 = r1 - (d * d - r2 * r2 + r1 * r1) / (2.0 * d)
  let w2 = r2 - (d * d - r1 * r1 + r2 * r2) / (2.0 * d)
  circle_area(r1, w1) + circle_area(r2, w2)
}

///|
/// `circleCircleIntersection(p1, p2)`: where two circles cross, if they
/// do.
fn circle_circle_intersection(
  p1 : Circle,
  p2 : Circle,
) -> Array[(Double, Double)] {
  let d = distance(p1.x, p1.y, p2.x, p2.y)
  let r1 = p1.radius
  let r2 = p2.radius
  if d >= r1 + r2 || d <= (r1 - r2).abs() {
    return []
  }
  let a = (r1 * r1 - r2 * r2 + d * d) / (2.0 * d)
  let h = (r1 * r1 - a * a).sqrt()
  let x0 = p1.x + a * (p2.x - p1.x) / d
  let y0 = p1.y + a * (p2.y - p1.y) / d
  let rx = -(p2.y - p1.y) * (h / d)
  let ry = -(p2.x - p1.x) * (h / d)
  [(x0 + rx, y0 - ry), (x0 - rx, y0 + ry)]
}

///|
/// `getIntersectionPoints(circles)`
fn intersection_points(circles : Array[Circle]) -> Array[Point] {
  let ret = []
  for i in 0..<circles.length() {
    for j in (i + 1)..<circles.length() {
      for p in circle_circle_intersection(circles[i], circles[j]) {
        ret.push({ x: p.0, y: p.1, parent_index: [i, j], angle: 0.0, })
      }
    }
  }
  ret
}

///|
/// `containedInCircles(point, circles)`
fn contained_in_circles(point : Point, circles : Array[Circle]) -> Bool {
  for circle in circles {
    if !(distance(point.x, point.y, circle.x, circle.y) < circle.radius + SMALL) {
      return false
    }
  }
  true
}

///|
/// `intersectionArea(circles, stats)`: the area all the circles share, and
/// the arcs around it. `circles` is not empty.
fn intersection_area(circles : Array[Circle]) -> (Double, Array[Arc]) {
  let inner_points = intersection_points(circles).filter(p => {
    contained_in_circles(p, circles)
  })
  let mut arc_area = 0.0
  let mut polygon_area = 0.0
  let arcs : Array[Arc] = []
  if inner_points.length() > 1 {
    // The points in order around their centre.
    let mut center_x = 0.0
    let mut center_y = 0.0
    for point in inner_points {
      center_x += point.x
      center_y += point.y
    }
    center_x /= inner_points.length().to_double()
    center_y /= inner_points.length().to_double()
    for p in inner_points {
      p.angle = @jsmath.atan2(p.x - center_x, p.y - center_y)
    }
    @d3.js_sort(inner_points, (a, b) => b.angle - a.angle)
    // Between two neighbours the boundary is an arc of a circle both lie
    // on: of several, the one that bulges least.
    let mut p2 = inner_points[inner_points.length() - 1]
    for i in 0..<inner_points.length() {
      let p1 = inner_points[i]
      polygon_area += (p2.x + p1.x) * (p1.y - p2.y)
      let mid_x = (p1.x + p2.x) / 2.0
      let mid_y = (p1.y + p2.y) / 2.0
      let mut arc : Arc? = None
      for index in p1.parent_index {
        if p2.parent_index.contains(index) {
          let circle = circles[index]
          let a1 = @jsmath.atan2(p1.x - circle.x, p1.y - circle.y)
          let a2 = @jsmath.atan2(p2.x - circle.x, p2.y - circle.y)
          let mut angle_diff = a2 - a1
          if angle_diff < 0.0 {
            angle_diff += 2.0 * PI
          }
          let a = a2 - angle_diff / 2.0
          let mut width = distance(
            mid_x,
            mid_y,
            circle.x + circle.radius * @jsmath.sin(a),
            circle.y + circle.radius * @jsmath.cos(a),
          )
          if width > circle.radius * 2.0 {
            width = circle.radius * 2.0
          }
          let narrower = match arc {
            None => true
            Some(arc) => arc.width > width
          }
          if narrower {
            arc = Some({ circle, width, p1, p2, large: width > circle.radius, })
          }
        }
      }
      if arc is Some(arc) {
        arcs.push(arc)
        arc_area += circle_area(arc.circle.radius, arc.width)
        p2 = p1
      }
    }
  } else {
    // No crossing inside: the smallest circle lies in all the others, or
    // nothing is shared.
    let mut smallest = circles[0]
    for i in 1..<circles.length() {
      if circles[i].radius < smallest.radius {
        smallest = circles[i]
      }
    }
    let mut disjoint = false
    for circle in circles {
      if distance(circle.x, circle.y, smallest.x, smallest.y) >
        (smallest.radius - circle.radius).abs() {
        disjoint = true
        break
      }
    }
    if disjoint {
      arc_area = 0.0
      polygon_area = 0.0
    } else {
      arc_area = smallest.radius * smallest.radius * PI
      arcs.push({
        circle: smallest,
        p1: {
          x: smallest.x,
          y: smallest.y + smallest.radius,
          parent_index: [],
          angle: 0.0,
        },
        p2: {
          x: smallest.x - SMALL,
          y: smallest.y + smallest.radius,
          parent_index: [],
          angle: 0.0,
        },
        width: smallest.radius * 2.0,
        large: true,
      })
    }
  }
  polygon_area /= 2.0
  (arc_area + polygon_area, arcs)
}

///|
/// `circlePath(x, y, r)`: a full circle as two half arcs.
fn circle_path(x : Double, y : Double, r : Double) -> String {
  let n = @dom.number
  "\nM \{n(x)} \{n(y)} \nm \{n(-r)} 0 \na \{n(r)} \{n(r)} 0 1 0 \{n(r * 2.0)} 0 \na \{n(r)} \{n(r)} 0 1 0 \{n(-r * 2.0)} 0"
}

///|
/// `intersectionAreaPath(circles)`: the outline of what the circles
/// share, with nothing rounded.
fn intersection_area_path(circles : Array[Circle]) -> String {
  let n = @dom.number
  let arcs = if circles.length() == 0 {
    []
  } else {
    intersection_area(circles).1
  }
  if arcs.length() == 0 {
    return "M 0 0"
  }
  if arcs.length() == 1 {
    let circle = arcs[0].circle
    return circle_path(circle.x, circle.y, circle.radius)
  }
  let out = StringBuilder()
  out.write_string("\nM \{n(arcs[0].p2.x)} \{n(arcs[0].p2.y)}")
  for arc in arcs {
    let radius = n(arc.circle.radius)
    let large = if arc.large { 1 } else { 0 }
    out.write_string(
      " \nA \{radius} \{radius} 0 \{large} 1 \{n(arc.p1.x)} \{n(arc.p1.y)}",
    )
  }
  out.to_string()
}
