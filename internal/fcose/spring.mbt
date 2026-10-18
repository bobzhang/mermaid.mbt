// The forces of layout-base 2.0.1's `FDLayout` and the moves of cose-base
// 2.2.0's `CoSENode`, summed in upstream's order.

///|
/// `FDLayout.calcSpringForces`.
fn Layout::calc_spring_forces(self : Layout) -> Unit {
  let clip = FixedArray::make(4, 0.0)
  for edge in self.manager.all_edges() {
    let source = self.manager.nodes[edge.source]
    let target = self.manager.nodes[edge.target]
    // `LEdge.updateLength`
    edge.is_overlapping_source_and_target = intersection(
      target.rect,
      source.rect,
      clip,
    )
    if edge.is_overlapping_source_and_target {
      continue
    }
    edge.length_x = clip[0] - clip[2]
    edge.length_y = clip[1] - clip[3]
    if edge.length_x.abs() < 1.0 {
      edge.length_x = sign(edge.length_x)
    }
    if edge.length_y.abs() < 1.0 {
      edge.length_y = sign(edge.length_y)
    }
    edge.length = (edge.length_x * edge.length_x + edge.length_y * edge.length_y).sqrt()
    let length = edge.length
    if length == 0.0 {
      continue
    }
    let spring_force = edge.edge_elasticity * (length - edge.ideal_length)
    let spring_force_x = spring_force * (edge.length_x / length)
    let spring_force_y = spring_force * (edge.length_y / length)
    source.spring_force_x += spring_force_x
    source.spring_force_y += spring_force_y
    target.spring_force_x -= spring_force_x
    target.spring_force_y -= spring_force_y
  }
}

///|
/// `FDLayout.calcRepulsionForce`.
fn Layout::calc_repulsion_force(self : Layout, a : LNode, b : LNode) -> Unit {
  let rect_a = a.rect
  let rect_b = b.rect
  if rect_a.intersects(rect_b) {
    let overlap = FixedArray::make(2, 0.0)
    separation_amount(rect_a, rect_b, overlap, self.default_edge_length / 2.0)
    let repulsion_force_x = 2.0 * overlap[0]
    let repulsion_force_y = 2.0 * overlap[1]
    let children_constant = a.no_of_children *
      b.no_of_children /
      (a.no_of_children + b.no_of_children)
    a.repulsion_force_x -= children_constant * repulsion_force_x
    a.repulsion_force_y -= children_constant * repulsion_force_y
    b.repulsion_force_x += children_constant * repulsion_force_x
    b.repulsion_force_y += children_constant * repulsion_force_y
  } else {
    let clip = FixedArray::make(4, 0.0)
    intersection(rect_a, rect_b, clip) |> ignore
    let mut distance_x = clip[2] - clip[0]
    let mut distance_y = clip[3] - clip[1]
    if distance_x.abs() < self.min_repulsion_dist {
      distance_x = sign(distance_x) * self.min_repulsion_dist
    }
    if distance_y.abs() < self.min_repulsion_dist {
      distance_y = sign(distance_y) * self.min_repulsion_dist
    }
    let distance_squared = distance_x * distance_x + distance_y * distance_y
    let distance = distance_squared.sqrt()
    let repulsion_force = (a.node_repulsion / 2.0 + b.node_repulsion / 2.0) *
      a.no_of_children *
      b.no_of_children /
      distance_squared
    let repulsion_force_x = repulsion_force * distance_x / distance
    let repulsion_force_y = repulsion_force * distance_y / distance
    a.repulsion_force_x -= repulsion_force_x
    a.repulsion_force_y -= repulsion_force_y
    b.repulsion_force_x += repulsion_force_x
    b.repulsion_force_y += repulsion_force_y
  }
}

///|
/// `FDLayout.calcRepulsionForces` with the grid: every tenth iteration the
/// nodes near each node are found again, among those of its own graph.
fn Layout::calc_repulsion_forces(self : Layout) -> Unit raise FcoseError {
  let nodes = self.manager.all_nodes()
  let refresh = self.total_iterations % grid_calculation_check_period == 1
  if refresh {
    self.update_grid(nodes)
  }
  let processed = Array::make(self.manager.nodes.length(), false)
  for a in nodes {
    if refresh {
      let in_surrounding = Array::make(self.manager.nodes.length(), false)
      let surrounding = []
      let grid = self.grid
      for i in (a.start_x - 1)..<(a.finish_x + 2) {
        for j in (a.start_y - 1)..<(a.finish_y + 2) {
          if i < 0 || j < 0 || i >= grid.length() || j >= grid[0].length() {
            continue
          }
          for index in grid[i][j] {
            let b = self.manager.nodes[index]
            if a.owner != b.owner || a.index == b.index {
              continue
            }
            if !processed[index] && !in_surrounding[index] {
              let distance_x = (a.center_x() - b.center_x()).abs() -
                (a.rect.width / 2.0 + b.rect.width / 2.0)
              let distance_y = (a.center_y() - b.center_y()).abs() -
                (a.rect.height / 2.0 + b.rect.height / 2.0)
              if distance_x <= self.repulsion_range &&
                distance_y <= self.repulsion_range {
                in_surrounding[index] = true
                surrounding.push(index)
              }
            }
          }
        }
      }
      a.surrounding = surrounding
    }
    for index in a.surrounding {
      self.calc_repulsion_force(a, self.manager.nodes[index])
    }
    processed[a.index] = true
  }
}

