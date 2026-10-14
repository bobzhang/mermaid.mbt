// `swimlanes/direction/siblingSharedFaceRouting.ts`: a detour between two
// nodes in line becomes a straight segment between their facing sides.

///|
const SIBLING_EPS : Double = 1.0e-6

///|
/// How far the straight segment moves off the middle when it must.
const SIBLING_PORT_SHIFT : Double = 4.0

///|
/// What a shift to make room for a label adds to its half extent.
const LABEL_CLEARANCE_BUFFER : Double = 3.0

///|
/// The same key for both orders of two node ids: `pairKey`.
fn pair_key(a : String, b : String) -> String {
  if @model.code_unit_less(a, b) {
    "\{a}::\{b}"
  } else {
    "\{b}::\{a}"
  }
}

///|
/// `straightenCollinearSiblingDetours`: replace a three-segment route
/// between nodes that are in line (on x or on y, not both) by the straight
/// segment between their facing sides, shifted aside by the largest label
/// half extent of the edges between the two nodes when the middle is
/// taken, when it hits no node and no other route.
pub fn straighten_collinear_sibling_detours(
  edges : Array[@model.Edge],
  nodes : Array[@model.Node],
) -> Unit {
  let (node_info_by_id, real_node_rects) = @model.collect_real_node_bounds(
    nodes,
  )
  let label_dim_by_id : Map[String, (Double, Double)] = Map([])
  for n in nodes {
    let id = n.id
    if n.is_group {
      continue
    }
    if n.is_edge_label {
      label_dim_by_id[id] = (n.width.unwrap_or(0.0), n.height.unwrap_or(0.0))
      continue
    }
  }
  let label_clearance_for = (
    this_edge : @model.Edge,
    this_src_id : String,
    this_dst_id : String,
    axis_x : Bool,
  ) => {
    let target_pair = pair_key(this_src_id, this_dst_id)
    let mut max_half = 0.0
    let consider = (label_id : String?) => {
      guard label_id is Some(label_id) && label_id != "" else { return }
      guard label_dim_by_id.get(label_id) is Some((w, h)) else { return }
      let half = if axis_x { w / 2.0 } else { h / 2.0 }
      if half > max_half {
        max_half = half
      }
    }
    consider(this_edge.label_node_id)
    for other in edges {
      if physical_equal(other, this_edge) {
        continue
      }
      if other.is_layout_only {
        continue
      }
      let o_src = other.start
      let o_dst = other.end
      if o_src == "" || o_dst == "" {
        continue
      }
      if pair_key(o_src, o_dst) != target_pair {
        continue
      }
      consider(other.label_node_id)
    }
    if max_half > 0.0 {
      max_half + LABEL_CLEARANCE_BUFFER
    } else {
      0.0
    }
  }
  for edge in edges {
    if edge.is_layout_only {
      continue
    }
    guard edge.points is Some(pts) &&
      @model.classify_three_segment_route(pts, epsilon=SIBLING_EPS) is Some(_) else {
      continue
    }
    guard @model.get_node_pair_geometry(
        edge,
        node_info_by_id,
        epsilon=SIBLING_EPS,
      )
      is Some(pair) else {
      continue
    }
    let src_id = pair.src_id
    let dst_id = pair.dst_id
    let src_info = pair.src_info
    let dst_info = pair.dst_info
    let collinear_x = pair.collinear_x
    if collinear_x == pair.collinear_y {
      continue
    }
    let (target_src, target_dst) = if collinear_x {
      let dst_below = dst_info.cy > src_info.cy
      (
        @model.pt(
          src_info.cx,
          if dst_below {
            src_info.rect.bottom
          } else {
            src_info.rect.top
          },
        ),
        @model.pt(
          dst_info.cx,
          if dst_below {
            dst_info.rect.top
          } else {
            dst_info.rect.bottom
          },
        ),
      )
    } else {
      let dst_east = dst_info.cx > src_info.cx
      (
        @model.pt(
          if dst_east {
            src_info.rect.right
          } else {
            src_info.rect.left
          },
          src_info.cy,
        ),
        @model.pt(
          if dst_east {
            dst_info.rect.left
          } else {
            dst_info.rect.right
          },
          dst_info.cy,
        ),
      )
    }
    if @model.segment_hits_any_rect(
        target_src,
        target_dst,
        real_node_rects,
        exclude_ids=[src_id, dst_id],
        shrink=1.0,
      ) {
      continue
    }
    let label_shift = label_clearance_for(edge, src_id, dst_id, collinear_x)
    let effective_shift = if label_shift > SIBLING_PORT_SHIFT {
      label_shift
    } else {
      SIBLING_PORT_SHIFT
    }
    let deltas = [0.0, effective_shift, -effective_shift]
    for delta in deltas {
      let shifted_src = target_src.copy()
      let shifted_dst = target_dst.copy()
      if collinear_x {
        shifted_src.x += delta
        shifted_dst.x += delta
        if shifted_src.x <= src_info.rect.left ||
          shifted_src.x >= src_info.rect.right {
          continue
        }
        if shifted_dst.x <= dst_info.rect.left ||
          shifted_dst.x >= dst_info.rect.right {
          continue
        }
      } else {
        shifted_src.y += delta
        shifted_dst.y += delta
        if shifted_src.y <= src_info.rect.top ||
          shifted_src.y >= src_info.rect.bottom {
          continue
        }
        if shifted_dst.y <= dst_info.rect.top ||
          shifted_dst.y >= dst_info.rect.bottom {
          continue
        }
      }
      if @model.segment_hits_any_rect(
          shifted_src,
          shifted_dst,
          real_node_rects,
          exclude_ids=[src_id, dst_id],
          shrink=1.0,
        ) {
        continue
      }
      if @model.segment_conflicts_with_any_edge(
          shifted_src,
          shifted_dst,
          edges,
          Some(edge),
          epsilon=SIBLING_EPS,
        ) {
        continue
      }
      edge.points = Some([shifted_src, shifted_dst])
      break
    }
  }
}
