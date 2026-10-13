// Post-processing of the routes ELK returns, before they are drawn.

///|
/// The clipping box of a node.
fn bounds_for(node : ElkNode) -> Bounds {
  let (x, y) = match node.offset {
    Some(offset) => (offset.pos_x, offset.pos_y)
    None => (0.0, 0.0)
  }
  let width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  {
    x: x + width / 2.0,
    y: y + height / 2.0,
    width: node.effective_width(),
    height,
  }
}

///|
fn is_center_approx(point : Point, node : ElkNode) -> Bool {
  (point.x - node.x).abs() < 1.0e-6 && (point.y - node.y).abs() < 1.0e-6
}

///|
/// The point of a route that should lie on the border of the node at one
/// end, and whether the route still starts at the node's centre.
fn candidate_border_point(
  points : Array[Point],
  node : ElkNode,
  at_start : Bool,
) -> (Point, Bool) {
  if points.is_empty() {
    return ({ x: node.x, y: node.y, }, true)
  }
  let n = points.length()
  let terminal = if at_start { points[0] } else { points[n - 1] }
  let center_approx = is_center_approx(terminal, node)
  let candidate = if center_approx && n > 1 {
    if at_start {
      points[1]
    } else {
      points[n - 2]
    }
  } else {
    terminal
  }
  (candidate, center_approx)
}

///|
/// Cut a route where it crosses the border of the group at one end.
fn clip_group_endpoint(
  points : Array[Point],
  bounds : Bounds,
  at_start : Bool,
) -> Bool {
  let step = if at_start { 1 } else { -1 }
  let terminal = if at_start { 0 } else { points.length() - 1 }
  let mut index = terminal
  while index >= 0 &&
        index < points.length() &&
        !outside_node(bounds, points[index]) {
    index += step
  }
  if index == terminal || index < 0 || index >= points.length() {
    return false
  }
  let outside = points[index]
  let inside = points[index - step]
  let dx = outside.x - inside.x
  let dy = outside.y - inside.y
  let infinity = 0x7ff0000000000000L.reinterpret_as_double()
  let sign = (value : Double) => {
    if value > 0.0 {
      1.0
    } else if value < 0.0 {
      -1.0
    } else {
      value
    }
  }
  let tx = if dx == 0.0 {
    infinity
  } else {
    (bounds.x + sign(dx) * bounds.width / 2.0 - inside.x) / dx
  }
  let ty = if dy == 0.0 {
    infinity
  } else {
    (bounds.y + sign(dy) * bounds.height / 2.0 - inside.y) / dy
  }
  let t = tx.min(ty)
  let crossing = { x: inside.x + t * dx, y: inside.y + t * dy, }
  if at_start {
    for _ in 0..<index {
      points.remove(0) |> ignore
    }
    points.insert(0, crossing)
  } else {
    while points.length() > index + 1 {
      points.pop() |> ignore
    }
    points.push(crossing)
  }
  true
}

///|
fn apply_start_intersection(
  points : Array[Point],
  node : ElkNode,
  bounds : Bounds,
) -> Unit {
  for point in points {
    if outside_node(bounds, point) {
      let value = compute_node_intersection(
        node.node.intersect,
        bounds,
        point,
        points[0],
      )
      replace_endpoint(points, true, value)
      return
    }
  }
}

///|
fn apply_end_intersection(
  points : Array[Point],
  node : ElkNode,
  bounds : Bounds,
) -> Unit {
  for index = points.length() - 1; index >= 0; index = index - 1 {
    if outside_node(bounds, points[index]) {
      let value = compute_node_intersection(
        node.node.intersect,
        bounds,
        points[index],
        points[points.length() - 1],
      )
      replace_endpoint(points, false, value)
      return
    }
  }
}

