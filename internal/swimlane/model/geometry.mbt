// Orthogonal-geometry helpers shared by the post-processing passes:
// `swimlanes/direction/geometry.ts`.

///|
/// The tolerance of most comparisons.
pub const EPS : Double = 1.0e-3

///|
/// A side of a rectangle.
pub(all) enum Side {
  Top
  Bottom
  Left
  Right
} derive(Eq, Debug)

///|
/// Whether a port on this side leaves horizontally.
pub fn Side::is_horizontal(self : Side) -> Bool {
  self is (Left | Right)
}

///|
/// A node's centre and box: `NodeBoundsInfo`.
pub(all) struct NodeInfo {
  id : String
  cx : Double
  cy : Double
  rect : Rect
}

///|
/// A rectangle with the id of its node.
pub(all) struct RectEntry {
  id : String
  rect : Rect
}

///|
/// An axis-aligned segment of a polyline: `OrthogonalSegment`.
pub(all) struct Seg {
  index : Int32
  a : Pt
  b : Pt
  horizontal : Bool
  vertical : Bool
}

///|
/// The centre and box of a measured node: `measuredNodeRect`.
pub fn measured_node_rect(node : Node) -> (Double, Double, Rect)? {
  let cx = node.x.unwrap_or(0.0)
  let cy = node.y.unwrap_or(0.0)
  let width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  if width > 0.0 && height > 0.0 {
    Some((cx, cy, rect_from_center_size(cx, cy, width, height)))
  } else {
    None
  }
}

///|
/// `nodeBoundsInfoFor`: groups and unmeasured nodes have none.
pub fn node_bounds_info_for(node : Node) -> NodeInfo? {
  if node.is_group {
    return None
  }
  guard measured_node_rect(node) is Some((cx, cy, rect)) else { return None }
  Some({ id: node.id, cx, cy, rect, })
}

///|
pub fn same_point(a : Pt, b : Pt, epsilon~ : Double = EPS) -> Bool {
  (a.x - b.x).abs() < epsilon && (a.y - b.y).abs() < epsilon
}

///|
pub fn same_x(a : Pt, b : Pt, epsilon~ : Double = EPS) -> Bool {
  (a.x - b.x).abs() < epsilon
}

///|
pub fn same_y(a : Pt, b : Pt, epsilon~ : Double = EPS) -> Bool {
  (a.y - b.y).abs() < epsilon
}

///|
pub fn is_horizontal_segment(a : Pt, b : Pt, epsilon~ : Double = EPS) -> Bool {
  same_y(a, b, epsilon~) && (a.x - b.x).abs() > epsilon
}

///|
pub fn is_vertical_segment(a : Pt, b : Pt, epsilon~ : Double = EPS) -> Bool {
  same_x(a, b, epsilon~) && (a.y - b.y).abs() > epsilon
}

///|
/// The length two intervals share.
pub fn overlap_length(
  a1 : Double,
  a2 : Double,
  b1 : Double,
  b2 : Double,
) -> Double {
  js_max(
    0.0,
    js_min(js_max(a1, a2), js_max(b1, b2)) -
    js_max(js_min(a1, a2), js_min(b1, b2)),
  )
}

///|
pub fn same_axis_segment_overlap_length(
  a : Seg,
  b : Seg,
  epsilon~ : Double = EPS,
) -> Double {
  if a.horizontal && b.horizontal && same_y(a.a, b.a, epsilon~) {
    return overlap_length(a.a.x, a.b.x, b.a.x, b.b.x)
  }
  if a.vertical && b.vertical && same_x(a.a, b.a, epsilon~) {
    return overlap_length(a.a.y, a.b.y, b.a.y, b.b.y)
  }
  0.0
}

///|
/// The horizontal and vertical segments of a polyline.
pub fn orthogonal_segments_for_points(
  points : Array[Pt],
  epsilon~ : Double = EPS,
) -> Array[Seg] {
  let result = []
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let horizontal = is_horizontal_segment(a, b, epsilon~)
    let vertical = is_vertical_segment(a, b, epsilon~)
    if horizontal || vertical {
      result.push({ index: i, a, b, horizontal, vertical, })
    }
  }
  result
}

///|
pub fn count_orthogonal_bends(
  points : Array[Pt],
  epsilon~ : Double = EPS,
) -> Int32 {
  let segments = orthogonal_segments_for_points(points, epsilon~)
  let mut bends = 0
  for i in 1..<segments.length() {
    if segments[i - 1].horizontal != segments[i].horizontal {
      bends += 1
    }
  }
  bends
}

