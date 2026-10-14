// dagre's `layout.js`.

///|
/// Lay out a graph: `nodes` in the order the graph lists them, each with
/// the node it is nested in, and `edges` in the order the graph lists
/// them. The result has the nodes and edges in the same order.
pub fn layout(
  graph : GraphAttrs,
  nodes : Array[NodeAttrs],
  edges : Array[EdgeAttrs],
) -> Layout raise LayoutError {
  let g = build_layout_graph(graph, nodes, edges)
  run_layout(g)
  // `updateInputGraph`
  let node_layouts = []
  for node in nodes {
    let label = nd(g, node.id)
    node_layouts.push({
      x: label.x,
      y: label.y,
      width: label.width,
      height: label.height,
      compound: !g.children(node.id).is_empty(),
    })
  }
  let edge_layouts = []
  for edge in edges {
    let label = match g.edge_between(edge.v, edge.w, name?=edge.name) {
      Some(label) => label
      None => raise LayoutError("no edge from \{edge.v} to \{edge.w}")
    }
    let points = match label.points {
      Some(points) => points.map(p => Point::{ x: p.x, y: p.y, })
      None => []
    }
    let label = match (label.x, label.y) {
      (Some(x), Some(y)) => Some(Point::{ x, y, })
      _ => None
    }
    edge_layouts.push({ points, label, })
  }
  {
    width: g.graph().width,
    height: g.graph().height,
    nodes: node_layouts,
    edges: edge_layouts,
  }
}

///|
fn run_layout(g : LayoutGraph) -> Unit raise LayoutError {
  make_space_for_edge_labels(g)
  remove_self_edges(g)
  acyclic_run(g)
  nesting_graph_run(g)
  rank(as_non_compound_graph(g))
  inject_edge_label_proxies(g)
  remove_empty_ranks(g)
  nesting_graph_cleanup(g)
  normalize_ranks(g)
  assign_rank_min_max(g)
  remove_edge_label_proxies(g)
  normalize_run(g)
  parent_dummy_chains(g)
  add_border_segments(g)
  order(g)
  insert_self_edges(g)
  coordinate_system_adjust(g)
  position(g)
  position_self_edges(g)
  remove_border_nodes(g)
  normalize_undo(g)
  fixup_edge_label_coords(g)
  coordinate_system_undo(g)
  translate_graph(g)
  assign_node_intersects(g)
  reverse_points_for_reversed_edges(g)
  acyclic_undo(g)
}

///|
/// A whole number an edge attribute has to be for the layout to index
/// ranks by it.
fn whole(value : Double, what : String) -> Int32 raise LayoutError {
  if value.is_nan() || value.is_inf() || value != value.floor() {
    raise LayoutError("an edge with a \{what} of \{value} is not supported")
  }
  value.to_int()
}

///|
/// Constructs a new graph from the input graph, which can be used for
/// layout. Attributes that are missing take their defaults.
fn build_layout_graph(
  graph : GraphAttrs,
  nodes : Array[NodeAttrs],
  edges : Array[EdgeAttrs],
) -> LayoutGraph raise LayoutError {
  let label : GraphLabel = {
    ranksep: graph.ranksep.unwrap_or(50.0),
    edgesep: graph.edgesep.unwrap_or(20.0),
    nodesep: graph.nodesep.unwrap_or(50.0),
    rankdir: graph.rankdir.unwrap_or("tb"),
    marginx: graph.marginx,
    marginy: graph.marginy,
    acyclicer: graph.acyclicer,
    ranker: graph.ranker,
    align: graph.align,
    nesting_root: None,
    node_rank_factor: None,
    dummy_chains: [],
    width: 0.0,
    height: 0.0,
  }
  let g : LayoutGraph = @graphlib.Graph::new(
    label,
    default_node=missing_node,
    multigraph=true,
    compound=true,
  )
  for node in nodes {
    g.set_node(
      node.id,
      NodeLabel::new(
        width=node.width.unwrap_or(0.0),
        height=node.height.unwrap_or(0.0),
      ),
    )
    graph_op(() => g.set_parent(node.id, parent?=node.parent))
  }
  for edge in edges {
    let label : EdgeLabel = {
      minlen: whole(edge.minlen.unwrap_or(1.0), "minlen"),
      weight: edge.weight.unwrap_or(1.0),
      width: edge.width.unwrap_or(0.0),
      height: edge.height.unwrap_or(0.0),
      labeloffset: edge.labeloffset.unwrap_or(10.0),
      labelpos: edge.labelpos.unwrap_or("r"),
      points: None,
      x: None,
      y: None,
      reversed: false,
      forward_name: None,
      label_rank: None,
      nesting_edge: false,
    }
    graph_op(() => g.set_edge(edge.v, edge.w, label, name?=edge.name))
  }
  // dagre throws on a node that only an edge or a child names, since it
  // has no label to read, and on an edge at a node that has children,
  // which ranking knows nothing of.
  for v in g.nodes() {
    nd(g, v) |> ignore
  }
  for e in g.edges() {
    if !g.children(e.v).is_empty() || !g.children(e.w).is_empty() {
      raise LayoutError(
        "the edge from \{e.v} to \{e.w} is at a node that has children",
      )
    }
  }
  g
}

