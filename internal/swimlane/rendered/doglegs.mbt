// Detours that leave a track and come back to it:
// `collapseRedundantRectangularDoglegs`.

///|
/// `points` without the dogleg starting at `index`, when there is one: a
/// route that turns off its line and back onto it (four turns, or three
/// at the end of a route), going one way and then back. `withoutDogleg`.
fn without_dogleg(points : Array[@model.Pt], i : Int32) -> Array[@model.Pt]? {
  if i + 4 >= points.length() {
    return None
  }
  let p0 = points[i]
  let p1 = points[i + 1]
  let p2 = points[i + 2]
  let p3 = points[i + 3]
  let p4 = points[i + 4]
  let terminal_vertical_dogleg = @model.is_horizontal_segment(p0, p1) &&
    @model.is_vertical_segment(p1, p2) &&
    @model.is_horizontal_segment(p2, p3) &&
    @model.is_vertical_segment(p3, p4) &&
    @model.same_x(p0, p3, epsilon=EPS_LOCAL) &&
    @model.same_x(p0, p4, epsilon=EPS_LOCAL) &&
    @model.same_x(p1, p2, epsilon=EPS_LOCAL) &&
    (p1.x - p0.x) * (p3.x - p2.x) < 0.0
  let terminal_horizontal_dogleg = @model.is_vertical_segment(p0, p1) &&
    @model.is_horizontal_segment(p1, p2) &&
    @model.is_vertical_segment(p2, p3) &&
    @model.is_horizontal_segment(p3, p4) &&
    @model.same_y(p0, p3, epsilon=EPS_LOCAL) &&
    @model.same_y(p0, p4, epsilon=EPS_LOCAL) &&
    @model.same_y(p1, p2, epsilon=EPS_LOCAL) &&
    (p1.y - p0.y) * (p3.y - p2.y) < 0.0
  if terminal_vertical_dogleg || terminal_horizontal_dogleg {
    return Some(
      @model.dedupe_consecutive_points([..points[:i + 1], p4, ..points[i + 5:]]),
    )
  }
  if i + 5 >= points.length() {
    return None
  }
  let p5 = points[i + 5]
  let vertical_dogleg = @model.is_vertical_segment(p0, p1) &&
    @model.is_horizontal_segment(p1, p2) &&
    @model.is_vertical_segment(p2, p3) &&
    @model.is_horizontal_segment(p3, p4) &&
    @model.is_vertical_segment(p4, p5) &&
    @model.same_x(p0, p4, epsilon=EPS_LOCAL) &&
    @model.same_x(p0, p5, epsilon=EPS_LOCAL) &&
    @model.same_x(p2, p3, epsilon=EPS_LOCAL) &&
    (p2.x - p1.x) * (p4.x - p3.x) < 0.0
  let horizontal_dogleg = @model.is_horizontal_segment(p0, p1) &&
    @model.is_vertical_segment(p1, p2) &&
    @model.is_horizontal_segment(p2, p3) &&
    @model.is_vertical_segment(p3, p4) &&
    @model.is_horizontal_segment(p4, p5) &&
    @model.same_y(p0, p4, epsilon=EPS_LOCAL) &&
    @model.same_y(p0, p5, epsilon=EPS_LOCAL) &&
    @model.same_y(p2, p3, epsilon=EPS_LOCAL) &&
    (p2.y - p1.y) * (p4.y - p3.y) < 0.0
  if !vertical_dogleg && !horizontal_dogleg {
    return None
  }
  Some(
    @model.dedupe_consecutive_points([..points[:i + 1], p5, ..points[i + 6:]]),
  )
}

///|
/// Whether the route `candidate` of `edge` stays orthogonal, keeps clear of
/// the nodes and labels, and neither shares a track with nor crosses
/// another route: `candidateIsSafe` of the dogleg pass.
fn dogleg_candidate_is_safe(
  edge : @model.Edge,
  candidate : Array[@model.Pt],
  edges : Array[@model.Edge],
  real_node_rects : Array[@model.RectEntry],
  label_rects : Array[@model.RectEntry],
) -> Bool {
  let candidate_segments = segments_for(candidate)
  if candidate_segments.length() != candidate.length() - 1 {
    return false
  }
  let endpoints = endpoint_ids(edge)
  for segment in candidate_segments {
    if segment_hits_nodes(
        segment,
        endpoints,
        real_node_rects,
        Some(label_rects),
      ) {
      return false
    }
  }
  for other in edges {
    if physical_equal(other, edge) || other.is_layout_only {
      continue
    }
    guard other.points is Some(other_points) && other_points.length() >= 2 else {
      continue
    }
    let other_segments = segments_for(
      @model.dedupe_consecutive_points(other_points),
    )
    for candidate_segment in candidate_segments {
      for other_segment in other_segments {
        if @model.same_axis_segment_overlap_length(
            candidate_segment,
            other_segment,
            epsilon=0.5,
          ) >=
          MIN_SHARED {
          return false
        }
        if @model.orthogonal_segments_strictly_cross(
            candidate_segment.a,
            candidate_segment.b,
            other_segment.a,
            other_segment.b,
            epsilon=EPS_LOCAL,
          ) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Cut out the rectangular detours of the routes where the straight route
/// is free: `collapseRedundantRectangularDoglegs`. One dogleg goes per
/// iteration, the first one of the first route that has a safe one.
pub fn collapse_redundant_rectangular_doglegs(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let (real_node_rects, label_rects) = @model.collect_node_rect_entries(
    node_by_id.values(),
  )
  for _iteration in 0..<8 {
    let mut fixed = false
    for edge in edges {
      if edge.is_layout_only {
        continue
      }
      let points = route_of(edge)
      for i = 0; i <= points.length() - 5; i = i + 1 {
        guard without_dogleg(points, i) is Some(candidate) else { continue }
        if !dogleg_candidate_is_safe(
            edge, candidate, edges, real_node_rects, label_rects,
          ) {
          continue
        }
        edge.points = Some(candidate)
        fixed = true
        break
      }
      if fixed {
        break
      }
    }
    if !fixed {
      return
    }
  }
}
