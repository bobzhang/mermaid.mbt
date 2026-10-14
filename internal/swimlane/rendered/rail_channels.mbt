// Routes going round the outside of their nodes in parallel, crossing:
// `reassignCrossingExternalRailChannels`.

///|
/// An inner segment of a route that runs outside the box around both of
/// its ends.
priv struct ExternalRail {
  /// The visible edge, by position.
  edge : Int32
  points : Array[@model.Pt]
  segment_index : Int32
  vertical : Bool
  /// `"left"`/`"right"` for vertical rails, `"top"`/`"bottom"` otherwise.
  side : String
  coord : Double
  min : Double
  max : Double
}

///|
/// The space between parallel rails given new tracks: `RAIL_CHANNEL_GAP`.
const RAIL_CHANNEL_GAP : Double = 12.0

///|
/// Components up to this size try every assignment of the tracks:
/// `MAX_EXHAUSTIVE_COMPONENT`.
const MAX_EXHAUSTIVE_COMPONENT : Int32 = 6

///|
/// The rail of `segment`, when it is an inner segment beyond both ends of
/// the edge: `externalRailForSegment`.
fn external_rail_for_segment(
  visible : Array[@model.Edge],
  edge_index : Int32,
  points : Array[@model.Pt],
  segment : @model.Seg,
  node_by_id : Map[String, @model.Node],
) -> ExternalRail? {
  if segment.index <= 0 || segment.index + 1 >= points.length() - 1 {
    return None
  }
  // `endpointRectsFor`
  let edge = visible[edge_index]
  guard node_for(node_by_id, edge.start) is Some(src_node) &&
    node_for(node_by_id, edge.end) is Some(dst_node) &&
    @model.rect_of_node_bounds(src_node) is Some(src) &&
    @model.rect_of_node_bounds(dst_node) is Some(dst) else {
    return None
  }
  if segment.vertical {
    let coord = segment.a.x
    let left_bound = @model.js_min(src.left, dst.left)
    let right_bound = @model.js_max(src.right, dst.right)
    let side = if coord < left_bound - EPS_LOCAL {
      "left"
    } else if coord > right_bound + EPS_LOCAL {
      "right"
    } else {
      return None
    }
    return Some({
      edge: edge_index,
      points,
      segment_index: segment.index,
      vertical: true,
      side,
      coord,
      min: @model.js_min(segment.a.y, segment.b.y),
      max: @model.js_max(segment.a.y, segment.b.y),
    })
  }
  if segment.horizontal {
    let coord = segment.a.y
    let top_bound = @model.js_min(src.top, dst.top)
    let bottom_bound = @model.js_max(src.bottom, dst.bottom)
    let side = if coord < top_bound - EPS_LOCAL {
      "top"
    } else if coord > bottom_bound + EPS_LOCAL {
      "bottom"
    } else {
      return None
    }
    return Some({
      edge: edge_index,
      points,
      segment_index: segment.index,
      vertical: false,
      side,
      coord,
      min: @model.js_min(segment.a.x, segment.b.x),
      max: @model.js_max(segment.a.x, segment.b.x),
    })
  }
  None
}

///|
/// Two rails of different edges on the same side, side by side for at
/// least `MIN_SHARED`: `railsInteract`.
fn rails_interact(a : ExternalRail, b : ExternalRail) -> Bool {
  a.edge != b.edge &&
  a.vertical == b.vertical &&
  a.side == b.side &&
  @model.overlap_length(a.min, a.max, b.min, b.max) >= MIN_SHARED
}

///|
/// The groups of interacting rails with more than one rail:
/// `connectedComponents`.
fn rail_components(rails : Array[ExternalRail]) -> Array[Array[ExternalRail]] {
  let result = []
  let seen = Array::make(rails.length(), false)
  for start in 0..<rails.length() {
    if seen[start] {
      continue
    }
    let queue = [start]
    let component = []
    seen[start] = true
    while queue.pop() is Some(current) {
      component.push(rails[current])
      for next in 0..<rails.length() {
        if !seen[next] && rails_interact(rails[current], rails[next]) {
          seen[next] = true
          queue.push(next)
        }
      }
    }
    if component.length() > 1 {
      result.push(component)
    }
  }
  result
}

///|
/// The tracks of the component's rails, with new ones beyond them until
/// there is one per rail: `uniqueCoordsFor`.
fn unique_coords_for(component : Array[ExternalRail]) -> Array[Double] {
  let coords : Array[Double] = []
  for rail in component {
    if !coords.iter().any(fn(coord) { (coord - rail.coord).abs() < EPS_LOCAL }) {
      coords.push(rail.coord)
    }
  }
  while coords.length() < component.length() {
    let min = min_of(coords)
    let max = max_of(coords)
    let side = component[0].side
    let room = RAIL_CHANNEL_GAP *
      (component.length() - coords.length()).to_double()
    coords.push(
      if side == "left" || side == "top" {
        min - room
      } else {
        max + room
      },
    )
  }
  coords
}

