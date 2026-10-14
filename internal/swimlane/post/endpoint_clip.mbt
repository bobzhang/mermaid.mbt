// `swimlanes/direction/endpointClip.ts`: routes end on the border of their
// nodes, away from the corners.

///|
/// How far inside a box a point must be to count as inside.
const INSIDE_EPS : Double = 0.5

///|
/// How far from a corner of a box a route may meet it.
const CORNER_CLEARANCE : Double = 4.0

///|
/// The route of a drawn edge with the boxes of its ends: `endpointContextFor`.
priv struct EndpointContext {
  edge : @model.Edge
  points : Array[@model.Pt]
  src_rect : @model.Rect?
  dst_rect : @model.Rect?
}

///|
fn endpoint_context_for(
  edge : @model.Edge,
  node_by_id : Map[String, @model.Node],
  min_points : Int32,
) -> EndpointContext? {
  if edge.is_layout_only {
    return None
  }
  guard edge.points is Some(points) && points.length() >= min_points else {
    return None
  }
  let src = if edge.start != "" { node_by_id.get(edge.start) } else { None }
  let dst = if edge.end != "" { node_by_id.get(edge.end) } else { None }
  Some({
    edge,
    points,
    src_rect: src.bind(@model.rect_of_node_bounds),
    dst_rect: dst.bind(@model.rect_of_node_bounds),
  })
}

///|
/// Where a segment from `outside` towards `inside` enters the box.
fn segment_enter_point(
  outside : @model.Pt,
  inside : @model.Pt,
  r : @model.Rect,
) -> @model.Pt {
  if @model.same_y(outside, inside) {
    let x = if outside.x < r.left { r.left } else { r.right }
    return @model.pt(x, outside.y)
  }
  if @model.same_x(outside, inside) {
    let y = if outside.y < r.top { r.top } else { r.bottom }
    return @model.pt(outside.x, y)
  }
  @model.pt(
    @model.js_min(r.right, @model.js_max(r.left, outside.x)),
    @model.js_min(r.bottom, @model.js_max(r.top, outside.y)),
  )
}

///|
/// Drop the points of one end that lie inside the box and end the route
/// where it enters it: `clipEndpoint`.
fn clip_endpoint(
  points : Array[@model.Pt],
  rect : @model.Rect,
  at_start : Bool,
) -> Array[@model.Pt] {
  let step = if at_start { 1 } else { -1 }
  let mut outside_index = if at_start { 0 } else { points.length() - 1 }
  while outside_index >= 0 &&
        outside_index < points.length() &&
        @model.point_inside_rect(points[outside_index], rect, buffer=INSIDE_EPS) {
    outside_index += step
  }
  if outside_index < 0 || outside_index >= points.length() {
    return points
  }
  let inside_index = outside_index - step
  if inside_index < 0 || inside_index >= points.length() {
    return points
  }
  let entry = segment_enter_point(
    points[outside_index],
    points[inside_index],
    rect,
  )
  if at_start {
    [entry, ..points[outside_index:]]
  } else {
    [..points[:outside_index + 1], entry]
  }
}

///|
/// `clipEdgeEndpointsToNodeBoundaries`: cut every route where it enters the
/// boxes of its ends.
pub fn clip_edge_endpoints_to_node_boundaries(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  for edge in edges {
    guard endpoint_context_for(edge, node_by_id, 2) is Some(context) else {
      continue
    }
    let mut next = context.points.copy()
    if context.src_rect is Some(src_rect) {
      next = clip_endpoint(next, src_rect, true)
    }
    if context.dst_rect is Some(dst_rect) {
      next = clip_endpoint(next, dst_rect, false)
    }
    next = @model.simplify_polyline(@model.orthogonalize_polyline(next))
    next = clear_straight_endpoint_corner_connections(
      next,
      context.src_rect,
      context.dst_rect,
    )
    context.edge.points = Some(
      @model.simplify_polyline(@model.orthogonalize_polyline(next)),
    )
  }
}

