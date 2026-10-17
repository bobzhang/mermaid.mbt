// cose-base 2.2.0's `ConstraintHandler.handleConstraints` as it runs when
// the layout starts from given positions (the constraints are enforced, no
// transformation is sought), and the constraint variables of
// `CoSELayout` that keep them during the spring embedder: alignments move
// together, relative placements are relaxed in a shuffled order.

///|
/// A neighbour in the graph of relative placements: `{id, gap,
/// direction}`.
priv struct Adjacent {
  id : String
  gap : Double
}

///|
/// A relative placement as one of its ends sees it: the other end and
/// whether that end is after this one (right of it, or below it).
priv struct Side {
  other : String
  after : Bool
  gap : Double
}

///|
/// The variables of `initConstraintVariables` for relative placements.
priv struct RelativeState {
  dummy_to_node_vertical : Map[String, Array[String]]
  dummy_to_node_horizontal : Map[String, Array[String]]
  nodes_in_relative_horizontal : Array[String]
  nodes_in_relative_vertical : Array[String]
  constraints_horizontal : Map[String, Array[Side]]
  constraints_vertical : Map[String, Array[Side]]
  temp_horizontal : Map[String, Double]
  temp_vertical : Map[String, Double]
}

///|
/// The alignments of one axis as `dummy<i>` nodes: which dummy stands for
/// a node, and which nodes a dummy stands for (a node listed twice is
/// there twice).
fn dummies(
  alignments : Array[Array[String]]?,
) -> (Map[String, String], Map[String, Array[String]]) {
  let node_to_dummy : Map[String, String] = Map([])
  let dummy_to_node : Map[String, Array[String]] = Map([])
  if alignments is Some(lists) {
    for i, list in lists {
      let dummy = "dummy\{i}"
      dummy_to_node[dummy] = []
      for id in list {
        node_to_dummy[id] = dummy
        dummy_to_node[dummy].push(id)
      }
    }
  }
  (node_to_dummy, dummy_to_node)
}

///|
/// The members of a list once each, in order: a `Set` of it.
fn unique(list : Array[String]) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  let out = []
  for id in list {
    if !seen.contains(id) {
      seen[id] = ()
      out.push(id)
    }
  }
  out
}

///|
/// `dagToUndirected`.
fn dag_to_undirected(
  dag : Map[String, Array[Adjacent]],
) -> Map[String, Array[Adjacent]] {
  let undirected : Map[String, Array[Adjacent]] = Map([])
  for key, _ in dag {
    undirected[key] = []
  }
  for key, value in dag {
    for adjacent in value {
      undirected[key].push(adjacent)
      undirected[adjacent.id].push({ id: key, gap: adjacent.gap, })
    }
  }
  undirected
}

///|
/// `dagToReversed`.
fn dag_to_reversed(
  dag : Map[String, Array[Adjacent]],
) -> Map[String, Array[Adjacent]] {
  let reversed : Map[String, Array[Adjacent]] = Map([])
  for key, _ in dag {
    reversed[key] = []
  }
  for key, value in dag {
    for adjacent in value {
      reversed[adjacent.id].push({ id: key, gap: adjacent.gap, })
    }
  }
  reversed
}

///|
/// `findComponents`: breadth first, from the keys in order.
fn find_components(
  graph : Map[String, Array[Adjacent]],
) -> Array[Array[String]] {
  let components = []
  let visited : Map[String, Unit] = Map([])
  for key, _ in graph {
    if visited.contains(key) {
      continue
    }
    let component = [key]
    visited[key] = ()
    let queue = [key]
    let mut next = 0
    while next < queue.length() {
      let current = queue[next]
      next += 1
      for neighbor in graph[current] {
        if !visited.contains(neighbor.id) {
          queue.push(neighbor.id)
          visited[neighbor.id] = ()
          component.push(neighbor.id)
        }
      }
    }
    components.push(component)
  }
  components
}

