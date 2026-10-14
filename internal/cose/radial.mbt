// The start of a layout: a graph that is a forest is drawn tree by tree,
// every tree in rings around its centre (cose-base's
// `positionNodesRadially`).

///|
/// `Layout.getFlatForest`: the trees of the graph, each as its nodes in
/// breadth-first order from the first node not yet reached. Empty when
/// the graph has a cycle.
fn flat_forest(nodes : Array[LNode]) -> Array[Array[LNode]] {
  let flat_forest : Array[Array[LNode]] = []
  let unprocessed = nodes.copy()
  let parents : Array[LNode?] = Array::make(nodes.length(), None)
  while unprocessed.length() > 0 {
    // The nodes of this tree in the order they are first visited.
    let visited : Array[LNode] = []
    let seen = Array::make(nodes.length(), false)
    let to_be_visited = [unprocessed[0]]
    let mut next = 0
    while next < to_be_visited.length() {
      let current = to_be_visited[next]
      next += 1
      if !seen[current.index] {
        seen[current.index] = true
        visited.push(current)
      }
      for edge in current.edges {
        let neighbor = edge.other_end(current)
        let is_parent = match parents[current.index] {
          Some(parent) => physical_equal(parent, neighbor)
          None => false
        }
        if !is_parent {
          if !seen[neighbor.index] {
            to_be_visited.push(neighbor)
            parents[neighbor.index] = Some(current)
          } else {
            return []
          }
        }
      }
    }
    flat_forest.push(visited)
    for node in visited {
      if unprocessed.search_by(other => physical_equal(other, node))
        is Some(index) {
        unprocessed.remove(index) |> ignore
      }
      parents[node.index] = None
    }
  }
  flat_forest
}

///|
/// `Layout.findCenterOfTree`. Upstream means to peel leaves off the tree
/// until one or two nodes are left, but its loop removes every node it
/// looks at while walking the list by index, so each round drops every
/// other node of the list whatever its degree: the "centre" depends on the
/// order of `nodes` alone.
fn center_of_tree(nodes : Array[LNode]) -> LNode {
  let mut list = nodes.copy()
  while !(list.length() == 1 || list.length() == 2) {
    let kept = []
    for i, node in list {
      if i % 2 == 1 {
        kept.push(node)
      }
    }
    list = kept
  }
  list[0]
}

///|
/// `CoSELayout.branchRadialLayout`: put `node` at `distance` from the
/// origin in the middle of the sector between the angles (in degrees), and
/// share the sector among its other neighbours, one ring further out.
fn branch_radial_layout(
  node : LNode,
  parent_of_node : LNode?,
  start_angle : Double,
  end_angle : Double,
  distance : Double,
  radial_separation : Double,
) -> Unit {
  let mut half_interval = (end_angle - start_angle + 1.0) / 2.0
  if half_interval < 0.0 {
    half_interval += 180.0
  }
  let node_angle = (half_interval + start_angle) % 360.0
  let teta = node_angle * two_pi / 360.0
  let x = distance * @jsmath.cos(teta)
  let y = distance * @jsmath.sin(teta)
  node.set_center(x, y)
  let neighbor_edges = node.edges
  let mut child_count = neighbor_edges.length()
  let inc_edges_count = neighbor_edges.length()
  // Two nodes are joined by one edge at most, so there is no surplus of
  // edges to the parent to take out of the count.
  let start_index = match parent_of_node {
    Some(parent) => {
      child_count -= 1
      let to_parent = neighbor_edges
        .search_by(edge => physical_equal(edge.other_end(node), parent))
        .unwrap_or(-1)
      (to_parent + 1) % inc_edges_count
    }
    None => 0
  }
  let step_angle = (end_angle - start_angle).abs() / child_count.to_double()
  let mut branch_count = 0
  let mut i = start_index
  while branch_count != child_count {
    let current_neighbor = neighbor_edges[i].other_end(node)
    i = (i + 1) % inc_edges_count
    if parent_of_node is Some(parent) &&
      physical_equal(current_neighbor, parent) {
      continue
    }
    let child_start_angle = (
        start_angle + branch_count.to_double() * step_angle
      ) %
      360.0
    let child_end_angle = (child_start_angle + step_angle) % 360.0
    branch_radial_layout(
      current_neighbor,
      Some(node),
      child_start_angle,
      child_end_angle,
      distance + radial_separation,
      radial_separation,
    )
    branch_count += 1
  }
}

///|
/// `IGeometry.TWO_PI`.
let two_pi : Double = 2.0 * 3.141592653589793

///|
/// `CoSELayout.radialLayout`: lay `tree` out in rings around
/// `center_node` and move its top left corner to `starting_point`;
/// answers with the bottom right corner.
fn radial_layout(
  tree : Array[LNode],
  center_node : LNode,
  starting_point : (Double, Double),
) -> (Double, Double) {
  // `maxDiagonalInTree`
  let mut max_diagonal = integer_min
  for node in tree {
    let diagonal = node.diagonal()
    if diagonal > max_diagonal {
      max_diagonal = diagonal
    }
  }
  let radial_sep = js_max(max_diagonal, radial_separation)
  branch_radial_layout(center_node, None, 0.0, 359.0, 0.0, radial_sep)
  let bounds = calculate_bounds(tree)
  let transform = {
    device_org_x: bounds.x,
    device_org_y: bounds.y,
    world_org_x: starting_point.0,
    world_org_y: starting_point.1,
  }
  for node in tree {
    node.transform(transform)
  }
  (transform.inverse_x(bounds.right()), transform.inverse_y(bounds.bottom()))
}

///|
/// `CoSELayout.positionNodesRadially`: the trees of the forest side by
/// side in rows, the whole centred on the world's centre.
fn Layout::position_nodes_radially(
  self : Layout,
  forest : Array[Array[LNode]],
) -> Unit {
  let number_of_columns = forest.length().to_double().sqrt().ceil().to_int()
  let mut height = 0.0
  let mut current_y = 0.0
  let mut current_x = 0.0
  let mut point = (0.0, 0.0)
  for i, tree in forest {
    if i % number_of_columns == 0 {
      current_x = 0.0
      current_y = height
      if i != 0 {
        current_y += component_separation
      }
      height = 0.0
    }
    let center_node = center_of_tree(tree)
    point = radial_layout(tree, center_node, (current_x, current_y))
    if point.1 > height {
      height = point.1.floor()
    }
    current_x = (point.0 + component_separation).floor()
  }
  self.transform(world_center_x - point.0 / 2.0, world_center_y - point.1 / 2.0)
}
