// cytoscape-fcose 2.2.0's `coseLayout` for a layout that starts from the
// positions it is given (`randomize: false`, `quality: "proof"`), and
// cose-base 2.2.0's `CoSELayout` with layout-base 2.0.1's `FDLayout` as
// that drives them: the graph is built, the constraints are enforced, and
// the spring embedder runs.

///|
/// Why a layout fails.
pub(all) suberror FcoseError {
  /// What the port cannot reproduce exactly and refuses.
  Unsupported(String)
  /// Contradicting constraints put a node at an infinite position, and
  /// the repulsion grid cannot be built: upstream's `RangeError` "Invalid
  /// array length".
  InvalidArrayLength
} derive(Eq, Debug)

///|
/// A node to lay out, with the nodes inside it.
pub(all) struct Node {
  id : String
  /// The top left corner and the size.
  x : Double
  y : Double
  width : Double
  height : Double
  /// The padding of a compound node: the margin around its insides.
  padding : Double
  /// `nodeRepulsion`.
  repulsion : Double
  children : Array[Node]
}

///|
/// An edge between two nodes, by id.
pub(all) struct Edge {
  id : String
  source : String
  target : String
  ideal_length : Double
  elasticity : Double
}

///|
/// A relative placement constraint: `left` left of `right` (or `top`
/// above `bottom`) by at least `gap` between centres.
pub(all) enum Relative {
  Horizontal(left~ : String, right~ : String, gap~ : Double)
  Vertical(top~ : String, bottom~ : String, gap~ : Double)
} derive(Debug)

///|
/// fcose's `alignmentConstraint` and `relativePlacementConstraint`.
/// `vertical` lists share an x, `horizontal` lists a y; a list may name a
/// node twice, and counts it twice where upstream does.
pub(all) struct Constraints {
  vertical : Array[Array[String]]?
  horizontal : Array[Array[String]]?
  relative : Array[Relative]?
}

///|
/// The options the layout takes from fcose's.
pub(all) struct Options {
  /// `numIter`.
  num_iter : Int32
  /// The seed of `Math.random`.
  seed : UInt32
}

///|
/// A node where the layout put it: its top left corner and size.
pub(all) struct Placed {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Debug, ToJson)

///|
/// Told the nodes, in upstream's order, at the steps of a run.
pub(all) struct Tracer {
  /// The graph as built, before anything moved.
  start : (Array[Placed]) -> Unit
  /// Once the constraints are enforced.
  enforced : (Array[Placed]) -> Unit
  /// After every iteration of the spring embedder.
  tick : (Array[Placed]) -> Unit
}

///|
/// The constants of `CoSEConstants`/`FDLayoutConstants` as fcose sets
/// them for this layout.
let gravity_constant = 0.25

///|
let gravity_range_factor = 3.8

///|
let compound_gravity_constant = 1.0

///|
let compound_gravity_range_factor = 1.5

///|
let per_level_ideal_edge_length_factor = 0.1

///|
let initial_cooling_factor = 0.3

///|
let max_node_displacement = 100.0

///|
let convergence_check_period = 100

///|
let grid_calculation_check_period = 10

///|
/// The state of a run: `CoSELayout`.
priv struct Layout {
  manager : Manager
  constraints : Constraints
  /// `CoSEConstants.DEFAULT_EDGE_LENGTH`: the mean ideal edge length.
  default_edge_length : Double
  /// `MIN_REPULSION_DIST`.
  min_repulsion_dist : Double
  ideal_edge_length : Double
  random : Random
  mut nodes_with_gravity : Array[Int32]
  mut cooling_factor : Double
  mut max_iterations : Int32
  mut total_iterations : Int32
  mut total_displacement : Double
  mut old_total_displacement : Double
  mut total_displacement_threshold : Double
  mut repulsion_range : Double
  mut cooling_cycle : Int32
  mut grid : Array[Array[Array[Int32]]]
  mut relative : RelativeState?
  tracer : Tracer?
}

///|
fn Layout::snapshot(self : Layout) -> Array[Placed] {
  self.manager
  .all_nodes()
  .map(node => {
    id: node.id,
    x: node.rect.x,
    y: node.rect.y,
    width: node.rect.width,
    height: node.rect.height,
  })
}

