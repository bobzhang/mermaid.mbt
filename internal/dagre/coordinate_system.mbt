// dagre's `coordinate-system.js`: the layout is computed from top to
// bottom, and turned for the other directions.

///|
fn coordinate_system_adjust(g : LayoutGraph) -> Unit raise LayoutError {
  let rank_dir = g.graph().rankdir.to_lower()
  if rank_dir == "lr" || rank_dir == "rl" {
    swap_width_height(g)
  }
}

///|
fn coordinate_system_undo(g : LayoutGraph) -> Unit raise LayoutError {
  let rank_dir = g.graph().rankdir.to_lower()
  if rank_dir == "bt" || rank_dir == "rl" {
    reverse_y(g)
  }
  if rank_dir == "lr" || rank_dir == "rl" {
    swap_xy(g)
    swap_width_height(g)
  }
}

///|
fn swap_width_height(g : LayoutGraph) -> Unit raise LayoutError {
  for v in g.nodes() {
    let node = nd(g, v)
    let w = node.width
    node.width = node.height
    node.height = w
  }
  for e in g.edges() {
    let edge = ed(g, e)
    let w = edge.width
    edge.width = edge.height
    edge.height = w
  }
}

///|
fn reverse_y(g : LayoutGraph) -> Unit raise LayoutError {
  for v in g.nodes() {
    let node = nd(g, v)
    node.y = -node.y
  }
  for e in g.edges() {
    let edge = ed(g, e)
    if edge.points is Some(points) {
      for point in points {
        point.y = -point.y
      }
    }
    if edge.y is Some(y) {
      edge.y = Some(-y)
    }
  }
}

///|
fn swap_xy(g : LayoutGraph) -> Unit raise LayoutError {
  for v in g.nodes() {
    let node = nd(g, v)
    let x = node.x
    node.x = node.y
    node.y = x
  }
  for e in g.edges() {
    let edge = ed(g, e)
    if edge.points is Some(points) {
      for point in points {
        let x = point.x
        point.x = point.y
        point.y = x
      }
    }
    if edge.x is Some(_) {
      let x = edge.x
      edge.x = edge.y
      edge.y = x
    }
  }
}