///|
fn attach_along_departure_axis(
  node : ElkNode,
  bounds : Bounds,
  points : Array[Point],
  port_index : Int32,
  step : Int32,
) -> Point? {
  if node.node.is_group {
    return None
  }
  let next_index = port_index + step
  guard port_index >= 0 && port_index < points.length() else { return None }
  guard next_index >= 0 && next_index < points.length() else { return None }
  outline_attach_point(
    node.node.intersect,
    bounds,
    points[port_index],
    points[next_index],
  )
}

///|
/// Clip a route that runs from centre to centre against both nodes.
fn cutter2(
  start_node : ElkNode,
  end_node : ElkNode,
  original : Array[Point],
) -> Array[Point] {
  let start_bounds = bounds_for(start_node)
  let end_bounds = bounds_for(end_node)
  if original.is_empty() {
    return []
  }
  let points = original.copy()
  let start_center = points[0]
  let end_center = points[points.length() - 1]
  let mut first_outside = -1
  for index, point in points {
    if outside_node(start_bounds, point) {
      first_outside = index
      break
    }
  }
  if first_outside != -1 {
    let value = match
      attach_along_departure_axis(
        start_node, start_bounds, points, first_outside, 1,
      ) {
      Some(point) => point
      None =>
        compute_node_intersection(
          start_node.node.intersect,
          start_bounds,
          points[first_outside],
          start_center,
        )
    }
    replace_endpoint(points, true, value)
  }
  let mut outside_index = -1
  for index = points.length() - 1; index >= 0; index = index - 1 {
    if outside_node(end_bounds, points[index]) {
      outside_index = index
      break
    }
  }
  if outside_index == -1 && points.length() > 1 {
    outside_index = points.length() - 2
  }
  if outside_index != -1 {
    let value = match
      attach_along_departure_axis(
        end_node, end_bounds, points, outside_index, -1,
      ) {
      Some(point) => point
      None =>
        compute_node_intersection(
          end_node.node.intersect,
          end_bounds,
          points[outside_index],
          end_center,
        )
    }
    replace_endpoint(points, false, value)
  }
  if points.length() > 1 {
    let last = points[points.length() - 1]
    let previous = points[points.length() - 2]
    let dx = last.x - previous.x
    let dy = last.y - previous.y
    if (dx * dx + dy * dy).sqrt() < 2.0 {
      points.pop() |> ignore
    }
  }
  points
}

///|
fn is_finite_point(point : Point) -> Bool {
  !(point.x.is_nan() || point.x.is_inf() || point.y.is_nan() || point.y.is_inf())
}

///|
/// Mermaid's `sanitizeElkEdgePoints`: clip the route against its nodes and
/// drop repeated points.
fn sanitize_edge_points(
  points : Array[Point],
  start_node : ElkNode,
  end_node : ElkNode,
) -> Array[Point] {
  let previous = points.copy()
  let start_bounds = bounds_for(start_node)
  let end_bounds = bounds_for(end_node)
  let start_is_group = start_node.node.is_group
  let end_is_group = end_node.node.is_group
  let (start_candidate, start_center) = candidate_border_point(
    previous, start_node, true,
  )
  let (end_candidate, end_center) = candidate_border_point(
    previous, end_node, false,
  )
  let mut skip_start = start_is_group &&
    on_border(start_bounds, start_candidate)
  let mut skip_end = end_is_group && on_border(end_bounds, end_candidate)
  if skip_start && start_center && !previous.is_empty() {
    previous.remove(0) |> ignore
  }
  if skip_end && end_center && !previous.is_empty() {
    previous.pop() |> ignore
  }
  if start_is_group && !skip_start {
    skip_start = clip_group_endpoint(previous, start_bounds, true)
  }
  if end_is_group && !skip_end {
    skip_end = clip_group_endpoint(previous, end_bounds, false)
  }
  let mut clipped = if skip_start || skip_end {
    if !skip_start {
      apply_start_intersection(previous, start_node, start_bounds)
    }
    if !skip_end {
      apply_end_intersection(previous, end_node, end_bounds)
    }
    previous
  } else {
    cutter2(start_node, end_node, previous)
  }
  if clipped.length() < 2 || clipped.any(point => !is_finite_point(point)) {
    let cleaned = previous.filter(is_finite_point)
    clipped = if cleaned.length() >= 2 { cleaned } else { previous }
  }
  let deduped = []
  for index, point in clipped {
    if index == 0 {
      deduped.push(point)
      continue
    }
    let before = clipped[index - 1]
    if (point.x - before.x).abs() > 1.0e-6 ||
      (point.y - before.y).abs() > 1.0e-6 {
      deduped.push(point)
    }
  }
  deduped
}