///|
/// `findAppropriatePositionForRelativePlacement` with an empty set of
/// fixed nodes (which upstream tests as present): the sources of every
/// component start at their mean position, every node goes at least a
/// gap after its predecessors, and every group of nodes that flow into a
/// sink is moved back to where it was centred.
fn appropriate_positions(
  graph : Map[String, Array[Adjacent]],
  position : (String) -> Double,
  component_sources : Array[Array[String]],
) -> Map[String, Double] {
  let in_degrees : Map[String, Int32] = Map([])
  for key, _ in graph {
    in_degrees[key] = 0
  }
  for _, value in graph {
    for adjacent in value {
      in_degrees[adjacent.id] = in_degrees[adjacent.id] + 1
    }
  }
  let positions : Map[String, Double] = Map([])
  let past : Map[String, Array[String]] = Map([])
  let queue = []
  for key, degree in in_degrees {
    if degree == 0 {
      queue.push(key)
    } else {
      positions[key] = @double.neg_infinity
    }
    past[key] = [key]
  }
  for component in component_sources {
    let mut sum = 0.0
    for id in component {
      sum += position(id)
    }
    let mean = sum / component.length().to_double()
    for id in component {
      positions[id] = mean
    }
  }
  let mut next = 0
  while next < queue.length() {
    let current = queue[next]
    next += 1
    for neighbor in graph[current] {
      // A missing position compares as `undefined` does: never less.
      match (positions.get(neighbor.id), positions.get(current)) {
        (Some(at), Some(from)) if at < from + neighbor.gap =>
          positions[neighbor.id] = from + neighbor.gap
        _ => ()
      }
      in_degrees[neighbor.id] = in_degrees[neighbor.id] - 1
      if in_degrees[neighbor.id] == 0 {
        queue.push(neighbor.id)
      }
      past[neighbor.id] = set_union(past[current], past[neighbor.id])
    }
  }
  // Every sink with the nodes that flow into it.
  let components : Array[Array[String]] = []
  let members_of : Array[Map[String, Unit]] = []
  for key, value in past {
    guard graph[key].is_empty() else { continue }
    let mut exist_at = -1
    for index, set in members_of {
      if set.contains(value[0]) {
        exist_at = index
      }
    }
    if exist_at < 0 {
      let set : Map[String, Unit] = Map([])
      for id in value {
        set[id] = ()
      }
      members_of.push(set)
      components.push(unique(value))
    } else {
      for id in value {
        if !members_of[exist_at].contains(id) {
          members_of[exist_at][id] = ()
          components[exist_at].push(id)
        }
      }
    }
  }
  for component in components {
    let mut min_before = @double.infinity
    let mut min_after = @double.infinity
    let mut max_before = @double.neg_infinity
    let mut max_after = @double.neg_infinity
    for id in component {
      let before = position(id)
      let after = positions.get(id).unwrap_or(@double.not_a_number)
      if before < min_before {
        min_before = before
      }
      if before > max_before {
        max_before = before
      }
      if after < min_after {
        min_after = after
      }
      if after > max_after {
        max_after = after
      }
    }
    let diff = (min_before + max_before) / 2.0 - (min_after + max_after) / 2.0
    for id in component {
      positions[id] = positions.get(id).unwrap_or(@double.not_a_number) + diff
    }
  }
  positions
}

///|
/// `setUnion`: the first set's members, then the second's that are new.
fn set_union(a : Array[String], b : Array[String]) -> Array[String] {
  let out = a.copy()
  let seen : Map[String, Unit] = Map([])
  for id in a {
    seen[id] = ()
  }
  for id in b {
    if !seen.contains(id) {
      seen[id] = ()
      out.push(id)
    }
  }
  out
}

