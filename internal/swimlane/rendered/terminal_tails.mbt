// Two routes into the same node that cross on the way:
// `swapDestinationTerminalTailsToReduceCrossings`.

///|
/// The last segment of a route of at least four points, when it is
/// orthogonal: `terminalTailFor`, as `(tailStart, terminal)`.
fn terminal_tail_for(points : Array[@model.Pt]) -> (@model.Pt, @model.Pt)? {
  if points.length() < 4 {
    return None
  }
  let tail_start = points[points.length() - 2]
  let terminal = points[points.length() - 1]
  if !@model.is_horizontal_segment(tail_start, terminal, epsilon=EPS_LOCAL) &&
    !@model.is_vertical_segment(tail_start, terminal, epsilon=EPS_LOCAL) {
    return None
  }
  Some((tail_start, terminal))
}

///|
/// The route that leaves like `points` and ends with the tail of another
/// route: `candidateWithDestinationTail`.
fn candidate_with_destination_tail(
  points : Array[@model.Pt],
  tail : (@model.Pt, @model.Pt),
) -> Array[@model.Pt]? {
  if points.length() < 3 {
    return None
  }
  let (tail_start, terminal) = tail
  let start = points[0]
  let first_turn = points[1]
  let connector = if @model.is_horizontal_segment(
      start,
      first_turn,
      epsilon=EPS_LOCAL,
    ) {
    @model.pt(first_turn.x, tail_start.y)
  } else if @model.is_vertical_segment(start, first_turn, epsilon=EPS_LOCAL) {
    @model.pt(tail_start.x, first_turn.y)
  } else {
    return None
  }
  let candidate = @model.simplify_polyline(
    @model.dedupe_consecutive_points([
      start, first_turn, connector, tail_start, terminal,
    ]),
  )
  if segments_for(candidate).length() == candidate.length() - 1 {
    Some(candidate)
  } else {
    None
  }
}

///|
/// Whether the route `path` of the visible edge `index` keeps clear of the
/// nodes other than its ends and shares no track with the other routes,
/// some of them replaced: `candidateIsSafe` of the tail swap.
fn tail_candidate_is_safe(
  visible : Array[@model.Edge],
  index : Int32,
  path : Array[@model.Pt],
  replacements : Map[Int32, Array[@model.Pt]],
  real_node_rects : Array[@model.RectEntry],
) -> Bool {
  let edge = visible[index]
  let endpoints = endpoint_ids(edge)
  let path_segments = segments_for(path)
  // `pathHasNodeHit`
  for segment in path_segments {
    if segment_hits_nodes(segment, endpoints, real_node_rects, None) {
      return false
    }
  }
  // `pathHasSharedTrack`
  for other_index, other in visible {
    if physical_equal(other, edge) {
      continue
    }
    let other_segments = segments_for(
      replacement_points(visible, other_index, replacements),
    )
    if share_track(path_segments, other_segments) {
      return false
    }
  }
  true
}

///|
/// For two routes into the same node, try giving each the other's last
/// segment, and keep the swap that removes the most crossings (then the
/// most bends): `swapDestinationTerminalTailsToReduceCrossings`.
pub fn swap_destination_terminal_tails_to_reduce_crossings(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let (real_node_rects, _) = @model.collect_node_rect_entries(
    node_by_id.values(),
  )
  let visible = visible_edges(edges)
  let no_replacements : Map[Int32, Array[@model.Pt]] = Map([])
  for _iteration in 0..<4 {
    let current_crossings = strict_crossing_count(visible, no_replacements)
    if current_crossings == 0 {
      return
    }
    let current_bends = total_bends(visible, no_replacements)
    let mut best_replacements : Map[Int32, Array[@model.Pt]]? = None
    let mut best_crossings = current_crossings
    let mut best_bends = current_bends
    // `edgesByDestination`
    let by_destination : Map[String, Array[Int32]] = Map([])
    for index, edge in visible {
      let dst_id = edge.end
      if dst_id == "" || !node_by_id.contains(dst_id) {
        continue
      }
      if route_of(edge).length() < 4 {
        continue
      }
      match by_destination.get(dst_id) {
        Some(bucket) => bucket.push(index)
        None => by_destination[dst_id] = [index]
      }
    }
    for _, destination_edges in by_destination {
      for i in 0..<destination_edges.length() {
        for j in (i + 1)..<destination_edges.length() {
          let first = destination_edges[i]
          let second = destination_edges[j]
          let first_points = route_of(visible[first])
          let second_points = route_of(visible[second])
          guard terminal_tail_for(first_points) is Some(first_tail) &&
            terminal_tail_for(second_points) is Some(second_tail) else {
            continue
          }
          guard candidate_with_destination_tail(first_points, second_tail)
            is Some(first_candidate) &&
            candidate_with_destination_tail(second_points, first_tail)
            is Some(second_candidate) else {
            continue
          }
          let replacements = Map([
            (first, first_candidate),
            (second, second_candidate),
          ])
          if !tail_candidate_is_safe(
              visible, first, first_candidate, replacements, real_node_rects,
            ) ||
            !tail_candidate_is_safe(
              visible, second, second_candidate, replacements, real_node_rects,
            ) {
            continue
          }
          let candidate_crossings = strict_crossing_count(visible, replacements)
          let candidate_bends = total_bends(visible, replacements)
          if candidate_crossings >= current_crossings {
            continue
          }
          if candidate_crossings > best_crossings ||
            (
              candidate_crossings == best_crossings &&
              candidate_bends >= best_bends
            ) {
            continue
          }
          best_replacements = Some(replacements)
          best_crossings = candidate_crossings
          best_bends = candidate_bends
        }
      }
    }
    guard best_replacements is Some(replacements) else { return }
    for index, points in replacements {
      visible[index].points = Some(points)
    }
  }
}