///|
/// Drop a first segment too short to hold the start marker.
fn ensure_start_marker_segment(
  points : Array[Point],
  start_bounds : Bounds,
  marker_offset : Double,
) -> Array[Point] {
  if marker_offset <= 0.0 || points.length() < 3 {
    return points
  }
  let start = points[0]
  let exit = points[1]
  let length = @jsmath.hypot(exit.x - start.x, exit.y - start.y)
  if length >= 8.0.max(marker_offset * 2.0) {
    return points
  }
  if !on_border(start_bounds, exit, tol=1.0) {
    return points
  }
  let adjusted = [start]
  for index in 2..<points.length() {
    adjusted.push(points[index])
  }
  adjusted
}

///|
/// Drop a last segment too short to hold the end marker.
fn ensure_end_marker_segment(
  points : Array[Point],
  end_bounds : Bounds,
  marker_offset : Double,
) -> Array[Point] {
  if marker_offset <= 0.0 || points.length() < 3 {
    return points
  }
  let n = points.length()
  let end = points[n - 1]
  let entry = points[n - 2]
  let length = @jsmath.hypot(end.x - entry.x, end.y - entry.y)
  if length >= 8.0.max(marker_offset * 2.0) {
    return points
  }
  if !on_border(end_bounds, entry, tol=1.0) {
    return points
  }
  let adjusted = []
  for index in 0..<(n - 2) {
    adjusted.push(points[index])
  }
  adjusted.push(end)
  adjusted
}

///|
/// `h` or `v` for an axis-aligned segment, nothing otherwise.
fn axis_of(a : Point, b : Point) -> Char? {
  let dx = (b.x - a.x).abs()
  let dy = (b.y - a.y).abs()
  if dx > 0.01 && dy <= 0.01 {
    Some('h')
  } else if dy > 0.01 && dx <= 0.01 {
    Some('v')
  } else {
    None
  }
}

///|
/// A stretch of a route before and after it was moved.
priv struct StraightenedRun {
  old_a : Point
  old_b : Point
  new_a : Point
  new_b : Point
}

///|
fn js_sign(value : Double) -> Double {
  if value > 0.0 {
    1.0
  } else if value < 0.0 {
    -1.0
  } else {
    value
  }
}

///|
/// Collapse the small step ELK leaves right after a port: the port is
/// moved onto the row of the channel the edge continues in.
fn straighten_front(pts : Array[Point]) -> (Array[Point], StraightenedRun)? {
  if pts.length() < 5 {
    return None
  }
  let p0 = pts[0]
  let p1 = pts[1]
  let p2 = pts[2]
  let p3 = pts[3]
  guard axis_of(p0, p1) is Some(axis) else { return None }
  let other = if axis == 'h' { 'v' } else { 'h' }
  if axis_of(p2, p3) != Some(axis) || axis_of(p1, p2) != Some(other) {
    return None
  }
  if @jsmath.hypot(p1.x - p0.x, p1.y - p0.y) > 30.0 {
    return None
  }
  let jog = if axis == 'h' { (p2.y - p1.y).abs() } else { (p2.x - p1.x).abs() }
  if jog < 0.01 || jog > 16.0 {
    return None
  }
  let forward = if axis == 'h' {
    js_sign(p1.x - p0.x) == js_sign(p3.x - p2.x)
  } else {
    js_sign(p1.y - p0.y) == js_sign(p3.y - p2.y)
  }
  if !forward {
    return None
  }
  let mut last = 3
  while last + 1 < pts.length() &&
        axis_of(pts[last], pts[last + 1]) == Some(axis) {
    last += 1
  }
  if last == pts.length() - 1 {
    return None
  }
  let moved = pts.copy()
  for i in 2..<=last {
    moved[i] = if axis == 'h' {
      { x: pts[i].x, y: p0.y, }
    } else {
      { x: p0.x, y: pts[i].y, }
    }
  }
  let run = {
    old_a: pts[2],
    old_b: pts[last],
    new_a: moved[2],
    new_b: moved[last],
  }
  moved.remove(1) |> ignore
  moved.remove(1) |> ignore
  Some((moved, run))
}