///|
/// Move an end that runs along `inner` onto the border of the box: the
/// side it approaches from with `use_approach_side`, else the nearer one.
/// Returns `endpoint` itself when it stays.
fn snap_endpoint_to_boundary(
  inner : @model.Pt,
  endpoint : @model.Pt,
  r : @model.Rect,
  use_approach_side~ : Bool = false,
) -> @model.Pt {
  if @model.same_y(inner, endpoint) {
    if endpoint.y < r.top - @model.EPS || endpoint.y > r.bottom + @model.EPS {
      return endpoint
    }
    if use_approach_side {
      if inner.x < r.left - @model.EPS {
        return @model.pt(r.left, inner.y)
      }
      if inner.x > r.right + @model.EPS {
        return @model.pt(r.right, inner.y)
      }
    }
    let to_left = (endpoint.x - r.left).abs() <= (endpoint.x - r.right).abs()
    return @model.pt(if to_left { r.left } else { r.right }, inner.y)
  }
  if @model.same_x(inner, endpoint) {
    if endpoint.x < r.left - @model.EPS || endpoint.x > r.right + @model.EPS {
      return endpoint
    }
    if use_approach_side {
      if inner.y < r.top - @model.EPS {
        return @model.pt(inner.x, r.top)
      }
      if inner.y > r.bottom + @model.EPS {
        return @model.pt(inner.x, r.bottom)
      }
    }
    let to_top = (endpoint.y - r.top).abs() <= (endpoint.y - r.bottom).abs()
    return @model.pt(inner.x, if to_top { r.top } else { r.bottom })
  }
  endpoint
}

///|
/// The first point from an end that is not the end itself, else the one
/// next to it (`undefined` past the array).
fn first_distinct_adjacent(
  points : Array[@model.Pt],
  endpoint_index : Int32,
  step : Int32,
) -> @model.Pt? {
  let endpoint = points[endpoint_index]
  let mut index = endpoint_index + step
  while index >= 0 && index < points.length() {
    let candidate = points[index]
    if !@model.same_point(candidate, endpoint) {
      return Some(candidate)
    }
    index += step
  }
  let index = endpoint_index + step
  if index >= 0 && index < points.length() {
    Some(points[index])
  } else {
    None
  }
}

///|
/// The part of `[min, max]` a corner clearance away from both ends, or its
/// middle when there is none.
fn corner_clearance_range(min : Double, max : Double) -> (Double, Double) {
  let lo = min + CORNER_CLEARANCE
  let hi = max - CORNER_CLEARANCE
  if lo <= hi {
    (lo, hi)
  } else {
    ((min + max) / 2.0, (min + max) / 2.0)
  }
}

///|
fn clamp_to_corner_clearance(
  value : Double,
  min : Double,
  max : Double,
) -> Double {
  let (lo, hi) = corner_clearance_range(min, max)
  @model.js_min(hi, @model.js_max(lo, value))
}

///|
fn intersect_ranges(ranges : Array[(Double, Double)]) -> (Double, Double)? {
  let mut lo = -@double.infinity
  for range in ranges {
    lo = @model.js_max(lo, range.0)
  }
  let mut hi = @double.infinity
  for range in ranges {
    hi = @model.js_min(hi, range.1)
  }
  if lo > hi {
    return None
  }
  Some((lo, hi))
}

///|
fn clearance_range_for_side(
  r : @model.Rect,
  side : @model.Side,
) -> (Double, Double) {
  if side.is_horizontal() {
    corner_clearance_range(r.top, r.bottom)
  } else {
    corner_clearance_range(r.left, r.right)
  }
}

///|
/// The side of the box an end sits on when its segment leaves across that
/// side.
fn terminal_side_for_segment(
  endpoint : @model.Pt,
  adjacent : @model.Pt,
  r : @model.Rect,
) -> @model.Side? {
  let y_within = endpoint.y >= r.top - @model.EPS &&
    endpoint.y <= r.bottom + @model.EPS
  let x_within = endpoint.x >= r.left - @model.EPS &&
    endpoint.x <= r.right + @model.EPS
  if @model.same_y(endpoint, adjacent) && y_within {
    if (endpoint.x - r.left).abs() < @model.EPS {
      return Some(Left)
    }
    if (endpoint.x - r.right).abs() < @model.EPS {
      return Some(Right)
    }
  }
  if @model.same_x(endpoint, adjacent) && x_within {
    if (endpoint.y - r.top).abs() < @model.EPS {
      return Some(Top)
    }
    if (endpoint.y - r.bottom).abs() < @model.EPS {
      return Some(Bottom)
    }
  }
  None
}

///|
/// Where a straight route may run so that it meets both boxes away from
/// their corners.
fn straight_clearance_range(
  start : @model.Pt,
  end : @model.Pt,
  src_rect : @model.Rect?,
  dst_rect : @model.Rect?,
  horizontal : Bool,
) -> (Double, Double)? {
  let ranges = []
  let src_side = src_rect.bind(r => terminal_side_for_segment(start, end, r))
  let dst_side = dst_rect.bind(r => terminal_side_for_segment(end, start, r))
  if src_rect is Some(r) &&
    src_side is Some(side) &&
    side.is_horizontal() == horizontal {
    ranges.push(clearance_range_for_side(r, side))
  }
  if dst_rect is Some(r) &&
    dst_side is Some(side) &&
    side.is_horizontal() == horizontal {
    ranges.push(clearance_range_for_side(r, side))
  }
  if ranges.length() > 0 {
    intersect_ranges(ranges)
  } else {
    None
  }
}