///|
/// The points with consecutive repeats dropped, as fresh points.
pub fn dedupe_consecutive_points(
  points : Array[Pt],
  epsilon~ : Double = EPS,
) -> Array[Pt] {
  let result : Array[Pt] = []
  for point in points {
    match result.last() {
      Some(last) if same_point(last, point, epsilon~) => ()
      _ => result.push(pt(point.x, point.y))
    }
  }
  result
}

///|
/// A route of three segments: horizontal-vertical-horizontal (`HVH`) or
/// the other way round.
pub(all) struct ThreeSegmentRoute {
  hvh : Bool
  p0 : Pt
  p1 : Pt
  p2 : Pt
  p3 : Pt
}

///|
pub fn classify_three_segment_route(
  points : Array[Pt],
  epsilon~ : Double = EPS,
) -> ThreeSegmentRoute? {
  guard points is [p0, p1, p2, p3] else { return None }
  let is_hvh = is_horizontal_segment(p0, p1, epsilon~) &&
    is_vertical_segment(p1, p2, epsilon~) &&
    is_horizontal_segment(p2, p3, epsilon~)
  if is_hvh {
    return Some({ hvh: true, p0, p1, p2, p3, })
  }
  let is_vhv = is_vertical_segment(p0, p1, epsilon~) &&
    is_horizontal_segment(p1, p2, epsilon~) &&
    is_vertical_segment(p2, p3, epsilon~)
  if is_vhv {
    Some({ hvh: false, p0, p1, p2, p3, })
  } else {
    None
  }
}

///|
pub fn segment_bounds_overlap_rect(
  a : Pt,
  b : Pt,
  rect : Rect,
  buffer~ : Double = 0.0,
) -> Bool {
  let seg_min_x = js_min(a.x, b.x)
  let seg_max_x = js_max(a.x, b.x)
  let seg_min_y = js_min(a.y, b.y)
  let seg_max_y = js_max(a.y, b.y)
  seg_max_x > rect.left - buffer &&
  seg_min_x < rect.right + buffer &&
  seg_max_y > rect.top - buffer &&
  seg_min_y < rect.bottom + buffer
}

///|
pub fn point_inside_rect(
  point : Pt,
  rect : Rect,
  buffer~ : Double = 0.0,
) -> Bool {
  point.x > rect.left + buffer &&
  point.x < rect.right - buffer &&
  point.y > rect.top + buffer &&
  point.y < rect.bottom - buffer
}

///|
pub fn rect_contains_rect(outer : Rect, inner : Rect) -> Bool {
  outer.left <= inner.left &&
  outer.right >= inner.right &&
  outer.top <= inner.top &&
  outer.bottom >= inner.bottom
}

///|
pub fn rects_overlap(a : Rect, b : Rect) -> Bool {
  a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top
}

///|
pub fn inflate_rect(rect : Rect, margin : Double) -> Rect {
  {
    left: rect.left - margin,
    right: rect.right + margin,
    top: rect.top - margin,
    bottom: rect.bottom + margin,
  }
}

///|
pub fn rect_from_center_size(
  cx : Double,
  cy : Double,
  width : Double,
  height : Double,
) -> Rect {
  {
    left: cx - width / 2.0,
    right: cx + width / 2.0,
    top: cy - height / 2.0,
    bottom: cy + height / 2.0,
  }
}

///|
pub fn rect_of_node_bounds(node : Node) -> Rect? {
  match measured_node_rect(node) {
    Some((_, _, rect)) => Some(rect)
    None => None
  }
}

///|
/// The middle of a side of a node's box.
pub fn port_for_rect_side(node : NodeInfo, side : Side) -> Pt {
  match side {
    Top => pt(node.cx, node.rect.top)
    Bottom => pt(node.cx, node.rect.bottom)
    Left => pt(node.rect.left, node.cy)
    Right => pt(node.rect.right, node.cy)
  }
}