///|
/// The ways to give the rails the tracks, other than the present one:
/// every permutation for small components, every swap of two rails
/// otherwise. `coordinateAssignmentsFor`.
fn coordinate_assignments_for(
  component : Array[ExternalRail],
) -> Array[Array[Double]] {
  let current = component.map(fn(rail) { rail.coord })
  let coords = unique_coords_for(component)
  let assignments = []
  if component.length() <= MAX_EXHAUSTIVE_COMPONENT {
    let used = Array::make(coords.length(), false)
    let next : Array[Double] = []
    fn visit() -> Unit {
      if next.length() == component.length() {
        let mut moved = false
        for index, coord in next {
          if (coord - current[index]).abs() >= EPS_LOCAL {
            moved = true
            break
          }
        }
        if moved {
          assignments.push(next.copy())
        }
        return
      }
      for i, coord in coords {
        if used[i] {
          continue
        }
        used[i] = true
        next.push(coord)
        visit()
        next.pop() |> ignore
        used[i] = false
      }
    }

    visit()
    return assignments
  }
  for i in 0..<current.length() {
    for j in (i + 1)..<current.length() {
      let assignment = current.copy()
      let swapped = assignment[i]
      assignment[i] = assignment[j]
      assignment[j] = swapped
      assignments.push(assignment)
    }
  }
  assignments
}

///|
/// The routes with the rails moved to the tracks of `assignment`, when they
/// all stay orthogonal: `replacementsForAssignment`.
fn replacements_for_assignment(
  component : Array[ExternalRail],
  assignment : Array[Double],
) -> Map[Int32, Array[@model.Pt]]? {
  let draft_by_edge : Map[Int32, Array[@model.Pt]] = Map([])
  for i, rail in component {
    let coord = assignment[i]
    let points = match draft_by_edge.get(rail.edge) {
      Some(points) => points
      None => rail.points.map(fn(point) { @model.pt(point.x, point.y) })
    }
    if rail.vertical {
      points[rail.segment_index].x = coord
      points[rail.segment_index + 1].x = coord
    } else {
      points[rail.segment_index].y = coord
      points[rail.segment_index + 1].y = coord
    }
    draft_by_edge[rail.edge] = points
  }
  let replacements : Map[Int32, Array[@model.Pt]] = Map([])
  for edge, points in draft_by_edge {
    let simplified = @model.simplify_polyline(
      @model.dedupe_consecutive_points(points),
    )
    if segments_for(simplified).length() != simplified.length() - 1 {
      return None
    }
    replacements[edge] = simplified
  }
  Some(replacements)
}

///|
/// Whether the moved routes keep clear of nodes and labels and share no
/// track with any route: `candidateIsSafe` of the rail channels.
fn channel_replacements_are_safe(
  visible : Array[@model.Edge],
  replacements : Map[Int32, Array[@model.Pt]],
  real_node_rects : Array[@model.RectEntry],
  label_rects : Array[@model.RectEntry],
) -> Bool {
  for edge, points in replacements {
    let endpoints = endpoint_ids(visible[edge])
    for segment in segments_for(points) {
      if segment_hits_nodes(
          segment,
          endpoints,
          real_node_rects,
          Some(label_rects),
        ) {
        return false
      }
    }
  }
  for i in 0..<visible.length() {
    let first_changed = replacements.contains(i)
    let first_segments = segments_for(
      replacement_points(visible, i, replacements),
    )
    for j in (i + 1)..<visible.length() {
      if !first_changed && !replacements.contains(j) {
        continue
      }
      let second_segments = segments_for(
        replacement_points(visible, j, replacements),
      )
      if share_track(first_segments, second_segments) {
        return false
      }
    }
  }
  true
}

///|
/// Where routes going round the outside of their ends run side by side and
/// cross, give their outer segments the tracks in another order, keeping
/// the order with the fewest crossings, then bends, then displacement:
/// `reassignCrossingExternalRailChannels`.
pub fn reassign_crossing_external_rail_channels(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let (real_node_rects, label_rects) = @model.collect_node_rect_entries(
    node_by_id.values(),
  )
  let visible = visible_edges(edges)
  let no_replacements : Map[Int32, Array[@model.Pt]] = Map([])
  for _iteration in 0..<4 {
    let current_crossings = strict_crossing_count(visible, no_replacements)
    if current_crossings == 0 {
      return
    }
    let mut best_replacements : Map[Int32, Array[@model.Pt]]? = None
    let mut best_crossings = current_crossings
    let mut best_bends = total_bends(visible, no_replacements)
    let mut best_displacement = @double.infinity
    // `collectExternalRails`
    let rails = []
    for index in 0..<visible.length() {
      let points = replacement_points(visible, index, no_replacements)
      for segment in segments_for(points) {
        if external_rail_for_segment(
            visible, index, points, segment, node_by_id,
          )
          is Some(rail) {
          rails.push(rail)
        }
      }
    }
    for component in rail_components(rails) {
      for assignment in coordinate_assignments_for(component) {
        guard replacements_for_assignment(component, assignment)
          is Some(replacements) else {
          continue
        }
        if !channel_replacements_are_safe(
            visible, replacements, real_node_rects, label_rects,
          ) {
          continue
        }
        let candidate_crossings = strict_crossing_count(visible, replacements)
        if candidate_crossings >= current_crossings {
          continue
        }
        let candidate_bends = total_bends(visible, replacements)
        let mut candidate_displacement = 0.0
        for index, rail in component {
          candidate_displacement = candidate_displacement +
            (assignment[index] - rail.coord).abs()
        }
        if candidate_crossings > best_crossings ||
          (
            candidate_crossings == best_crossings &&
            (
              candidate_bends > best_bends ||
              (
                candidate_bends == best_bends &&
                candidate_displacement >= best_displacement
              )
            )
          ) {
          continue
        }
        best_replacements = Some(replacements)
        best_crossings = candidate_crossings
        best_bends = candidate_bends
        best_displacement = candidate_displacement
      }
    }
    guard best_replacements is Some(replacements) else { return }
    for index, points in replacements {
      visible[index].points = Some(points)
    }
  }
}
