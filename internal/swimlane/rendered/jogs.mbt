// Routes that step aside and come back: `shortcutRedundantOrthogonalJogs`.

///|
/// The length of the orthogonal segments of a route: `pathLength` of the
/// jog pass.
fn euclidean_route_length(points : Array[@model.Pt]) -> Double {
  let mut sum = 0.0
  for segment in segments_for(points) {
    let dx = segment.a.x - segment.b.x
    let dy = segment.a.y - segment.b.y
    sum = sum + @jsmath.hypot(dx, dy)
  }
  sum
}

///|
/// Whether a segment runs along a side of `rect` for at least `MIN_SHARED`:
/// `segmentRunsAlongRectBorder`.
fn segment_runs_along_rect_border(
  segment : @model.Seg,
  rect : @model.Rect,
) -> Bool {
  if segment.horizontal {
    let y = segment.a.y
    let on_border = (y - rect.top).abs() < 1.0 || (y - rect.bottom).abs() < 1.0
    return on_border &&
      @model.overlap_length(segment.a.x, segment.b.x, rect.left, rect.right) >=
      MIN_SHARED
  }
  if segment.vertical {
    let x = segment.a.x
    let on_border = (x - rect.left).abs() < 1.0 || (x - rect.right).abs() < 1.0
    return on_border &&
      @model.overlap_length(segment.a.y, segment.b.y, rect.top, rect.bottom) >=
      MIN_SHARED
  }
  false
}

///|
/// The routes without the jog `points[index..index + 3]`, a segment out and
/// one back in opposite directions: straight through when the ends of the
/// jog line up, otherwise through either corner. `shortcutCandidatesAt`.
fn shortcut_candidates_at(
  points : Array[@model.Pt],
  index : Int32,
) -> Array[Array[@model.Pt]] {
  if index + 3 >= points.length() {
    return []
  }
  let p0 = points[index]
  let p1 = points[index + 1]
  let p2 = points[index + 2]
  let p3 = points[index + 3]
  let is_hvh = @model.is_horizontal_segment(p0, p1, epsilon=EPS_LOCAL) &&
    @model.is_vertical_segment(p1, p2, epsilon=EPS_LOCAL) &&
    @model.is_horizontal_segment(p2, p3, epsilon=EPS_LOCAL)
  let is_vhv = @model.is_vertical_segment(p0, p1, epsilon=EPS_LOCAL) &&
    @model.is_horizontal_segment(p1, p2, epsilon=EPS_LOCAL) &&
    @model.is_vertical_segment(p2, p3, epsilon=EPS_LOCAL)
  if !is_hvh && !is_vhv {
    return []
  }
  let outer_segments_oppose = if is_hvh {
    js_sign(p1.x - p0.x) != js_sign(p3.x - p2.x)
  } else {
    js_sign(p1.y - p0.y) != js_sign(p3.y - p2.y)
  }
  if !outer_segments_oppose {
    return []
  }
  let raw_candidates = if @model.same_x(p0, p3, epsilon=EPS_LOCAL) ||
    @model.same_y(p0, p3, epsilon=EPS_LOCAL) {
    [[..points[:index + 1], ..points[index + 3:]]]
  } else {
    [@model.pt(p0.x, p3.y), @model.pt(p3.x, p0.y)].map(fn(corner) {
      [..points[:index + 1], corner, ..points[index + 3:]]
    })
  }
  let seen : Set[String] = Set([])
  let result = []
  for raw in raw_candidates {
    let candidate = @model.simplify_polyline(
      @model.dedupe_consecutive_points(raw),
    )
    if segments_for(candidate).length() != candidate.length() - 1 {
      continue
    }
    if !candidate
      .iter()
      .any(fn(point) { @model.same_point(point, p3, epsilon=EPS_LOCAL) }) {
      continue
    }
    let key = route_key(candidate)
    if seen.contains(key) {
      continue
    }
    seen.add(key)
    result.push(candidate)
  }
  result
}

