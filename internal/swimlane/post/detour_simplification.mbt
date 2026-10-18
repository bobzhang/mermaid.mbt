// `swimlanes/direction/detourSimplification.ts`: a route with many bends
// is replaced by a simple one between ports on the sides of its nodes.

///|
/// How long two routes may run along each other before that counts as a
/// conflict.
const DETOUR_MIN_SHARED : Double = 8.0

///|
/// How far a route turning back to the same side goes out first.
const DETOUR_ANCHOR : Double = 20.0

///|
/// Routes with fewer bends are left alone.
const DETOUR_BEND_THRESHOLD : Int32 = 4

///|
/// The sides in the order they are tried.
let detour_sides : Array[@model.Side] = [Top, Bottom, Left, Right]

///|
/// The side of the node's box nearest to `point`, the first in the order
/// top, bottom, left, right on a tie: `nearestSideOfRect`.
fn nearest_side_of_rect(
  point : @model.Pt,
  info : @model.NodeInfo,
) -> @model.Side {
  let d_top = (point.y - info.rect.top).abs()
  let d_bottom = (point.y - info.rect.bottom).abs()
  let d_left = (point.x - info.rect.left).abs()
  let d_right = (point.x - info.rect.right).abs()
  let mut best : @model.Side = Top
  let mut best_dist = d_top
  if d_bottom < best_dist {
    best = Bottom
    best_dist = d_bottom
  }
  if d_left < best_dist {
    best = Left
    best_dist = d_left
  }
  if d_right < best_dist {
    best = Right
  }
  best
}

///|
/// A side of a node a route ends on.
priv struct FaceClaim {
  side : @model.Side
  edge_id : String
}

///|
fn add_face_claim(
  face_claims : Map[String, Array[FaceClaim]],
  node_id : String,
  side : @model.Side,
  edge_id : String,
) -> Unit {
  let claims = face_claims.get(node_id).unwrap_or([])
  claims.push({ side, edge_id, })
  face_claims[node_id] = claims
}

///|
/// Whether another route than `ignore_edge_id` ends on that side.
fn face_is_claimed(
  face_claims : Map[String, Array[FaceClaim]],
  node_id : String,
  side : @model.Side,
  ignore_edge_id : String,
) -> Bool {
  match face_claims.get(node_id) {
    Some(claims) =>
      claims.iter().any(c => c.edge_id != ignore_edge_id && c.side == side)
    None => false
  }
}

///|
/// How many segments of other routes cross `path` or run along it for at
/// least `DETOUR_MIN_SHARED`, counting per pair of segments. Routes sharing
/// an end with `current_edge` are left out unless
/// `include_incident_edges`: `pathConflictCount`.
fn path_conflict_count(
  edges : Array[@model.Edge],
  path : Array[@model.Pt],
  current_edge : @model.Edge,
  include_incident_edges~ : Bool = false,
) -> Int32 {
  let mut conflicts = 0
  let path_segments = @model.orthogonal_segments_for_points(path)
  let current_start = current_edge.start
  let current_end = current_edge.end
  for other in edges {
    if physical_equal(other, current_edge) || other.is_layout_only {
      continue
    }
    let other_start = other.start
    let other_end = other.end
    if !include_incident_edges &&
      current_start != "" &&
      current_end != "" &&
      (
        other_start == current_start ||
        other_start == current_end ||
        other_end == current_start ||
        other_end == current_end
      ) {
      continue
    }
    guard other.points is Some(other_pts) && other_pts.length() >= 2 else {
      continue
    }
    for path_segment in path_segments {
      for other_segment in @model.orthogonal_segments_for_points(other_pts) {
        if @model.orthogonal_segments_cross(
            path_segment.a,
            path_segment.b,
            other_segment.a,
            other_segment.b,
            endpoint_tolerance=@model.EPS,
          ) {
          conflicts += 1
          continue
        }
        if @model.same_axis_segment_overlap_length(path_segment, other_segment) >=
          DETOUR_MIN_SHARED {
          conflicts += 1
        }
      }
    }
  }
  conflicts
}

