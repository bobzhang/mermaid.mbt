// Drawing the edges of a dagre layout: mermaid's `insertEdge` for routes
// that still run to the centres of their nodes (`rendering-elements/
// edges.js`), the cutting of routes at the frames of groups, the routes of
// self loops (`layout-algorithms/dagre/index.js`), and the placement of
// labels along a route (`utils.ts`).

///|
/// The distance between two points, nothing when one is missing:
/// `Math.sqrt(Math.pow(dx, 2) + Math.pow(dy, 2))` (V8's `Math.pow(x, 2)`
/// is `x * x` to the last bit).
fn point_distance(p1 : Point, p2 : Point?) -> Double {
  guard p2 is Some(p2) else { return 0.0 }
  let dx = p2.x - p1.x
  let dy = p2.y - p1.y
  (dx * dx + dy * dy).sqrt()
}

///|
/// `Math.round(num * 10 ** 5) / 10 ** 5`.
fn round5(num : Double) -> Double {
  @d3.js_round(num * 100000.0) / 100000.0
}

///|
/// The point `distance` along a route: mermaid's `calculatePoint`.
fn calculate_point(
  points : Array[Point],
  distance : Double,
) -> Point raise LayoutError {
  let mut prev : Point? = None
  let mut remaining = distance
  for point in points {
    if prev is Some(prev_point) {
      let vector_distance = point_distance(point, Some(prev_point))
      if vector_distance == 0.0 {
        return prev_point
      }
      if vector_distance < remaining {
        remaining -= vector_distance
      } else {
        let ratio = remaining / vector_distance
        if ratio <= 0.0 {
          return prev_point
        }
        if ratio >= 1.0 {
          return { x: point.x, y: point.y, }
        }
        if ratio > 0.0 && ratio < 1.0 {
          return {
            x: round5((1.0 - ratio) * prev_point.x + ratio * point.x),
            y: round5((1.0 - ratio) * prev_point.y + ratio * point.y),
          }
        }
      }
    }
    prev = Some(point)
  }
  raise LayoutError("Could not find a suitable point for the given distance")
}

///|
/// The middle of a route by length: mermaid's `calcLabelPosition`.
fn calc_label_position(points : Array[Point]) -> Point raise LayoutError {
  if points.length() == 1 {
    return points[0]
  }
  let mut total = 0.0
  let mut prev : Point? = None
  for point in points {
    total += point_distance(point, prev)
    prev = Some(point)
  }
  calculate_point(points, total / 2.0)
}

///|
/// Where a label at an end of a route goes: beside the route, 25 pixels
/// (and the size of the marker) along it. Mermaid's
/// `calcTerminalLabelPosition`.
fn calc_terminal_label_position(
  marker_size : Double,
  position : String,
  route : Array[Point],
) -> Point raise LayoutError {
  let points = route.copy()
  if position != "start_left" && position != "start_right" {
    points.rev_in_place()
  }
  let centre = calculate_point(points, 25.0 + marker_size)
  let d = 10.0 + marker_size * 0.5
  let first = points[0]
  let angle = @jsmath.atan2(first.y - centre.y, first.x - centre.x)
  let pi = 3.141592653589793
  let turned = match position {
    "start_left" => angle + pi
    "end_right" => angle - pi
    _ => angle
  }
  {
    x: @jsmath.sin(turned) * d + (first.x + centre.x) / 2.0,
    y: -@jsmath.cos(turned) * d + (first.y + centre.y) / 2.0,
  }
}

///|
/// `String(Math.round(value))`.
fn rounded_text(value : Double) -> String {
  @d3.number(@d3.js_round(value))
}

///|
/// Whether the middle of a route shows in the path drawn for it, by its
/// rounded coordinates: mermaid's `isLabelCoordinateInPath`.
fn is_label_coordinate_in_path(point : Point, d : String) -> Bool {
  // Every `\d+\.\d+` of the path is replaced by its rounded value.
  let sanitized = StringBuilder()
  let n = d.length()
  let is_digit = (i : Int32) => i < n && d[i] >= '0' && d[i] <= '9'
  let mut i = 0
  while i < n {
    if is_digit(i) {
      let mut j = i
      while is_digit(j) {
        j += 1
      }
      if j < n && d[j] == '.' && is_digit(j + 1) {
        let mut k = j + 1
        while is_digit(k) {
          k += 1
        }
        let value = @string.parse_double(d[i:k]) catch { _ => 0.0 }
        sanitized.write_string(rounded_text(value))
        i = k
        continue
      }
      // No fraction after these digits: a match cannot start in them.
      sanitized.write_string(d[i:j].to_owned())
      i = j
      continue
    }
    sanitized.write_char(d.get_char(i).unwrap_or(' '))
    i += 1
  }
  let text = sanitized.to_string()
  text.contains(rounded_text(point.x)) || text.contains(rounded_text(point.y))
}

