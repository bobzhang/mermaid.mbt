// Routes running along a node they pass: `liftObstacleHuggingSameSideRails`.

///|
/// The middle segment of a route of three segments that turns at both
/// ends: `middleRail`.
fn middle_rail(points : Array[@model.Pt]) -> @model.Seg? {
  let segments = segments_for(points)
  if segments.length() != 3 {
    return None
  }
  let middle = segments[1]
  if segments[0].horizontal == middle.horizontal ||
    segments[2].horizontal == middle.horizontal {
    return None
  }
  Some(middle)
}

///|
/// The nodes other than the edge's ends that the rail runs along or
/// through, within 2px: `blockingRectsFor`.
fn blocking_rects_for(
  edge : @model.Edge,
  rail : @model.Seg,
  real_node_rects : Array[@model.RectEntry],
) -> Array[@model.RectEntry] {
  let endpoints = endpoint_ids(edge)
  let buffer = 2.0
  real_node_rects.filter(fn(entry) {
    if endpoints.contains(entry.id) {
      return false
    }
    let rect = entry.rect
    if rail.horizontal {
      let x_overlap = @model.overlap_length(
        rail.a.x,
        rail.b.x,
        rect.left,
        rect.right,
      )
      return x_overlap >= MIN_SHARED &&
        rail.a.y >= rect.top - buffer &&
        rail.a.y <= rect.bottom + buffer
    }
    let y_overlap = @model.overlap_length(
      rail.a.y,
      rail.b.y,
      rect.top,
      rect.bottom,
    )
    y_overlap >= MIN_SHARED &&
    rail.a.x >= rect.left - buffer &&
    rail.a.x <= rect.right + buffer
  })
}

///|
/// The route with the rail moved to `coord`, when it stays orthogonal:
/// `candidateByMovingRail`.
fn candidate_by_moving_rail(
  points : Array[@model.Pt],
  rail : @model.Seg,
  coord : Double,
) -> Array[@model.Pt]? {
  let candidate = points.map(fn(point) { point.copy() })
  if rail.horizontal {
    candidate[rail.index].y = coord
    candidate[rail.index + 1].y = coord
  } else if rail.vertical {
    candidate[rail.index].x = coord
    candidate[rail.index + 1].x = coord
  } else {
    return None
  }
  let simplified = @model.simplify_polyline(
    @model.dedupe_consecutive_points(candidate),
  )
  if segments_for(simplified).length() == simplified.length() - 1 {
    Some(simplified)
  } else {
    None
  }
}

///|
/// Whether the route `candidate` of the visible edge `index` stays
/// orthogonal, keeps clear of nodes and labels, shares no track and
/// crosses no more than `current_crossings` times in all: `candidateIsSafe`
/// of the rail lift (and of `shortcutRedundantOrthogonalJogs` with the
/// border check). The crossings are left to the caller.
fn rail_candidate_is_clear(
  visible : Array[@model.Edge],
  index : Int32,
  candidate : Array[@model.Pt],
  real_node_rects : Array[@model.RectEntry],
  label_rects : Array[@model.RectEntry],
) -> Bool {
  let edge = visible[index]
  let endpoints = endpoint_ids(edge)
  let candidate_segments = segments_for(candidate)
  if candidate_segments.length() != candidate.length() - 1 {
    return false
  }
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
/// Move the middle rail of a three-segment route that runs along or
/// through other nodes to 20px beyond them, on either side, when the new
/// route is clear and crosses no more: `liftObstacleHuggingSameSideRails`.
pub fn lift_obstacle_hugging_same_side_rails(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let clearance = 20.0
  let (real_node_rects, label_rects) = @model.collect_node_rect_entries(
    node_by_id.values(),
  )
  let visible = visible_edges(edges)
  for _iteration in 0..<8 {
    let current_crossings = strict_crossing_count(visible, Map([]))
    let mut fixed = false
    for index, edge in visible {
      let points = route_of(edge)
      guard middle_rail(points) is Some(rail) else { continue }
      let blockers = blocking_rects_for(edge, rail, real_node_rects)
      if blockers.length() == 0 {
        continue
      }
      let coords = if rail.horizontal {
        [
          min_of(blockers.map(fn(entry) { entry.rect.top })) - clearance,
          max_of(blockers.map(fn(entry) { entry.rect.bottom })) + clearance,
        ]
      } else {
        [
          min_of(blockers.map(fn(entry) { entry.rect.left })) - clearance,
          max_of(blockers.map(fn(entry) { entry.rect.right })) + clearance,
        ]
      }
      for coord in coords {
        guard candidate_by_moving_rail(points, rail, coord) is Some(candidate) else {
          continue
        }
        if !rail_candidate_is_clear(
            visible, index, candidate, real_node_rects, label_rects,
          ) ||
          strict_crossing_count(visible, Map([(index, candidate)])) >
          current_crossings {
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
