// The spring embedder: layout-base's `FDLayout` with cose-base's
// `CoSELayout.tick` and `CoSENode.move`, for a graph that was not reduced
// to its trunk (a forest never is).

///|
/// `FDLayout.initSpringEmbedder` for a layout from scratch.
fn Layout::init_spring_embedder(self : Layout) -> Unit {
  let s = self.nodes.length()
  // Up to `ADAPTATION_LOWER_NODE_LIMIT` nodes the layout starts at 1.
  self.cooling_factor = 1.0
  if s * 5 > self.max_iterations {
    self.max_iterations = s * 5
  }
  // `displacementThresholdPerNode`
  self.total_displacement_threshold = 3.0 * edge_length / 100.0 * s.to_double()
  // `calcRepulsionRange` at level 0
  self.repulsion_range = 2.0 * (0.0 + 1.0) * edge_length
}

///|
/// `CoSELayout.tick`: one iteration; whether the layout is finished.
fn Layout::tick(self : Layout) -> Bool {
  self.total_iterations += 1
  if self.total_iterations == self.max_iterations {
    return true
  }
  if self.total_iterations % convergence_check_period == 0 {
    if self.is_converged() {
      return true
    }
    self.cooling_cycle += 1
    // With the quality "proof" the cooling adjuster stays 1.
    self.cooling_factor = if self.cooling_cycle <= cooling_schedule.length() {
      cooling_schedule[self.cooling_cycle - 1]
    } else {
      final_temperature
    }
  }
  self.total_displacement = 0.0
  self.update_bounds()
  self.calc_spring_forces()
  self.calc_repulsion_forces()
  self.calc_gravitational_forces()
  self.move_nodes()
  false
}

///|
/// `FDLayout.isConverged`.
fn Layout::is_converged(self : Layout) -> Bool {
  let mut oscilating = false
  if self.total_iterations.to_double() > self.max_iterations.to_double() / 3.0 {
    oscilating = (self.total_displacement - self.old_total_displacement).abs() <
      2.0
  }
  let converged = self.total_displacement < self.total_displacement_threshold
  self.old_total_displacement = self.total_displacement
  converged || oscilating
}

///|
/// `LEdge.updateLength`.
fn LEdge::update_length(self : LEdge) -> Unit {
  match clip_points(self.target.rect, self.source.rect) {
    None => self.is_overlapping_source_and_target = true
    Some((tx, ty, sx, sy)) => {
      self.is_overlapping_source_and_target = false
      self.length_x = tx - sx
      self.length_y = ty - sy
      if self.length_x.abs() < 1.0 {
        self.length_x = sign(self.length_x)
      }
      if self.length_y.abs() < 1.0 {
        self.length_y = sign(self.length_y)
      }
      self.length = (self.length_x * self.length_x +
      self.length_y * self.length_y).sqrt()
    }
  }
}

///|
/// `FDLayout.calcSpringForces`.
fn Layout::calc_spring_forces(self : Layout) -> Unit {
  for edge in self.edges {
    let source_node = edge.source
    let target_node = edge.target
    edge.update_length()
    if edge.is_overlapping_source_and_target {
      continue
    }
    let length = edge.length
    if length == 0.0 {
      continue
    }
    let spring_force = spring_strength * (length - edge.ideal_length)
    let spring_force_x = spring_force * (edge.length_x / length)
    let spring_force_y = spring_force * (edge.length_y / length)
    source_node.spring_force_x += spring_force_x
    source_node.spring_force_y += spring_force_y
    target_node.spring_force_x -= spring_force_x
    target_node.spring_force_y -= spring_force_y
  }
}

///|
/// `FDLayout.calcRepulsionForces` with the grid variant: every tenth
/// iteration the nodes are sorted into a grid and each node notes those
/// within the repulsion range; in between it is repelled by those noted.
fn Layout::calc_repulsion_forces(self : Layout) -> Unit {
  let update = self.total_iterations % grid_calculation_check_period == 1
  if update {
    self.update_grid()
  }
  let processed = Array::make(self.nodes.length(), false)
  for node_a in self.nodes {
    if update {
      self.find_surrounding(node_a, processed)
    }
    for node_b in node_a.surrounding {
      calc_repulsion_force(node_a, node_b)
    }
    processed[node_a.index] = true
  }
}

///|
/// The part of `FDLayout.calculateRepulsionForceOfANode` that collects the
/// nodes in the cells around `node_a` that are within the repulsion range
/// and come after it.
fn Layout::find_surrounding(
  self : Layout,
  node_a : LNode,
  processed : Array[Bool],
) -> Unit {
  let surrounding : Array[LNode] = []
  let in_surrounding = Array::make(self.nodes.length(), false)
  let grid = self.grid
  for i = node_a.start_x - 1; i < node_a.finish_x + 2; i = i + 1 {
    for j = node_a.start_y - 1; j < node_a.finish_y + 2; j = j + 1 {
      if i < 0 || j < 0 || i >= grid.length() || j >= grid[0].length() {
        continue
      }
      for node_b in grid[i][j] {
        if physical_equal(node_a, node_b) {
          continue
        }
        if !processed[node_b.index] && !in_surrounding[node_b.index] {
          let distance_x = (node_a.center_x() - node_b.center_x()).abs() -
            (node_a.rect.width / 2.0 + node_b.rect.width / 2.0)
          let distance_y = (node_a.center_y() - node_b.center_y()).abs() -
            (node_a.rect.height / 2.0 + node_b.rect.height / 2.0)
          if distance_x <= self.repulsion_range &&
            distance_y <= self.repulsion_range {
            in_surrounding[node_b.index] = true
            surrounding.push(node_b)
          }
        }
      }
    }
  }
  node_a.surrounding = surrounding
}