///|
fn clear_straight_endpoint_corner_axis(
  start : @model.Pt,
  end : @model.Pt,
  src_rect : @model.Rect?,
  dst_rect : @model.Rect?,
  horizontal : Bool,
) -> Array[@model.Pt]? {
  guard straight_clearance_range(start, end, src_rect, dst_rect, horizontal)
    is Some((lo, hi)) else {
    return None
  }
  let current = if horizontal { start.y } else { start.x }
  let next = @model.js_min(hi, @model.js_max(lo, current))
  if (next - current).abs() < @model.EPS {
    return None
  }
  if horizontal {
    Some([@model.pt(start.x, next), @model.pt(end.x, next)])
  } else {
    Some([@model.pt(next, start.y), @model.pt(next, end.y)])
  }
}

///|
/// Slide a straight two-point route off the corners of its boxes: the
/// same array when it stays.
fn clear_straight_endpoint_corner_connections(
  points : Array[@model.Pt],
  src_rect : @model.Rect?,
  dst_rect : @model.Rect?,
) -> Array[@model.Pt] {
  guard points is [start, end] else { return points }
  if @model.same_y(start, end) {
    return clear_straight_endpoint_corner_axis(
      start, end, src_rect, dst_rect, true,
    ).unwrap_or(points)
  }
  if @model.same_x(start, end) {
    return clear_straight_endpoint_corner_axis(
      start, end, src_rect, dst_rect, false,
    ).unwrap_or(points)
  }
  points
}

///|
fn corner_cleared_endpoint(
  endpoint : @model.Pt,
  r : @model.Rect,
  side : @model.Side,
) -> @model.Pt {
  if side.is_horizontal() {
    @model.pt(
      endpoint.x,
      clamp_to_corner_clearance(endpoint.y, r.top, r.bottom),
    )
  } else {
    @model.pt(
      clamp_to_corner_clearance(endpoint.x, r.left, r.right),
      endpoint.y,
    )
  }
}

///|
/// A copy of the route with the run of points in line with the end moved
/// across to `adjusted`.
fn move_collinear_endpoint_run(
  points : Array[@model.Pt],
  endpoint_index : Int32,
  step : Int32,
  endpoint : @model.Pt,
  adjusted : @model.Pt,
  horizontal_terminal : Bool,
) -> Array[@model.Pt] {
  let next = points.map(point => point.copy())
  let mut index = endpoint_index
  while index >= 0 && index < points.length() {
    let point = points[index]
    if horizontal_terminal && !@model.same_y(point, endpoint) {
      break
    }
    if !horizontal_terminal && !@model.same_x(point, endpoint) {
      break
    }
    if horizontal_terminal {
      next[index].y = adjusted.y
    } else {
      next[index].x = adjusted.x
    }
    index += step
  }
  next
}

///|
/// Move an end that meets its box too near a corner along that side.
fn clear_endpoint_corner_connection(
  points : Array[@model.Pt],
  r : @model.Rect,
  at_start : Bool,
) -> Array[@model.Pt] {
  if points.length() < 2 {
    return points
  }
  let endpoint_index = if at_start { 0 } else { points.length() - 1 }
  let step = if at_start { 1 } else { -1 }
  let endpoint = points[endpoint_index]
  guard first_distinct_adjacent(points, endpoint_index, step) is Some(adjacent) else {
    return points
  }
  guard terminal_side_for_segment(endpoint, adjacent, r) is Some(side) else {
    return points
  }
  let horizontal_terminal = side.is_horizontal()
  let adjusted = corner_cleared_endpoint(endpoint, r, side)
  if @model.same_point(endpoint, adjusted) {
    return points
  }
  move_collinear_endpoint_run(
    points, endpoint_index, step, endpoint, adjusted, horizontal_terminal,
  )
}