///|
/// The box of a node as the layout left it, for cutting routes at frames.
fn dagre_bounds(node : DagreNode) -> Bounds? {
  match node {
    Leaf(node) =>
      Some({
        x: node.x,
        y: node.y,
        width: node.width.unwrap_or(@double.not_a_number),
        height: node.height.unwrap_or(@double.not_a_number),
      })
    Extracted(cluster) =>
      Some({
        x: cluster.x,
        y: cluster.y,
        width: cluster.width,
        height: cluster.height,
      })
    Unlabelled => None
  }
}

///|
/// Where the segment from `inside` to `outside` crosses the frame of a
/// group: mermaid's `intersection` in `edges.js`.
fn frame_intersection(node : Bounds, outside : Point, inside : Point) -> Point {
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
    let mut rx = if inside.x < outside.x {
      inside.x + r
    } else {
      inside.x - r_len + r
    }
    let mut ry = if inside.y < outside.y {
      inside.y + q_len - q
    } else {
      inside.y - q_len + q
    }
    if r == 0.0 {
      rx = outside.x
      ry = outside.y
    }
    if r_len == 0.0 {
      rx = outside.x
    }
    if q_len == 0.0 {
      ry = outside.y
    }
    { x: rx, y: ry, }
  } else {
    let r = if inside.x < outside.x {
      outside.x - w - x
    } else {
      x - w - outside.x
    }
    let q = q_len * r / r_len
    let mut rx = if inside.x < outside.x {
      inside.x + r_len - r
    } else {
      inside.x - r_len + r
    }
    let mut ry = if inside.y < outside.y { inside.y + q } else { inside.y - q }
    if r == 0.0 {
      rx = outside.x
      ry = outside.y
    }
    if r_len == 0.0 {
      rx = outside.x
    }
    if q_len == 0.0 {
      ry = outside.y
    }
    { x: rx, y: ry, }
  }
}

///|
/// The route up to where it first enters the frame of a group: mermaid's
/// `cutPathAtIntersect`.
fn cut_path_at_intersect(points : Array[Point], frame : Bounds) -> Array[Point] {
  let result : Array[Point] = []
  guard points is [first, ..] else { return result }
  let mut last_point_outside = first
  let mut is_inside = false
  for point in points {
    if !outside_node(frame, point) && !is_inside {
      let inter = frame_intersection(frame, last_point_outside, point)
      if !result.iter().any(e => e.x == inter.x && e.y == inter.y) {
        result.push(inter)
      }
      is_inside = true
    } else {
      last_point_outside = point
      if !is_inside {
        result.push(point)
      }
    }
  }
  result
}

///|
/// The routes drawn for an edge: the one the edge was laid out along and,
/// when the drawn one differs, that one too.
priv struct DagrePaths {
  updated : Array[Point]?
  original : Array[Point]
}

///|
/// Where the line from the centre of a node towards `point` leaves it, if
/// the node can tell.
fn dagre_intersect(node : DagreNode?) -> ((Point) -> Point raise LayoutError)? {
  guard node is Some(Leaf(node)) && node.intersect is Some(_) else {
    return None
  }
  Some(point => {
    match node.leaves_at(point) {
      Some(found) => found
      // Upstream puts the node itself into the route.
      None =>
        raise LayoutError(
          "An edge that does not cross the outline of \{node.id} is not supported yet.",
        )
    }
  })
}

