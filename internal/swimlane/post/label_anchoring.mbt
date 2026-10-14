// `swimlanes/direction/labelAnchoring.ts`: the label of an edge is placed
// on its route, inside a lane, clear of nodes, other routes, other labels
// and its own markers.

///|
/// The length of the space an end marker takes along the route.
const MARKER_CLEARANCE_LENGTH : Double = 10.0

///|
/// Half the width of the space an end marker takes across the route.
const MARKER_CLEARANCE_HALF_WIDTH : Double = 7.0

///|
/// How far a label keeps from foreign nodes and routes.
const LABEL_PLACEMENT_BUFFER : Double = 3.0

///|
/// How far a label clamped into a lane keeps from its border.
const LABEL_LANE_MARGIN : Double = 1.0

///|
/// How far beyond its half extent a label keeps from the ends of the route.
const LABEL_ENDPOINT_CLEARANCE : Double = 12.0

///|
/// Where along a segment a label is tried, in turn.
let along_segment_ts : Array[Double] = [
  0.5, 0.25, 0.75, 0.05, 0.95, 0.15, 0.85, 0.1, 0.9,
]

///|
/// `Math.sign`.
fn js_sign(x : Double) -> Double {
  if x > 0.0 {
    1.0
  } else if x < 0.0 {
    -1.0
  } else {
    // 0, -0 and NaN are their own sign.
    x
  }
}

///|
/// The space the marker at one end of the route takes: `markerClearanceRectFor`.
fn marker_clearance_rect_for(
  pts : Array[@model.Pt],
  at_start : Bool,
) -> @model.Rect? {
  let terminal_index = if at_start { 0 } else { pts.length() - 1 }
  let step = if at_start { 1 } else { -1 }
  let inner_index = terminal_index + step
  if terminal_index < 0 ||
    terminal_index >= pts.length() ||
    inner_index < 0 ||
    inner_index >= pts.length() {
    return None
  }
  let tip = pts[terminal_index]
  let inner = pts[inner_index]
  let dx = inner.x - tip.x
  let dy = inner.y - tip.y
  let len = dx.abs() + dy.abs()
  if len < @model.EPS {
    return None
  }
  if dy.abs() <= @model.EPS {
    let x2 = tip.x + js_sign(dx) * MARKER_CLEARANCE_LENGTH
    return Some({
      left: @model.js_min(tip.x, x2),
      right: @model.js_max(tip.x, x2),
      top: tip.y - MARKER_CLEARANCE_HALF_WIDTH,
      bottom: tip.y + MARKER_CLEARANCE_HALF_WIDTH,
    })
  }
  if dx.abs() <= @model.EPS {
    let y2 = tip.y + js_sign(dy) * MARKER_CLEARANCE_LENGTH
    return Some({
      left: tip.x - MARKER_CLEARANCE_HALF_WIDTH,
      right: tip.x + MARKER_CLEARANCE_HALF_WIDTH,
      top: @model.js_min(tip.y, y2),
      bottom: @model.js_max(tip.y, y2),
    })
  }
  Some({
    left: @model.js_min(tip.x, inner.x),
    right: @model.js_max(tip.x, inner.x),
    top: @model.js_min(tip.y, inner.y),
    bottom: @model.js_max(tip.y, inner.y),
  })
}

///|
fn normalize_rect(rect : @model.Rect) -> @model.Rect {
  {
    left: @model.js_min(rect.left, rect.right),
    right: @model.js_max(rect.left, rect.right),
    top: @model.js_min(rect.top, rect.bottom),
    bottom: @model.js_max(rect.top, rect.bottom),
  }
}

///|
/// Whether the label box covers a marker of its own route.
fn label_overlaps_own_marker(
  rect : @model.Rect,
  pts : Array[@model.Pt],
) -> Bool {
  let visible_pts = @model.dedupe_consecutive_points(pts)
  let start_marker = marker_clearance_rect_for(visible_pts, true)
  let end_marker = marker_clearance_rect_for(visible_pts, false)
  [start_marker, end_marker]
  .iter()
  .any(marker => {
    marker is Some(marker) && @model.rects_overlap(rect, normalize_rect(marker))
  })
}

