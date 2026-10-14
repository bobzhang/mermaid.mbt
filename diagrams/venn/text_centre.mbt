// Where the label of each area goes: the point of the area furthest
// from its edges, found by the same simplex search as the layout.

///|
/// The place of a label.
priv struct TextCentre {
  x : Double
  y : Double
}

///|
/// `circleMargin(current, interior, exterior)`: how far a point is
/// inside all the interior circles and outside all the exterior ones.
fn circle_margin(
  x : Double,
  y : Double,
  interior : Array[Circle],
  exterior : Array[Circle],
) -> Double {
  let mut margin = interior[0].radius -
    distance(interior[0].x, interior[0].y, x, y)
  for i in 1..<interior.length() {
    let m = interior[i].radius - distance(interior[i].x, interior[i].y, x, y)
    if m <= margin {
      margin = m
    }
  }
  for circle in exterior {
    let m = distance(circle.x, circle.y, x, y) - circle.radius
    if m <= margin {
      margin = m
    }
  }
  margin
}

///|
/// `computeTextCentre(interior, exterior)`
fn compute_text_centre(
  interior : Array[Circle],
  exterior : Array[Circle],
) -> TextCentre {
  // The search starts from the best of the centres of the interior
  // circles and the points halfway to their rims.
  let points : Array[(Double, Double)] = []
  for c in interior {
    points.push((c.x, c.y))
    points.push((c.x + c.radius / 2.0, c.y))
    points.push((c.x - c.radius / 2.0, c.y))
    points.push((c.x, c.y + c.radius / 2.0))
    points.push((c.x, c.y - c.radius / 2.0))
  }
  let mut initial = points[0]
  let mut margin = circle_margin(points[0].0, points[0].1, interior, exterior)
  for i in 1..<points.length() {
    let m = circle_margin(points[i].0, points[i].1, interior, exterior)
    if m >= margin {
      initial = points[i]
      margin = m
    }
  }
  let solution = nelder_mead(
      p => -1.0 * circle_margin(p[0], p[1], interior, exterior),
      [initial.0, initial.1],
      max_iterations=500,
      min_error_delta=1.0e-10,
    ).x
  let ret : TextCentre = { x: solution[0], y: solution[1], }
  let mut valid = true
  for i in interior {
    if distance(ret.x, ret.y, i.x, i.y) > i.radius {
      valid = false
      break
    }
  }
  for e in exterior {
    if distance(ret.x, ret.y, e.x, e.y) < e.radius {
      valid = false
      break
    }
  }
  if valid {
    return ret
  }
  if interior.length() == 1 {
    return { x: interior[0].x, y: interior[0].y, }
  }
  let arcs = intersection_area(interior).1
  if arcs.length() == 0 {
    // An area that is not on the screen.
    return { x: 0.0, y: -1000.0, }
  }
  if arcs.length() == 1 {
    return { x: arcs[0].circle.x, y: arcs[0].circle.y, }
  }
  if exterior.length() > 0 {
    // Try again without the exterior circles.
    return compute_text_centre(interior, [])
  }
  // `getCenter(areaStats.arcs.map((a) => a.p1))`
  let mut x = 0.0
  let mut y = 0.0
  for arc in arcs {
    x += arc.p1.x
    y += arc.p1.y
  }
  x /= arcs.length().to_double()
  y /= arcs.length().to_double()
  { x, y, }
}

///|
/// `getOverlappingCircles(circles)`: for every circle, those it lies
/// inside.
fn overlapping_circles(circles : Dict[Circle]) -> Map[String, Array[String]] {
  let ret : Map[String, Array[String]] = Map([])
  let circleids = circles.keys()
  for circleid in circleids {
    ret[circleid] = []
  }
  for i in 0..<circleids.length() {
    let ci = circleids[i]
    let a = circle_of(circles, ci)
    for j in (i + 1)..<circleids.length() {
      let cj = circleids[j]
      let b = circle_of(circles, cj)
      let d = distance(a.x, a.y, b.x, b.y)
      if d + b.radius <= a.radius + 1.0e-10 {
        ret.get(cj).unwrap_or([]).push(ci)
      } else if d + a.radius <= b.radius + 1.0e-10 {
        ret.get(ci).unwrap_or([]).push(cj)
      }
    }
  }
  ret
}

///|
/// `computeTextCentres(circles, areas)`: the place of the label of every
/// area, by the key of the area. The label of an area avoids the circles
/// that are not part of it, except those its own circles lie inside.
fn compute_text_centres(
  circles : Dict[Circle],
  areas : Array[Area],
) -> Map[String, TextCentre] {
  let ret : Map[String, TextCentre] = Map([])
  let overlapped = overlapping_circles(circles)
  for area in areas {
    let areaids : Map[String, Unit] = Map([])
    let exclude : Map[String, Unit] = Map([])
    for set in area.sets {
      areaids[set] = ()
      for overlap in overlapped.get(set).unwrap_or([]) {
        exclude[overlap] = ()
      }
    }
    let interior = []
    let exterior = []
    for setid in circles.keys() {
      if areaids.contains(setid) {
        interior.push(circle_of(circles, setid))
      } else if !exclude.contains(setid) {
        exterior.push(circle_of(circles, setid))
      }
    }
    ret[area.key()] = compute_text_centre(interior, exterior)
  }
  ret
}