///|
/// `FDLayout.updateGrid`: cells as wide as the repulsion range over the
/// bounds of the graph, each with the nodes that reach into it.
fn Layout::update_grid(self : Layout) -> Unit {
  // `calcGrid`
  let size_x = ((self.right - self.left) / self.repulsion_range).ceil().to_int()
  let size_y = ((self.bottom - self.top) / self.repulsion_range).ceil().to_int()
  let grid : Array[Array[Array[LNode]]] = Array::makei(size_x, _ => {
    Array::makei(size_y, _ => [])
  })
  self.grid = grid
  for v in self.nodes {
    // `addNodeToGrid`
    let start_x = ((v.rect.x - self.left) / self.repulsion_range)
      .floor()
      .to_int()
    let finish_x = ((v.rect.width + v.rect.x - self.left) / self.repulsion_range)
      .floor()
      .to_int()
    let start_y = ((v.rect.y - self.top) / self.repulsion_range)
      .floor()
      .to_int()
    let finish_y = ((v.rect.height + v.rect.y - self.top) / self.repulsion_range)
      .floor()
      .to_int()
    for i = start_x; i <= finish_x; i = i + 1 {
      for j = start_y; j <= finish_y; j = j + 1 {
        grid[i][j].push(v)
      }
    }
    v.start_x = start_x
    v.finish_x = finish_x
    v.start_y = start_y
    v.finish_y = finish_y
  }
}

///|
/// `FDLayout.calcRepulsionForce` between two nodes without children.
fn calc_repulsion_force(node_a : LNode, node_b : LNode) -> Unit {
  let rect_a = node_a.rect
  let rect_b = node_b.rect
  match clip_points(rect_a, rect_b) {
    None => {
      // Overlapping nodes are pushed apart.
      let (overlap_x, overlap_y) = separation_amount(
        rect_a,
        rect_b,
        edge_length / 2.0,
      )
      let repulsion_force_x = 2.0 * overlap_x
      let repulsion_force_y = 2.0 * overlap_y
      // `noOfChildren` is 1 for both.
      let children_constant = 1.0 * 1.0 / (1.0 + 1.0)
      node_a.repulsion_force_x -= children_constant * repulsion_force_x
      node_a.repulsion_force_y -= children_constant * repulsion_force_y
      node_b.repulsion_force_x += children_constant * repulsion_force_x
      node_b.repulsion_force_y += children_constant * repulsion_force_y
    }
    Some((ax, ay, bx, by)) => {
      let mut distance_x = bx - ax
      let mut distance_y = by - ay
      if distance_x.abs() < min_repulsion_dist {
        distance_x = sign(distance_x) * min_repulsion_dist
      }
      if distance_y.abs() < min_repulsion_dist {
        distance_y = sign(distance_y) * min_repulsion_dist
      }
      let distance_squared = distance_x * distance_x + distance_y * distance_y
      let distance = distance_squared.sqrt()
      let repulsion_force = repulsion_strength * 1.0 * 1.0 / distance_squared
      let repulsion_force_x = repulsion_force * distance_x / distance
      let repulsion_force_y = repulsion_force * distance_y / distance
      node_a.repulsion_force_x -= repulsion_force_x
      node_a.repulsion_force_y -= repulsion_force_y
      node_b.repulsion_force_x += repulsion_force_x
      node_b.repulsion_force_y += repulsion_force_y
    }
  }
}

///|
/// `FDLayout.calcGravitationalForces`: nodes of a graph in several pieces
/// are pulled towards its centre once they are far from it.
fn Layout::calc_gravitational_forces(self : Layout) -> Unit {
  for node in self.nodes_with_gravity {
    let owner_center_x = (self.right + self.left) / 2.0
    let owner_center_y = (self.top + self.bottom) / 2.0
    let distance_x = node.center_x() - owner_center_x
    let distance_y = node.center_y() - owner_center_y
    let abs_distance_x = distance_x.abs() + node.rect.width / 2.0
    let abs_distance_y = distance_y.abs() + node.rect.height / 2.0
    let estimated_size = self.estimated_size * gravity_range_factor
    if abs_distance_x > estimated_size || abs_distance_y > estimated_size {
      node.gravitation_force_x = -gravity_strength * distance_x
      node.gravitation_force_y = -gravity_strength * distance_y
    }
  }
}

///|
/// `FDLayout.moveNodes` with `CoSENode.move`.
fn Layout::move_nodes(self : Layout) -> Unit {
  let limit = self.cooling_factor * max_node_displacement
  for node in self.nodes {
    // `noOfChildren` is 1.
    let mut displacement_x = self.cooling_factor *
      (node.spring_force_x + node.repulsion_force_x + node.gravitation_force_x) /
      1.0
    let mut displacement_y = self.cooling_factor *
      (node.spring_force_y + node.repulsion_force_y + node.gravitation_force_y) /
      1.0
    if displacement_x.abs() > limit {
      displacement_x = limit * sign(displacement_x)
    }
    if displacement_y.abs() > limit {
      displacement_y = limit * sign(displacement_y)
    }
    node.rect.x += displacement_x
    node.rect.y += displacement_y
    self.total_displacement += displacement_x.abs() + displacement_y.abs()
    node.spring_force_x = 0.0
    node.spring_force_y = 0.0
    node.repulsion_force_x = 0.0
    node.repulsion_force_y = 0.0
    node.gravitation_force_x = 0.0
    node.gravitation_force_y = 0.0
  }
}