///|
/// `simplifyDetouredEdges`: replace a route with at least four bends by
/// the route between side ports of its nodes with the fewest bends that
/// hits no node and conflicts with no more routes (or, when the route
/// crosses others, the one with the fewest crossings). A side another
/// route already ends on is not used.
pub fn simplify_detoured_edges(
  edges : Array[@model.Edge],
  nodes : Array[@model.Node],
) -> Unit {
  let (node_info_by_id, real_node_rects) = @model.collect_real_node_bounds(
    nodes,
  )
  let mut track_top = @double.infinity
  for node in real_node_rects {
    track_top = @model.js_min(track_top, node.rect.top)
  }
  let mut track_bottom = -@double.infinity
  for node in real_node_rects {
    track_bottom = @model.js_max(track_bottom, node.rect.bottom)
  }
  let mut track_left = @double.infinity
  for node in real_node_rects {
    track_left = @model.js_min(track_left, node.rect.left)
  }
  let mut track_right = -@double.infinity
  for node in real_node_rects {
    track_right = @model.js_max(track_right, node.rect.right)
  }
  let outside_track = (side : @model.Side) => {
    match side {
      Top => track_top - DETOUR_ANCHOR
      Bottom => track_bottom + DETOUR_ANCHOR
      Left => track_left - DETOUR_ANCHOR
      Right => track_right + DETOUR_ANCHOR
    }
  }
  let build_orthogonal_path_candidates = (
    src : @model.Pt,
    src_side : @model.Side,
    dst : @model.Pt,
    dst_side : @model.Side,
  ) => {
    let paths = []
    if @model.build_orthogonal_port_path(
        src,
        src_side,
        dst,
        dst_side,
        DETOUR_ANCHOR,
      )
      is Some(base) {
      paths.push(base)
    }
    if src_side == dst_side {
      paths.push(
        @model.build_same_side_track_path(
          src,
          src_side,
          dst,
          outside_track(src_side),
        ),
      )
    }
    paths
  }
  let path_hits_node = (pts : Array[@model.Pt], exclude_ids : Array[String]) => {
    for i in 0..<(pts.length() - 1) {
      if @model.segment_hits_any_rect(
          pts[i],
          pts[i + 1],
          real_node_rects,
          exclude_ids~,
          shrink=1.0,
        ) {
        return true
      }
    }
    false
  }
  let face_claims : Map[String, Array[FaceClaim]] = Map([])
  for e in edges {
    if e.is_layout_only {
      continue
    }
    let pts = e.points.unwrap_or([])
    if pts.length() < 1 {
      continue
    }
    let e_id = e.id
    let start_id = e.start
    let end_id = e.end
    if start_id != "" && node_info_by_id.get(start_id) is Some(info) {
      add_face_claim(
        face_claims,
        start_id,
        nearest_side_of_rect(pts[0], info),
        e_id,
      )
    }
    if end_id != "" && node_info_by_id.get(end_id) is Some(info) {
      add_face_claim(
        face_claims,
        end_id,
        nearest_side_of_rect(pts[pts.length() - 1], info),
        e_id,
      )
    }
  }
  for edge in edges {
    if edge.is_layout_only {
      continue
    }
    guard edge.points is Some(pts) && pts.length() >= 2 else { continue }
    let current_bends = @model.count_orthogonal_bends(pts)
    if current_bends < DETOUR_BEND_THRESHOLD {
      continue
    }
    let src_id = edge.start
    let dst_id = edge.end
    if src_id == "" || dst_id == "" {
      continue
    }
    guard node_info_by_id.get(src_id) is Some(src_info) &&
      node_info_by_id.get(dst_id) is Some(dst_info) else {
      continue
    }
    let edge_id = edge.id
    let current_crossing_conflicts = path_conflict_count(
      edges,
      pts,
      edge,
      include_incident_edges=true,
    )
    let current_non_incident_conflicts = path_conflict_count(edges, pts, edge)
    let mut best_path : Array[@model.Pt]? = None
    let mut best_crossing_conflicts = current_crossing_conflicts
    let mut best_bends = current_bends
    for src_side in detour_sides {
      if face_is_claimed(face_claims, src_id, src_side, edge_id) {
        continue
      }
      let src_port = @model.port_for_rect_side(src_info, src_side)
      for dst_side in detour_sides {
        if face_is_claimed(face_claims, dst_id, dst_side, edge_id) {
          continue
        }
        let dst_port = @model.port_for_rect_side(dst_info, dst_side)
        for
          path in build_orthogonal_path_candidates(
            src_port, src_side, dst_port, dst_side,
          ) {
          if path_hits_node(path, [src_id, dst_id]) {
            continue
          }
          let path_bends = @model.count_orthogonal_bends(path)
          if current_crossing_conflicts > 0 {
            let path_crossing_conflicts = path_conflict_count(
              edges,
              path,
              edge,
              include_incident_edges=true,
            )
            if path_crossing_conflicts > best_crossing_conflicts ||
              (
                path_crossing_conflicts == best_crossing_conflicts &&
                path_bends >= best_bends
              ) {
              continue
            }
            best_crossing_conflicts = path_crossing_conflicts
            best_bends = path_bends
            best_path = Some(path)
            continue
          }
          if path_conflict_count(edges, path, edge) >
            current_non_incident_conflicts {
            continue
          }
          if path_bends < best_bends {
            best_bends = path_bends
            best_path = Some(path)
          }
        }
      }
    }
    guard best_path is Some(best_path) else { continue }
    edge.points = Some(best_path)
    if face_claims.get(src_id) is Some(refresh_src) {
      face_claims[src_id] = refresh_src.filter(c => c.edge_id != edge_id)
    }
    if face_claims.get(dst_id) is Some(refresh_dst) {
      face_claims[dst_id] = refresh_dst.filter(c => c.edge_id != edge_id)
    }
    add_face_claim(
      face_claims,
      src_id,
      nearest_side_of_rect(best_path[0], src_info),
      edge_id,
    )
    add_face_claim(
      face_claims,
      dst_id,
      nearest_side_of_rect(best_path[best_path.length() - 1], dst_info),
      edge_id,
    )
  }
}