///|
/// This idea comes from the Gansner paper: to account for edge labels in
/// our layout we split each rank in half by doubling minlen and halving
/// ranksep. Then we can place labels at these mid-points between nodes.
///
/// We also add some minimal padding to the width to push the label for
/// the edge away from the edge itself a bit.
fn make_space_for_edge_labels(g : LayoutGraph) -> Unit raise LayoutError {
  let graph = g.graph()
  graph.ranksep = graph.ranksep / 2.0
  for e in g.edges() {
    let edge = ed(g, e)
    edge.minlen = edge.minlen * 2
    if edge.labelpos.to_lower() != "c" {
      if graph.rankdir == "TB" || graph.rankdir == "BT" {
        edge.width = edge.width + edge.labeloffset
      } else {
        edge.height = edge.height + edge.labeloffset
      }
    }
  }
}

///|
/// Creates temporary dummy nodes that capture the rank in which each
/// edge's label is going to, if it has one of non-zero width and height.
/// We do this so that we can safely remove empty ranks while preserving
/// balance for the label's position.
fn inject_edge_label_proxies(g : LayoutGraph) -> Unit raise LayoutError {
  for e in g.edges() {
    let edge = ed(g, e)
    if truthy(edge.width) && truthy(edge.height) {
      let v_rank = rank_of(g, e.v)
      let w_rank = rank_of(g, e.w)
      // Halfway between two ranks that are an odd number apart is no
      // rank: dagre keeps the fraction, which no rank of a dummy node
      // ever equals, so the label gets no place of its own.
      let label = if (w_rank - v_rank) % 2 != 0 {
        NodeLabel::new()
      } else {
        NodeLabel::new(rank=(w_rank - v_rank) / 2 + v_rank)
      }
      label.e = Some(e)
      add_dummy_node(g, "edge-proxy", label, "_ep") |> ignore
    }
  }
}

///|
fn assign_rank_min_max(g : LayoutGraph) -> Unit raise LayoutError {
  for v in g.nodes() {
    let node = nd(g, v)
    if node.border_top is Some(top) && node.border_bottom is Some(bottom) {
      node.min_rank = nd(g, top).rank
      node.max_rank = nd(g, bottom).rank
    }
  }
}

///|
fn remove_edge_label_proxies(g : LayoutGraph) -> Unit raise LayoutError {
  for v in g.nodes() {
    let node = nd(g, v)
    if node.dummy is Some("edge-proxy") {
      guard node.e is Some(e) else { continue }
      ed(g, e).label_rank = node.rank
      g.remove_node(v)
    }
  }
}

///|
fn translate_graph(g : LayoutGraph) -> Unit raise LayoutError {
  let mut min_x = @double.infinity
  let mut max_x = 0.0
  let mut min_y = @double.infinity
  let mut max_y = 0.0
  let graph_label = g.graph()
  let margin_x = match graph_label.marginx {
    Some(margin) if truthy(margin) => margin
    _ => 0.0
  }
  let margin_y = match graph_label.marginy {
    Some(margin) if truthy(margin) => margin
    _ => 0.0
  }
  for v in g.nodes() {
    let node = nd(g, v)
    min_x = js_min(min_x, node.x - node.width / 2.0)
    max_x = js_max(max_x, node.x + node.width / 2.0)
    min_y = js_min(min_y, node.y - node.height / 2.0)
    max_y = js_max(max_y, node.y + node.height / 2.0)
  }
  for e in g.edges() {
    let edge = ed(g, e)
    if edge.x is Some(x) {
      let y = edge.y.unwrap_or(@double.not_a_number)
      min_x = js_min(min_x, x - edge.width / 2.0)
      max_x = js_max(max_x, x + edge.width / 2.0)
      min_y = js_min(min_y, y - edge.height / 2.0)
      max_y = js_max(max_y, y + edge.height / 2.0)
    }
  }
  min_x = min_x - margin_x
  min_y = min_y - margin_y
  for v in g.nodes() {
    let node = nd(g, v)
    node.x = node.x - min_x
    node.y = node.y - min_y
  }
  for e in g.edges() {
    let edge = ed(g, e)
    if edge.points is Some(points) {
      for p in points {
        p.x = p.x - min_x
        p.y = p.y - min_y
      }
    }
    if edge.x is Some(x) {
      edge.x = Some(x - min_x)
    }
    if edge.y is Some(y) {
      edge.y = Some(y - min_y)
    }
  }
  graph_label.width = max_x - min_x + margin_x
  graph_label.height = max_y - min_y + margin_y
}

