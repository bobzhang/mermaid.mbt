// The graph structures of layout-base 2.0.1 (`LNode`, `LEdge`, `LGraph`,
// `LGraphManager`) with the fields cose-base 2.2.0 adds to them, as
// cytoscape-fcose builds them. Nodes and graphs live in arrays and refer
// to each other by index; the arrays keep upstream's orders, which decide
// in what order forces are summed.

///|
/// `RectangleD`.
priv struct Rect {
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
}

///|
fn Rect::right(self : Rect) -> Double {
  self.x + self.width
}

///|
fn Rect::bottom(self : Rect) -> Double {
  self.y + self.height
}

///|
fn Rect::center_x(self : Rect) -> Double {
  self.x + self.width / 2.0
}

///|
fn Rect::center_y(self : Rect) -> Double {
  self.y + self.height / 2.0
}

///|
/// `RectangleD.intersects`: touching rectangles intersect.
fn Rect::intersects(self : Rect, other : Rect) -> Bool {
  !(self.right() < other.x ||
  self.bottom() < other.y ||
  other.right() < self.x ||
  other.bottom() < self.y)
}

///|
/// A node: `CoSENode` with everything it inherits.
priv struct LNode {
  index : Int32
  id : String
  rect : Rect
  /// The graph the node is in; -1 for the parent of the root graph.
  mut owner : Int32
  /// The graph inside a compound node.
  mut child : Int32?
  edges : Array[LEdge]
  mut estimated_size : Double
  mut inclusion_tree_depth : Int32
  /// `paddingLeft`; none for the root graph's parent, whose graph then
  /// keeps the default margin.
  padding : Double?
  node_repulsion : Double
  mut no_of_children : Double
  mut spring_force_x : Double
  mut spring_force_y : Double
  mut repulsion_force_x : Double
  mut repulsion_force_y : Double
  mut gravitation_force_x : Double
  mut gravitation_force_y : Double
  mut displacement_x : Double
  mut displacement_y : Double
  mut start_x : Int32
  mut finish_x : Int32
  mut start_y : Int32
  mut finish_y : Int32
  mut surrounding : Array[Int32]
}

///|
fn LNode::new(
  index : Int32,
  id : String,
  rect : Rect,
  padding : Double?,
  node_repulsion : Double,
) -> LNode {
  {
    index,
    id,
    rect,
    owner: -1,
    child: None,
    edges: [],
    estimated_size: integer_min,
    inclusion_tree_depth: integer_max_int,
    padding,
    node_repulsion,
    no_of_children: 0.0,
    spring_force_x: 0.0,
    spring_force_y: 0.0,
    repulsion_force_x: 0.0,
    repulsion_force_y: 0.0,
    gravitation_force_x: 0.0,
    gravitation_force_y: 0.0,
    displacement_x: 0.0,
    displacement_y: 0.0,
    start_x: 0,
    finish_x: 0,
    start_y: 0,
    finish_y: 0,
    surrounding: [],
  }
}

///|
fn LNode::center_x(self : LNode) -> Double {
  self.rect.center_x()
}

///|
fn LNode::center_y(self : LNode) -> Double {
  self.rect.center_y()
}

///|
/// `LNode.setCenter`.
fn LNode::set_center(self : LNode, cx : Double, cy : Double) -> Unit {
  self.rect.x = cx - self.rect.width / 2.0
  self.rect.y = cy - self.rect.height / 2.0
}

///|
/// An edge: `CoSEEdge`.
priv struct LEdge {
  source : Int32
  target : Int32
  mut ideal_length : Double
  edge_elasticity : Double
  mut is_inter_graph : Bool
  /// The graph of the lowest common ancestor of the ends, and the ends'
  /// ancestors (or themselves) in it.
  mut lca : Int32
  mut source_in_lca : Int32
  mut target_in_lca : Int32
  mut length : Double
  mut length_x : Double
  mut length_y : Double
  mut is_overlapping_source_and_target : Bool
}

///|
/// A graph: the root, or the inside of a compound node.
priv struct LGraph {
  /// The compound node, or the root graph's parent.
  parent : Int32
  nodes : Array[Int32]
  edges : Array[LEdge]
  mut left : Double
  mut right : Double
  mut top : Double
  mut bottom : Double
  mut estimated_size : Double
  mut is_connected : Bool
}

///|
/// `Integer.MAX_VALUE` and `Integer.MIN_VALUE` of layout-base.
const INTEGER_MAX : Double = 2147483647.0

///|
let integer_min : Double = -2147483648.0

///|
let integer_max_int : Int32 = 2147483647

///|
/// `LayoutConstants.DEFAULT_GRAPH_MARGIN`.
const DEFAULT_GRAPH_MARGIN : Double = 15.0

///|
/// `LayoutConstants.EMPTY_COMPOUND_NODE_SIZE`.
const EMPTY_COMPOUND_NODE_SIZE : Double = 40.0

///|
/// `LayoutConstants.SIMPLE_NODE_SIZE`.
const SIMPLE_NODE_SIZE : Double = 40.0

