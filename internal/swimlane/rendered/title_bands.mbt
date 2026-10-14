// Lane titles a route runs through: `liftTopLaneTitleBandsAboveRails`
// and `shiftLeftLaneTitleBandsLeftOfRails`. The lanes grow on the title's
// side by the room the routes need, and the titles move out with them.

///|
/// A lane and the band its title is drawn in.
priv struct LaneTitle {
  node : @model.Node
  rect : @model.Rect
}

///|
/// The lane's title band when it is a proper rectangle: `validTitleRect`.
fn valid_title_rect(node : @model.Node) -> @model.Rect? {
  guard node.group_title_rect is Some(rect) else { return None }
  if !is_finite(rect.left) ||
    !is_finite(rect.right) ||
    !is_finite(rect.top) ||
    !is_finite(rect.bottom) ||
    rect.right <= rect.left ||
    rect.bottom <= rect.top {
    return None
  }
  Some(rect)
}

///|
/// Whether the node is a lane (a group outside every group), in the
/// direction `wanted` says, of the layout's direction when it has none of
/// its own.
fn is_lane_in(
  node : @model.Node,
  layout_direction : String,
  wanted : (String) -> Bool,
) -> Bool {
  if !node.is_group || (node.parent_id is Some(parent) && parent != "") {
    return false
  }
  wanted(upper_case_direction(node.direction.unwrap_or(layout_direction)))
}

///|
/// A coordinate and a size that are set, finite, and a positive size.
fn is_measured(coord : Double?, size : Double?) -> Bool {
  coord is Some(c) && size is Some(s) && is_finite(c) && is_finite(s) && s > 0.0
}

///|
/// Whether a horizontal segment runs through the title band for at least
/// `MIN_SHARED`: `horizontalSegmentIntersectsTitle`.
fn horizontal_segment_intersects_title(
  segment : @model.Seg,
  rect : @model.Rect,
) -> Bool {
  if !segment.horizontal {
    return false
  }
  let y = segment.a.y
  if y < rect.top - EPS_LOCAL || y > rect.bottom + EPS_LOCAL {
    return false
  }
  @model.overlap_length(segment.a.x, segment.b.x, rect.left, rect.right) >=
  MIN_SHARED
}

///|
/// Whether a vertical segment runs through the title band for at least
/// `MIN_SHARED`: `verticalSegmentIntersectsTitle`.
fn vertical_segment_intersects_title(
  segment : @model.Seg,
  rect : @model.Rect,
) -> Bool {
  if !segment.vertical {
    return false
  }
  let x = segment.a.x
  if x < rect.left - EPS_LOCAL || x > rect.right + EPS_LOCAL {
    return false
  }
  @model.overlap_length(segment.a.y, segment.b.y, rect.top, rect.bottom) >=
  MIN_SHARED
}

///|
/// The segments of the drawn routes.
fn visible_route_segments(edges : Array[@model.Edge]) -> Array[@model.Seg] {
  let result = []
  for edge in edges {
    if edge.is_layout_only {
      continue
    }
    result.append(segments_for(route_of(edge)))
  }
  result
}

///|
/// Where a horizontal route runs through the title band at the top of a
/// lane (lanes of `TB` layouts), raise the bands of all such lanes above
/// the highest such route, and grow the lanes upwards with them:
/// `liftTopLaneTitleBandsAboveRails`.
pub fn lift_top_lane_title_bands_above_rails(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
  direction : String,
) -> Unit {
  let clearance = 4.0
  let lanes : Array[LaneTitle] = []
  for node in node_by_id.values() {
    if !is_lane_in(node, direction, fn(d) {
        d != "LR" && d != "RL" && d != "BT"
      }) {
      continue
    }
    guard valid_title_rect(node) is Some(rect) &&
      is_measured(node.y, node.height) else {
      continue
    }
    let title_width = rect.right - rect.left
    let title_height = rect.bottom - rect.top
    if title_height <= 0.0 || title_width < title_height {
      continue
    }
    lanes.push({ node, rect, })
  }
  if lanes.length() == 0 {
    return
  }
  let mut top_delta = 0.0
  for segment in visible_route_segments(edges) {
    for lane in lanes {
      if !horizontal_segment_intersects_title(segment, lane.rect) {
        continue
      }
      top_delta = @model.js_max(
        top_delta,
        lane.rect.bottom - segment.a.y + clearance,
      )
    }
  }
  if top_delta <= EPS_LOCAL {
    return
  }
  for lane in lanes {
    guard lane.node.y is Some(y) && lane.node.height is Some(height) else {
      continue
    }
    if !is_measured(lane.node.y, lane.node.height) {
      continue
    }
    lane.node.y = Some(y - top_delta / 2.0)
    lane.node.height = Some(height + top_delta)
    lane.node.group_title_rect = Some({
      ..lane.rect,
      top: lane.rect.top - top_delta,
      bottom: lane.rect.bottom - top_delta,
    })
  }
}

///|
/// Where a route runs through the title band at the left of a lane (lanes
/// of `LR` layouts), move the bands of all such lanes left of the leftmost
/// such route, and grow the lanes leftwards with them:
/// `shiftLeftLaneTitleBandsLeftOfRails`.
pub fn shift_left_lane_title_bands_left_of_rails(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
  direction : String,
) -> Unit {
  let clearance = 4.0
  let lanes : Array[LaneTitle] = []
  for node in node_by_id.values() {
    if !is_lane_in(node, direction, fn(d) { d == "LR" }) {
      continue
    }
    guard valid_title_rect(node) is Some(rect) &&
      is_measured(node.x, node.width) else {
      continue
    }
    let title_width = rect.right - rect.left
    let title_height = rect.bottom - rect.top
    if title_width <= 0.0 || title_height < title_width {
      continue
    }
    lanes.push({ node, rect, })
  }
  if lanes.length() == 0 {
    return
  }
  let mut left_delta = 0.0
  for segment in visible_route_segments(edges) {
    for lane in lanes {
      if vertical_segment_intersects_title(segment, lane.rect) {
        left_delta = @model.js_max(
          left_delta,
          lane.rect.right - segment.a.x + clearance,
        )
      } else if horizontal_segment_intersects_title(segment, lane.rect) {
        let segment_left = @model.js_min(segment.a.x, segment.b.x)
        left_delta = @model.js_max(
          left_delta,
          lane.rect.right - segment_left + clearance,
        )
      }
    }
  }
  if left_delta <= EPS_LOCAL {
    return
  }
  for lane in lanes {
    guard lane.node.x is Some(x) && lane.node.width is Some(width) else {
      continue
    }
    if !is_measured(lane.node.x, lane.node.width) {
      continue
    }
    lane.node.x = Some(x - left_delta / 2.0)
    lane.node.width = Some(width + left_delta)
    lane.node.group_title_rect = Some({
      ..lane.rect,
      left: lane.rect.left - left_delta,
      right: lane.rect.right - left_delta,
    })
  }
}
