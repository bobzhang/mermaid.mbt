// Reading ELK's result back into the layout data: node positions, group
// frames and edge routes. The second half of mermaid's
// `layout-algorithms/elk/render.ts`.

///|
fn json_field(json : Json, key : String) -> Json {
  match json {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn json_number(json : Json, key : String) -> Double {
  match json_field(json, key) {
    Number(value, ..) => value
    _ => 0.0
  }
}

///|
fn json_text(json : Json, key : String) -> String {
  match json_field(json, key) {
    String(value) => value
    _ => ""
  }
}

///|
fn json_items(json : Json, key : String) -> Array[Json] {
  match json_field(json, key) {
    Array(items) => items
    _ => []
  }
}

///|
fn json_point(json : Json) -> Point {
  { x: json_number(json, "x"), y: json_number(json, "y"), }
}

///|
/// An edge as ELK returned it.
priv struct ResultEdge {
  id : String
  source : String
  target : String
  /// The route of every section: start, bend points, end.
  sections : Array[Array[Point]]
  /// The position and size of the first label.
  label : (Double, Double, Double, Double)?
}

///|
fn result_edges(graph : Json) -> Array[ResultEdge] {
  json_items(graph, "edges").map(edge => {
    let first = (key : String) => {
      match json_items(edge, key) {
        [String(id), ..] => id
        _ => ""
      }
    }
    let sections = json_items(edge, "sections").map(section => {
      let points = [json_point(json_field(section, "startPoint"))]
      for bend in json_items(section, "bendPoints") {
        points.push(json_point(bend))
      }
      points.push(json_point(json_field(section, "endPoint")))
      points
    })
    let label = match json_items(edge, "labels") {
      [label, ..] =>
        Some(
          (
            json_number(label, "x"),
            json_number(label, "y"),
            json_number(label, "width"),
            json_number(label, "height"),
          ),
        )
      _ => None
    }
    {
      id: json_text(edge, "id"),
      source: first("sources"),
      target: first("targets"),
      sections,
      label,
    }
  })
}

///|
/// Mermaid's `applyElkNodePositions`.
fn apply_node_positions(
  result_nodes : Array[Json],
  state : ElkState,
  rel_x : Double,
  rel_y : Double,
) -> Unit {
  for node in result_nodes {
    guard state.node_db.get(json_text(node, "id")) is Some(graph_node) else {
      continue
    }
    let width = json_number(node, "width")
    let height = json_number(node, "height")
    let label_width = match graph_node.label_data {
      Some(label) => label.width
      None => 0.0
    }
    let offset : Offset = {
      pos_x: json_number(node, "x") + rel_x,
      pos_y: json_number(node, "y") + rel_y,
    }
    graph_node.offset = Some(offset)
    graph_node.x = offset.pos_x + width / 2.0
    graph_node.y = offset.pos_y + height / 2.0
    graph_node.width = Some(width)
    graph_node.height = Some(height)
    let layout_node = graph_node.node
    layout_node.x = graph_node.x
    layout_node.y = graph_node.y
    layout_node.width = Some(
      if layout_node.is_group {
        width.max(label_width)
      } else {
        width
      },
    )
    layout_node.height = Some(height)
    if layout_node.is_group {
      apply_node_positions(
        json_items(node, "children"),
        state,
        offset.pos_x,
        offset.pos_y,
      )
    }
  }
}

///|
fn collect_descendants(node : ElkNode, into : Map[String, Unit]) -> Unit {
  for child in node.children {
    into[child.node.id] = ()
    collect_descendants(child, into)
  }
}

///|
/// The origin edge sections between two nodes are relative to: that of
/// the container holding both.
fn ElkState::edge_offset(
  self : ElkState,
  source : String,
  target : String,
) -> Point {
  let ancestor = self.tree.common_ancestor(source, target)
  if ancestor == "root" {
    return { x: 0.0, y: 0.0, }
  }
  guard self.node_db.get(ancestor) is Some(node) else {
    return { x: 0.0, y: 0.0, }
  }
  match (node.elk_origin, node.offset) {
    (Some(origin), _) => origin
    (None, Some(offset)) => { x: offset.pos_x, y: offset.pos_y, }
    (None, None) => { x: 0.0, y: 0.0, }
  }
}

///|
/// The points of every edge routed inside a group, plus where edges ending
/// on the group itself attach.
fn internal_edge_points(
  edges : Array[ResultEdge],
  descendants : Map[String, Unit],
  state : ElkState,
  group_id : String,
) -> Array[Point] {
  let points = []
  for edge in edges {
    let is_internal = descendants.contains(edge.source) &&
      descendants.contains(edge.target)
    let at_start = edge.source == group_id
    let at_end = edge.target == group_id
    if !is_internal && !at_start && !at_end {
      continue
    }
    let offset = state.edge_offset(edge.source, edge.target)
    for section in edge.sections {
      let picked = if is_internal {
        section
      } else {
        let picked = []
        if at_start {
          picked.push(section[0])
        }
        if at_end {
          picked.push(section[section.length() - 1])
        }
        picked
      }
      for p in picked {
        points.push({ x: p.x + offset.x, y: p.y + offset.y, })
      }
    }
  }
  points
}

///|
/// Pull each group's frame in to an even distance from its contents:
/// mermaid's `evenGroupFrames`.
fn even_group_frames(
  nodes : Array[ElkNode],
  state : ElkState,
  edges : Array[ResultEdge],
) -> Unit {
  for group in nodes {
    guard group.node.is_group else { continue }
    even_group_frames(group.children, state, edges)
    guard group.offset is Some(origin) else { continue }
    let xs = []
    let ys = []
    for child in group.children {
      guard child.offset is Some(offset) else { continue }
      let width = child.width.unwrap_or(0.0)
      let height = child.height.unwrap_or(0.0)
      guard width != 0.0 && height != 0.0 else { continue }
      xs.push(offset.pos_x)
      xs.push(offset.pos_x + width)
      ys.push(offset.pos_y)
      ys.push(offset.pos_y + height)
    }
    guard !xs.is_empty() else { continue }
    let descendants : Map[String, Unit] = Map([])
    collect_descendants(group, descendants)
    for p in internal_edge_points(edges, descendants, state, group.node.id) {
      xs.push(p.x)
      ys.push(p.y)
    }
    let minimum = (values : Array[Double]) => {
      values.fold(init=values[0], (a, b) => if b < a { b } else { a })
    }
    let maximum = (values : Array[Double]) => {
      values.fold(init=values[0], (a, b) => if b > a { b } else { a })
    }
    let group_width = group.width.unwrap_or(0.0)
    let group_height = group.height.unwrap_or(0.0)
    // Only ever pull a frame in.
    let left = origin.pos_x.max(minimum(xs) - SUBGRAPH_PADDING)
    let right = (origin.pos_x + group_width).min(maximum(xs) + SUBGRAPH_PADDING)
    let bottom = (origin.pos_y + group_height).min(
      maximum(ys) + SUBGRAPH_PADDING,
    )
    let top = origin.pos_y
    let label_floor = group.title_width()
    let mut x = left
    let mut width = right - left
    if width < label_floor {
      x = x - (label_floor - width) / 2.0
      width = label_floor
      let original_right = origin.pos_x + group_width
      x = origin.pos_x.max(x.min(original_right - width))
      width = width.min(group_width)
    }
    let height = bottom - top
    if height <= 0.0 || width <= 0.0 {
      continue
    }
    if group.elk_origin is None {
      group.elk_origin = Some({ x: origin.pos_x, y: origin.pos_y, })
    }
    origin.pos_x = x
    group.width = Some(width)
    group.height = Some(height)
    group.x = x + width / 2.0
    group.y = top + height / 2.0
    group.node.x = group.x
    group.node.y = group.y
    group.node.width = Some(width)
    group.node.height = Some(height)
  }
}

///|
/// A node too narrow to offer a port anywhere but its middle is moved so
/// that its middle meets the port ELK chose.
fn align_degenerate_node(
  node : ElkNode,
  anchor : Point,
  aligned : Map[String, Unit],
) -> Unit {
  guard node.offset is Some(offset) else { return }
  let width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  let top = offset.pos_y
  let bottom = top + height
  let along_width = (anchor.y - top).abs() <= 0.5 ||
    (anchor.y - bottom).abs() <= 0.5
  if (if along_width { width } else { height }) >=
    2.0 * PORTS_SURROUNDING_MARGIN {
    return
  }
  if aligned.contains(node.node.id) {
    return
  }
  aligned[node.node.id] = ()
  let delta = if along_width {
    anchor.x - (offset.pos_x + width / 2.0)
  } else {
    anchor.y - (offset.pos_y + height / 2.0)
  }
  if delta.abs() < 0.01 {
    return
  }
  if along_width {
    offset.pos_x = offset.pos_x + delta
    node.x = offset.pos_x + width / 2.0
  } else {
    offset.pos_y = offset.pos_y + delta
    node.y = offset.pos_y + height / 2.0
  }
  node.node.x = offset.pos_x + width / 2.0
  node.node.y = offset.pos_y + height / 2.0
}

///|
/// How far the drawn path is pulled back from an end to make room for the
/// marker there.
fn marker_path_offset(arrow_type : String) -> Double {
  marker_offset(arrow_type).max(marker_offset2(arrow_type))
}

///|
/// Mermaid's `applyElkEdgeLayout`.
fn apply_edge_layout(
  data : LayoutData,
  state : ElkState,
  edges : Array[ResultEdge],
) -> Unit {
  let elk_edges : Map[String, ElkEdge] = Map([])
  for edge in state.edges {
    if !elk_edges.contains(edge.edge.id) {
      elk_edges[edge.edge.id] = edge
    }
  }
  let aligned : Map[String, Unit] = Map([])
  for edge in edges {
    guard edge.sections is [section, ..] else { continue }
    guard state.node_db.get(edge.source) is Some(start_node) else { continue }
    guard state.node_db.get(edge.target) is Some(end_node) else { continue }
    let offset = state.edge_offset(edge.source, edge.target)
    let first = section[0]
    let last = section[section.length() - 1]
    align_degenerate_node(
      start_node,
      { x: first.x + offset.x, y: first.y + offset.y, },
      aligned,
    )
    align_degenerate_node(
      end_node,
      { x: last.x + offset.x, y: last.y + offset.y, },
      aligned,
    )
  }
  for edge in edges {
    guard elk_edges.get(edge.id) is Some(elk_edge) else { continue }
    let layout_edge = elk_edge.edge
    let (start_id, end_id) = if elk_edge.reversed {
      (edge.target, edge.source)
    } else {
      (edge.source, edge.target)
    }
    guard state.node_db.get(start_id) is Some(start_node) else { continue }
    guard state.node_db.get(end_id) is Some(end_node) else { continue }
    let centre = (node : ElkNode) => {
      let (x, y) = match node.offset {
        Some(offset) => (offset.pos_x, offset.pos_y)
        None => (node.x, node.y)
      }
      {
        x: x + node.width.unwrap_or(0.0) / 2.0,
        y: y + node.height.unwrap_or(0.0) / 2.0,
      }
    }
    let from = centre(start_node)
    let to = centre(end_node)
    start_node.x = from.x
    start_node.y = from.y
    end_node.x = to.x
    end_node.y = to.y
    guard edge.sections is [section, ..] else {
      // Nothing routed: a straight line between the two nodes.
      let straight = sanitize_edge_points([from, to], start_node, end_node)
      layout_edge.points = straight
      layout_edge.curve = "linear"
      let line_start = straight[0]
      let line_end = straight[straight.length() - 1]
      layout_edge.position = Some({
        x: (line_start.x + line_end.x) / 2.0,
        y: (line_start.y + line_end.y) / 2.0,
      })
      continue
    }
    let offset = state.edge_offset(layout_edge.start, layout_edge.end)
    let points = section.map(p => { x: p.x + offset.x, y: p.y + offset.y, })
    if elk_edge.reversed {
      points.rev_in_place()
    }
    points.insert(0, from)
    points.push(to)
    let clipped = sanitize_edge_points(points, start_node, end_node)
    layout_edge.points = ensure_start_marker_segment(
      ensure_end_marker_segment(
        clipped,
        bounds_for(end_node),
        marker_path_offset(layout_edge.arrow_type_end),
      ),
      bounds_for(start_node),
      marker_path_offset(layout_edge.arrow_type_start),
    )
    layout_edge.curve = "rounded"
    if edge.label is Some((x, y, width, height)) {
      layout_edge.position = Some({
        x: x + offset.x + width / 2.0,
        y: y + offset.y + height / 2.0,
      })
    }
  }
  if !(data.config.get("elk.straightenEdges") is False) {
    straighten_edge_terminals(data.edges)
  }
  settle_terminal_labels(data.edges, data.nodes)
  separate_opposite_edge_labels(data.edges)
}

///|
/// Draw containers before their contents, outermost first: mermaid's
/// `orderNodesForElkPaint`.
fn order_nodes_for_paint(nodes : Array[Node]) -> Unit {
  let by_id : Map[String, Node] = Map([])
  for node in nodes {
    by_id[node.id] = node
  }
  let depth = (node : Node) => {
    let mut depth = 0
    let visited : Map[String, Unit] = Map([])
    let mut parent_id = node.parent_id
    while parent_id is Some(id) {
      if visited.contains(id) {
        break
      }
      visited[id] = ()
      guard by_id.get(id) is Some(parent) && parent.is_group else { break }
      depth += 1
      parent_id = parent.parent_id
    }
    depth
  }
  // A stable sort, as JavaScript's is.
  let keyed = nodes.mapi((index, node) => {
    (if node.is_group { depth(node) } else { 1 << 30 }, index, node)
  })
  keyed.sort_by((a, b) => {
    if a.0 != b.0 {
      a.0.compare(b.0)
    } else {
      a.1.compare(b.1)
    }
  })
  for index, entry in keyed {
    nodes[index] = entry.2
  }
}
