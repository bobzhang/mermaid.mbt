// The rest of `layout.js`: a solved layout is turned to a standard
// orientation, its disjoint groups are put side by side, and the whole
// is scaled to the size of the chart.

///|
/// `fromObjectNotation(solution)`: the circles in the order of the
/// object's keys, each told the name of its set.
fn from_object_notation(solution : Dict[Circle]) -> Array[Circle] {
  solution
  .keys()
  .map(id => {
    let circle = circle_of(solution, id)
    circle.setid = id
    circle
  })
}

///|
/// `toObjectNotation(circles)`
fn to_object_notation(circles : Array[Circle]) -> Dict[Circle] {
  let r : Dict[Circle] = Dict::new()
  for circle in circles {
    r.set(circle.setid, circle)
  }
  r
}

///|
/// `orientateCircles(circles, orientation)`: the largest circle at the
/// origin, the second in the direction of `orientation`, the third on a
/// fixed side of the line through both.
fn orientate_circles(circles : Array[Circle], orientation : Double) -> Unit {
  @d3.js_sort(circles, (a, b) => b.radius - a.radius)
  if circles.length() > 0 {
    let largest_x = circles[0].x
    let largest_y = circles[0].y
    for circle in circles {
      circle.x -= largest_x
      circle.y -= largest_y
    }
  }
  if circles.length() == 2 {
    // A circle inside the other touches it on the inside.
    let dist = distance(circles[0].x, circles[0].y, circles[1].x, circles[1].y)
    if dist < (circles[1].radius - circles[0].radius).abs() {
      circles[1].x = circles[0].x +
        circles[0].radius -
        circles[1].radius -
        1.0e-10
      circles[1].y = circles[0].y
    }
  }
  if circles.length() > 1 {
    let rotation = @jsmath.atan2(circles[1].x, circles[1].y) - orientation
    let c = @jsmath.cos(rotation)
    let s = @jsmath.sin(rotation)
    for circle in circles {
      let x = circle.x
      let y = circle.y
      circle.x = c * x - s * y
      circle.y = s * x + c * y
    }
  }
  if circles.length() > 2 {
    let mut angle = @jsmath.atan2(circles[2].x, circles[2].y) - orientation
    while angle < 0.0 {
      angle += 2.0 * PI
    }
    while angle > 2.0 * PI {
      angle -= 2.0 * PI
    }
    if angle > PI {
      // Mirror everything in the line through the first two.
      let slope = circles[1].y / (1.0e-10 + circles[1].x)
      for circle in circles {
        let d = (circle.x + slope * circle.y) / (1.0 + slope * slope)
        circle.x = 2.0 * d - circle.x
        circle.y = 2.0 * d * slope - circle.y
      }
    }
  }
}

///|
/// `disjointCluster(circles)`: the circles in groups of those that
/// overlap, directly or through others.
fn disjoint_cluster(circles : Array[Circle]) -> Array[Array[Circle]] {
  for circle in circles {
    circle.parent = Some(circle)
  }
  fn find(circle : Circle) -> Circle {
    guard circle.parent is Some(parent) else { return circle }
    if !physical_equal(parent, circle) {
      circle.parent = Some(find(parent))
    }
    circle.parent.unwrap_or(circle)
  }

  for i in 0..<circles.length() {
    for j in (i + 1)..<circles.length() {
      let max_distance = circles[i].radius + circles[j].radius
      if distance(circles[i].x, circles[i].y, circles[j].x, circles[j].y) +
        1.0e-10 <
        max_distance {
        // `union(circles[j], circles[i])`
        let x_root = find(circles[j])
        let y_root = find(circles[i])
        x_root.parent = Some(y_root)
      }
    }
  }
  let clusters : Map[String, Array[Circle]] = Map([])
  for circle in circles {
    let setid = find(circle).setid
    match clusters.get(setid) {
      Some(cluster) => cluster.push(circle)
      None => clusters[setid] = [circle]
    }
  }
  for circle in circles {
    circle.parent = None
  }
  clusters.values().collect()
}

///|
/// The extent of some circles: `getBoundingBox`.
priv struct Bounds {
  x_min : Double
  x_max : Double
  y_min : Double
  y_max : Double
}

