// `swimlanes/direction/terminalStub.ts`: a route whose last segment is a
// short sideways stub enters its target straight instead.

///|
/// The key of a segment by its ends rounded to three decimals.
fn own_segment_key(a : @model.Pt, b : @model.Pt) -> String {
  "\{@d3.to_fixed(a.x, 3)},\{@d3.to_fixed(a.y, 3)}|\{@d3.to_fixed(b.x, 3)},\{@d3.to_fixed(b.y, 3)}"
}

///|
/// `collapseShortTerminalStub`: when the last segment of a route is
/// shorter than 10 and turns off the one before, move that one over to the
/// middle of the target and end the route straight on its border, when
/// the new segments hit no node and cross no other route. A label of the
/// edge moves to the middle of the longest segment it fits along.
pub fn collapse_short_terminal_stub(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let min_stub = 10.0
  let buffer = 2.0
  let (real_node_rects, label_rects) = @model.collect_node_rect_entries(
    node_by_id.values(),
  )
  for edge in edges {
    if edge.is_layout_only {
      continue
    }
    guard edge.points is Some(raw_pts) && raw_pts.length() >= 4 else {
      continue
    }
    let pts = @model.dedupe_consecutive_points(raw_pts)
    if pts.length() < 4 {
      continue
    }
    let n_last = pts.length() - 1
    let end_pt = pts[n_last]
    let penult_pt = pts[n_last - 1]
    let prev_pt = pts[n_last - 2]
    let last_dx = end_pt.x - penult_pt.x
    let last_dy = end_pt.y - penult_pt.y
    let last_len = @jsmath.hypot(last_dx, last_dy)
    if last_len >= min_stub || last_len < @model.EPS {
      continue
    }
    let penult_dx = penult_pt.x - prev_pt.x
    let penult_dy = penult_pt.y - prev_pt.y
    let penult_len = @jsmath.hypot(penult_dx, penult_dy)
    if penult_len < @model.EPS {
      continue
    }
    let last_is_horiz = @model.is_horizontal_segment(penult_pt, end_pt)
    let last_is_vert = @model.is_vertical_segment(penult_pt, end_pt)
    let penult_is_horiz = @model.is_horizontal_segment(prev_pt, penult_pt)
    let penult_is_vert = @model.is_vertical_segment(prev_pt, penult_pt)
    if !((last_is_horiz && penult_is_vert) || (last_is_vert && penult_is_horiz)) {
      continue
    }
    let dst_id = edge.end
    let src_id = edge.start
    guard dst_id != "" && node_by_id.get(dst_id) is Some(dst) else { continue }
    let dst_cx = dst.x.unwrap_or(0.0)
    let dst_cy = dst.y.unwrap_or(0.0)
    guard @model.rect_of_node_bounds(dst) is Some(dst_rect) else { continue }
    let (new_prev, new_end) = if penult_is_vert {
      let approach_from_below = penult_dy < 0.0
      (
        @model.pt(dst_cx, prev_pt.y),
        @model.pt(
          dst_cx,
          if approach_from_below {
            dst_rect.bottom
          } else {
            dst_rect.top
          },
        ),
      )
    } else {
      let approach_from_left = penult_dx > 0.0
      (
        @model.pt(prev_pt.x, dst_cy),
        @model.pt(
          if approach_from_left {
            dst_rect.right
          } else {
            dst_rect.left
          },
          dst_cy,
        ),
      )
    }
    if @model.segment_hits_any_rect(
        new_prev,
        new_end,
        real_node_rects,
        exclude_ids=[dst_id],
        shrink=-buffer,
      ) {
      continue
    }
    if @model.segment_hits_any_rect(
        new_prev,
        new_end,
        label_rects,
        shrink=-buffer,
      ) {
      continue
    }
    if src_id != "" {
      let src_rect = node_by_id.get(src_id).bind(@model.rect_of_node_bounds)
      if src_rect is Some(src_rect) &&
        @model.point_inside_rect(new_prev, src_rect, buffer~) {
        continue
      }
    }
    let self_segments : Set[String] = Set([])
    for i in 0..<(pts.length() - 1) {
      self_segments.add(own_segment_key(pts[i], pts[i + 1]))
    }
    let segment_crosses_other_edge = (from : @model.Pt, to : @model.Pt) => {
      for other in edges {
        if physical_equal(other, edge) {
          continue
        }
        if other.is_layout_only {
          continue
        }
        guard other.points is Some(o_pts) && o_pts.length() >= 2 else {
          continue
        }
        for i in 0..<(o_pts.length() - 1) {
          let a = o_pts[i]
          let b = o_pts[i + 1]
          if self_segments.contains(own_segment_key(a, b)) {
            continue
          }
          if @model.orthogonal_segments_strictly_cross(from, to, a, b) {
            return true
          }
        }
      }
      false
    }
    if segment_crosses_other_edge(new_prev, new_end) {
      continue
    }
    if n_last - 3 >= 0 {
      let before_prev = pts[n_last - 3]
      let endpoint_ids = [src_id, dst_id].filter(id => id != "")
      if @model.segment_hits_any_rect(
          before_prev,
          new_prev,
          real_node_rects,
          exclude_ids=endpoint_ids,
          shrink=-buffer,
        ) {
        continue
      }
      if segment_crosses_other_edge(before_prev, new_prev) {
        continue
      }
    }
    let new_pts = [..pts[:n_last - 2], new_prev, new_end]
    edge.points = Some(new_pts)
    guard edge.label_node_id is Some(label_id) && label_id != "" else {
      continue
    }
    guard node_by_id.get(label_id) is Some(label_node) else { continue }
    let lw = label_node.width.unwrap_or(0.0)
    let lh = label_node.height.unwrap_or(0.0)
    if !(lw > 0.0 && lh > 0.0) {
      continue
    }
    let mut best_mid : (Double, Double)? = None
    let mut best_len = -1.0
    for i in 0..<(new_pts.length() - 1) {
      let a = new_pts[i]
      let b = new_pts[i + 1]
      let seg_len = @jsmath.hypot(b.x - a.x, b.y - a.y)
      let is_horiz = @model.same_y(a, b)
      let is_vert = @model.same_x(a, b)
      let fits = (is_horiz && seg_len >= lw + 2.0) ||
        (is_vert && seg_len >= lh + 2.0)
      if !fits {
        continue
      }
      if seg_len > best_len {
        best_len = seg_len
        best_mid = Some(((a.x + b.x) / 2.0, (a.y + b.y) / 2.0))
      }
    }
    if best_mid is Some((mid_x, mid_y)) {
      label_node.x = Some(mid_x)
      label_node.y = Some(mid_y)
    }
  }
}