///|
/// Draw an edge along the route the layout gave it: mermaid's `insertEdge`
/// for the dagre layout. The route is clipped to the outlines of the nodes
/// at its ends and cut at the frames of the groups it was redirected from
/// or to.
fn DagreState::insert_dagre_edge(
  self : DagreState,
  group : @dom.Element,
  edge : DagreEdge,
  start : DagreNode?,
  end : DagreNode?,
) -> DagrePaths raise LayoutError {
  let layout_edge = edge.edge
  let route = layout_edge.points
  let mut points = route
  let mut points_has_changed = false
  match (dagre_intersect(end), dagre_intersect(start)) {
    (Some(head), Some(tail)) => {
      guard route.length() >= 3 else {
        raise LayoutError(
          "A route of \{route.length()} points is not supported.",
        )
      }
      let inner = route[1:route.length() - 1].to_owned()
      let first = tail(inner[0])
      let last = head(inner[inner.length() - 1])
      points = [first, ..inner, last]
    }
    _ => ()
  }
  let points_text = points_json(points)
  if edge.to_cluster is Some(cluster) {
    guard self.cluster_db.get(cluster) is Some(entry) &&
      entry.node.bind(dagre_bounds) is Some(frame) else {
      raise LayoutError("The group \{cluster} has no frame to cut an edge at.")
    }
    points = cut_path_at_intersect(route, frame)
    points_has_changed = true
  }
  if edge.from_cluster is Some(cluster) {
    guard self.cluster_db.get(cluster) is Some(entry) &&
      entry.node.bind(dagre_bounds) is Some(frame) else {
      raise LayoutError("The group \{cluster} has no frame to cut an edge at.")
    }
    // `points.reverse()` reverses the route itself when nothing replaced
    // it yet: what the label is placed by is reversed then too.
    points.rev_in_place()
    let cut = cut_path_at_intersect(points, frame)
    cut.rev_in_place()
    points = cut
    points_has_changed = true
  }
  let mut line_data = points.filter(p => !p.y.is_nan())
  let curve = if layout_edge.curve != "" {
    layout_edge.curve
  } else {
    self.data.config.text("flowchart.curve").unwrap_or("basis")
  }
  if curve != "rounded" {
    line_data = fix_corners(line_data)
  }
  let path = if curve == "rounded" {
    rounded_path(apply_marker_offsets(line_data, layout_edge), 5.0)
  } else if line_data.is_empty() {
    raise LayoutError("An edge without a point to draw is not supported.")
  } else {
    let offset = offset_line_points(line_data, layout_edge)
    match @d3.line(curve, offset) {
      Some(path) => path
      None => @d3.line("basis", offset).unwrap_or("")
    }
  }
  let drawn = insert_edge(group, layout_edge, self.data, path~, points_text~)
  // The middle of the route has to show in the path drawn (the sketch of
  // it in the hand-drawn look), or the label follows the drawn path.
  if points.get(points.length() / 2) is Some(middle) &&
    !is_label_coordinate_in_path(middle, drawn.get_attr("d").unwrap_or(path)) {
    points_has_changed = true
  }
  {
    updated: if points_has_changed {
      Some(points)
    } else {
      None
    },
    original: route,
  }
}

///|
/// Where the centre label of an edge goes: where the layout put it, moved
/// as much as the middle of the drawn route moved. Mermaid's
/// `resolveEdgeLabelPosition`.
fn resolve_edge_label_position(
  edge : Edge,
  paths : DagrePaths,
) -> (Double, Double) raise LayoutError {
  let (x, y) = match edge.position {
    Some(position) => (position.x, position.y)
    None => (@double.not_a_number, @double.not_a_number)
  }
  guard paths.updated is Some(updated) else { return (x, y) }
  let updated_mid = calc_label_position(updated)
  let original_mid = calc_label_position(paths.original)
  (x + (updated_mid.x - original_mid.x), y + (updated_mid.y - original_mid.y))
}