///|
/// Straighten both ends of a route; nothing when neither changes.
fn straighten_terminal_jogs(
  points : Array[Point],
) -> (Array[Point], Array[StraightenedRun])? {
  let runs = []
  let mut pts = points
  let mut changed = false
  if straighten_front(pts) is Some((moved, run)) {
    pts = moved
    runs.push(run)
    changed = true
  }
  if straighten_front(pts.rev()) is Some((moved, run)) {
    pts = moved.rev()
    runs.push(run)
    changed = true
  }
  if changed {
    Some((pts, runs))
  } else {
    None
  }
}

///|
fn segments_cross_strict(
  a1 : Point,
  a2 : Point,
  b1 : Point,
  b2 : Point,
) -> Bool {
  let side = (o : Point, p : Point, q : Point) => {
    (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x)
  }
  let d1 = side(b1, b2, a1)
  let d2 = side(b1, b2, a2)
  let d3 = side(a1, a2, b1)
  let d4 = side(a1, a2, b2)
  ((d1 > 0.0 && d2 < 0.0) || (d1 < 0.0 && d2 > 0.0)) &&
  ((d3 > 0.0 && d4 < 0.0) || (d3 < 0.0 && d4 > 0.0))
}

///|
fn crossing_count(a : Array[Point], b : Array[Point]) -> Int32 {
  let mut n = 0
  for i in 0..<(a.length() - 1) {
    for j in 0..<(b.length() - 1) {
      if segments_cross_strict(a[i], a[i + 1], b[j], b[j + 1]) {
        n += 1
      }
    }
  }
  n
}

///|
/// Carry a label along with the stretch of route it sat on.
fn project_onto_run(label : Point, runs : Array[StraightenedRun]) -> Point? {
  let mut best : (Double, Point)? = None
  for run in runs {
    let a = run.old_a
    let b = run.old_b
    let abx = b.x - a.x
    let aby = b.y - a.y
    let len_sq = abx * abx + aby * aby
    let t = if len_sq == 0.0 {
      0.0
    } else {
      let raw = ((label.x - a.x) * abx + (label.y - a.y) * aby) / len_sq
      0.0.max(raw.min(1.0))
    }
    let old_point = { x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y), }
    let dx = old_point.x - label.x
    let dy = old_point.y - label.y
    let dist_sq = dx * dx + dy * dy
    if best is Some((best_dist, _)) && !(dist_sq < best_dist) {
      continue
    }
    best = Some(
      (
        dist_sq,
        {
          x: run.new_a.x + t * (run.new_b.x - run.new_a.x),
          y: run.new_a.y + t * (run.new_b.y - run.new_a.y),
        },
      ),
    )
  }
  best.map(pair => pair.1)
}

///|
/// A label's box: centre and size.
priv struct LabelArea {
  centre : Point
  width : Double
  height : Double
}

