// Clean-ups of the routes as they will be drawn:
// `swimlanes/direction/materializedGeometry.ts`. Every pass works on the
// routes the renderer receives, after the endpoints were clipped to the
// node borders. This file holds what the passes share; upstream repeats
// most of it in each pass as local closures.
//
// Where upstream keys maps and sets by edge objects, the passes here use
// the position of the edge among the visible edges, which is the same as
// long as an edge appears once in the layout.

///|
/// `EPS_LOCAL`.
const EPS_LOCAL : Double = 1.0e-3

///|
/// How long two routes may run along the same track before it counts as a
/// shared track: `MIN_SHARED`.
const MIN_SHARED : Double = 8.0

///|
/// `upperCaseDirection`.
fn upper_case_direction(raw : String) -> String {
  raw.to_upper()
}

///|
/// `segmentsFor`.
fn segments_for(points : Array[@model.Pt]) -> Array[@model.Seg] {
  @model.orthogonal_segments_for_points(points)
}

///|
/// `orthogonallyAligned`.
fn orthogonally_aligned(a : @model.Pt, b : @model.Pt) -> Bool {
  @model.same_x(a, b, epsilon=EPS_LOCAL) ||
  @model.same_y(a, b, epsilon=EPS_LOCAL)
}

///|
/// The ids of an edge's ends that are set: `[edge.start, edge.end].filter(Boolean)`.
fn endpoint_ids(edge : @model.Edge) -> Array[String] {
  [edge.start, edge.end].filter(fn(id) { id != "" })
}

///|
/// `id ? nodeByIdMap.get(id) : undefined`.
fn node_for(node_by_id : Map[String, @model.Node], id : String) -> @model.Node? {
  if id == "" {
    None
  } else {
    node_by_id.get(id)
  }
}

///|
/// The edges that are drawn.
fn visible_edges(edges : Array[@model.Edge]) -> Array[@model.Edge] {
  edges.filter(fn(edge) { !edge.is_layout_only })
}

///|
/// The route of an edge, deduplicated: `dedupeConsecutivePoints(edge.points ?? [])`.
fn route_of(edge : @model.Edge) -> Array[@model.Pt] {
  @model.dedupe_consecutive_points(edge.points.unwrap_or([]))
}

///|
/// The route of the visible edge `index`, or the one replacing it:
/// `replacementPointsFor`.
fn replacement_points(
  visible : Array[@model.Edge],
  index : Int32,
  replacements : Map[Int32, Array[@model.Pt]],
) -> Array[@model.Pt] {
  match replacements.get(index) {
    Some(points) => @model.dedupe_consecutive_points(points)
    None => route_of(visible[index])
  }
}

///|
/// How many times two sets of segments cross strictly:
/// `crossingCountBetweenSegments`.
fn crossing_count_between(
  first : Array[@model.Seg],
  second : Array[@model.Seg],
) -> Int32 {
  let mut count = 0
  for first_segment in first {
    for second_segment in second {
      if @model.orthogonal_segments_strictly_cross(
          first_segment.a,
          first_segment.b,
          second_segment.a,
          second_segment.b,
          epsilon=EPS_LOCAL,
        ) {
        count += 1
      }
    }
  }
  count
}

///|
/// How many times the visible routes cross each other strictly, some of
/// them replaced: `strictCrossingCount`/`crossingCount`. (Upstream works
/// out the segments of the second route again for every first one; they
/// are the same.)
fn strict_crossing_count(
  visible : Array[@model.Edge],
  replacements : Map[Int32, Array[@model.Pt]],
) -> Int32 {
  let segments = Array::makei(visible.length(), fn(i) {
    segments_for(replacement_points(visible, i, replacements))
  })
  let mut count = 0
  for i in 0..<visible.length() {
    for j in (i + 1)..<visible.length() {
      count += crossing_count_between(segments[i], segments[j])
    }
  }
  count
}

///|
/// The bends of all visible routes, some of them replaced: `totalBends`.
fn total_bends(
  visible : Array[@model.Edge],
  replacements : Map[Int32, Array[@model.Pt]],
) -> Int32 {
  let mut sum = 0
  for i in 0..<visible.length() {
    sum += @model.count_orthogonal_bends(
      replacement_points(visible, i, replacements),
    )
  }
  sum
}

///|
/// Whether two sets of segments run along the same track for at least
/// `MIN_SHARED`.
fn share_track(first : Array[@model.Seg], second : Array[@model.Seg]) -> Bool {
  first
  .iter()
  .any(fn(a) {
    second
    .iter()
    .any(fn(b) {
      @model.same_axis_segment_overlap_length(a, b, epsilon=0.5) >= MIN_SHARED
    })
  })
}

///|
/// Whether a segment goes through a node other than the edge's ends, or
/// through an edge label, with 2px of slack: the checks every pass makes
/// on a new route (`segmentHitsAnyRect(.., -BUFFER)`).
fn segment_hits_nodes(
  segment : @model.Seg,
  endpoints : Array[String],
  real_node_rects : Array[@model.RectEntry],
  label_rects : Array[@model.RectEntry]?,
) -> Bool {
  if @model.segment_hits_any_rect(
      segment.a,
      segment.b,
      real_node_rects,
      exclude_ids=endpoints,
      shrink=-2.0,
    ) {
    return true
  }
  match label_rects {
    Some(rects) =>
      @model.segment_hits_any_rect(segment.a, segment.b, rects, shrink=-2.0)
    None => false
  }
}

///|
/// The key of a route by its points rounded to 3 decimals, to drop
/// repeated candidates.
fn route_key(points : Array[@model.Pt]) -> String {
  points
  .map(fn(point) { "\{@d3.to_fixed(point.x, 3)},\{@d3.to_fixed(point.y, 3)}" })
  .join("|")
}

///|
/// `Math.min(...values)`.
fn min_of(values : Array[Double]) -> Double {
  let mut result = @double.infinity
  for value in values {
    result = @model.js_min(result, value)
  }
  result
}

///|
/// `Math.max(...values)`.
fn max_of(values : Array[Double]) -> Double {
  let mut result = @double.neg_infinity
  for value in values {
    result = @model.js_max(result, value)
  }
  result
}

///|
/// `Math.sign`.
fn js_sign(x : Double) -> Double {
  if x > 0.0 {
    1.0
  } else if x < 0.0 {
    -1.0
  } else {
    // 0, -0 and NaN are their own sign.
    x
  }
}

///|
/// `Number.isFinite`.
fn is_finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}
