// `layout.js` of venn.js: circles whose overlaps have the areas asked
// for, as nearly as an optimiser gets them. Transcribed operation by
// operation, like `fmin.mbt`.

///|
/// A set or an overlap as venn.js sees it: the datum of a chart.
priv struct Area {
  sets : Array[String]
  size : Double
  label : String?
}

///|
/// The key of an area in a JavaScript object: its sets as an array turns
/// into a string.
fn Area::key(self : Area) -> String {
  self.sets.join(",")
}

///|
/// The source of `Math.random()`: mulberry32 seeded with 0, restarted
/// for every diagram.
///
/// Upstream draws the starting points of one of its two initial layouts
/// from `Math.random()`, which nothing seeds: with four sets or more two
/// renders of a diagram need not agree. The port always draws the same
/// numbers, and the reference browser is given the same generator
/// (`testdata/venn/oracle-prelude.js`) where output is compared.
priv struct Random {
  mut state : UInt32
}

///|
fn Random::new() -> Random {
  { state: 0, }
}

///|
fn Random::next(self : Random) -> Double {
  self.state = self.state + 0x6D2B79F5
  let s = self.state
  let t = (s ^ (s >> 15)) * (s | 1)
  let t = (t + (t ^ (t >> 7)) * (t | 61)) ^ t
  (t ^ (t >> 14)).to_double() / 4294967296.0
}

///|
/// `distanceFromIntersectArea(r1, r2, overlap)`: how far apart two
/// circles share that much area.
fn distance_from_intersect_area(
  r1 : Double,
  r2 : Double,
  overlap : Double,
) -> Double raise VennError {
  if js_min(r1, r2) * js_min(r1, r2) * PI <= overlap + SMALL {
    return (r1 - r2).abs()
  }
  bisect(distance => circle_overlap(r1, r2, distance) - overlap, 0.0, r1 + r2)
}

///|
/// `addMissingAreas(areas)`: every pair of sets without a declared
/// overlap gets an empty one.
fn add_missing_areas(areas : Array[Area]) -> Array[Area] {
  let r = areas.copy()
  let ids = []
  let pairs : Map[String, Unit] = Map([])
  for area in r {
    if area.sets.length() == 1 {
      ids.push(area.sets[0])
    } else if area.sets.length() == 2 {
      let a = area.sets[0]
      let b = area.sets[1]
      pairs["\{a};\{b}"] = ()
      pairs["\{b};\{a}"] = ()
    }
  }
  @d3.js_sort(ids, (a, b) => compare_code_units(a, b).to_double())
  for i in 0..<ids.length() {
    let a = ids[i]
    for j in (i + 1)..<ids.length() {
      let b = ids[j]
      if !pairs.contains("\{a};\{b}") {
        r.push({ sets: [a, b], size: 0.0, label: None, })
      }
    }
  }
  r
}

///|
/// The circle of a set. Every set an area names has one: unions are of
/// declared sets.
fn circle_of(circles : Dict[Circle], set : String) -> Circle {
  match circles.get(set) {
    Some(circle) => circle
    None => abort("no circle for set \{set}")
  }
}

///|
/// `lossFunction(circles, overlaps)`: the squared differences between
/// the overlaps the circles have and those asked for.
fn loss_function(circles : Dict[Circle], overlaps : Array[Area]) -> Double {
  let mut output = 0.0
  for area in overlaps {
    if area.sets.length() == 1 {
      continue
    }
    let overlap = if area.sets.length() == 2 {
      let left = circle_of(circles, area.sets[0])
      let right = circle_of(circles, area.sets[1])
      circle_overlap(
        left.radius,
        right.radius,
        distance(left.x, left.y, right.x, right.y),
      )
    } else {
      intersection_area(area.sets.map(set => circle_of(circles, set))).0
    }
    // The weight of every area is 1.
    output += 1.0 * (overlap - area.size) * (overlap - area.size)
  }
  output
}

///|
/// An overlap of a set with another, for the greedy layout.
priv struct SetOverlap {
  set : String
  size : Double
  weight : Double
}