///|
/// `LGraphManager`: the nodes, the graphs in the order they were added
/// (the root first) and the edges between graphs.
priv struct Manager {
  nodes : Array[LNode]
  graphs : Array[LGraph]
  inter_graph_edges : Array[LEdge]
}

///|
fn Manager::new() -> Manager {
  { nodes: [], graphs: [], inter_graph_edges: [], }
}

///|
/// The root graph.
fn Manager::root(self : Manager) -> LGraph {
  self.graphs[0]
}

///|
/// `getAllNodes`: the nodes of every graph, graph after graph.
fn Manager::all_nodes(self : Manager) -> Array[LNode] {
  let out = []
  for graph in self.graphs {
    for index in graph.nodes {
      out.push(self.nodes[index])
    }
  }
  out
}

///|
/// `getAllEdges`: the edges of every graph, then those between graphs.
fn Manager::all_edges(self : Manager) -> Array[LEdge] {
  let out = []
  for graph in self.graphs {
    out.append(graph.edges)
  }
  out.append(self.inter_graph_edges)
  out
}

///|
/// `LNode.getEdgesBetween`.
fn Manager::edges_between(self : Manager, a : Int32, b : Int32) -> Int32 {
  let mut count = 0
  for edge in self.nodes[a].edges {
    if edge.target == b || edge.source == b {
      count += 1
    }
  }
  count
}

///|
/// `LGraphManager.add` for an edge: inside the graph of both ends, or
/// between graphs.
fn Manager::add_edge(self : Manager, edge : LEdge) -> Unit {
  let source = self.nodes[edge.source]
  let target = self.nodes[edge.target]
  if source.owner == target.owner {
    edge.is_inter_graph = false
    self.graphs[source.owner].edges.push(edge)
    source.edges.push(edge)
    if edge.target != edge.source {
      target.edges.push(edge)
    }
  } else {
    edge.is_inter_graph = true
    self.inter_graph_edges.push(edge)
    source.edges.push(edge)
    target.edges.push(edge)
  }
}

///|
/// `LGraph.updateBounds`, recursively into compound nodes: the box around
/// the nodes, widened by the padding of the compound node (or the default
/// margin for the root).
fn Manager::update_graph_bounds(self : Manager, graph : Int32) -> Unit {
  let g = self.graphs[graph]
  let mut left = INTEGER_MAX
  let mut right = -INTEGER_MAX
  let mut top = INTEGER_MAX
  let mut bottom = -INTEGER_MAX
  for index in g.nodes {
    let node = self.nodes[index]
    if node.child is Some(_) {
      self.update_node_bounds(node)
    }
    let node_left = node.rect.x
    let node_right = node.rect.right()
    let node_top = node.rect.y
    let node_bottom = node.rect.bottom()
    if left > node_left {
      left = node_left
    }
    if right < node_right {
      right = node_right
    }
    if top > node_top {
      top = node_top
    }
    if bottom < node_bottom {
      bottom = node_bottom
    }
  }
  // `new RectangleD(left, top, right - left, bottom - top)`, then its
  // edges again.
  let width = right - left
  let height = bottom - top
  let margin = match self.nodes[g.parent].padding {
    Some(padding) => padding
    None => DEFAULT_GRAPH_MARGIN
  }
  g.left = left - margin
  g.right = left + width + margin
  g.top = top - margin
  g.bottom = top + height + margin
}

///|
/// `LNode.updateBounds` of a compound node: the box of its graph.
fn Manager::update_node_bounds(self : Manager, node : LNode) -> Unit {
  guard node.child is Some(child) else { return }
  if self.graphs[child].nodes.length() != 0 {
    self.update_graph_bounds(child)
    let graph = self.graphs[child]
    node.rect.x = graph.left
    node.rect.y = graph.top
    node.rect.width = graph.right - graph.left
    node.rect.height = graph.bottom - graph.top
  }
}

///|
/// `LNode.getNoOfChildren`.
fn Manager::no_of_children(self : Manager, node : LNode) -> Double {
  match node.child {
    None => 1.0
    Some(child) => {
      let mut count = 0.0
      for index in self.graphs[child].nodes {
        count += self.no_of_children(self.nodes[index])
      }
      if count == 0.0 {
        1.0
      } else {
        count
      }
    }
  }
}

///|
/// `LGraph.calcEstimatedSize`; a compound node takes its graph's size as
/// its width and height.
fn Manager::graph_estimated_size(self : Manager, graph : Int32) -> Double {
  let g = self.graphs[graph]
  let mut size = 0.0
  for index in g.nodes {
    size += self.node_estimated_size(self.nodes[index])
  }
  g.estimated_size = if size == 0.0 {
    EMPTY_COMPOUND_NODE_SIZE
  } else {
    size / g.nodes.length().to_double().sqrt()
  }
  g.estimated_size
}

