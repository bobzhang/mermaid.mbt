// Flowcharts laid out in lanes: the swimlane layout's renderer
// (`layout-algorithms/swimlanes/index.ts` on top of
// `layout-algorithms/common`). The layout itself is `internal/swimlane`;
// this file hands it the measured nodes and draws what it returns.

///|
/// The edge of the layout the label node of an edge stands for, and the
/// rendering node for every node the layout adds.
fn swimlane_node(model : @swimlane_model.Node, data : LayoutData) -> Node {
  let look = model.look.unwrap_or("")
  let node = Node::new(
    id=model.id,
    label=model.label,
    parent_id?=model.parent_id,
    padding=model.padding.unwrap_or(0.0),
    dir?=model.dir,
    look~,
    is_group=model.is_group,
    shape=model.shape,
    color_index?=model.color_index,
  )
  ignore(data)
  node.label_style = model.label_style
  node
}

///|
/// The layout's view of a node: the fields the swimlane layout reads.
fn swimlane_model_node(node : Node) -> @swimlane_model.Node {
  @swimlane_model.Node::new(
    id=node.id,
    label=node.label,
    is_group=node.is_group,
    parent_id?=node.parent_id,
    padding=node.padding,
    shape=node.shape,
    dir?=node.dir,
    look?=if node.look == "" { None } else { Some(node.look) },
    color_index?=node.color_index,
    label_style=node.label_style,
  )
}

///|
/// The edge's label style as the label node gets it: the first of the
/// edge's styles (flowchart edges keep their label styles in an array).
fn first_label_style(edge : Edge) -> String {
  match edge.style {
    [first, ..] => first
    [] => ""
  }
}

///|
/// Where an edge meets its nodes, as `insertEdge` clips a swimlane route:
/// the ends are moved onto the shapes' outlines, an end pinned on its
/// neighbour stays, and ends that land on their neighbours are dropped.
fn swimlane_clipped_points(
  points : Array[@swimlane_model.Pt],
  tail : Node,
  head : Node,
) -> Array[Point] {
  let points : Array[Point] = points.map(p => { x: p.x, y: p.y, })
  guard tail.intersect is Some(tail_intersect) &&
    head.intersect is Some(head_intersect) &&
    points.length() >= 2 else {
    return points
  }
  if points.length() == 2 {
    return [tail_intersect(points[0]), head_intersect(points[1])]
  }
  let inner_points = points[1:points.length() - 1].to_owned()
  let first_inner = inner_points[0]
  let last_inner = inner_points[inner_points.length() - 1]
  let tolerance = 0.5
  let last = points[points.length() - 1]
  let last_is_pinned = (last.x - last_inner.x).abs() < tolerance &&
    (last.y - last_inner.y).abs() < tolerance
  let new_first = tail_intersect(first_inner)
  let new_last = if last_is_pinned {
    last_inner
  } else {
    head_intersect(last_inner)
  }
  let last_is_duplicate = (new_last.x - last_inner.x).abs() < tolerance &&
    (new_last.y - last_inner.y).abs() < tolerance
  let first_is_duplicate = (new_first.x - first_inner.x).abs() < tolerance &&
    (new_first.y - first_inner.y).abs() < tolerance
  let result = []
  if !first_is_duplicate {
    result.push(new_first)
  }
  result.append(inner_points)
  if !last_is_duplicate {
    result.push(new_last)
  }
  result
}