///|
/// `greedyLayout(areas)`: the sets one by one, the most overlapped
/// first, each at the best of a few candidate places.
fn greedy_layout(areas : Array[Area]) -> Dict[Circle] raise VennError {
  let circles : Dict[Circle] = Dict::new()
  let set_overlaps : Dict[Array[SetOverlap]] = Dict::new()
  for area in areas {
    if area.sets.length() == 1 {
      let set = area.sets[0]
      circles.set(
        set,
        Circle::new(1.0e10, 1.0e10, (area.size / PI).sqrt(), size=area.size),
      )
      set_overlaps.set(set, [])
    }
  }
  let areas = areas.filter(a => a.sets.length() == 2)
  for current in areas {
    let mut weight = 1.0
    let left = current.sets[0]
    let right = current.sets[1]
    if current.size + SMALL >=
      js_min(circle_of(circles, left).size, circle_of(circles, right).size) {
      weight = 0.0
    }
    if set_overlaps.get(left) is Some(overlaps) {
      overlaps.push({ set: right, size: current.size, weight, })
    }
    if set_overlaps.get(right) is Some(overlaps) {
      overlaps.push({ set: left, size: current.size, weight, })
    }
  }
  let most_overlapped : Array[(String, Double)] = []
  for set in set_overlaps.keys() {
    let mut size = 0.0
    for overlap in set_overlaps.get(set).unwrap_or([]) {
      size += overlap.size * overlap.weight
    }
    most_overlapped.push((set, size))
  }
  @d3.js_sort(most_overlapped, (a, b) => b.1 - a.1)
  if most_overlapped.length() == 0 {
    // `mostOverlapped[0].set`
    raise Invalid("Cannot read properties of undefined (reading 'set')")
  }
  let positioned : Map[String, Unit] = Map([])
  let first = circle_of(circles, most_overlapped[0].0)
  first.x = 0.0
  first.y = 0.0
  positioned[most_overlapped[0].0] = ()
  for i in 1..<most_overlapped.length() {
    let set_index = most_overlapped[i].0
    let overlap = set_overlaps
      .get(set_index)
      .unwrap_or([])
      .filter(element => positioned.contains(element.set))
    let set = circle_of(circles, set_index)
    @d3.js_sort(overlap, (a, b) => b.size - a.size)
    if overlap.length() == 0 {
      raise Invalid("ERROR: missing pairwise overlap information")
    }
    // Around each placed set it overlaps: left, right, above and below
    // at the right distance, and where two such distances meet.
    let points : Array[(Double, Double)] = []
    for j in 0..<overlap.length() {
      let p1 = circle_of(circles, overlap[j].set)
      let d1 = distance_from_intersect_area(
        set.radius,
        p1.radius,
        overlap[j].size,
      )
      points.push((p1.x + d1, p1.y))
      points.push((p1.x - d1, p1.y))
      points.push((p1.x, p1.y + d1))
      points.push((p1.x, p1.y - d1))
      for k in (j + 1)..<overlap.length() {
        let p2 = circle_of(circles, overlap[k].set)
        let d2 = distance_from_intersect_area(
          set.radius,
          p2.radius,
          overlap[k].size,
        )
        let extra_points = circle_circle_intersection(
          Circle::new(p1.x, p1.y, d1),
          Circle::new(p2.x, p2.y, d2),
        )
        points.append(extra_points)
      }
    }
    let mut best_loss = 1.0e50
    let mut best_point = points[0]
    for point in points {
      set.x = point.0
      set.y = point.1
      let local_loss = loss_function(circles, areas)
      if local_loss < best_loss {
        best_loss = local_loss
        best_point = point
      }
    }
    set.x = best_point.0
    set.y = best_point.1
    positioned[set_index] = ()
  }
  circles
}

///|
/// `constrainedMDSGradient(x, fxprime, distances, constraints)`
fn constrained_mds_gradient(
  x : Array[Double],
  fxprime : Array[Double],
  distances : Array[Array[Double]],
  constraints : Array[Array[Double]],
) -> Double {
  for i in 0..<fxprime.length() {
    fxprime[i] = 0.0
  }
  let mut loss = 0.0
  for i in 0..<distances.length() {
    let xi = x[2 * i]
    let yi = x[2 * i + 1]
    for j in (i + 1)..<distances.length() {
      let xj = x[2 * j]
      let yj = x[2 * j + 1]
      let dij = distances[i][j]
      let constraint = constraints[i][j]
      let squared_distance = (xj - xi) * (xj - xi) + (yj - yi) * (yj - yi)
      let distance = squared_distance.sqrt()
      let delta = squared_distance - dij * dij
      if (constraint > 0.0 && distance <= dij) ||
        (constraint < 0.0 && distance >= dij) {
        continue
      }
      loss += 2.0 * delta * delta
      fxprime[2 * i] += 4.0 * delta * (xi - xj)
      fxprime[2 * i + 1] += 4.0 * delta * (yi - yj)
      fxprime[2 * j] += 4.0 * delta * (xj - xi)
      fxprime[2 * j + 1] += 4.0 * delta * (yj - yi)
    }
  }
  loss
}