///|
/// The side of the box a segment lies along.
fn border_side_for_segment(
  a : @model.Pt,
  b : @model.Pt,
  r : @model.Rect,
) -> @model.Side? {
  let x_within = @model.js_min(a.x, b.x) >= r.left - @model.EPS &&
    @model.js_max(a.x, b.x) <= r.right + @model.EPS
  let y_within = @model.js_min(a.y, b.y) >= r.top - @model.EPS &&
    @model.js_max(a.y, b.y) <= r.bottom + @model.EPS
  if (a.y - r.top).abs() < @model.EPS &&
    (b.y - r.top).abs() < @model.EPS &&
    x_within {
    return Some(Top)
  }
  if (a.y - r.bottom).abs() < @model.EPS &&
    (b.y - r.bottom).abs() < @model.EPS &&
    x_within {
    return Some(Bottom)
  }
  if (a.x - r.left).abs() < @model.EPS &&
    (b.x - r.left).abs() < @model.EPS &&
    y_within {
    return Some(Left)
  }
  if (a.x - r.right).abs() < @model.EPS &&
    (b.x - r.right).abs() < @model.EPS &&
    y_within {
    return Some(Right)
  }
  None
}

///|
/// Whether the segment from `from` to `to` leaves the box straight out
/// across `side`.
fn leaves_outward(
  side : @model.Side,
  from : @model.Pt,
  to : @model.Pt,
  r : @model.Rect,
) -> Bool {
  match side {
    Top => @model.same_x(from, to) && to.y < r.top - @model.EPS
    Bottom => @model.same_x(from, to) && to.y > r.bottom + @model.EPS
    Left => @model.same_y(from, to) && to.x < r.left - @model.EPS
    Right => @model.same_y(from, to) && to.x > r.right + @model.EPS
  }
}

///|
/// Drop a first (or last) segment that runs along the border of its own
/// box before the route leaves it.
fn collapse_own_border_stub(
  points : Array[@model.Pt],
  r : @model.Rect,
  at_start : Bool,
) -> Array[@model.Pt] {
  if points.length() < 3 {
    return points
  }
  if at_start {
    if border_side_for_segment(points[0], points[1], r) is Some(side) &&
      leaves_outward(side, points[1], points[2], r) {
      return points[1:].to_owned()
    }
    return points
  }
  let last = points.length() - 1
  if border_side_for_segment(points[last - 1], points[last], r) is Some(side) &&
    leaves_outward(side, points[last - 1], points[last - 2], r) {
    return points[:last].to_owned()
  }
  points
}

///|
fn snap_and_collapse_endpoints(
  points : Array[@model.Pt],
  src_rect : @model.Rect?,
  dst_rect : @model.Rect?,
) -> Array[@model.Pt] {
  let mut next = points
  if src_rect is Some(src_rect) {
    if first_distinct_adjacent(next, 0, 1) is Some(adjacent) {
      let snapped = snap_endpoint_to_boundary(adjacent, next[0], src_rect)
      if !physical_equal(snapped, next[0]) {
        next = [snapped, ..next[1:]]
      }
    }
    next = collapse_own_border_stub(next, src_rect, true)
  }
  if dst_rect is Some(dst_rect) {
    let last = next.length() - 1
    if first_distinct_adjacent(next, last, -1) is Some(adjacent) {
      let snapped = snap_endpoint_to_boundary(
        adjacent,
        next[last],
        dst_rect,
        use_approach_side=true,
      )
      if !physical_equal(snapped, next[last]) {
        next = [..next[:last], snapped]
      }
    }
    next = collapse_own_border_stub(next, dst_rect, false)
  }
  let straight_cleared = clear_straight_endpoint_corner_connections(
    next, src_rect, dst_rect,
  )
  if !physical_equal(straight_cleared, next) || next.length() == 2 {
    return straight_cleared
  }
  if src_rect is Some(src_rect) {
    next = clear_endpoint_corner_connection(next, src_rect, true)
  }
  if dst_rect is Some(dst_rect) {
    next = clear_endpoint_corner_connection(next, dst_rect, false)
  }
  next
}

///|
/// `prepareEdgeEndpointsForRenderer`: put the ends of every route on the
/// border of their boxes, and repeat the first and last points (as copies)
/// for the renderer's markers.
pub fn prepare_edge_endpoints_for_renderer(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  for edge in edges {
    guard endpoint_context_for(edge, node_by_id, 2) is Some(context) else {
      continue
    }
    let input = @model.dedupe_consecutive_points(context.points)
    let new_pts = snap_and_collapse_endpoints(
      input,
      context.src_rect,
      context.dst_rect,
    )
    if new_pts.length() < 3 {
      context.edge.points = Some(new_pts)
      continue
    }
    let first = new_pts[0]
    let last = new_pts[new_pts.length() - 1]
    context.edge.points = Some(
      [
        first,
        first.copy(),
        ..new_pts[1:new_pts.length() - 1],
        last,
        last.copy(),
      ],
    )
  }
}