///|
fn bounding_box(circles : Array[Circle]) -> Bounds {
  let mut x_max = @double.neg_infinity
  let mut x_min = @double.infinity
  for c in circles {
    x_max = js_max(x_max, c.x + c.radius)
  }
  for c in circles {
    x_min = js_min(x_min, c.x - c.radius)
  }
  let mut y_max = @double.neg_infinity
  let mut y_min = @double.infinity
  for c in circles {
    y_max = js_max(y_max, c.y + c.radius)
  }
  for c in circles {
    y_min = js_min(y_min, c.y - c.radius)
  }
  { x_min, x_max, y_min, y_max, }
}

///|
/// A group of overlapping circles, with the area of its bounding box.
priv struct Cluster {
  circles : Array[Circle]
  size : Double
  bounds : Bounds
}

///|
/// `normalizeSolution(solution, orientation)`: every group of circles in
/// the standard orientation, the smaller groups to the right of and
/// below the largest.
fn normalize_solution(
  solution : Dict[Circle],
  orientation : Double,
) -> Dict[Circle] {
  let copies = from_object_notation(solution).map(d => {
    Circle::new(d.x, d.y, d.radius, setid=d.setid, size=d.size)
  })
  let clusters : Array[Cluster] = []
  for cluster in disjoint_cluster(copies) {
    orientate_circles(cluster, orientation)
    let bounds = bounding_box(cluster)
    clusters.push({
      circles: cluster,
      size: (bounds.x_max - bounds.x_min) * (bounds.y_max - bounds.y_min),
      bounds,
    })
  }
  @d3.js_sort(clusters, (a, b) => b.size - a.size)
  let circles = clusters[0].circles
  let mut return_bounds = clusters[0].bounds
  let spacing = (return_bounds.x_max - return_bounds.x_min) / 50.0
  let add_cluster = (index : Int32, right : Bool, bottom : Bool) => {
    guard index < clusters.length() else { return }
    let cluster = clusters[index]
    let bounds = cluster.bounds
    let mut x_offset = 0.0
    let mut y_offset = 0.0
    if right {
      x_offset = return_bounds.x_max - bounds.x_min + spacing
    } else {
      x_offset = return_bounds.x_max - bounds.x_max
      let centreing = (bounds.x_max - bounds.x_min) / 2.0 -
        (return_bounds.x_max - return_bounds.x_min) / 2.0
      if centreing < 0.0 {
        x_offset += centreing
      }
    }
    if bottom {
      y_offset = return_bounds.y_max - bounds.y_min + spacing
    } else {
      y_offset = return_bounds.y_max - bounds.y_max
      let centreing = (bounds.y_max - bounds.y_min) / 2.0 -
        (return_bounds.y_max - return_bounds.y_min) / 2.0
      if centreing < 0.0 {
        y_offset += centreing
      }
    }
    for c in cluster.circles {
      c.x += x_offset
      c.y += y_offset
      circles.push(c)
    }
  }
  let mut index = 1
  while index < clusters.length() {
    add_cluster(index, true, false)
    add_cluster(index + 1, false, true)
    add_cluster(index + 2, true, true)
    index += 3
    return_bounds = bounding_box(circles)
  }
  to_object_notation(circles)
}

///|
/// `scaleSolution(solution, width, height, padding)`: the layout as
/// large as fits the chart inside its padding, centred.
fn scale_solution(
  solution : Dict[Circle],
  width : Double,
  height : Double,
  padding : Double,
) -> Dict[Circle] {
  let circles = from_object_notation(solution)
  let width = width - 2.0 * padding
  let height = height - 2.0 * padding
  let { x_min, x_max, y_min, y_max, } = bounding_box(circles)
  if x_max == x_min || y_max == y_min {
    // "not scaling solution: zero size detected"
    return solution
  }
  let x_scaling = width / (x_max - x_min)
  let y_scaling = height / (y_max - y_min)
  let scaling = js_min(y_scaling, x_scaling)
  let x_offset = (width - (x_max - x_min) * scaling) / 2.0
  let y_offset = (height - (y_max - y_min) * scaling) / 2.0
  to_object_notation(
    circles.map(circle => {
      Circle::new(
        padding + x_offset + (circle.x - x_min) * scaling,
        padding + y_offset + (circle.y - y_min) * scaling,
        scaling * circle.radius,
        setid=circle.setid,
      )
    }),
  )
}
