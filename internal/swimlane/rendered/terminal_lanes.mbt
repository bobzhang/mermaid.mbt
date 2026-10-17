// Two routes ending on the same node along the same lane:
// `separateSharedRenderedTerminalLanes`.

///|
/// The stretch of a route between a node's border and the first turn:
/// one end of a route as drawn.
priv struct TerminalLane {
  edge : @model.Edge
  node_id : String
  at_start : Bool
  /// Orientation `"V"`, otherwise `"H"`.
  vertical : Bool
  coord : Double
  min : Double
  max : Double
  /// Where the route meets the node's box.
  boundary : @model.Pt
  /// Where the lane turns, or the end of the route when it does not.
  rail_end : @model.Pt
  rect : @model.Rect
}

///|
/// How far a lane moves at a time: `TRACK_SHIFT`.
const TRACK_SHIFT : Double = 7.0

///|
/// How close two lanes on the same face of a node may come:
/// `MIN_FACE_CLEARANCE`.
const MIN_FACE_CLEARANCE : Double = 16.0

///|
/// Where the line from the centre of a node towards `point` leaves its box,
/// as dagre computes it: `rectIntersect`.
fn rect_intersect(node : @model.Node, point : @model.Pt) -> @model.Pt {
  let x = node.x.unwrap_or(0.0)
  let y = node.y.unwrap_or(0.0)
  let dx = point.x - x
  let dy = point.y - y
  let mut w = node.width.unwrap_or(0.0) / 2.0
  let mut h = node.height.unwrap_or(0.0) / 2.0
  if dy.abs() * w > dx.abs() * h {
    if dy < 0.0 {
      h = -h
    }
    return @model.pt(x + (if dy == 0.0 { 0.0 } else { h * dx / dy }), y + h)
  }
  if dx < 0.0 {
    w = -w
  }
  @model.pt(x + w, y + (if dx == 0.0 { 0.0 } else { w * dy / dx }))
}

///|
/// The lane at one end of `route`, a route of `edge`: `terminalLaneFor`.
fn terminal_lane_for(
  edge : @model.Edge,
  route : Array[@model.Pt],
  at_start : Bool,
  node_by_id : Map[String, @model.Node],
) -> TerminalLane? {
  let points = @model.dedupe_consecutive_points(route)
  if points.length() < 2 {
    return None
  }
  let node_id = if at_start { edge.start } else { edge.end }
  guard node_for(node_by_id, node_id) is Some(node) else { return None }
  guard @model.rect_of_node_bounds(node) is Some(rect) else { return None }
  let n = points.length()
  let endpoint = if at_start { points[0] } else { points[n - 1] }
  let adjacent = if at_start { points[1] } else { points[n - 2] }
  let boundary = rect_intersect(node, endpoint)
  let mut rail_end = endpoint
  if orthogonally_aligned(adjacent, boundary) {
    rail_end = adjacent
  }
  if @model.same_x(boundary, rail_end, epsilon=EPS_LOCAL) {
    return Some({
      edge,
      node_id,
      at_start,
      vertical: true,
      coord: boundary.x,
      min: @model.js_min(boundary.y, rail_end.y),
      max: @model.js_max(boundary.y, rail_end.y),
      boundary,
      rail_end,
      rect,
    })
  }
  if @model.same_y(boundary, rail_end, epsilon=EPS_LOCAL) {
    return Some({
      edge,
      node_id,
      at_start,
      vertical: false,
      coord: boundary.y,
      min: @model.js_min(boundary.x, rail_end.x),
      max: @model.js_max(boundary.x, rail_end.x),
      boundary,
      rail_end,
      rect,
    })
  }
  None
}

///|
/// `projectedOverlapLength`.
fn projected_overlap_length(a : TerminalLane, b : TerminalLane) -> Double {
  @model.js_max(0.0, @model.js_min(a.max, b.max) - @model.js_max(a.min, b.min))
}

///|
/// Whether two horizontal lanes meet the same vertical face, or two
/// vertical ones the same horizontal face: `sameTerminalFace`.
fn same_terminal_face(a : TerminalLane, b : TerminalLane) -> Bool {
  if a.node_id != b.node_id || a.vertical != b.vertical {
    return false
  }
  if !a.vertical {
    let a_on_horizontal_face = (a.boundary.x - a.rect.left).abs() < 1.0 ||
      (a.boundary.x - a.rect.right).abs() < 1.0
    return a_on_horizontal_face &&
      @model.same_x(a.boundary, b.boundary, epsilon=1.0)
  }
  let a_on_vertical_face = (a.boundary.y - a.rect.top).abs() < 1.0 ||
    (a.boundary.y - a.rect.bottom).abs() < 1.0
  a_on_vertical_face && @model.same_y(a.boundary, b.boundary, epsilon=1.0)
}