///|
/// A segment of a route between two points of it.
priv struct EdgeSegment {
  edge_id : String
  p1 : @model.Pt
  p2 : @model.Pt
}

///|
/// An axis-aligned visible segment of the route being labelled.
priv struct LabelSegment {
  idx : Int32
  length : Double
  horizontal : Bool
  mid_x : Double
  mid_y : Double
}

///|
/// A place for a label and the lane it lies in.
priv struct Placement {
  lane_id : String
  mid_x : Double
  mid_y : Double
  rect : @model.Rect
}

///|
/// A label placed so far.
priv struct PlacedLabel {
  label_id : String
  rect : @model.Rect
}

///|
/// `anchorLabelsToPolyline`: move the label node of every edge onto its
/// route, preferring the middle segments along the label's long side that
/// it fits along, and make the lane it lands in its parent.
pub fn anchor_labels_to_polyline(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let all_edge_segments : Array[EdgeSegment] = []
  for other in edges {
    if other.is_layout_only {
      continue
    }
    guard other.points is Some(pts) && pts.length() >= 2 else { continue }
    for i in 0..<(pts.length() - 1) {
      all_edge_segments.push({ edge_id: other.id, p1: pts[i], p2: pts[i + 1], })
    }
  }
  let foreign_node_rects : Array[@model.RectEntry] = []
  let lane_groups : Array[@model.RectEntry] = []
  for n in node_by_id.values() {
    let is_group = n.is_group
    if is_group && !(n.parent_id is Some(parent_id) && parent_id != "") {
      if @model.rect_of_node_bounds(n) is Some(rect) {
        lane_groups.push({ id: n.id, rect, })
      }
      continue
    }
    if is_group {
      continue
    }
    if n.is_edge_label {
      continue
    }
    guard @model.rect_of_node_bounds(n) is Some(rect) else { continue }
    foreign_node_rects.push({ id: n.id, rect, })
  }
  let label_overlaps_foreign_node = (label_id : String, rect : @model.Rect) => {
    let buffered = @model.inflate_rect(rect, LABEL_PLACEMENT_BUFFER)
    for entry in foreign_node_rects {
      if entry.id == label_id {
        continue
      }
      if @model.rects_overlap(buffered, entry.rect) {
        return true
      }
    }
    false
  }
  let label_overlaps_foreign_edge = (edge_id : String, rect : @model.Rect) => {
    let buffered = @model.inflate_rect(rect, LABEL_PLACEMENT_BUFFER)
    for s in all_edge_segments {
      if s.edge_id == edge_id {
        continue
      }
      if @model.segment_bounds_overlap_rect(s.p1, s.p2, buffered) {
        return true
      }
    }
    false
  }
  let label_overlaps_anything = (
    label_id : String,
    edge_id : String,
    rect : @model.Rect,
  ) => {
    label_overlaps_foreign_node(label_id, rect) ||
    label_overlaps_foreign_edge(edge_id, rect)
  }
  let placed_label_rects : Array[PlacedLabel] = []
  let find_containing_lane = (rect : @model.Rect) => {
    for lane in lane_groups {
      if @model.rect_contains_rect(lane.rect, rect) {
        return Some(lane.id)
      }
    }
    None
  }
  let overlaps_placed_label = (label_id : String, rect : @model.Rect) => {
    placed_label_rects
    .iter()
    .any(placed => {
      placed.label_id != label_id && @model.rects_overlap(rect, placed.rect)
    })
  }
  for edge in edges {
    if edge.is_layout_only {
      continue
    }
    guard edge.label_node_id is Some(label_id) && label_id != "" else {
      continue
    }
    guard node_by_id.get(label_id) is Some(label_node) else { continue }
    guard edge.points is Some(pts) && pts.length() >= 2 else { continue }
    let lw = label_node.width.unwrap_or(0.0)
    let lh = label_node.height.unwrap_or(0.0)
    if lw <= 0.0 || lh <= 0.0 {
      continue
    }
    let segments : Array[LabelSegment] = []
    for i in 0..<(pts.length() - 1) {
      let a = pts[i]
      let b = pts[i + 1]
      let dx = (a.x - b.x).abs()
      let dy = (a.y - b.y).abs()
      if dx < @model.EPS && dy < @model.EPS {
        continue
      }
      if dx >= @model.EPS && dy >= @model.EPS {
        continue
      }
      segments.push({
        idx: i,
        length: dx + dy,
        horizontal: dx >= @model.EPS,
        mid_x: (a.x + b.x) / 2.0,
        mid_y: (a.y + b.y) / 2.0,
      })
    }
    if segments.length() == 0 {
      continue
    }
    // `idx` is an index of the points, compared with the number of
    // segments, as upstream.
    let middle_segments = if segments.length() >= 3 {
      segments.filter(s => s.idx > 0 && s.idx < segments.length() - 1)
    } else {
      segments
    }
    let pool_base = if middle_segments.length() > 0 {
      middle_segments
    } else {
      segments
    }
    let label_long_axis_horizontal = lw >= lh
    let rank_segments = (pool : Array[LabelSegment]) => {
      let ranked = pool.copy()
      @d3.js_sort(ranked, (a, b) => {
        let a_long_axis = a.horizontal == label_long_axis_horizontal
        let b_long_axis = b.horizontal == label_long_axis_horizontal
        if a_long_axis != b_long_axis {
          return if a_long_axis { -1.0 } else { 1.0 }
        }
        let a_fits = a.length >= (if a.horizontal { lw } else { lh }) + 2.0
        let b_fits = b.length >= (if b.horizontal { lw } else { lh }) + 2.0
        if a_fits != b_fits {
          return if a_fits { -1.0 } else { 1.0 }
        }
        b.length - a.length
      })
      ranked
    }
    let first_visible_segment = segments[0]
    let last_visible_segment = segments[segments.length() - 1]
    let anchor_at_t = (seg : LabelSegment, t : Double) => {
      let a = pts[seg.idx]
      let b = pts[seg.idx + 1]
      (a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }
    let clamp = (value : Double, min : Double, max : Double) => {
      @model.js_min(max, @model.js_max(min, value))
    }
    let point_inside_rect_inclusive = (
      mid_x : Double,
      mid_y : Double,
      rect : @model.Rect,
    ) => {
      mid_x >= rect.left - @model.EPS &&
      mid_x <= rect.right + @model.EPS &&
      mid_y >= rect.top - @model.EPS &&
      mid_y <= rect.bottom + @model.EPS
    }
    let placement_for_anchor = (mid_x : Double, mid_y : Double) => {
      let centered_rect = @model.rect_from_center_size(mid_x, mid_y, lw, lh)
      if find_containing_lane(centered_rect) is Some(centered_lane) &&
        centered_lane != "" {
        return Some(Placement::{
          lane_id: centered_lane,
          mid_x,
          mid_y,
          rect: centered_rect,
        })
      }
      let mut containing_lane = None
      for lane in lane_groups {
        if point_inside_rect_inclusive(mid_x, mid_y, lane.rect) {
          containing_lane = Some(lane)
          break
        }
      }
      guard containing_lane is Some(containing_lane) else { return None }
      let min_x = containing_lane.rect.left + lw / 2.0 + LABEL_LANE_MARGIN
      let max_x = containing_lane.rect.right - lw / 2.0 - LABEL_LANE_MARGIN
      let min_y = containing_lane.rect.top + lh / 2.0 + LABEL_LANE_MARGIN
      let max_y = containing_lane.rect.bottom - lh / 2.0 - LABEL_LANE_MARGIN
      if min_x > max_x || min_y > max_y {
        return None
      }
      let clamped_x = clamp(mid_x, min_x, max_x)
      let clamped_y = clamp(mid_y, min_y, max_y)
      let clamped_rect = @model.rect_from_center_size(
        clamped_x, clamped_y, lw, lh,
      )
      if point_inside_rect_inclusive(mid_x, mid_y, clamped_rect) {
        Some(Placement::{
          lane_id: containing_lane.id,
          mid_x: clamped_x,
          mid_y: clamped_y,
          rect: clamped_rect,
        })
      } else {
        None
      }
    }
    let distance_along_segment = (
      seg : LabelSegment,
      mid_x : Double,
      mid_y : Double,
      endpoint : @model.Pt,
    ) => {
      if seg.horizontal {
        (mid_x - endpoint.x).abs()
      } else {
        (mid_y - endpoint.y).abs()
      }
    }
    let label_clears_terminal_endpoints = (
      seg : LabelSegment,
      mid_x : Double,
      mid_y : Double,
    ) => {
      let label_half_extent = if seg.horizontal { lw / 2.0 } else { lh / 2.0 }
      let required_distance = label_half_extent + LABEL_ENDPOINT_CLEARANCE
      if seg.idx == first_visible_segment.idx {
        let start = pts[seg.idx]
        if distance_along_segment(seg, mid_x, mid_y, start) + @model.EPS <
          required_distance {
          return false
        }
      }
      if seg.idx == last_visible_segment.idx {
        let end = pts[seg.idx + 1]
        if distance_along_segment(seg, mid_x, mid_y, end) + @model.EPS <
          required_distance {
          return false
        }
      }
      true
    }
    let try_pool = (pool : Array[LabelSegment]) => {
      let ranked_pool = rank_segments(pool)
      for seg in ranked_pool {
        for t in along_segment_ts {
          let (mid_x, mid_y) = anchor_at_t(seg, t)
          if !label_clears_terminal_endpoints(seg, mid_x, mid_y) {
            continue
          }
          guard placement_for_anchor(mid_x, mid_y) is Some(placement) else {
            continue
          }
          if label_overlaps_own_marker(placement.rect, pts) {
            continue
          }
          if overlaps_placed_label(label_id, placement.rect) {
            continue
          }
          if !label_overlaps_anything(label_id, edge.id, placement.rect) {
            return Some(placement)
          }
        }
      }
      None
    }
    let find_lane_containing_fallback = (
      pool : Array[LabelSegment],
      require_endpoint_clearance : Bool,
      allow_foreign_edge_overlap : Bool,
    ) => {
      let ranked_pool = rank_segments(pool)
      for seg in ranked_pool {
        if require_endpoint_clearance &&
          !label_clears_terminal_endpoints(seg, seg.mid_x, seg.mid_y) {
          continue
        }
        if placement_for_anchor(seg.mid_x, seg.mid_y) is Some(placement) &&
          !label_overlaps_own_marker(placement.rect, pts) &&
          !overlaps_placed_label(label_id, placement.rect) &&
          !label_overlaps_foreign_node(label_id, placement.rect) &&
          (
            allow_foreign_edge_overlap ||
            !label_overlaps_foreign_edge(edge.id, placement.rect)
          ) {
          return Some(placement)
        }
      }
      None
    }
    let chosen = match try_pool(pool_base) {
      Some(placement) => Some(placement)
      None => {
        let second = if pool_base.length() < segments.length() {
          try_pool(segments)
        } else {
          None
        }
        match second {
          Some(placement) => Some(placement)
          None =>
            match find_lane_containing_fallback(segments, true, false) {
              Some(placement) => Some(placement)
              None =>
                match find_lane_containing_fallback(segments, false, false) {
                  Some(placement) => Some(placement)
                  None => find_lane_containing_fallback(segments, false, true)
                }
            }
        }
      }
    }
    guard chosen is Some(chosen) else { continue }
    label_node.x = Some(chosen.mid_x)
    label_node.y = Some(chosen.mid_y)
    label_node.parent_id = Some(chosen.lane_id)
    let chosen_rect = @model.rect_from_center_size(
      chosen.mid_x,
      chosen.mid_y,
      lw,
      lh,
    )
    let mut prior_idx = -1
    for i, placed in placed_label_rects {
      if placed.label_id == label_id {
        prior_idx = i
        break
      }
    }
    if prior_idx >= 0 {
      placed_label_rects[prior_idx] = { label_id, rect: chosen_rect, }
    } else {
      placed_label_rects.push({ label_id, rect: chosen_rect, })
    }
  }
}
