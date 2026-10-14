// The data the swimlane layout works on: mermaid's `LayoutData` nodes and
// edges reduced to the fields `rendering-util/layout-algorithms/swimlanes`
// reads and writes. Upstream mutates these objects in place and compares
// points by identity in places, so nodes, edges and points are reference
// types here too: a `Pt` shared by two arrays is one object, as in
// JavaScript.

///|
/// A point. Mutable, as upstream moves points in place.
pub(all) struct Pt {
  mut x : Double
  mut y : Double
} derive(Debug)

///|
/// A new point: the object literal `{ x, y }`.
pub fn pt(x : Double, y : Double) -> Pt {
  { x, y, }
}

///|
/// A copy of the point: `{ ...point }`.
pub fn Pt::copy(self : Pt) -> Pt {
  { x: self.x, y: self.y, }
}

///|
/// An axis-aligned rectangle by its sides.
pub(all) struct Rect {
  left : Double
  right : Double
  top : Double
  bottom : Double
} derive(Eq, Debug)

///|
/// A node of the layout: a lane (a top-level group), a nested group, a
/// node of the diagram or the label of an edge, which the layout places as
/// a node of its own.
pub(all) struct Node {
  id : String
  mut label : String
  is_group : Bool
  /// The group the node belongs to.
  mut parent_id : String?
  /// The padding of a group; `undefined` upstream when absent.
  padding : Double?
  mut shape : String
  /// The diagram's direction, set on lanes by the layout.
  mut direction : String?
  /// The direction a subgraph sets for itself (`dir`).
  dir : String?
  look : String?
  color_index : Int32?
  /// A node standing for an edge's label.
  is_edge_label : Bool
  is_dummy : Bool
  /// The ends of the edge a label node stands for.
  edge_start : String?
  edge_end : String?
  label_style : String
  // Measured, then laid out.
  mut width : Double?
  mut height : Double?
  /// The centre.
  mut x : Double?
  mut y : Double?
  mut layer : Int32?
  mut order : Int32?
  /// Where the content of a lane begins, below its title.
  mut swimlane_content_top : Double?
  /// The band of a lane its title is drawn in.
  mut group_title_rect : Rect?
}

///|
/// A node with only the given fields set.
pub fn Node::new(
  id~ : String,
  label~ : String = "",
  is_group~ : Bool = false,
  parent_id? : String,
  padding? : Double,
  shape~ : String = "",
  direction? : String,
  dir? : String,
  look? : String,
  color_index? : Int32,
  is_edge_label~ : Bool = false,
  is_dummy~ : Bool = false,
  edge_start? : String,
  edge_end? : String,
  label_style~ : String = "",
  width? : Double,
  height? : Double,
) -> Node {
  {
    id,
    label,
    is_group,
    parent_id,
    padding,
    shape,
    direction,
    dir,
    look,
    color_index,
    is_edge_label,
    is_dummy,
    edge_start,
    edge_end,
    label_style,
    width,
    height,
    x: None,
    y: None,
    layer: None,
    order: None,
    swimlane_content_top: None,
    group_title_rect: None,
  }
}

///|
/// An edge of the layout.
pub(all) struct Edge {
  id : String
  start : String
  end : String
  /// The label until the layout moves it onto a label node.
  mut label : String?
  label_style : String
  /// The route, once the layout has made one.
  mut points : Array[Pt]?
  /// An edge that only steers the layout (to and from label nodes) and is
  /// not drawn.
  is_layout_only : Bool
  /// The node standing for the edge's label.
  mut label_node_id : String?
  mut curve : String?
  arrow_type_start : String?
  arrow_type_end : String?
}

///|
/// An edge with only the given fields set.
pub fn Edge::new(
  id~ : String,
  start~ : String,
  end~ : String,
  label? : String,
  label_style~ : String = "",
  is_layout_only~ : Bool = false,
  curve? : String,
  arrow_type_start? : String,
  arrow_type_end? : String,
) -> Edge {
  {
    id,
    start,
    end,
    label,
    label_style,
    points: None,
    is_layout_only,
    label_node_id: None,
    curve,
    arrow_type_start,
    arrow_type_end,
  }
}

///|
/// The swimlane options of the configuration.
pub(all) struct Options {
  /// `flowchart.nodeSpacing`
  node_spacing : Double?
  /// `flowchart.rankSpacing`
  rank_spacing : Double?
  /// `swimlane.ignoreCrossLaneEdges`
  ignore_cross_lane_edges : Bool
  /// `swimlane.optimizeRanksByCrossings`
  optimize_ranks_by_crossings : Bool
  /// `swimlane.automaticLaneOrdering`
  automatic_lane_ordering : Bool
  /// `look`, given to the lane made for nodes outside every lane.
  look : String?
}

///|
/// The defaults of the configuration schema.
pub fn Options::default() -> Options {
  {
    node_spacing: Some(50.0),
    rank_spacing: Some(50.0),
    ignore_cross_lane_edges: true,
    optimize_ranks_by_crossings: true,
    automatic_lane_ordering: false,
    look: None,
  }
}

///|
/// What the layout works on: `data4Layout`.
pub(all) struct Layout {
  mut nodes : Array[Node]
  mut edges : Array[Edge]
  /// The diagram's direction, when it sets one.
  direction : String?
  options : Options
}