///|
/// Two lanes of a node on the same track: `exactTerminalLaneConflict`.
fn exact_terminal_lane_conflict(a : TerminalLane, b : TerminalLane) -> Bool {
  if a.node_id != b.node_id || a.vertical != b.vertical {
    return false
  }
  let shared = projected_overlap_length(a, b)
  shared >= MIN_SHARED && (a.coord - b.coord).abs() < 0.5
}

///|
/// A route leaving and one entering a node on the same face, on tracks
/// too close to tell apart: `nearTerminalLaneConflict`.
fn near_terminal_lane_conflict(a : TerminalLane, b : TerminalLane) -> Bool {
  if a.node_id != b.node_id ||
    a.vertical != b.vertical ||
    a.vertical ||
    a.at_start == b.at_start {
    return false
  }
  let shared = projected_overlap_length(a, b)
  if shared < MIN_SHARED {
    return false
  }
  let face_span = a.rect.bottom - a.rect.top
  if shared < face_span || shared > 2.0 * face_span {
    return false
  }
  same_terminal_face(a, b) && (a.coord - b.coord).abs() < MIN_FACE_CLEARANCE
}

///|
/// The route of the lane's edge with the lane moved by `shift` across
/// itself, when the lane stays on the same face of the node and the route
/// stays orthogonal: `shiftedCandidate`.
fn shifted_candidate(lane : TerminalLane, shift : Double) -> Array[@model.Pt]? {
  let points = route_of(lane.edge)
  if points.length() < 2 {
    return None
  }
  let shifted_boundary = if lane.vertical {
    @model.pt(lane.boundary.x + shift, lane.boundary.y)
  } else {
    @model.pt(lane.boundary.x, lane.boundary.y + shift)
  }
  let shifted_rail_end = if lane.vertical {
    @model.pt(lane.rail_end.x + shift, lane.rail_end.y)
  } else {
    @model.pt(lane.rail_end.x, lane.rail_end.y + shift)
  }
  let boundary_stays_on_same_face = if (lane.boundary.y - lane.rect.top).abs() <
    1.0 ||
    (lane.boundary.y - lane.rect.bottom).abs() < 1.0 {
    @model.same_y(shifted_boundary, lane.boundary, epsilon=EPS_LOCAL) &&
    shifted_boundary.x >= lane.rect.left + 1.0 &&
    shifted_boundary.x <= lane.rect.right - 1.0
  } else if (lane.boundary.x - lane.rect.left).abs() < 1.0 ||
    (lane.boundary.x - lane.rect.right).abs() < 1.0 {
    @model.same_x(shifted_boundary, lane.boundary, epsilon=EPS_LOCAL) &&
    shifted_boundary.y >= lane.rect.top + 1.0 &&
    shifted_boundary.y <= lane.rect.bottom - 1.0
  } else {
    false
  }
  if !boundary_stays_on_same_face {
    return None
  }
  let n = points.length()
  if lane.at_start {
    let rail_end_is_adjacent = n > 1 &&
      @model.same_point(points[1], lane.rail_end, epsilon=EPS_LOCAL)
    let rest = points[if rail_end_is_adjacent { 2 } else { 1 }:].to_owned()
    if rest is [next, ..] && !orthogonally_aligned(next, shifted_rail_end) {
      return None
    }
    return Some([shifted_boundary, shifted_rail_end, ..rest])
  }
  let rail_end_is_adjacent = n > 1 &&
    @model.same_point(points[n - 2], lane.rail_end, epsilon=EPS_LOCAL)
  let before = points[:n - (if rail_end_is_adjacent { 2 } else { 1 })].to_owned()
  if before is [.., previous] &&
    !orthogonally_aligned(previous, shifted_rail_end) {
    return None
  }
  Some([..before, shifted_rail_end, shifted_boundary])
}