///|
/// Lay out a graph as fcose does from the given positions, and answer with
/// every node where it ends, compound nodes included, in upstream's order
/// (`getAllNodes`): the top-level nodes, then the insides of every compound
/// node in the order they were built.
///
/// Edges whose ends are one node, or two nodes already joined, are left
/// out as fcose leaves them out.
pub fn layout(
  roots : Array[Node],
  edges : Array[Edge],
  constraints : Constraints,
  options : Options,
  tracer? : Tracer,
) -> Array[Placed] raise FcoseError {
  let manager = Manager::new()
  // The parent of the root graph, which has no padding.
  manager.nodes.push(
    LNode::new(0, "", { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }, None, 0.0),
  )
  manager.graphs.push(new_graph(0))
  let by_id : Map[String, Int32] = Map([])
  // `processChildrenList`
  fn add_children(graph : Int32, children : Array[Node]) -> Unit {
    for child in children {
      let index = manager.nodes.length()
      let rect : Rect = {
        x: child.x,
        y: child.y,
        width: child.width,
        height: child.height,
      }
      if rect.x.is_nan() {
        rect.x = 0.0
      }
      if rect.y.is_nan() {
        rect.y = 0.0
      }
      let node = LNode::new(
        index,
        child.id,
        rect,
        Some(child.padding),
        child.repulsion,
      )
      node.owner = graph
      manager.nodes.push(node)
      manager.graphs[graph].nodes.push(index)
      by_id[child.id] = index
      if !child.children.is_empty() {
        let inside = manager.graphs.length()
        manager.graphs.push(new_graph(index))
        node.child = Some(inside)
        add_children(inside, child.children)
      }
    }
  }

  add_children(0, roots)
  // `processEdges`
  let mut ideal_length_total = 0.0
  let mut edge_count = 0
  for edge in edges {
    guard by_id.get(edge.source) is Some(source) &&
      by_id.get(edge.target) is Some(target) else {
      continue
    }
    if source != target && manager.edges_between(source, target) == 0 {
      manager.add_edge({
        source,
        target,
        ideal_length: edge.ideal_length,
        edge_elasticity: edge.elasticity,
        is_inter_graph: false,
        lca: -1,
        source_in_lca: -1,
        target_in_lca: -1,
        length: 0.0,
        length_x: 0.0,
        length_y: 0.0,
        is_overlapping_source_and_target: false,
      })
      ideal_length_total += edge.ideal_length
      edge_count += 1
    }
  }
  // An `idealEdgeLength` function averages the edges, or is 50 without
  // any.
  let default_edge_length = if edge_count > 0 {
    ideal_length_total / edge_count.to_double()
  } else {
    50.0
  }
  if manager.nodes.length() - 1 > 1000 {
    raise Unsupported("fcose: more than 1000 nodes cool down differently")
  }
  let layout : Layout = {
    manager,
    constraints,
    default_edge_length,
    min_repulsion_dist: default_edge_length / 10.0,
    ideal_edge_length: if default_edge_length < 10.0 {
      10.0
    } else {
      default_edge_length
    },
    random: { state: options.seed, },
    nodes_with_gravity: [],
    cooling_factor: initial_cooling_factor,
    max_iterations: options.num_iter,
    total_iterations: 0,
    total_displacement: 0.0,
    old_total_displacement: 0.0,
    total_displacement_threshold: 0.0,
    repulsion_range: 0.0,
    cooling_cycle: 0,
    grid: [],
    relative: None,
    tracer,
  }
  if layout.tracer is Some(tracer) {
    (tracer.start)(layout.snapshot())
  }
  // `runLayout`: nothing to lay out without nodes.
  if !manager.root().nodes.is_empty() {
    layout.remove_invalid_edges()
    layout.classic_layout()
  }
  layout.snapshot()
}

///|
fn new_graph(parent : Int32) -> LGraph {
  {
    parent,
    nodes: [],
    edges: [],
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
    estimated_size: integer_min,
    is_connected: false,
  }
}

///|
/// `LGraphManager.includesInvalidEdge`: edges between a compound node and
/// what is inside it go.
fn Layout::remove_invalid_edges(self : Layout) -> Unit {
  let manager = self.manager
  let invalid = manager.inter_graph_edges.filter(edge => {
    manager.is_one_ancestor_of_other(edge.source, edge.target)
  })
  for edge in invalid {
    let remove_from = (list : Array[LEdge]) => {
      match list.search_by(e => physical_equal(e, edge)) {
        Some(at) => list.remove(at) |> ignore
        None => ()
      }
    }
    remove_from(manager.nodes[edge.source].edges)
    remove_from(manager.nodes[edge.target].edges)
    remove_from(manager.inter_graph_edges)
  }
}