///|
/// `FDLayout.updateGrid`: the cells of the root graph's box, each as
/// wide as the repulsion range, and the nodes that cover them.
fn Layout::update_grid(
  self : Layout,
  nodes : Array[LNode],
) -> Unit raise FcoseError {
  let root = self.manager.root()
  let cells_x = ((root.right - root.left) / self.repulsion_range).ceil()
  let cells_y = ((root.bottom - root.top) / self.repulsion_range).ceil()
  if cells_x.is_nan() ||
    cells_x.is_inf() ||
    cells_y.is_nan() ||
    cells_y.is_inf() {
    raise InvalidArrayLength
  }
  let size_x = cells_x.to_int()
  let size_y = cells_y.to_int()
  let grid = Array::makei(size_x, _ => Array::makei(size_y, _ => []))
  self.grid = grid
  for v in nodes {
    let left = root.left
    let top = root.top
    let start_x = js_floor_int((v.rect.x - left) / self.repulsion_range)
    let finish_x = js_floor_int(
      (v.rect.width + v.rect.x - left) / self.repulsion_range,
    )
    let start_y = js_floor_int((v.rect.y - top) / self.repulsion_range)
    let finish_y = js_floor_int(
      (v.rect.height + v.rect.y - top) / self.repulsion_range,
    )
    for i in start_x..<=finish_x {
      for j in start_y..<=finish_y {
        grid[i][j].push(v.index)
        v.start_x = start_x
        v.finish_x = finish_x
        v.start_y = start_y
        v.finish_y = finish_y
      }
    }
  }
}

///|
/// `parseInt(Math.floor(x))`.
fn js_floor_int(x : Double) -> Int32 {
  x.floor().to_int()
}

///|
/// `FDLayout.calcGravitationalForces`: towards the centre of the node's
/// graph, for the nodes of graphs that are not connected and only when
/// they are far from it.
fn Layout::calc_gravitational_forces(self : Layout) -> Unit {
  for index in self.nodes_with_gravity {
    let node = self.manager.nodes[index]
    let owner = self.manager.graphs[node.owner]
    let owner_center_x = (owner.right + owner.left) / 2.0
    let owner_center_y = (owner.top + owner.bottom) / 2.0
    let distance_x = node.center_x() - owner_center_x
    let distance_y = node.center_y() - owner_center_y
    let abs_distance_x = distance_x.abs() + node.rect.width / 2.0
    let abs_distance_y = distance_y.abs() + node.rect.height / 2.0
    if node.owner == 0 {
      let estimated_size = owner.estimated_size * gravity_range_factor
      if abs_distance_x > estimated_size || abs_distance_y > estimated_size {
        node.gravitation_force_x = -gravity_constant * distance_x
        node.gravitation_force_y = -gravity_constant * distance_y
      }
    } else {
      let estimated_size = owner.estimated_size * compound_gravity_range_factor
      if abs_distance_x > estimated_size || abs_distance_y > estimated_size {
        node.gravitation_force_x = -gravity_constant *
          distance_x *
          compound_gravity_constant
        node.gravitation_force_y = -gravity_constant *
          distance_y *
          compound_gravity_constant
      }
    }
  }
}

///|
/// `CoSELayout.moveNodes`: every node's displacement, then the constraints'
/// say, then the moves.
fn Layout::move_nodes(self : Layout) -> Unit {
  let nodes = self.manager.all_nodes()
  for node in nodes {
    self.calculate_displacement(node)
  }
  self.update_displacements()
  for node in nodes {
    // `CoSENode.move`: compound nodes follow their insides.
    let empty = match node.child {
      None => true
      Some(child) => self.manager.graphs[child].nodes.is_empty()
    }
    if empty {
      node.rect.x += node.displacement_x
      node.rect.y += node.displacement_y
      self.total_displacement += node.displacement_x.abs() +
        node.displacement_y.abs()
    }
    node.spring_force_x = 0.0
    node.spring_force_y = 0.0
    node.repulsion_force_x = 0.0
    node.repulsion_force_y = 0.0
    node.gravitation_force_x = 0.0
    node.gravitation_force_y = 0.0
    node.displacement_x = 0.0
    node.displacement_y = 0.0
  }
}

///|
/// `CoSENode.calculateDisplacement`: the forces, cooled and divided among
/// the node's leaves, capped; a compound node hands its displacement to
/// everything inside it.
fn Layout::calculate_displacement(self : Layout, node : LNode) -> Unit {
  node.displacement_x += self.cooling_factor *
    (node.spring_force_x + node.repulsion_force_x + node.gravitation_force_x) /
    node.no_of_children
  node.displacement_y += self.cooling_factor *
    (node.spring_force_y + node.repulsion_force_y + node.gravitation_force_y) /
    node.no_of_children
  let cap = self.cooling_factor * max_node_displacement
  if node.displacement_x.abs() > cap {
    node.displacement_x = cap * sign(node.displacement_x)
  }
  if node.displacement_y.abs() > cap {
    node.displacement_y = cap * sign(node.displacement_y)
  }
  if node.child is Some(child) && !self.manager.graphs[child].nodes.is_empty() {
    self.propagate_displacement(child, node.displacement_x, node.displacement_y)
  }
}

///|
/// `CoSENode.propogateDisplacementToChildren`.
fn Layout::propagate_displacement(
  self : Layout,
  graph : Int32,
  dx : Double,
  dy : Double,
) -> Unit {
  for index in self.manager.graphs[graph].nodes {
    let node = self.manager.nodes[index]
    match node.child {
      None => {
        node.displacement_x += dx
        node.displacement_y += dy
      }
      Some(child) => self.propagate_displacement(child, dx, dy)
    }
  }
}