///|
/// `ConstraintHandler.handleConstraints` without a transformation: the
/// alignments are enforced, then the relative placements, on the centres
/// of the leaves.
fn Layout::handle_constraints(self : Layout) -> Unit {
  let manager = self.manager
  let node_indexes : Map[String, Int32] = Map([])
  let x_coords : Array[Double] = []
  let y_coords : Array[Double] = []
  let leaves = []
  for node in manager.all_nodes() {
    if node.child is None {
      node_indexes[node.id] = x_coords.length()
      x_coords.push(node.center_x())
      y_coords.push(node.center_y())
      leaves.push(node)
    }
  }
  let index_of = (id : String) => node_indexes.get(id).unwrap_or(-1)
  let coordinate = (coords : Array[Double], id : String) => {
    match node_indexes.get(id) {
      Some(index) => coords[index]
      None => @double.not_a_number
    }
  }
  // `calculateAvgPosition` of an alignment, as a set.
  let mean = (coords : Array[Double], list : Array[String]) => {
    let set = unique(list)
    let mut sum = 0.0
    for id in set {
      sum += coordinate(coords, id)
    }
    sum / set.length().to_double()
  }
  let { vertical, horizontal, relative, } = self.constraints
  if vertical is Some(lists) {
    for list in lists {
      let x = mean(x_coords, list)
      for id in unique(list) {
        let index = index_of(id)
        if index >= 0 {
          x_coords[index] = x
        }
      }
    }
  }
  if horizontal is Some(lists) {
    for list in lists {
      let y = mean(y_coords, list)
      for id in unique(list) {
        let index = index_of(id)
        if index >= 0 {
          y_coords[index] = y
        }
      }
    }
  }
  if relative is Some(constraints) {
    // The graph of the relative placements, both axes.
    // `dag` keeps one order of keys for both axes.
    let dag : Map[String, Array[(Adjacent, Bool)]] = Map([])
    for constraint in constraints {
      let (from, to, gap, horizontal_axis) = match constraint {
        Horizontal(left~, right~, gap~) => (left, right, gap, true)
        Vertical(top~, bottom~, gap~) => (top, bottom, gap, false)
      }
      match dag.get(from) {
        Some(list) => list.push(({ id: to, gap, }, horizontal_axis))
        None => dag[from] = [({ id: to, gap, }, horizontal_axis)]
      }
      if !dag.contains(to) {
        dag[to] = []
      }
    }
    let (node_to_dummy_vertical, dummy_to_node_vertical) = dummies(vertical)
    let (node_to_dummy_horizontal, dummy_to_node_horizontal) = dummies(
      horizontal,
    )
    let dummy_positions_vertical : Map[String, Double] = Map([])
    if vertical is Some(lists) {
      for i, list in lists {
        dummy_positions_vertical["dummy\{i}"] = coordinate(x_coords, list[0])
      }
    }
    let dummy_positions_horizontal : Map[String, Double] = Map([])
    if horizontal is Some(lists) {
      for i, list in lists {
        dummy_positions_horizontal["dummy\{i}"] = coordinate(y_coords, list[0])
      }
    }
    let dag_on_horizontal : Map[String, Array[Adjacent]] = Map([])
    let dag_on_vertical : Map[String, Array[Adjacent]] = Map([])
    for node_id, list in dag {
      for entry in list {
        let (adjacent, horizontal_axis) = entry
        let (dag_on, node_to_dummy) = if horizontal_axis {
          (dag_on_horizontal, node_to_dummy_vertical)
        } else {
          (dag_on_vertical, node_to_dummy_horizontal)
        }
        let source_id = node_to_dummy.get(node_id).unwrap_or(node_id)
        let target : Adjacent = match node_to_dummy.get(adjacent.id) {
          Some(dummy) => { id: dummy, gap: adjacent.gap, }
          None => adjacent
        }
        match dag_on.get(source_id) {
          Some(targets) => targets.push(target)
          None => dag_on[source_id] = [target]
        }
        if !dag_on.contains(target.id) {
          dag_on[target.id] = []
        }
      }
    }
    let sources = (dag_on : Map[String, Array[Adjacent]]) => {
      let reversed = dag_to_reversed(dag_on)
      find_components(dag_to_undirected(dag_on)).map(component => {
        component.filter(id => reversed[id].is_empty())
      })
    }
    let positions_horizontal = appropriate_positions(
      dag_on_horizontal,
      id => {
        match node_indexes.get(id) {
          Some(index) => x_coords[index]
          None =>
            dummy_positions_vertical.get(id).unwrap_or(@double.not_a_number)
        }
      },
      sources(dag_on_horizontal),
    )
    let positions_vertical = appropriate_positions(
      dag_on_vertical,
      id => {
        match node_indexes.get(id) {
          Some(index) => y_coords[index]
          None =>
            dummy_positions_horizontal.get(id).unwrap_or(@double.not_a_number)
        }
      },
      sources(dag_on_vertical),
    )
    for key, value in positions_horizontal {
      match dummy_to_node_vertical.get(key) {
        Some(members) =>
          for id in members {
            let index = index_of(id)
            if index >= 0 {
              x_coords[index] = value
            }
          }
        None => {
          let index = index_of(key)
          if index >= 0 {
            x_coords[index] = value
          }
        }
      }
    }
    for key, value in positions_vertical {
      match dummy_to_node_horizontal.get(key) {
        Some(members) =>
          for id in members {
            let index = index_of(id)
            if index >= 0 {
              y_coords[index] = value
            }
          }
        None => {
          let index = index_of(key)
          if index >= 0 {
            y_coords[index] = value
          }
        }
      }
    }
  }
  for node in leaves {
    let index = index_of(node.id)
    node.set_center(x_coords[index], y_coords[index])
  }
}