///|
/// Whether the lane's edge is a straight line between two nodes on a row
/// or a column, which moving the lane would bend:
/// `laneIsStraightCollinearConnector`.
fn lane_is_straight_collinear_connector(
  lane : TerminalLane,
  node_by_id : Map[String, @model.Node],
) -> Bool {
  let edge = lane.edge
  let points = route_of(edge)
  guard points is [a, b] else { return false }
  guard node_for(node_by_id, edge.start) is Some(start) &&
    node_for(node_by_id, edge.end) is Some(end) else {
    return false
  }
  let start_x = start.x.unwrap_or(0.0)
  let start_y = start.y.unwrap_or(0.0)
  let end_x = end.x.unwrap_or(0.0)
  let end_y = end.y.unwrap_or(0.0)
  (
    @model.same_y(a, b, epsilon=EPS_LOCAL) &&
    (start_y - end_y).abs() < 1.0 &&
    (start_x - end_x).abs() > 1.0
  ) ||
  (
    @model.same_x(a, b, epsilon=EPS_LOCAL) &&
    (start_x - end_x).abs() < 1.0 &&
    (start_y - end_y).abs() > 1.0
  )
}

///|
/// `Number(flag)`.
fn bool_number(flag : Bool) -> Double {
  if flag {
    1.0
  } else {
    0.0
  }
}

///|
/// Move one lane of the first conflicting pair of `lanes` to a free track:
/// one iteration of `separateSharedRenderedTerminalLanes`. Whether a lane
/// moved.
fn separate_first_conflict(
  lanes : Array[TerminalLane],
  node_by_id : Map[String, @model.Node],
) -> Bool {
  let shifts = [
    -TRACK_SHIFT,
    TRACK_SHIFT,
    -2.0 * TRACK_SHIFT,
    2.0 * TRACK_SHIFT,
    -3.0 * TRACK_SHIFT,
    3.0 * TRACK_SHIFT,
  ]
  for i in 0..<lanes.length() {
    for j in (i + 1)..<lanes.length() {
      let first = lanes[i]
      let second = lanes[j]
      if physical_equal(first.edge, second.edge) ||
        !(exact_terminal_lane_conflict(first, second) ||
        near_terminal_lane_conflict(first, second)) {
        continue
      }
      let fixing_near_conflict = !exact_terminal_lane_conflict(first, second)
      let candidates = [first, second]
      // Move a lane that is not a straight connector first, then the
      // lane at the end of a route.
      @d3.js_sort(candidates, fn(a, b) {
        let a_preserves_straight = lane_is_straight_collinear_connector(
          a, node_by_id,
        )
        let b_preserves_straight = lane_is_straight_collinear_connector(
          b, node_by_id,
        )
        if a_preserves_straight != b_preserves_straight {
          return bool_number(a_preserves_straight) -
            bool_number(b_preserves_straight)
        }
        bool_number(!b.at_start) - bool_number(!a.at_start)
      })
      for lane in candidates {
        for shift in shifts {
          guard shifted_candidate(lane, shift) is Some(candidate) else {
            continue
          }
          guard terminal_lane_for(
              lane.edge,
              candidate,
              lane.at_start,
              node_by_id,
            )
            is Some(next_lane) else {
            continue
          }
          let conflicts = lanes
            .iter()
            .any(fn(other) {
              !physical_equal(other.edge, lane.edge) &&
              (
                exact_terminal_lane_conflict(next_lane, other) ||
                (
                  fixing_near_conflict &&
                  near_terminal_lane_conflict(next_lane, other)
                )
              )
            })
          if conflicts {
            continue
          }
          lane.edge.points = Some(candidate)
          return true
        }
      }
    }
  }
  false
}

///|
/// Where two routes run into a node along the same track (or, for a route
/// leaving and one entering on the same side face, along tracks too close
/// to tell apart), move the end of one of them a few pixels along the
/// node's face. `separateSharedRenderedTerminalLanes`.
pub fn separate_shared_rendered_terminal_lanes(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  for _iteration in 0..<8 {
    let lanes : Array[TerminalLane] = []
    for edge in edges {
      if edge.is_layout_only {
        continue
      }
      for at_start in [true, false] {
        let route = edge.points.unwrap_or([])
        if terminal_lane_for(edge, route, at_start, node_by_id) is Some(lane) {
          lanes.push(lane)
        }
      }
    }
    if !separate_first_conflict(lanes, node_by_id) {
      return
    }
  }
}