///|
/// An orthogonal route from a port on one side to a port on another, when
/// there is a simple one: `buildOrthogonalPortPath`.
pub fn build_orthogonal_port_path(
  src : Pt,
  src_side : Side,
  dst : Pt,
  dst_side : Side,
  anchor : Double,
  epsilon~ : Double = EPS,
) -> Array[Pt]? {
  let src_h = src_side.is_horizontal()
  let dst_h = dst_side.is_horizontal()
  if src_h && dst_h {
    let opposing_dir = (src_side == Right && dst_side == Left && src.x < dst.x) ||
      (src_side == Left && dst_side == Right && src.x > dst.x)
    if opposing_dir {
      if same_y(src, dst, epsilon~) {
        return Some([src, dst])
      }
      let mid_x = (src.x + dst.x) / 2.0
      return Some([src, pt(mid_x, src.y), pt(mid_x, dst.y), dst])
    }
    if src_side == dst_side {
      if same_y(src, dst, epsilon~) {
        return None
      }
      let int_x = if src_side == Left {
        js_min(src.x, dst.x) - anchor
      } else {
        js_max(src.x, dst.x) + anchor
      }
      return Some([src, pt(int_x, src.y), pt(int_x, dst.y), dst])
    }
    return None
  }
  if !src_h && !dst_h {
    if src_side == dst_side {
      if same_x(src, dst, epsilon~) {
        return None
      }
      let int_y = if src_side == Top {
        js_min(src.y, dst.y) - anchor
      } else {
        js_max(src.y, dst.y) + anchor
      }
      return Some([src, pt(src.x, int_y), pt(dst.x, int_y), dst])
    }
    let same_dir = (src_side == Bottom && dst_side == Top && src.y < dst.y) ||
      (src_side == Top && dst_side == Bottom && src.y > dst.y)
    if !same_dir {
      return None
    }
    if same_x(src, dst, epsilon~) {
      return Some([src, dst])
    }
    let mid_y = (src.y + dst.y) / 2.0
    return Some([src, pt(src.x, mid_y), pt(dst.x, mid_y), dst])
  }
  if src_h && !dst_h {
    let same_dir_src2 = (src_side == Right && dst.x > src.x) ||
      (src_side == Left && dst.x < src.x)
    let same_dir_dst2 = (dst_side == Top && src.y < dst.y) ||
      (dst_side == Bottom && src.y > dst.y)
    return if same_dir_src2 && same_dir_dst2 {
      Some([src, pt(dst.x, src.y), dst])
    } else {
      None
    }
  }
  let same_dir_src = (src_side == Bottom && dst.y > src.y) ||
    (src_side == Top && dst.y < src.y)
  let same_dir_dst = (dst_side == Left && src.x < dst.x) ||
    (dst_side == Right && src.x > dst.x)
  if same_dir_src && same_dir_dst {
    Some([src, pt(src.x, dst.y), dst])
  } else {
    None
  }
}

///|
/// A route leaving and entering on the same side, along a track.
pub fn build_same_side_track_path(
  src : Pt,
  side : Side,
  dst : Pt,
  track : Double,
) -> Array[Pt] {
  if side.is_horizontal() {
    [src, pt(track, src.y), pt(track, dst.y), dst]
  } else {
    [src, pt(src.x, track), pt(dst.x, track), dst]
  }
}

///|
/// The boxes of the nodes that are not edge labels.
pub fn collect_real_node_bounds(
  nodes : Array[Node],
) -> (Map[String, NodeInfo], Array[RectEntry]) {
  let node_info_by_id : Map[String, NodeInfo] = Map([])
  let real_node_rects : Array[RectEntry] = []
  for node in nodes {
    if node.is_edge_label {
      continue
    }
    guard node_bounds_info_for(node) is Some(info) else { continue }
    node_info_by_id[info.id] = info
    real_node_rects.push({ id: info.id, rect: info.rect, })
  }
  (node_info_by_id, real_node_rects)
}

///|
/// The boxes of the nodes, those of edge labels apart:
/// `{ realNodeRects, labelNodeRects }`.
pub fn collect_node_rect_entries(
  nodes : Iter[Node],
) -> (Array[RectEntry], Array[RectEntry]) {
  let real_node_rects : Array[RectEntry] = []
  let label_node_rects : Array[RectEntry] = []
  for node in nodes {
    guard node_bounds_info_for(node) is Some(info) else { continue }
    let entry = { id: info.id, rect: info.rect, }
    if node.is_edge_label {
      label_node_rects.push(entry)
    } else {
      real_node_rects.push(entry)
    }
  }
  (real_node_rects, label_node_rects)
}

///|
/// The boxes of all nodes that are not groups, measured or not.
pub fn collect_layout_node_rects(
  nodes : Array[Node],
  include_edge_labels~ : Bool = true,
) -> Array[RectEntry] {
  let result = []
  for node in nodes {
    if node.is_group || (!include_edge_labels && node.is_edge_label) {
      continue
    }
    let cx = node.x.unwrap_or(0.0)
    let cy = node.y.unwrap_or(0.0)
    let width = node.width.unwrap_or(0.0)
    let height = node.height.unwrap_or(0.0)
    result.push({
      id: node.id,
      rect: rect_from_center_size(cx, cy, width, height),
    })
  }
  result
}