///|
/// `initConstraintVariables` for relative placements, with movements
/// relaxed: every node (or alignment) of a relative placement, its
/// placements and a position to check them against.
fn Layout::init_constraint_variables(self : Layout) -> Unit {
  guard self.constraints.relative is Some(constraints) else { return }
  let by_id : Map[String, LNode] = Map([])
  for node in self.manager.all_nodes() {
    by_id[node.id] = node
  }
  let (node_to_dummy_vertical, dummy_to_node_vertical) = dummies(
    self.constraints.vertical,
  )
  let (node_to_dummy_horizontal, dummy_to_node_horizontal) = dummies(
    self.constraints.horizontal,
  )
  let state : RelativeState = {
    dummy_to_node_vertical,
    dummy_to_node_horizontal,
    nodes_in_relative_horizontal: [],
    nodes_in_relative_vertical: [],
    constraints_horizontal: Map([]),
    constraints_vertical: Map([]),
    temp_horizontal: Map([]),
    temp_vertical: Map([]),
  }
  let center = (
    id : String,
    dummy_to_node : Map[String, Array[String]],
    x : Bool,
  ) => {
    let node = match dummy_to_node.get(id) {
      Some(members) => by_id.get(members[0])
      None => by_id.get(id)
    }
    match node {
      Some(node) => if x { node.center_x() } else { node.center_y() }
      None => @double.not_a_number
    }
  }
  for constraint in constraints {
    match constraint {
      Horizontal(left~, right~, gap~) => {
        let left = node_to_dummy_vertical.get(left).unwrap_or(left)
        let right = node_to_dummy_vertical.get(right).unwrap_or(right)
        for id in [left, right] {
          if !state.nodes_in_relative_horizontal.contains(id) {
            state.nodes_in_relative_horizontal.push(id)
            state.constraints_horizontal[id] = []
            state.temp_horizontal[id] = center(id, dummy_to_node_vertical, true)
          }
        }
        state.constraints_horizontal[left].push({
          other: right,
          after: true,
          gap,
        })
        state.constraints_horizontal[right].push({
          other: left,
          after: false,
          gap,
        })
      }
      Vertical(top~, bottom~, gap~) => {
        let top = node_to_dummy_horizontal.get(top).unwrap_or(top)
        let bottom = node_to_dummy_horizontal.get(bottom).unwrap_or(bottom)
        for id in [top, bottom] {
          if !state.nodes_in_relative_vertical.contains(id) {
            state.nodes_in_relative_vertical.push(id)
            state.constraints_vertical[id] = []
            state.temp_vertical[id] = center(
              id, dummy_to_node_horizontal, false,
            )
          }
        }
        state.constraints_vertical[top].push({
          other: bottom,
          after: true,
          gap,
        })
        state.constraints_vertical[bottom].push({
          other: top,
          after: false,
          gap,
        })
      }
    }
  }
  self.relative = Some(state)
}