///|
/// The ends of every route are put where it crosses the border of the
/// box of its node.
fn assign_node_intersects(g : LayoutGraph) -> Unit raise LayoutError {
  for e in g.edges() {
    let edge = ed(g, e)
    let node_v = nd(g, e.v)
    let node_w = nd(g, e.w)
    let (points, p1, p2) = match edge.points {
      Some(points) if !points.is_empty() =>
        (points, points[0], points[points.length() - 1])
      Some(points) =>
        // The ends of a route without a point are undefined, and reading
        // their coordinates throws.
        raise LayoutError(
          "the edge from \{e.v} to \{e.w} has a route of \{points.length()} points",
        )
      None => {
        let points = []
        edge.points = Some(points)
        (points, { x: node_w.x, y: node_w.y, }, { x: node_v.x, y: node_v.y, })
      }
    }
    let first = intersect_rect(
      node_v.x,
      node_v.y,
      node_v.width,
      node_v.height,
      p1,
    )
    let last = intersect_rect(
      node_w.x,
      node_w.y,
      node_w.width,
      node_w.height,
      p2,
    )
    points.insert(0, first)
    points.push(last)
  }
}

///|
fn fixup_edge_label_coords(g : LayoutGraph) -> Unit raise LayoutError {
  for e in g.edges() {
    let edge = ed(g, e)
    if edge.x is Some(x) {
      if edge.labelpos == "l" || edge.labelpos == "r" {
        edge.width = edge.width - edge.labeloffset
      }
      match edge.labelpos {
        "l" => edge.x = Some(x - (edge.width / 2.0 + edge.labeloffset))
        "r" => edge.x = Some(x + (edge.width / 2.0 + edge.labeloffset))
        _ => ()
      }
    }
  }
}

///|
fn reverse_points_for_reversed_edges(g : LayoutGraph) -> Unit raise LayoutError {
  for e in g.edges() {
    let edge = ed(g, e)
    if edge.reversed && edge.points is Some(points) {
      points.rev_in_place()
    }
  }
}

///|
/// A compound node is as large as its border nodes are apart.
fn remove_border_nodes(g : LayoutGraph) -> Unit raise LayoutError {
  for v in g.nodes() {
    if !g.children(v).is_empty() {
      let node = nd(g, v)
      guard node.border_top is Some(top) &&
        node.border_bottom is Some(bottom) &&
        node.border_left.bind(borders => borders.last()) is Some(left) &&
        node.border_right.bind(borders => borders.last()) is Some(right) else {
        raise LayoutError("the compound node \{v} has no border")
      }
      let t = nd(g, top)
      let b = nd(g, bottom)
      let l = nd(g, left)
      let r = nd(g, right)
      node.width = (r.x - l.x).abs()
      node.height = (b.y - t.y).abs()
      node.x = l.x + node.width / 2.0
      node.y = t.y + node.height / 2.0
    }
  }
  for v in g.nodes() {
    if nd(g, v).dummy is Some("border") {
      g.remove_node(v)
    }
  }
}

///|
fn remove_self_edges(g : LayoutGraph) -> Unit raise LayoutError {
  for e in g.edges() {
    if e.v == e.w {
      let node = nd(g, e.v)
      let self_edges = match node.self_edges {
        Some(self_edges) => self_edges
        None => {
          let self_edges = []
          node.self_edges = Some(self_edges)
          self_edges
        }
      }
      self_edges.push((e, ed(g, e)))
      g.remove_edge(e)
    }
  }
}

///|
/// A self edge takes the place of a node to the right of its own in its
/// rank.
fn insert_self_edges(g : LayoutGraph) -> Unit raise LayoutError {
  let layers = build_layer_matrix(g)
  for layer in layers {
    let mut order_shift = 0
    for i, v in layer {
      let node = nd(g, v)
      node.order = Some(i + order_shift)
      if node.self_edges is Some(self_edges) {
        for self_edge in self_edges {
          order_shift += 1
          let label = NodeLabel::new(
            width=self_edge.1.width,
            height=self_edge.1.height,
            rank?=node.rank,
          )
          label.order = Some(i + order_shift)
          label.e = Some(self_edge.0)
          label.label = Some(self_edge.1)
          add_dummy_node(g, "selfedge", label, "_se") |> ignore
        }
      }
      node.self_edges = None
    }
  }
}

///|
fn position_self_edges(g : LayoutGraph) -> Unit raise LayoutError {
  for v in g.nodes() {
    let node = nd(g, v)
    if node.dummy is Some("selfedge") {
      guard node.e is Some(e) && node.label is Some(label) else { continue }
      let self_node = nd(g, e.v)
      let x = self_node.x + self_node.width / 2.0
      let y = self_node.y
      let dx = node.x - x
      let dy = self_node.height / 2.0
      graph_op(() => g.set_edge_obj(e, label))
      g.remove_node(v)
      label.points = Some([
        { x: x + 2.0 * dx / 3.0, y: y - dy, },
        { x: x + 5.0 * dx / 6.0, y: y - dy, },
        { x: x + dx, y, },
        { x: x + 5.0 * dx / 6.0, y: y + dy, },
        { x: x + 2.0 * dx / 3.0, y: y + dy, },
      ])
      label.x = Some(node.x)
      label.y = Some(node.y)
    }
  }
}