///|
/// The two ends of an edge: `getNodePairGeometry`.
pub(all) struct NodePair {
  src_id : String
  dst_id : String
  src_info : NodeInfo
  dst_info : NodeInfo
  collinear_x : Bool
  collinear_y : Bool
}

///|
pub fn get_node_pair_geometry(
  edge : Edge,
  node_info_by_id : Map[String, NodeInfo],
  epsilon~ : Double = EPS,
) -> NodePair? {
  let src_id = edge.start
  let dst_id = edge.end
  if src_id == "" || dst_id == "" {
    return None
  }
  guard node_info_by_id.get(src_id) is Some(src_info) else { return None }
  guard node_info_by_id.get(dst_id) is Some(dst_info) else { return None }
  Some({
    src_id,
    dst_id,
    src_info,
    dst_info,
    collinear_x: (src_info.cx - dst_info.cx).abs() < epsilon,
    collinear_y: (src_info.cy - dst_info.cy).abs() < epsilon,
  })
}

///|
pub fn segment_hits_any_rect(
  a : Pt,
  b : Pt,
  rects : Array[RectEntry],
  exclude_ids~ : Array[String] = [],
  shrink~ : Double = 0.0,
) -> Bool {
  for entry in rects {
    if exclude_ids.contains(entry.id) {
      continue
    }
    if segment_bounds_overlap_rect(a, b, entry.rect, buffer=-shrink) {
      return true
    }
  }
  false
}

///|
/// Whether a horizontal and a vertical segment cross, touching at a shared
/// end apart.
pub fn orthogonal_segments_cross(
  a1 : Pt,
  b1 : Pt,
  a2 : Pt,
  b2 : Pt,
  epsilon~ : Double = EPS,
  endpoint_tolerance~ : Double = 1.0e-6,
) -> Bool {
  let s1h = same_y(a1, b1, epsilon~)
  let s1v = same_x(a1, b1, epsilon~)
  let s2h = same_y(a2, b2, epsilon~)
  let s2v = same_x(a2, b2, epsilon~)
  if (s1h && s2h) || (s1v && s2v) {
    return false
  }
  if !(s1h || s1v) || !(s2h || s2v) {
    return false
  }
  let (ha, hb) = if s1h { (a1, b1) } else { (a2, b2) }
  let (va, vb) = if s1v { (a1, b1) } else { (a2, b2) }
  let h_y = ha.y
  let h_x1 = js_min(ha.x, hb.x)
  let h_x2 = js_max(ha.x, hb.x)
  let v_x = va.x
  let v_y1 = js_min(va.y, vb.y)
  let v_y2 = js_max(va.y, vb.y)
  if v_x < h_x1 || v_x > h_x2 || h_y < v_y1 || h_y > v_y2 {
    return false
  }
  let t = endpoint_tolerance
  let matches_horiz_endpoint = (
      (v_x - ha.x).abs() < t && (h_y - ha.y).abs() < t
    ) ||
    ((v_x - hb.x).abs() < t && (h_y - hb.y).abs() < t)
  let matches_vert_endpoint = ((v_x - va.x).abs() < t && (h_y - va.y).abs() < t) ||
    ((v_x - vb.x).abs() < t && (h_y - vb.y).abs() < t)
  !(matches_horiz_endpoint && matches_vert_endpoint)
}

///|
pub fn same_axis_segments_overlap(
  a1 : Pt,
  b1 : Pt,
  a2 : Pt,
  b2 : Pt,
  epsilon~ : Double = EPS,
) -> Bool {
  let s1h = same_y(a1, b1, epsilon~)
  let s1v = same_x(a1, b1, epsilon~)
  let s2h = same_y(a2, b2, epsilon~)
  let s2v = same_x(a2, b2, epsilon~)
  if s1v && s2v && same_x(a1, a2, epsilon~) {
    return overlap_length(a1.y, b1.y, a2.y, b2.y) > epsilon
  }
  if s1h && s2h && same_y(a1, a2, epsilon~) {
    return overlap_length(a1.x, b1.x, a2.x, b2.x) > epsilon
  }
  false
}