///|
/// The `shuffle` of `initConstraintVariables`: the last third of the list
/// is shuffled with `Math.random`.
fn Layout::shuffle(self : Layout, list : Array[String]) -> Unit {
  let length = list.length()
  let mut i = length - 1
  while i.to_double() >= 2.0 * length.to_double() / 3.0 {
    let j = (self.random.next() * (i + 1).to_double()).floor().to_int()
    let x = list[i]
    list[i] = list[j]
    list[j] = x
    i -= 1
  }
}

///|
/// `CoSELayout.updateDisplacements`: aligned nodes move by their mean
/// displacement, and the displacements of relatively placed nodes are
/// trimmed so that every gap stays.
fn Layout::update_displacements(self : Layout) -> Unit {
  let manager = self.manager
  let by_id : Map[String, LNode] = Map([])
  for node in manager.all_nodes() {
    by_id[node.id] = node
  }
  let node = (id : String) => by_id[id]
  if self.constraints.vertical is Some(lists) {
    for list in lists {
      let mut total = 0.0
      for id in list {
        total += node(id).displacement_x
      }
      let average = total / list.length().to_double()
      for id in list {
        node(id).displacement_x = average
      }
    }
  }
  if self.constraints.horizontal is Some(lists) {
    for list in lists {
      let mut total = 0.0
      for id in list {
        total += node(id).displacement_y
      }
      let average = total / list.length().to_double()
      for id in list {
        node(id).displacement_y = average
      }
    }
  }
  guard self.relative is Some(state) else { return }
  if self.total_iterations % 10 == 0 {
    self.shuffle(state.nodes_in_relative_horizontal)
    self.shuffle(state.nodes_in_relative_vertical)
  }
  for id in state.nodes_in_relative_horizontal {
    let mut displacement = match state.dummy_to_node_vertical.get(id) {
      Some(members) => node(members[0]).displacement_x
      None => node(id).displacement_x
    }
    for side in state.constraints_horizontal[id] {
      if side.after {
        let diff = state.temp_horizontal[side.other] -
          state.temp_horizontal[id] -
          displacement
        if diff < side.gap {
          displacement -= side.gap - diff
        }
      } else {
        let diff = state.temp_horizontal[id] -
          state.temp_horizontal[side.other] +
          displacement
        if diff < side.gap {
          displacement += side.gap - diff
        }
      }
    }
    state.temp_horizontal[id] = state.temp_horizontal[id] + displacement
    match state.dummy_to_node_vertical.get(id) {
      Some(members) =>
        for id in members {
          node(id).displacement_x = displacement
        }
      None => node(id).displacement_x = displacement
    }
  }
  for id in state.nodes_in_relative_vertical {
    let mut displacement = match state.dummy_to_node_horizontal.get(id) {
      Some(members) => node(members[0]).displacement_y
      None => node(id).displacement_y
    }
    for side in state.constraints_vertical[id] {
      if side.after {
        let diff = state.temp_vertical[side.other] -
          state.temp_vertical[id] -
          displacement
        if diff < side.gap {
          displacement -= side.gap - diff
        }
      } else {
        let diff = state.temp_vertical[id] -
          state.temp_vertical[side.other] +
          displacement
        if diff < side.gap {
          displacement += side.gap - diff
        }
      }
    }
    state.temp_vertical[id] = state.temp_vertical[id] + displacement
    match state.dummy_to_node_horizontal.get(id) {
      Some(members) =>
        for id in members {
          node(id).displacement_y = displacement
        }
      None => node(id).displacement_y = displacement
    }
  }
}
