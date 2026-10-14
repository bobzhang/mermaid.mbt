// The layout as a whole: layout-base's `Layout.runLayout` and cose-base's
// `CoSELayout.classicLayout`, driven as cytoscape-cose-bilkent's `run`
// drives them.

///|
/// The state of a layout: `CoSELayout` with its graph manager and its one
/// graph, the root.
priv struct Layout {
  nodes : Array[LNode]
  edges : Array[LEdge]
  /// The bounds of the root graph, margin included.
  mut left : Double
  mut right : Double
  mut top : Double
  mut bottom : Double
  mut estimated_size : Double
  /// The nodes gravity pulls on: those of a graph that is not connected.
  mut nodes_with_gravity : Array[LNode]
  mut cooling_factor : Double
  mut max_iterations : Int32
  mut total_displacement_threshold : Double
  mut repulsion_range : Double
  mut total_iterations : Int32
  mut total_displacement : Double
  mut old_total_displacement : Double
  mut cooling_cycle : Int32
  /// The nodes by the cells of the repulsion grid they cover.
  mut grid : Array[Array[Array[LNode]]]
  /// Told the top left corners of the nodes before the first iteration
  /// and after every iteration.
  on_tick : ((Array[(Double, Double)]) -> Unit)?
}

///|
/// Lay out a graph without compound nodes. `sizes` are the widths and
/// heights of the nodes, `edges` pairs of node indices; an edge from a node
/// to itself and a second edge between two nodes are left out, as
/// cytoscape-cose-bilkent leaves them out. Answers with the centres of the
/// nodes.
///
/// `on_tick` is told the top left corners of the nodes before the first
/// iteration and after every iteration, to compare a run with upstream's
/// step by step.
///
/// Exact for forests, which upstream starts from a radial drawing. A
/// graph with a cycle is started from positions that depend on what the
/// page has laid out before and is grown back from its trunk with
/// `Math.random`, and several nodes without edges are packed into a
/// compound node: neither is ported.
pub fn layout(
  sizes : Array[(Double, Double)],
  edges : Array[(Int32, Int32)],
  on_tick? : (Array[(Double, Double)]) -> Unit,
) -> Array[(Double, Double)] raise Unsupported {
  let nodes = sizes.mapi((index, size) => LNode::new(index, size.0, size.1))
  let self : Layout = {
    nodes,
    edges: [],
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
    estimated_size: integer_min,
    nodes_with_gravity: [],
    cooling_factor: 1.0,
    max_iterations,
    total_displacement_threshold: 0.0,
    repulsion_range: 0.0,
    total_iterations: 0,
    total_displacement: 0.0,
    old_total_displacement: 0.0,
    cooling_cycle: 0,
    grid: [],
    on_tick,
  }
  for pair in edges {
    let source = nodes[pair.0]
    let target = nodes[pair.1]
    if !physical_equal(source, target) &&
      source.edges_between(target).is_empty() {
      // `LGraph.add`
      let edge : LEdge = {
        source,
        target,
        ideal_length: edge_length,
        length_x: 0.0,
        length_y: 0.0,
        length: 0.0,
        is_overlapping_source_and_target: false,
      }
      self.edges.push(edge)
      source.edges.push(edge)
      target.edges.push(edge)
    }
  }
  self.run()
  nodes.map(node => (node.center_x(), node.center_y()))
}

///|
/// `Layout.runLayout`.
fn Layout::run(self : Layout) -> Unit raise Unsupported {
  // `tilingPreLayout`: nodes without edges are tiled inside a compound
  // node of their own when there are several of them.
  if self.nodes.filter(node => node.edges.is_empty()).length() > 1 {
    raise Unsupported("cose-bilkent: several nodes without edges")
  }
  if self.nodes.length() > adaptation_lower_node_limit {
    // The layout starts cooler, on a schedule that was not measured.
    raise Unsupported(
      "cose-bilkent: more than \{adaptation_lower_node_limit} nodes",
    )
  }
  // `checkLayoutSuccess`: there is nothing to lay out.
  if self.nodes.is_empty() {
    return
  }
  self.classic_layout()
  // `doPostLayout`: the drawing's top left corner, margin included, goes
  // to the origin.
  self.transform(0.0, 0.0)
}

///|
/// `CoSELayout.classicLayout`.
fn Layout::classic_layout(self : Layout) -> Unit raise Unsupported {
  // `calculateNodesToApplyGravitationTo`
  self.nodes_with_gravity = if self.is_connected() { [] } else { self.nodes }
  // `LGraph.calcEstimatedSize`
  let mut size = 0.0
  for node in self.nodes {
    node.estimated_size = (node.rect.width + node.rect.height) / 2.0
    size += node.estimated_size
  }
  self.estimated_size = if size == 0.0 {
    empty_compound_node_size
  } else {
    size / self.nodes.length().to_double().sqrt()
  }
  // `calcIdealEdgeLengths`: no edge crosses between graphs.
  for edge in self.edges {
    edge.ideal_length = edge_length
  }
  let forest = flat_forest(self.nodes)
  if forest.is_empty() {
    raise Unsupported("cose-bilkent: a graph with a cycle")
  }
  self.position_nodes_radially(forest)
  self.init_spring_embedder()
  // `runSpringEmbedder`
  self.trace()
  while true {
    let done = self.tick()
    self.trace()
    if done {
      break
    }
  }
  self.update_bounds()
}

///|
fn Layout::trace(self : Layout) -> Unit {
  if self.on_tick is Some(on_tick) {
    on_tick(self.nodes.map(node => (node.rect.x, node.rect.y)))
  }
}

///|
/// `LGraph.updateConnected` for the root graph.
fn Layout::is_connected(self : Layout) -> Bool {
  let visited = Array::make(self.nodes.length(), false)
  let queue = [self.nodes[0]]
  visited[0] = true
  let mut count = 1
  let mut next = 0
  while next < queue.length() {
    let current = queue[next]
    next += 1
    for edge in current.edges {
      let neighbor = edge.other_end(current)
      if !visited[neighbor.index] {
        visited[neighbor.index] = true
        count += 1
        queue.push(neighbor)
      }
    }
  }
  count == self.nodes.length()
}

///|
/// `Layout.transform`: move the drawing so that the top left corner of
/// the root graph, margin included, is at the given point.
fn Layout::transform(self : Layout, x : Double, y : Double) -> Unit {
  // `LGraph.updateLeftTop`
  let mut top = integer_max
  let mut left = integer_max
  for node in self.nodes {
    let node_top = node.rect.y
    let node_left = node.rect.x
    if top > node_top {
      top = node_top
    }
    if left > node_left {
      left = node_left
    }
  }
  if top == integer_max {
    return
  }
  self.left = left - graph_margin
  self.top = top - graph_margin
  let trans = {
    world_org_x: x,
    world_org_y: y,
    device_org_x: self.left,
    device_org_y: self.top,
  }
  for node in self.nodes {
    node.transform(trans)
  }
}

///|
/// `LGraph.updateBounds` for the root graph.
fn Layout::update_bounds(self : Layout) -> Unit {
  let bounding_rect = calculate_bounds(self.nodes)
  self.left = bounding_rect.x - graph_margin
  self.right = bounding_rect.x + bounding_rect.width + graph_margin
  self.top = bounding_rect.y - graph_margin
  self.bottom = bounding_rect.y + bounding_rect.height + graph_margin
}
