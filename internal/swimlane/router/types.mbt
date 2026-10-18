// The router's working data: the type definitions of
// `orthogonalRouter/router.ts`. Pipes, tracks and routed segments are
// shared and mutated by reference, as upstream compares them by identity.

///|
/// `PRECISION.EPSILON`: the tolerance of the router's comparisons.
const EPS7 : Double = 1.0e-6

///|
/// How far obstacles reach beyond their node.
const NODE_PADDING : Double = 8.0

///|
const HORIZONTAL_PIPE_MARGIN : Double = 15.0

///|
const VERTICAL_PIPE_MARGIN : Double = 15.0

///|
/// How far the routing box reaches around an obstacle in the way.
const ROUTING_MARGIN : Double = 25.0

///|
/// How far an anchor stands off its port.
const ANCHOR_OFFSET : Double = 20.0

///|
/// The distance between parallel tracks of a pipe.
const TRACK_SPACING : Double = 10.0

///|
/// The cost A* adds for crossing an edge routed before.
const CROSSING_PENALTY : Double = 1.0e3

///|
/// The axis of a pipe or segment.
priv enum Orient {
  Horizontal
  Vertical
} derive(Eq)

///|
/// A node's box inflated by `NODE_PADDING`, which routes avoid.
priv struct Obstacle {
  node_id : String
  min_x : Double
  max_x : Double
  min_y : Double
  max_y : Double
  /// Half the extent across x the node will have once an LR layout is
  /// turned: its height then.
  visual_x_half_extent : Double
}

///|
/// A reference to a segment kept by a track: `SegmentRef`.
priv struct TrackRef {
  edge_index : Int32
  segment_index : Int32
  from : Double
  to : Double
}

///|
/// One lane of a pipe that segments are spread onto. (Upstream also keeps
/// the pipe's coord in it, which nothing reads.)
priv struct Track {
  index : Int32
  mut segments : Array[TrackRef]
}

///|
/// A line along which segments run: `RoutingPipe`.
priv struct Pipe {
  orientation : Orient
  coord : Double
  mut span_min : Double
  mut span_max : Double
  tracks : Array[Track]
}

///|
/// A segment of a routed edge: `RoutedSegment`.
priv struct RoutedSeg {
  edge_index : Int32
  segment_index : Int32
  orientation : Orient
  pipe : Pipe
  mut track_index : Int32
  from : Double
  to : Double
  /// Its index in `all_routed_segments` (each segment is pushed once and
  /// never removed), which upstream finds with `indexOf`.
  pos : Int32
}

///|
/// A drawn edge as the router sees it: `{ ...oe, __originalEdge: oe }`.
priv struct RouteEdge {
  orig : @model.Edge
  start : String
  end : String
  mut points : Array[@model.Pt]?
  label_node_id : String?
}

///|
/// The sides an edge leaves and enters by, decided before routing.
priv struct SideInfo {
  edge_idx : Int32
  src_id : String
  dst_id : String
  mut src_side : @model.Side
  dst_side : @model.Side
  abs_dx : Double
  abs_dy : Double
  dx_sign : Double
  dy_sign : Double
}

///|
/// An edge using a face of a node, with the coordinate of its other end.
priv struct PortEntry {
  edge_idx : Int32
  opposite_coord : Double
}

///|
/// The edges using one face of a node in one role: a value of
/// `portGroups` with the parts of its key `nodeId:side:role`.
priv struct PortGroup {
  node_id : String
  side : @model.Side
  role : String
  entries : Array[PortEntry]
}

///|
/// Where an edge heads after its first segment: `getDestInfo`.
priv struct DestInfo {
  dest : Double
  deviation : Double
  delta : Double
}

///|
/// A segment of the final route.
priv struct Line {
  orient : Orient
  coord : Double
  from : Double
  to : Double
}

///|
/// An entry of the A* open list.
priv struct OpenEntry {
  key : String
  mut f : Double
  pt : @model.Pt
}

///|
/// The state shared by the router's phases: the locals of
/// `routeEdgesOrthogonal` its closures capture.
priv struct Router {
  edges : Array[RouteEdge]
  node_by_id : Map[String, @model.Node]
  /// The id of the lane of every node in a lane.
  lane_by_node_id : Map[String, String]
  pipes : Array[Pipe]
  is_lr : Bool
  obstacles : Array[Obstacle]
  all_routed_segments : Array[RoutedSeg]
  edge_segment_indices : Array[Array[Int32]]
  straight_intra_lane_edges : Set[Int32]
  incident_edge_totals : Map[String, Int32]
  side_info_by_idx : Map[Int32, SideInfo]
  port_groups : Map[String, PortGroup]
  port_offsets : Map[String, Double]
  dest_info_cache : Map[Int32, DestInfo]
}

///|
/// `Math.sign`.
fn js_sign(x : Double) -> Double {
  if x > 0.0 {
    1.0
  } else if x < 0.0 {
    -1.0
  } else {
    x
  }
}

///|
/// The name of a side, as upstream spells it in keys.
fn side_name(side : @model.Side) -> String {
  match side {
    Top => "top"
    Bottom => "bottom"
    Left => "left"
    Right => "right"
  }
}

///|
/// Whether a port on this side leaves vertically (top or bottom).
fn side_is_vertical(side : @model.Side) -> Bool {
  side is (Top | Bottom)
}
