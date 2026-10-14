// `swimlanes/direction/portSwap.ts`: a three-segment route between nodes
// that are not in line becomes an L leaving from another side of the
// source.

///|
const PORT_SWAP_EPS : Double = 1.0e-6

///|
/// How far the new port may move off the middle of the side, tried in turn.
let port_swap_deltas : Array[Double] = [0.0, 8.0, -8.0, 16.0, -16.0]

///|
/// `portSwapToLShape`: replace a horizontal-vertical-horizontal route (or
/// the other way round) by an L from the top or bottom (left or right) of
/// the source to the old end, when the L hits no node and no other route.
pub fn port_swap_to_l_shape(
  edges : Array[@model.Edge],
  nodes : Array[@model.Node],
) -> Unit {
  let (node_info_by_id, real_node_rects) = @model.collect_real_node_bounds(
    nodes,
  )
  for edge in edges {
    if edge.is_layout_only {
      continue
    }
    guard edge.points is Some(pts) && pts.length() >= 4 else { continue }
    guard @model.classify_three_segment_route(
        @model.dedupe_consecutive_points(pts, epsilon=PORT_SWAP_EPS),
        epsilon=PORT_SWAP_EPS,
      )
      is Some(route) else {
      continue
    }
    let p3 = route.p3
    let is_hvh = route.hvh
    guard @model.get_node_pair_geometry(
        edge,
        node_info_by_id,
        epsilon=PORT_SWAP_EPS,
      )
      is Some(pair) else {
      continue
    }
    if pair.collinear_x || pair.collinear_y {
      continue
    }
    let src_info = pair.src_info
    let dst_info = pair.dst_info
    let src_rect = src_info.rect
    let mut new_pts : Array[@model.Pt]? = None
    for delta in port_swap_deltas {
      let (np0, np1, np2) = if is_hvh {
        let dst_below = dst_info.cy > src_info.cy
        let new_src_y = if dst_below { src_rect.bottom } else { src_rect.top }
        let new_src_x = src_info.cx + delta
        if new_src_x <= src_rect.left + PORT_SWAP_EPS ||
          new_src_x >= src_rect.right - PORT_SWAP_EPS {
          continue
        }
        (
          @model.pt(new_src_x, new_src_y),
          @model.pt(new_src_x, p3.y),
          @model.pt(p3.x, p3.y),
        )
      } else {
        let dst_east = dst_info.cx > src_info.cx
        let new_src_x = if dst_east { src_rect.right } else { src_rect.left }
        let new_src_y = src_info.cy + delta
        if new_src_y <= src_rect.top + PORT_SWAP_EPS ||
          new_src_y >= src_rect.bottom - PORT_SWAP_EPS {
          continue
        }
        (
          @model.pt(new_src_x, new_src_y),
          @model.pt(p3.x, new_src_y),
          @model.pt(p3.x, p3.y),
        )
      }
      let first_seg_degenerate = @model.same_point(
        np0,
        np1,
        epsilon=PORT_SWAP_EPS,
      )
      let second_seg_degenerate = @model.same_point(
        np1,
        np2,
        epsilon=PORT_SWAP_EPS,
      )
      if first_seg_degenerate && second_seg_degenerate {
        continue
      }
      if !first_seg_degenerate &&
        @model.segment_hits_any_rect(
          np0,
          np1,
          real_node_rects,
          exclude_ids=[pair.src_id],
          shrink=1.0,
        ) {
        continue
      }
      if !second_seg_degenerate &&
        @model.segment_hits_any_rect(
          np1,
          np2,
          real_node_rects,
          exclude_ids=[pair.dst_id],
          shrink=1.0,
        ) {
        continue
      }
      let first_seg_conflicts = !first_seg_degenerate &&
        @model.segment_conflicts_with_any_edge(
          np0,
          np1,
          edges,
          Some(edge),
          epsilon=PORT_SWAP_EPS,
          skip_degenerate_other=true,
        )
      let second_seg_conflicts = !second_seg_degenerate &&
        @model.segment_conflicts_with_any_edge(
          np1,
          np2,
          edges,
          Some(edge),
          epsilon=PORT_SWAP_EPS,
          skip_degenerate_other=true,
        )
      if first_seg_conflicts || second_seg_conflicts {
        continue
      }
      new_pts = Some(
        if first_seg_degenerate {
          [np1, np2]
        } else if second_seg_degenerate {
          [np0, np1]
        } else {
          [np0, np1, np2]
        },
      )
      break
    }
    if new_pts is Some(new_pts) {
      edge.points = Some(new_pts)
    }
  }
}