///|
/// Move the labels of an edge to their places: mermaid's
/// `positionEdgeLabel` and `positionRenderedEdgeLabel`.
fn DagreState::position_edge_label(
  self : DagreState,
  edge : Edge,
  paths : DagrePaths,
  title_margin : Double,
) -> Unit raise LayoutError {
  let n = @dom.number
  if edge.label != "" {
    guard self.edge_labels.get(edge.id) is Some(element) else {
      raise LayoutError("The label of the edge \{edge.id} was never drawn.")
    }
    let (x, y) = resolve_edge_label_position(edge, paths)
    // A label the layout gave no place is at `undefined`.
    let x_text = if edge.position is None && paths.updated is None {
      "undefined"
    } else {
      n(x)
    }
    element.attr(
      "transform",
      "translate(\{x_text}, \{n(y + title_margin / 2.0)})",
    )
    |> ignore
  }
  let path = paths.updated.unwrap_or(paths.original)
  let terminals = self.terminal_labels.get(edge.id).unwrap_or([])
  for terminal in terminals {
    let at_start = terminal.key.has_prefix("start")
    let arrow_type = if at_start {
      edge.arrow_type_start
    } else {
      edge.arrow_type_end
    }
    let side = match terminal.key {
      "startLeft" => "start_left"
      "startRight" => "start_right"
      "endLeft" => "end_left"
      _ => "end_right"
    }
    let position = calc_terminal_label_position(
      if arrow_type != "" {
        10.0
      } else {
        0.0
      },
      side,
      path,
    )
    terminal.element.attr(
      "transform",
      "translate(\{n(position.x)}, \{n(position.y)})",
    )
    |> ignore
  }
}

///|
/// Which side of its node a self loop goes around: away from where the
/// layout put the two nodes it was routed through. Mermaid's
/// `getSelfLoopSide`.
fn self_loop_side(
  graph : DagreGraph,
  node : Bounds,
  segments : Array[(DagreEdge, String, String)],
  original_node_id : String,
  rankdir : String?,
) -> String {
  let default_side = match rankdir {
    Some("BT") => "bottom"
    Some("LR") => "right"
    Some("RL") => "left"
    _ => "top"
  }
  let dummy_ids : Array[String] = []
  for segment in segments {
    let (_, start, end) = segment
    for id in [start, end] {
      if id != original_node_id && !dummy_ids.contains(id) {
        dummy_ids.push(id)
      }
    }
  }
  let hints : Array[Point] = []
  for id in dummy_ids {
    if graph.node(id).bind(dagre_bounds) is Some(dummy) &&
      !dummy.x.is_nan() &&
      !dummy.y.is_nan() {
      hints.push({ x: dummy.x, y: dummy.y, })
    }
  }
  if hints.is_empty() {
    for segment in segments {
      for point in segment.0.edge.points {
        hints.push(point)
      }
    }
  }
  if hints.is_empty() {
    return default_side
  }
  let count = hints.length().to_double()
  let mut cx = 0.0
  let mut cy = 0.0
  for point in hints {
    cx = cx + point.x / count
    cy = cy + point.y / count
  }
  let dx = cx - node.x
  let dy = cy - node.y
  if dx.abs() > dy.abs() {
    return if dx > 0.0 { "right" } else { "left" }
  }
  if dy.abs() > 0.0 {
    return if dy > 0.0 { "bottom" } else { "top" }
  }
  default_side
}

///|
/// `Math.max(min, Math.min(max, value))`.
fn clamp(value : Double, min : Double, max : Double) -> Double {
  @dagre.js_max(min, @dagre.js_min(max, value))
}

///|
/// The four corners of a self loop on one side of its node: mermaid's
/// `getSelfLoopPoints`.
fn self_loop_points(
  node : Bounds,
  side : String,
  y_offset : Double,
  label_width : Double,
) -> Array[Point] {
  let x = node.x
  let y = node.y - y_offset
  let half_width = node.width / 2.0
  let half_height = node.height / 2.0
  let max_span = @dagre.js_max(36.0, @dagre.js_min(100.0, node.width * 0.8))
  let span = clamp(
    @dagre.js_max(label_width, node.width * 0.35),
    36.0,
    max_span,
  )
  let depth = clamp(@dagre.js_min(node.width, node.height) * 0.45, 24.0, 48.0)
  match side {
    "bottom" => {
      let bottom = y + half_height
      [
        { x: x - span / 2.0, y: bottom, },
        { x: x - span / 2.0, y: bottom + depth, },
        { x: x + span / 2.0, y: bottom + depth, },
        { x: x + span / 2.0, y: bottom, },
      ]
    }
    "right" => {
      let right = x + half_width
      [
        { x: right, y: y - span / 2.0, },
        { x: right + depth, y: y - span / 2.0, },
        { x: right + depth, y: y + span / 2.0, },
        { x: right, y: y + span / 2.0, },
      ]
    }
    "left" => {
      let left = x - half_width
      [
        { x: left, y: y - span / 2.0, },
        { x: left - depth, y: y - span / 2.0, },
        { x: left - depth, y: y + span / 2.0, },
        { x: left, y: y + span / 2.0, },
      ]
    }
    _ => {
      let top = y - half_height
      [
        { x: x - span / 2.0, y: top, },
        { x: x - span / 2.0, y: top - depth, },
        { x: x + span / 2.0, y: top - depth, },
        { x: x + span / 2.0, y: top, },
      ]
    }
  }
}