///|
fn segment_hits_box(a : Point, b : Point, area : LabelArea) -> Bool {
  let x1 = area.centre.x - area.width / 2.0
  let y1 = area.centre.y - area.height / 2.0
  let x2 = area.centre.x + area.width / 2.0
  let y2 = area.centre.y + area.height / 2.0
  let mut t0 = 0.0
  let mut t1 = 1.0
  let dx = b.x - a.x
  let dy = b.y - a.y
  for pair in [(-dx, a.x - x1), (dx, x2 - a.x), (-dy, a.y - y1), (dy, y2 - a.y)] {
    let (p, q) = pair
    if p == 0.0 {
      if q < 0.0 {
        return false
      }
    } else if p < 0.0 {
      t0 = t0.max(q / p)
    } else {
      t1 = t1.min(q / p)
    }
  }
  t0 < t1
}

///|
fn route_covers(route : Array[Point], label : LabelArea?) -> Int32 {
  guard label is Some(area) else { return 0 }
  for i in 0..<(route.length() - 1) {
    if segment_hits_box(route[i], route[i + 1], area) {
      return 1
    }
  }
  0
}

///|
/// Mermaid's `straightenEdgeTerminals`: straighten the ends of every route
/// unless that adds a crossing or runs an edge under a label. Labels move
/// with the stretch they sat on.
fn straighten_edge_terminals(edges : Array[Edge]) -> Unit {
  let routes = edges.map(edge => edge.points)
  let labels : Array[LabelArea?] = edges.map(edge => {
    match edge.position {
      Some(centre) if edge.label != "" &&
        edge.width != 0.0 &&
        edge.height != 0.0 =>
        Some({ centre, width: edge.width, height: edge.height, })
      _ => None
    }
  })
  for index, edge in edges {
    let original = routes[index]
    if original.length() < 5 {
      continue
    }
    guard straighten_terminal_jogs(original) is Some((candidate, runs)) else {
      continue
    }
    let label = labels[index]
    let candidate_label = match label {
      Some(area) =>
        match project_onto_run(area.centre, runs) {
          Some(moved) => Some({ ..area, centre: moved, })
          None => label
        }
      None => None
    }
    let mut before = 0
    let mut after = 0
    let mut covered_before = 0
    let mut covered_after = 0
    for other, route in routes {
      if other == index || route.length() < 2 {
        continue
      }
      before += crossing_count(original, route)
      after += crossing_count(candidate, route)
      covered_before += route_covers(route, label) +
        route_covers(original, labels[other])
      covered_after += route_covers(route, candidate_label) +
        route_covers(candidate, labels[other])
    }
    if after > before || covered_after > covered_before {
      continue
    }
    edge.points = candidate
    routes[index] = candidate
    labels[index] = candidate_label
    if edge.position is Some(position) &&
      project_onto_run(position, runs) is Some(projected) {
      edge.position = Some(projected)
    }
  }
}

///|
/// Two labelled edges joining the same pair of nodes in opposite
/// directions get their labels pushed apart.
fn separate_opposite_edge_labels(edges : Array[Edge]) -> Unit {
  let by_pair : Map[String, Array[Edge]] = Map([])
  for edge in edges {
    guard edge.position is Some(_) && edge.label != "" && edge.width != 0.0 else {
      continue
    }
    let key = if edge.start <= edge.end {
      "\{edge.start}\u{0}\{edge.end}"
    } else {
      "\{edge.end}\u{0}\{edge.start}"
    }
    match by_pair.get(key) {
      Some(bucket) => bucket.push(edge)
      None => by_pair[key] = [edge]
    }
  }
  for _, bucket in by_pair {
    guard bucket is [a, b] else { continue }
    guard a.position is Some(pa) && b.position is Some(pb) else { continue }
    if (pa.y - pb.y).abs() > a.height.max(b.height) {
      continue
    }
    let required = a.width / 2.0 + b.width / 2.0 + 4.0
    let current = pb.x - pa.x
    let deficit = required - current.abs()
    if deficit <= 0.0 {
      continue
    }
    let sign = if current < 0.0 { -1.0 } else { 1.0 }
    a.position = Some({ x: pa.x - sign * deficit / 2.0, y: pa.y, })
    b.position = Some({ x: pb.x + sign * deficit / 2.0, y: pb.y, })
  }
}