///|
/// `constrainedMDSLayout(areas, params)`: the sets as far apart as their
/// overlaps say, by multidimensional scaling from ten random starts.
fn constrained_mds_layout(
  areas : Array[Area],
  max_iterations : Int32,
  random : Random,
) -> Dict[Circle] raise VennError {
  let restarts = 10
  let sets : Array[Area] = []
  let setids : Map[String, Int32] = Map([])
  for area in areas {
    if area.sets.length() == 1 {
      setids[area.sets[0]] = sets.length()
      sets.push(area)
    }
  }
  // `getDistanceMatrices`
  let count = sets.length()
  let mut distances = Array::makei(count, _ => zeros(count))
  let constraints = Array::makei(count, _ => zeros(count))
  for current in areas {
    guard current.sets.length() == 2 else { continue }
    guard setids.get(current.sets[0]) is Some(left) &&
      setids.get(current.sets[1]) is Some(right) else {
      abort("no circle for an overlap")
    }
    let r1 = (sets[left].size / PI).sqrt()
    let r2 = (sets[right].size / PI).sqrt()
    let distance = distance_from_intersect_area(r1, r2, current.size)
    distances[right][left] = distance
    distances[left][right] = distance
    let mut c = 0.0
    if current.size + 1.0e-10 >= js_min(sets[left].size, sets[right].size) {
      c = 1.0
    } else if current.size <= 1.0e-10 {
      c = -1.0
    }
    constraints[right][left] = c
    constraints[left][right] = c
  }
  let norm = norm2(distances.map(norm2)) / distances.length().to_double()
  distances = distances.map(row => row.map(value => value / norm))
  let obj = (x : Array[Double], fxprime : Array[Double]) => {
    constrained_mds_gradient(x, fxprime, distances, constraints)
  }
  let mut best : Descent? = None
  for _ in 0..<restarts {
    let initial = zeros(distances.length() * 2).map(_ => random.next())
    let current = conjugate_gradient(obj, initial, max_iterations)
    let better = match best {
      None => true
      Some(best) => current.fx < best.fx
    }
    if better {
      best = Some(current)
    }
  }
  let circles : Dict[Circle] = Dict::new()
  guard best is Some(best) else { return circles }
  let positions = best.x
  for i, set in sets {
    circles.set(
      set.sets[0],
      Circle::new(
        positions[2 * i] * norm,
        positions[2 * i + 1] * norm,
        (set.size / PI).sqrt(),
      ),
    )
  }
  circles
}

///|
/// `bestInitialLayout(areas, params)`: the greedy layout, unless there
/// are many areas and the scaled one is better.
fn best_initial_layout(
  areas : Array[Area],
  max_iterations : Int32,
  random : Random,
) -> Dict[Circle] raise VennError {
  let mut initial = greedy_layout(areas)
  if areas.length() >= 8 {
    let constrained = constrained_mds_layout(areas, max_iterations, random)
    let constrained_loss = loss_function(constrained, areas)
    let greedy_loss = loss_function(initial, areas)
    if constrained_loss + 1.0e-8 < greedy_loss {
      initial = constrained
    }
  }
  initial
}

///|
/// `venn(sets)`: the circles of a layout, by set, before they are turned
/// and scaled.
fn venn_layout(
  sets : Array[Area],
  random : Random,
) -> Dict[Circle] raise VennError {
  let max_iterations = 500
  let areas = add_missing_areas(sets)
  let circles = best_initial_layout(areas, max_iterations, random)
  let setids = circles.keys()
  let initial = []
  for setid in setids {
    let circle = circle_of(circles, setid)
    initial.push(circle.x)
    initial.push(circle.y)
  }
  let solution = nelder_mead(
    values => {
      let current : Dict[Circle] = Dict::new()
      for i, setid in setids {
        current.set(
          setid,
          Circle::new(
            values[2 * i],
            values[2 * i + 1],
            circle_of(circles, setid).radius,
          ),
        )
      }
      loss_function(current, areas)
    },
    initial,
    max_iterations~,
  )
  let positions = solution.x
  for i, setid in setids {
    let circle = circle_of(circles, setid)
    circle.x = positions[2 * i]
    circle.y = positions[2 * i + 1]
  }
  circles
}