///|
/// `CoSELayout.classicLayout` for an incremental layout with constraints.
fn Layout::classic_layout(self : Layout) -> Unit raise FcoseError {
  let manager = self.manager
  // `calculateNodesToApplyGravitationTo`
  let with_gravity = []
  for graph in 0..<manager.graphs.length() {
    manager.update_connected(graph)
    if !manager.graphs[graph].is_connected {
      with_gravity.append(manager.graphs[graph].nodes)
    }
  }
  self.nodes_with_gravity = with_gravity
  // `calcNoOfChildrenForAllNodes`
  for node in manager.all_nodes() {
    node.no_of_children = manager.no_of_children(node)
  }
  manager.calc_lowest_common_ancestors()
  manager.calc_inclusion_tree_depths(0, 1)
  manager.graph_estimated_size(0) |> ignore
  self.calc_ideal_edge_lengths()
  // The constraints are always handed over, if only as an empty
  // alignment.
  self.handle_constraints()
  self.init_constraint_variables()
  if self.tracer is Some(tracer) {
    (tracer.enforced)(self.snapshot())
  }
  self.init_spring_embedder()
  // `runSpringEmbedder`
  while true {
    let done = self.tick()
    if self.tracer is Some(tracer) {
      (tracer.tick)(self.snapshot())
    }
    if done {
      break
    }
  }
  manager.update_graph_bounds(0)
}

///|
/// `FDLayout.calcIdealEdgeLengths`: an edge between graphs is longer by
/// the sizes of what it joins and by how deep it reaches.
fn Layout::calc_ideal_edge_lengths(self : Layout) -> Unit {
  let manager = self.manager
  for edge in manager.all_edges() {
    let original = edge.ideal_length
    if edge.is_inter_graph {
      let source = manager.nodes[edge.source]
      let target = manager.nodes[edge.target]
      let size_of_source = manager.nodes[edge.source_in_lca].estimated_size
      let size_of_target = manager.nodes[edge.target_in_lca].estimated_size
      edge.ideal_length += size_of_source +
        size_of_target -
        2.0 * SIMPLE_NODE_SIZE
      let lca_depth = manager.graph_depth(edge.lca)
      edge.ideal_length += original *
        per_level_ideal_edge_length_factor *
        (source.inclusion_tree_depth +
        target.inclusion_tree_depth -
        2 * lca_depth).to_double()
    }
  }
}

///|
/// `FDLayout.initSpringEmbedder` and `CoSELayout.initSpringEmbedder` for
/// an incremental layout.
fn Layout::init_spring_embedder(self : Layout) -> Unit {
  let count = self.manager.all_nodes().length()
  self.max_iterations = if count * 5 > self.max_iterations {
    count * 5
  } else {
    self.max_iterations
  }
  let displacement_threshold_per_node = 3.0 * self.default_edge_length / 100.0
  self.total_displacement_threshold = displacement_threshold_per_node *
    count.to_double()
  // `calcRepulsionRange` at level 0.
  self.repulsion_range = 2.0 * (0 + 1).to_double() * self.ideal_edge_length
  self.cooling_cycle = 0
}

///|
/// `FDLayout.isConverged`.
fn Layout::is_converged(self : Layout) -> Bool {
  let mut oscillating = false
  if self.total_iterations.to_double() > self.max_iterations.to_double() / 3.0 {
    oscillating = (self.total_displacement - self.old_total_displacement).abs() <
      2.0
  }
  let converged = self.total_displacement < self.total_displacement_threshold
  self.old_total_displacement = self.total_displacement
  converged || oscillating
}

///|
/// `CoSELayout.tick`: one iteration; true when the layout is done.
fn Layout::tick(self : Layout) -> Bool raise FcoseError {
  self.total_iterations += 1
  if self.total_iterations == self.max_iterations {
    return true
  }
  if self.total_iterations % convergence_check_period == 0 {
    if self.is_converged() {
      return true
    }
    self.cooling_cycle += 1
    self.cooling_factor = cooling_factor(
      self.cooling_cycle,
      self.max_iterations,
    )
  }
  self.total_displacement = 0.0
  self.manager.update_graph_bounds(0)
  self.calc_spring_forces()
  self.calc_repulsion_forces()
  self.calc_gravitational_forces()
  self.move_nodes()
  false
}