///|
/// Lay out `data` with the swimlane layout and draw it into the first group
/// of `svg`: `render` with the `swimlane` layout algorithm.
fn render_swimlane(
  data : LayoutData,
  svg : @dom.Element,
) -> Unit raise LayoutError {
  for node in data.nodes {
    node.dom_id = "\{data.diagram_id}-\{node.dom_id}"
  }
  insert_look_defs(svg, data)
  guard svg.child_elements().filter(child => child.tag == "g") is [element, ..] else {
    raise LayoutError("the svg element has no group to draw into")
  }
  insert_markers(
    element,
    data.markers,
    data.diagram_type,
    data.diagram_id,
    config=data.config,
  )
  let env = {
    ..Env::new(data.config, data.diagram_id),
    node_text_centred: node_text_centred(data.diagram_type),
  }
  // The layout's view of the diagram.
  let rendering_edges : Map[String, Edge] = Map([])
  let model_edges = []
  for edge in data.edges {
    rendering_edges[edge.id] = edge
    let model = @swimlane_model.Edge::new(
      id=edge.id,
      start=edge.start,
      end=edge.end,
      label=edge.label,
      label_style=first_label_style(edge),
      curve?=if edge.curve == "" { None } else { Some(edge.curve) },
      arrow_type_start=edge.arrow_type_start,
      arrow_type_end=edge.arrow_type_end,
    )
    model_edges.push(model)
  }
  let config = data.config
  let layout : @swimlane_model.Layout = {
    nodes: data.nodes.map(swimlane_model_node),
    edges: model_edges,
    direction: Some(data.direction),
    options: {
      node_spacing: config.number("flowchart.nodeSpacing"),
      rank_spacing: config.number("flowchart.rankSpacing"),
      ignore_cross_lane_edges: !(config.get("swimlane.ignoreCrossLaneEdges")
      is False),
      optimize_ranks_by_crossings: !(config.get(
        "swimlane.optimizeRanksByCrossings",
      )
      is False),
      automatic_lane_ordering: config.get("swimlane.automaticLaneOrdering")
      is True,
      look: config.text("look"),
    },
  }
  for node in layout.nodes {
    guard @swimlane_model.collatable(node.id) && node.id != "null" else {
      raise LayoutError(
        "The swimlane layout of the node id \{node.id} is not supported yet.",
      )
    }
  }
  for edge in layout.edges {
    guard @swimlane_model.collatable(edge.id) else {
      raise LayoutError(
        "The swimlane layout of the edge id \{edge.id} is not supported yet.",
      )
    }
  }
  // Lanes for the nodes outside every lane, nodes for edge labels.
  @swimlane_layering.prepare(layout)
  let nodes_by_id : Map[String, Node] = Map([])
  for node in data.nodes {
    nodes_by_id[node.id] = node
  }
  let nodes = layout.nodes.map(model => {
    match nodes_by_id.get(model.id) {
      Some(node) => {
        // A node moved into the default lane takes its direction from
        // the diagram either way.
        node.shape = model.shape
        node
      }
      None => {
        let node = swimlane_node(model, data)
        nodes_by_id[model.id] = node
        node
      }
    }
  })
  for edge in layout.edges {
    if rendering_edges.get(edge.id) is Some(rendering) && edge.label is None {
      // The label is drawn by its node.
      rendering.label = ""
    }
  }
  // Measure: every node is drawn once to learn its size.
  let root = element.append("g").attr("class", "root")
  let clusters = root.append("g").attr("class", "clusters")
  let edge_paths = root.append("g").attr("class", "edges edgePaths")
  root.append("g").attr("class", "edgeLabels") |> ignore
  let nodes_group = root.append("g").attr("class", "nodes")
  for node in nodes {
    if node.is_group {
      measure_group_label(nodes_group, node, env)
    } else {
      let dir = node_dir(node, nodes_by_id, data.direction)
      let element = insert_node(nodes_group, node, env, dir)
      if node.look == "" {
        element.remove_attr("data-look") |> ignore
      }
      let box = element.bbox()
      node.width = Some(box.width)
      node.height = Some(box.height)
    }
  }
  for model in layout.nodes {
    guard nodes_by_id.get(model.id) is Some(node) else { continue }
    if !model.is_group {
      model.width = node.width
      model.height = node.height
    }
  }
  // Lay out.
  let _ = @swimlane.run_core(layout) catch {
    @swimlane_layering.LayeringError(message) => raise LayoutError(message)
  }
  // Paint.
  let n = @dom.number
  for model in layout.nodes {
    guard nodes_by_id.get(model.id) is Some(node) else { continue }
    node.x = model.x.unwrap_or(0.0)
    node.y = model.y.unwrap_or(0.0)
    node.width = model.width
    node.height = model.height
    if node.is_group {
      if node.shape == "swimlane" {
        swimlane_cluster(clusters, node, model, env)
      } else {
        insert_cluster_shape(clusters, node, env)
      }
    } else if node.element is Some(element) {
      element.attr("transform", "translate(\{n(node.x)}, \{n(node.y)})")
      |> ignore
    }
  }
  let paths : Map[String, @dom.Element] = Map([])
  let drawn = []
  for model in layout.edges {
    if model.is_layout_only {
      continue
    }
    guard rendering_edges.get(model.id) is Some(edge) else { continue }
    // Upstream reads the route of an edge the layout could not route
    // (a loop) and throws.
    guard model.points is Some(points) else {
      raise LayoutError(
        "Cannot read properties of undefined (reading 'filter')",
      )
    }
    edge.curve = model.curve.unwrap_or("")
    let tail = nodes_by_id.get(edge.start)
    let head = nodes_by_id.get(edge.end)
    edge.points = match (tail, head) {
      (Some(tail), Some(head)) => swimlane_clipped_points(points, tail, head)
      _ => points.map(p => { x: p.x, y: p.y, })
    }
    // Rounded routes are drawn by `insert_edge`; other curves go through
    // the corners cut by `fixCorners`.
    let path = if edge.curve == "rounded" {
      None
    } else {
      let line_data = fix_corners(edge.points.filter(p => !p.y.is_nan()))
      let points = offset_line_points(line_data, edge)
      Some(
        match @d3.line(edge.curve, points) {
          Some(path) => path
          None => @d3.line("basis", points).unwrap_or("")
        },
      )
    }
    let path = insert_edge(edge_paths, edge, data, path?)
    if !paths.contains(edge.id) {
      paths[edge.id] = path
    }
    drawn.push(edge)
  }
  // Line hops: `applySwimlaneLineJumps`, over the clipped routes the
  // paths record.
  apply_line_jumps(
    data,
    paths,
    key="swimlane.lineHops",
    edges=drawn,
    gap=data.config.text("swimlane.lineHops") == Some("gap"),
  )
}