///|
/// `LNode.calcEstimatedSize`.
fn Manager::node_estimated_size(self : Manager, node : LNode) -> Double {
  match node.child {
    None => {
      node.estimated_size = (node.rect.width + node.rect.height) / 2.0
      node.estimated_size
    }
    Some(child) => {
      node.estimated_size = self.graph_estimated_size(child)
      node.rect.width = node.estimated_size
      node.rect.height = node.estimated_size
      node.estimated_size
    }
  }
}

///|
/// `LNode.withChildren`: the node and everything inside it.
fn Manager::with_children(
  self : Manager,
  node : LNode,
  out : Array[Int32],
) -> Unit {
  out.push(node.index)
  if node.child is Some(child) {
    for index in self.graphs[child].nodes {
      self.with_children(self.nodes[index], out)
    }
  }
}

///|
/// `LEdge.getOtherEndInGraph`: the other end, or its ancestor that is in
/// `graph`.
fn Manager::other_end_in_graph(
  self : Manager,
  edge : LEdge,
  node : Int32,
  graph : Int32,
) -> Int32? {
  let mut other = if edge.source == node { edge.target } else { edge.source }
  while true {
    let owner = self.nodes[other].owner
    if owner == graph {
      return Some(other)
    }
    if owner == 0 {
      break
    }
    other = self.graphs[owner].parent
  }
  None
}

///|
/// `LGraph.updateConnected`.
fn Manager::update_connected(self : Manager, graph : Int32) -> Unit {
  let g = self.graphs[graph]
  if g.nodes.length() == 0 {
    g.is_connected = true
    return
  }
  let visited = Array::make(self.nodes.length(), false)
  let queue = []
  let start = []
  self.with_children(self.nodes[g.nodes[0]], start)
  for index in start {
    queue.push(index)
    visited[index] = true
  }
  let mut next = 0
  while next < queue.length() {
    let current = queue[next]
    next += 1
    for edge in self.nodes[current].edges {
      match self.other_end_in_graph(edge, current, graph) {
        Some(neighbor) if !visited[neighbor] => {
          let inside = []
          self.with_children(self.nodes[neighbor], inside)
          for index in inside {
            queue.push(index)
            visited[index] = true
          }
        }
        _ => ()
      }
    }
  }
  let mut count = 0
  let mut in_graph = 0
  for index, seen in visited {
    if seen {
      count += 1
      if self.nodes[index].owner == graph {
        in_graph += 1
      }
    }
  }
  g.is_connected = count >= g.nodes.length() && in_graph == g.nodes.length()
}

///|
/// `LGraphManager.calcLowestCommonAncestors`.
fn Manager::calc_lowest_common_ancestors(self : Manager) -> Unit {
  for edge in self.all_edges() {
    let source = edge.source
    let target = edge.target
    edge.lca = -1
    edge.source_in_lca = source
    edge.target_in_lca = target
    if source == target {
      edge.lca = self.nodes[source].owner
      continue
    }
    let mut source_ancestor = self.nodes[source].owner
    while edge.lca == -1 {
      edge.target_in_lca = target
      let mut target_ancestor = self.nodes[target].owner
      while edge.lca == -1 {
        if target_ancestor == source_ancestor {
          edge.lca = target_ancestor
          break
        }
        if target_ancestor == 0 {
          break
        }
        edge.target_in_lca = self.graphs[target_ancestor].parent
        target_ancestor = self.nodes[edge.target_in_lca].owner
      }
      if source_ancestor == 0 {
        break
      }
      if edge.lca == -1 {
        edge.source_in_lca = self.graphs[source_ancestor].parent
        source_ancestor = self.nodes[edge.source_in_lca].owner
      }
    }
  }
}

///|
/// `LGraphManager.calcInclusionTreeDepths`.
fn Manager::calc_inclusion_tree_depths(
  self : Manager,
  graph : Int32,
  depth : Int32,
) -> Unit {
  for index in self.graphs[graph].nodes {
    let node = self.nodes[index]
    node.inclusion_tree_depth = depth
    if node.child is Some(child) {
      self.calc_inclusion_tree_depths(child, depth + 1)
    }
  }
}

///|
/// `LGraph.getInclusionTreeDepth`: 1 for the root, the depth of the
/// compound node otherwise.
fn Manager::graph_depth(self : Manager, graph : Int32) -> Int32 {
  if graph == 0 {
    1
  } else {
    self.nodes[self.graphs[graph].parent].inclusion_tree_depth
  }
}

///|
/// `LGraphManager.isOneAncestorOfOther`.
fn Manager::is_one_ancestor_of_other(
  self : Manager,
  a : Int32,
  b : Int32,
) -> Bool {
  if a == b {
    return true
  }
  let mut owner = self.nodes[a].owner
  while owner > 0 {
    let parent = self.graphs[owner].parent
    if parent == b {
      return true
    }
    owner = self.nodes[parent].owner
  }
  owner = self.nodes[b].owner
  while owner > 0 {
    let parent = self.graphs[owner].parent
    if parent == a {
      return true
    }
    owner = self.nodes[parent].owner
  }
  false
}