///|
/// Whether the route `candidate` of the visible edge `index` keeps clear
/// of nodes and labels, does not run along the border of its own ends and
/// shares no track: `candidateIsSafe` of the jog pass, the crossings left
/// to the caller.
fn jog_candidate_is_clear(
  visible : Array[@model.Edge],
  index : Int32,
  candidate : Array[@model.Pt],
  node_by_id : Map[String, @model.Node],
  real_node_rects : Array[@model.RectEntry],
  label_rects : Array[@model.RectEntry],
) -> Bool {
  let edge = visible[index]
  let endpoints = endpoint_ids(edge)
  // `endpointRectsFor`
  let endpoint_rects = []
  for id in endpoints {
    if node_by_id.get(id) is Some(node) &&
      @model.rect_of_node_bounds(node) is Some(rect) {
      endpoint_rects.push(rect)
    }
  }
  let candidate_segments = segments_for(candidate)
  for segment in candidate_segments {
    if segment_hits_nodes(
        segment,
        endpoints,
        real_node_rects,
        Some(label_rects),
      ) {
      return false
    }
    if endpoint_rects
      .iter()
      .any(fn(rect) { segment_runs_along_rect_border(segment, rect) }) {
      return false
    }
  }
  for other in visible {
    if physical_equal(other, edge) {
      continue
    }
    if share_track(candidate_segments, segments_for(route_of(other))) {
      return false
    }
  }
  true
}

///|
/// Replace a jog of a route by a straighter way where that is clear and
/// crosses no more, keeping the best of all routes' shortcuts (fewest
/// crossings, then bends, then length): `shortcutRedundantOrthogonalJogs`.
pub fn shortcut_redundant_orthogonal_jogs(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let (real_node_rects, label_rects) = @model.collect_node_rect_entries(
    node_by_id.values(),
  )
  let visible = visible_edges(edges)
  for _iteration in 0..<8 {
    let current_crossings = strict_crossing_count(visible, Map([]))
    let mut best : (Int32, Array[@model.Pt])? = None
    let mut best_crossings = current_crossings
    let mut best_bends = 2147483647
    let mut best_length = @double.infinity
    for edge_index, edge in visible {
      let current_points = route_of(edge)
      let current_bends = @model.count_orthogonal_bends(
        current_points,
        epsilon=EPS_LOCAL,
      )
      let current_length = euclidean_route_length(current_points)
      for index = 0; index <= current_points.length() - 4; index = index + 1 {
        for candidate in shortcut_candidates_at(current_points, index) {
          let candidate_bends = @model.count_orthogonal_bends(
            candidate,
            epsilon=EPS_LOCAL,
          )
          let candidate_length = euclidean_route_length(candidate)
          let improves_shape = candidate_bends < current_bends ||
            (
              candidate_bends == current_bends &&
              candidate_length < current_length - EPS_LOCAL
            )
          if !improves_shape ||
            !jog_candidate_is_clear(
              visible, edge_index, candidate, node_by_id, real_node_rects, label_rects,
            ) {
            continue
          }
          // `candidateIsSafe` ends with the same count.
          let candidate_crossings = strict_crossing_count(
            visible,
            Map([(edge_index, candidate)]),
          )
          if candidate_crossings > current_crossings {
            continue
          }
          if candidate_crossings > best_crossings ||
            (
              candidate_crossings == best_crossings &&
              (
                candidate_bends > best_bends ||
                (
                  candidate_bends == best_bends &&
                  candidate_length >= best_length
                )
              )
            ) {
            continue
          }
          best = Some((edge_index, candidate))
          best_crossings = candidate_crossings
          best_bends = candidate_bends
          best_length = candidate_length
        }
      }
    }
    guard best is Some((edge_index, path)) else { return }
    visible[edge_index].points = Some(path)
  }
}