///|
/// The centre of the label of a self loop, outside the loop: mermaid's
/// `getSelfLoopLabelPosition`.
fn self_loop_label_position(
  node : Bounds,
  points : Array[Point],
  side : String,
  y_offset : Double,
  label_width : Double,
  label_height : Double,
) -> Point {
  let gap = 4.0
  let x = node.x
  let y = node.y - y_offset
  let xs = points.map(point => point.x)
  let ys = points.map(point => point.y)
  let max = (values : Array[Double]) => {
    values.fold(init=@double.neg_infinity, (a, b) => @dagre.js_max(a, b))
  }
  let min = (values : Array[Double]) => {
    values.fold(init=@double.infinity, (a, b) => @dagre.js_min(a, b))
  }
  match side {
    "bottom" => { x, y: max(ys) + label_height / 2.0 + gap, }
    "right" => { x: max(xs) + label_width / 2.0 + gap, y, }
    "left" => { x: min(xs) - label_width / 2.0 - gap, y, }
    _ => { x, y: min(ys) - label_height / 2.0 - gap, }
  }
}

///|
/// The edges to draw, with the three pieces of each self loop merged into
/// one loop on the side of its node: mermaid's `getEdgesToRender`. Each
/// comes with the ids of its ends.
fn edges_to_render(
  graph : DagreGraph,
  y_offset : Double,
  merge_self_loops : Bool,
) -> Array[(DagreEdge, String, String)] {
  let groups : Map[String, Array[(DagreEdge, String, String)]] = Map([])
  let result = []
  let rankdir = graph.graph().rankdir
  for e in graph.edges() {
    guard graph.edge(e) is Some(edge) else { continue }
    if merge_self_loops && edge.self_loop is Some((id, _)) {
      match groups.get(id) {
        Some(group) => group.push((edge, e.v, e.w))
        None => groups[id] = [(edge, e.v, e.w)]
      }
    } else {
      result.push((edge, e.v, e.w))
    }
  }
  for _, segments in groups {
    if segments.length() != 3 {
      result.append(segments)
      continue
    }
    let order = (segment : (DagreEdge, String, String)) => {
      match segment.0.self_loop {
        Some((_, order)) => order
        None => 0
      }
    }
    segments.sort_by((a, b) => order(a) - order(b))
    let (first, middle, last) = (segments[0].0, segments[1].0, segments[2].0)
    let original = match (first.original, middle.original, last.original) {
      (Some(original), _, _)
      | (_, Some(original), _)
      | (_, _, Some(original)) => original
      _ => middle.edge
    }
    guard graph.node(original.start).bind(dagre_bounds) is Some(node) else {
      result.append(segments)
      continue
    }
    let label_width = middle.edge.width
    let label_height = middle.edge.height
    let side = self_loop_side(graph, node, segments, original.start, rankdir)
    let points = self_loop_points(node, side, y_offset, label_width)
    let position = self_loop_label_position(
      node, points, side, y_offset, label_width, label_height,
    )
    let merged : Edge = {
      ..original,
      points,
      position: Some(position),
      width: label_width,
      height: label_height,
      label_style: middle.edge.label_style,
    }
    // `a ?? b ?? c`
    let pick = (a : String?, b : String?, c : String?) => {
      match (a, b) {
        (Some(_), _) => a
        (None, Some(_)) => b
        (None, None) => c
      }
    }
    result.push(
      (
        {
          edge: merged,
          from_cluster: pick(
            first.from_cluster,
            middle.from_cluster,
            last.from_cluster,
          ),
          to_cluster: pick(first.to_cluster, middle.to_cluster, last.to_cluster),
          self_loop: None,
          original: None,
        },
        original.start,
        original.end,
      ),
    )
  }
  result
}
