// A transcription of the layout of dagre as dagre-d3-es 7.0.14 ships it
// (`src/dagre/`), operation for operation: the layout is deterministic but
// sensitive to the order in which nodes and edges are visited, to the
// stability of every sort and to the order of floating point operations.
// Nothing here is improved on. Where dagre reads a property that an object
// may not have, the field is an option; a state in which dagre would throw
// a `TypeError` raises `LayoutError`.

///|
/// The layout failed, as dagre's does by throwing.
pub(all) suberror LayoutError {
  LayoutError(String)
} derive(Debug)

///|
/// What dagre reads of the label of the graph it lays out. An attribute
/// that is `None` is one the label does not have.
pub(all) struct GraphAttrs {
  /// `TB`, `BT`, `LR` or `RL`, in any case.
  rankdir : String?
  nodesep : Double?
  edgesep : Double?
  ranksep : Double?
  marginx : Double?
  marginy : Double?
  /// `greedy`, or anything else for the depth-first search.
  acyclicer : String?
  /// `network-simplex`, `tight-tree` or `longest-path`.
  ranker : String?
  /// `UL`, `UR`, `DL` or `DR`, or none to balance the four.
  align : String?
}

///|
/// A node of the graph to lay out, with what dagre reads of its label.
pub(all) struct NodeAttrs {
  id : String
  width : Double?
  height : Double?
  /// The node this one is nested in.
  parent : String?
}

///|
/// An edge of the graph to lay out, with what dagre reads of its label.
pub(all) struct EdgeAttrs {
  v : String
  w : String
  name : String?
  minlen : Double?
  weight : Double?
  /// The size of the label.
  width : Double?
  height : Double?
  labeloffset : Double?
  /// `l`, `c` or `r`.
  labelpos : String?
}

///|
pub(all) struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
/// What the layout writes back to the label of a node: its centre, and
/// its size when it has children.
pub(all) struct NodeLayout {
  x : Double
  y : Double
  width : Double
  height : Double
  /// Whether nodes are nested in this one, so that the size is the
  /// layout's.
  compound : Bool
}

///|
/// What the layout writes back to the label of an edge: its route and
/// the centre of its label, if the route makes room for one.
pub(all) struct EdgeLayout {
  points : Array[Point]
  label : Point?
}

///|
/// A laid out graph: its size, and the nodes and edges in the order they
/// were given.
pub(all) struct Layout {
  width : Double
  height : Double
  nodes : Array[NodeLayout]
  edges : Array[EdgeLayout]
}

///|
/// A point of a route while it is being laid out.
priv struct Pt {
  mut x : Double
  mut y : Double
}

///|
/// The label of the layout graph.
priv struct GraphLabel {
  mut ranksep : Double
  edgesep : Double
  nodesep : Double
  rankdir : String
  marginx : Double?
  marginy : Double?
  acyclicer : String?
  ranker : String?
  align : String?
  mut nesting_root : String?
  mut node_rank_factor : Int32?
  mut dummy_chains : Array[String]
  mut width : Double
  mut height : Double
}

///|
/// The label of a node of the layout graph: of a node of the input, or of
/// one of the dummy nodes the layout adds.
priv struct NodeLabel {
  mut width : Double
  mut height : Double
  /// Not a number until the node is positioned.
  mut x : Double
  mut y : Double
  mut rank : Int32?
  mut order : Int32?
  /// `root`, `border`, `edge`, `edge-label`, `edge-proxy` or `selfedge`
  /// for a node the layout added.
  mut dummy : String?
  /// `borderLeft` or `borderRight`.
  mut border_type : String?
  mut border_top : String?
  mut border_bottom : String?
  /// The border nodes of a compound node, one per rank from `min_rank`.
  mut border_left : Array[String]?
  mut border_right : Array[String]?
  mut min_rank : Int32?
  mut max_rank : Int32?
  /// The edge a dummy node stands for.
  mut edge_label : EdgeLabel?
  mut edge_obj : @graphlib.Edge?
  mut labelpos : String?
  /// The edge of an edge proxy or of a self edge.
  mut e : @graphlib.Edge?
  /// The label of the self edge a dummy node keeps room for.
  mut label : EdgeLabel?
  mut self_edges : Array[(@graphlib.Edge, EdgeLabel)]?
  /// A node without a label: one that only an edge or a child names.
  missing : Bool
}

///|
fn NodeLabel::new(
  width~ : Double = 0.0,
  height~ : Double = 0.0,
  rank? : Int32,
  missing~ : Bool = false,
) -> NodeLabel {
  {
    width,
    height,
    x: @double.not_a_number,
    y: @double.not_a_number,
    rank,
    order: None,
    dummy: None,
    border_type: None,
    border_top: None,
    border_bottom: None,
    border_left: None,
    border_right: None,
    min_rank: None,
    max_rank: None,
    edge_label: None,
    edge_obj: None,
    labelpos: None,
    e: None,
    label: None,
    self_edges: None,
    missing,
  }
}

///|
/// The label of an edge of the layout graph.
priv struct EdgeLabel {
  mut minlen : Int32
  weight : Double
  mut width : Double
  mut height : Double
  labeloffset : Double
  labelpos : String
  mut points : Array[Pt]?
  /// The centre of the label, once the edge has one.
  mut x : Double?
  mut y : Double?
  mut reversed : Bool
  mut forward_name : String?
  mut label_rank : Int32?
  nesting_edge : Bool
}

///|
/// The label of an edge the layout adds: `{ weight, minlen }` and no more.
fn EdgeLabel::new(
  weight~ : Double,
  minlen~ : Int32 = 1,
  nesting_edge~ : Bool = false,
) -> EdgeLabel {
  {
    minlen,
    weight,
    width: 0.0,
    height: 0.0,
    labeloffset: 0.0,
    labelpos: "",
    points: None,
    x: None,
    y: None,
    reversed: false,
    forward_name: None,
    label_rank: None,
    nesting_edge,
  }
}

///|
/// What ranking reads of an edge.
priv trait RankEdge {
  fn minlen(Self) -> Int32
  fn weight(Self) -> Double
}

///|
impl RankEdge for EdgeLabel with fn minlen(self) {
  self.minlen
}

///|
impl RankEdge for EdgeLabel with fn weight(self) {
  self.weight
}