///|
/// Whether a segment crosses or runs along a drawn edge other than
/// `exclude_edge` (compared by identity).
pub fn segment_conflicts_with_any_edge(
  a : Pt,
  b : Pt,
  edges : Array[Edge],
  exclude_edge : Edge?,
  epsilon~ : Double = EPS,
  skip_degenerate_other~ : Bool = false,
) -> Bool {
  for other in edges {
    if exclude_edge is Some(excluded) && physical_equal(other, excluded) {
      continue
    }
    if other.is_layout_only {
      continue
    }
    guard other.points is Some(points) && points.length() >= 2 else { continue }
    for i in 0..<(points.length() - 1) {
      let oa = points[i]
      let ob = points[i + 1]
      if skip_degenerate_other && same_point(oa, ob, epsilon~) {
        continue
      }
      if orthogonal_segments_cross(a, b, oa, ob, epsilon~) ||
        same_axis_segments_overlap(a, b, oa, ob, epsilon~) {
        return true
      }
    }
  }
  false
}

///|
/// Whether a horizontal and a vertical segment cross strictly inside both.
pub fn orthogonal_segments_strictly_cross(
  a1 : Pt,
  b1 : Pt,
  a2 : Pt,
  b2 : Pt,
  epsilon~ : Double = EPS,
) -> Bool {
  let a_horiz = same_y(a1, b1, epsilon~)
  let a_vert = same_x(a1, b1, epsilon~)
  let b_horiz = same_y(a2, b2, epsilon~)
  let b_vert = same_x(a2, b2, epsilon~)
  if !((a_horiz && b_vert) || (a_vert && b_horiz)) {
    return false
  }
  let (ha, hb) = if a_horiz { (a1, b1) } else { (a2, b2) }
  let (va, vb) = if a_horiz { (a2, b2) } else { (a1, b1) }
  let h_y = ha.y
  let h_xmin = js_min(ha.x, hb.x)
  let h_xmax = js_max(ha.x, hb.x)
  let v_x = va.x
  let v_ymin = js_min(va.y, vb.y)
  let v_ymax = js_max(va.y, vb.y)
  v_x > h_xmin + epsilon &&
  v_x < h_xmax - epsilon &&
  h_y > v_ymin + epsilon &&
  h_y < v_ymax - epsilon
}

///|
fn strictly_between(value : Double, a : Double, b : Double) -> Bool {
  let lo = js_min(a, b)
  let hi = js_max(a, b)
  value > lo + EPS && value < hi - EPS
}

///|
fn is_collinear_intermediate(prev : Pt, cur : Pt, next : Pt) -> Bool {
  if same_x(prev, cur) && same_x(cur, next) {
    return strictly_between(cur.y, prev.y, next.y)
  }
  if same_y(prev, cur) && same_y(cur, next) {
    return strictly_between(cur.x, prev.x, next.x)
  }
  false
}

///|
/// One pass of `simplifyPolyline`: whether it changed anything.
fn simplify_polyline_once(points : Array[Pt]) -> (Array[Pt], Bool) {
  let mut changed = false
  let out : Array[Pt] = []
  let mut i = 0
  while i < points.length() {
    let cur = points[i]
    let next = if i + 1 < points.length() { Some(points[i + 1]) } else { None }
    if out.last() is Some(prev) && next is Some(next) {
      if same_point(prev, next) {
        // The point and the next one go: the route came back on itself.
        i += 2
        changed = true
        continue
      }
      if is_collinear_intermediate(prev, cur, next) {
        changed = true
        i += 1
        continue
      }
    }
    out.push(cur)
    i += 1
  }
  (out, changed)
}

///|
/// Insert a corner wherever two consecutive points are not aligned, then
/// drop repeated points.
pub fn orthogonalize_polyline(pts : Array[Pt]) -> Array[Pt] {
  let cleaned = [pts[0]]
  for i in 1..<pts.length() {
    let prev = cleaned[cleaned.length() - 1]
    let curr = pts[i]
    if !same_x(prev, curr) && !same_y(prev, curr) {
      let incoming_vertical = if cleaned.length() >= 2 {
        same_x(cleaned[cleaned.length() - 2], prev)
      } else {
        false
      }
      let corner = if incoming_vertical {
        pt(prev.x, curr.y)
      } else {
        pt(curr.x, prev.y)
      }
      cleaned.push(corner)
    }
    cleaned.push(curr)
  }
  let deduped : Array[Pt] = []
  for p in cleaned {
    match deduped.last() {
      Some(last) if same_point(last, p) => ()
      _ => deduped.push(p)
    }
  }
  deduped
}

///|
/// Drop collinear intermediate points and back-and-forth spikes, up to 32
/// passes.
pub fn simplify_polyline(pts : Array[Pt]) -> Array[Pt] {
  if pts.length() < 3 {
    return pts
  }
  let mut work = pts.copy()
  for _guard in 0..<32 {
    let (points, changed) = simplify_polyline_once(work)
    work = points
    if !changed {
      break
    }
  }
  work
}
