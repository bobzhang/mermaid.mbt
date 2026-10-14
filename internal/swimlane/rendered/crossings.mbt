// Routes that still cross: `resolveRenderedOrthogonalCrossings`. The pass
// reroutes one edge at a time when that removes crossings; when no single
// edge can, it tries pairs of edges of a group of crossing routes.

///|
/// How many candidates of each edge the pair search keeps:
/// `MAX_PAIR_CANDIDATES_PER_EDGE`.
const MAX_PAIR_CANDIDATES_PER_EDGE : Int32 = 48

///|
/// Two routes and how many times they cross.
priv struct CrossingPair {
  first : Int32
  second : Int32
  count : Int32
}

///|
/// The crossings of the present routes: `crossingSnapshot`.
priv struct CrossingSnapshot {
  count : Int32
  pairs : Array[CrossingPair]
  edge_set : Set[Int32]
  /// The edges that cross another, in order.
  edges : Array[Int32]
}

///|
/// A route the pair search may give an edge.
priv struct PairCandidate {
  path : Array[@model.Pt]
  segments : Array[@model.Seg]
  /// The other edges it would share a track with.
  shared_track_conflicts : Set[Int32]
  total_bends : Int32
  length : Double
}

///|
/// A score of the pair search: the routes it replaces and the totals
/// with them replaced.
priv struct PairScore {
  replacements : Array[(Int32, Array[@model.Pt])]
  crossings : Int32
  bends : Int32
  length : Double
}

///|
/// What the scores of pairs are measured against: `scoringContext`.
priv struct PairScoring {
  current : CrossingSnapshot
  current_bends : Int32
  current_length : Double
  base_bends_by_edge : Array[Int32]
  base_length_by_edge : Array[Double]
  base_segments : Array[Array[@model.Seg]]
}

///|
/// Sort edges by position.
fn sort_indices(indices : Array[Int32]) -> Unit {
  @d3.js_sort(indices, fn(a, b) { (a - b).to_double() })
}

///|
/// `crossingSnapshot`, from the segments of the present routes.
fn crossing_snapshot(
  base_segments : Array[Array[@model.Seg]],
) -> CrossingSnapshot {
  let mut count = 0
  let pairs = []
  let edge_set : Set[Int32] = Set([])
  let edge_order = []
  fn add_edge(edge : Int32) {
    if !edge_set.contains(edge) {
      edge_set.add(edge)
      edge_order.push(edge)
    }
  }

  for i in 0..<base_segments.length() {
    for j in (i + 1)..<base_segments.length() {
      let pair_count = crossing_count_between(
        base_segments[i],
        base_segments[j],
      )
      if pair_count > 0 {
        count += pair_count
        pairs.push({ first: i, second: j, count: pair_count, })
        add_edge(i)
        add_edge(j)
      }
    }
  }
  sort_indices(edge_order)
  { count, pairs, edge_set, edges: edge_order, }
}

///|
/// The crossings with the route of one edge replaced:
/// `crossingCountWithSingleReplacement`.
fn crossing_count_with_single_replacement(
  current : CrossingSnapshot,
  edge : Int32,
  replacement : Array[@model.Pt],
  base_segments : Array[Array[@model.Seg]],
) -> Int32 {
  let mut current_affected = 0
  for pair in current.pairs {
    if pair.first == edge || pair.second == edge {
      current_affected += pair.count
    }
  }
  let replaced = segments_for(@model.dedupe_consecutive_points(replacement))
  let segments_of = fn(i : Int32) {
    if i == edge {
      replaced
    } else {
      base_segments[i]
    }
  }
  let mut replacement_affected = 0
  for i in 0..<base_segments.length() {
    for j in (i + 1)..<base_segments.length() {
      if i != edge && j != edge {
        continue
      }
      replacement_affected += crossing_count_between(
        segments_of(i),
        segments_of(j),
      )
    }
  }
  current.count - current_affected + replacement_affected
}

///|
/// The groups of routes that cross each other, of more than one route:
/// `crossingComponents`.
fn crossing_components(snapshot : CrossingSnapshot) -> Array[Array[Int32]] {
  let neighbors : Map[Int32, Set[Int32]] = Map([])
  for pair in snapshot.pairs {
    let first_neighbors = neighbors.get(pair.first).unwrap_or(Set([]))
    first_neighbors.add(pair.second)
    neighbors[pair.first] = first_neighbors
    let second_neighbors = neighbors.get(pair.second).unwrap_or(Set([]))
    second_neighbors.add(pair.first)
    neighbors[pair.second] = second_neighbors
  }
  let components = []
  let seen : Set[Int32] = Set([])
  for edge in snapshot.edges {
    if seen.contains(edge) {
      continue
    }
    let queue = [edge]
    let component = []
    seen.add(edge)
    while queue.pop() is Some(current) {
      component.push(current)
      if neighbors.get(current) is Some(next_edges) {
        for next in next_edges {
          if !seen.contains(next) {
            seen.add(next)
            queue.push(next)
          }
        }
      }
    }
    sort_indices(component)
    if component.length() > 1 {
      components.push(component)
    }
  }
  components
}

///|
/// The groups of crossing routes with the routes that share an end with
/// them: `pairSearchGroups`.
fn pair_search_groups(
  visible : Array[@model.Edge],
  snapshot : CrossingSnapshot,
) -> Array[Array[Int32]] {
  let groups = []
  for component in crossing_components(snapshot) {
    let component_set = Set::from_array(component)
    let component_endpoint_ids : Set[String] = Set([])
    for edge in component {
      for id in endpoint_ids(visible[edge]) {
        component_endpoint_ids.add(id)
      }
    }
    let group = component.copy()
    for edge in 0..<visible.length() {
      if component_set.contains(edge) {
        continue
      }
      if endpoint_ids(visible[edge])
        .iter()
        .any(fn(id) { component_endpoint_ids.contains(id) }) {
        group.push(edge)
      }
    }
    sort_indices(group)
    groups.push(group)
  }
  groups
}

///|
/// The length of a route along its segments, diagonal ones measured as
/// if orthogonal: `pathLength` of the crossing pass.
fn manhattan_route_length(points : Array[@model.Pt]) -> Double {
  let mut sum = 0.0
  for index in 1..<points.length() {
    let point = points[index]
    let previous = points[index - 1]
    sum = sum + (point.x - previous.x).abs() + (point.y - previous.y).abs()
  }
  sum
}

///|
/// Whether the route goes through a node other than the edge's ends:
/// `pathHitsNode`.
fn CrossingContext::path_hits_node(
  self : CrossingContext,
  edge : @model.Edge,
  path : Array[@model.Pt],
) -> Bool {
  let endpoints = endpoint_ids(edge)
  segments_for(path)
  .iter()
  .any(fn(segment) {
    segment_hits_nodes(segment, endpoints, self.real_node_rects, None)
  })
}

///|
/// Whether the route shares a track with another present route:
/// `pathHasSegmentConflict`.
fn path_has_segment_conflict(
  edge : Int32,
  path : Array[@model.Pt],
  base_segments : Array[Array[@model.Seg]],
) -> Bool {
  let path_segments = segments_for(path)
  for other in 0..<base_segments.length() {
    if other == edge {
      continue
    }
    if share_track(path_segments, base_segments[other]) {
      return true
    }
  }
  false
}

///|
/// The other edges the route would share a track with:
/// `sharedTrackConflictsFor`.
fn shared_track_conflicts_for(
  edge : Int32,
  candidate_segments : Array[@model.Seg],
  base_segments : Array[Array[@model.Seg]],
) -> Set[Int32] {
  let conflicts : Set[Int32] = Set([])
  for other in 0..<base_segments.length() {
    if other == edge {
      continue
    }
    if share_track(candidate_segments, base_segments[other]) {
      conflicts.add(other)
    }
  }
  conflicts
}

///|
/// The best routes the pair search may give the edge, by crossings with
/// the present routes, then bends, then length: `pairCandidatesFor`.
fn CrossingContext::pair_candidates_for(
  self : CrossingContext,
  edge : Int32,
  current : CrossingSnapshot,
  base_segments : Array[Array[@model.Seg]],
  crossing_count_by_edge : Map[Int32, Int32],
) -> Array[PairCandidate] {
  let visible_edge = self.visible[edge]
  let seen : Set[String] = Set([])
  let scored : Array[
    (Array[@model.Pt], Array[@model.Seg], Int32, Int32, Int32, Double),
  ] = []
  for raw in self.candidate_paths_for(visible_edge) {
    let candidate = @model.simplify_polyline(
      @model.dedupe_consecutive_points(raw),
    )
    if self.path_hits_node(visible_edge, candidate) {
      continue
    }
    let key = route_key(candidate)
    if seen.contains(key) || candidate.length() < 2 {
      continue
    }
    seen.add(key)
    let candidate_segments = segments_for(candidate)
    let mut replacement_affected = 0
    for other in 0..<base_segments.length() {
      if other == edge {
        continue
      }
      replacement_affected += crossing_count_between(
        candidate_segments,
        base_segments[other],
      )
    }
    let crossings = current.count -
      crossing_count_by_edge.get(edge).unwrap_or(0) +
      replacement_affected
    if crossings > current.count {
      continue
    }
    scored.push(
      (
        candidate,
        candidate_segments,
        crossings,
        @model.count_orthogonal_bends(candidate, epsilon=EPS_LOCAL),
        @model.count_orthogonal_bends(candidate),
        manhattan_route_length(candidate),
      ),
    )
  }
  @d3.js_sort(scored, fn(a, b) {
    let by_crossings = (a.2 - b.2).to_double()
    if by_crossings != 0.0 {
      return by_crossings
    }
    let by_bends = (a.3 - b.3).to_double()
    if by_bends != 0.0 {
      return by_bends
    }
    a.5 - b.5
  })
  let result = []
  for item in scored {
    if result.length() >= MAX_PAIR_CANDIDATES_PER_EDGE {
      break
    }
    let (path, segments, _, _, total_bends, length) = item
    result.push({
      path,
      segments,
      shared_track_conflicts: shared_track_conflicts_for(
        edge, segments, base_segments,
      ),
      total_bends,
      length,
    })
  }
  result
}

///|
/// The crossings with the routes of two edges replaced: `pairCrossingCount`.
fn pair_crossing_count(
  current : CrossingSnapshot,
  first_edge : Int32,
  first_candidate : PairCandidate,
  second_edge : Int32,
  second_candidate : PairCandidate,
  base_segments : Array[Array[@model.Seg]],
) -> Int32 {
  let mut current_affected = 0
  for pair in current.pairs {
    if pair.first == first_edge ||
      pair.second == first_edge ||
      pair.first == second_edge ||
      pair.second == second_edge {
      current_affected += pair.count
    }
  }
  let mut replacement_affected = crossing_count_between(
    first_candidate.segments,
    second_candidate.segments,
  )
  for other in 0..<base_segments.length() {
    if other == first_edge || other == second_edge {
      continue
    }
    let other_segments = base_segments[other]
    replacement_affected += crossing_count_between(
        first_candidate.segments,
        other_segments,
      ) +
      crossing_count_between(second_candidate.segments, other_segments)
  }
  current.count - current_affected + replacement_affected
}

///|
/// Whether the route shares a track with no other edge than `edge`:
/// `conflictsOnlyWith`.
fn conflicts_only_with(candidate : PairCandidate, edge : Int32) -> Bool {
  candidate.shared_track_conflicts.iter().all(fn(conflict) { conflict == edge })
}

///|
/// `scorePairReplacement`: none unless it removes crossings.
fn score_pair_replacement(
  context : PairScoring,
  first : Int32,
  first_candidate : PairCandidate,
  second : Int32,
  second_candidate : PairCandidate,
) -> PairScore? {
  let crossings = pair_crossing_count(
    context.current,
    first,
    first_candidate,
    second,
    second_candidate,
    context.base_segments,
  )
  if crossings >= context.current.count {
    return None
  }
  Some({
    replacements: [
      (first, first_candidate.path),
      (second, second_candidate.path),
    ],
    crossings,
    bends: context.current_bends -
    context.base_bends_by_edge[first] -
    context.base_bends_by_edge[second] +
    first_candidate.total_bends +
    second_candidate.total_bends,
    length: context.current_length -
    context.base_length_by_edge[first] -
    context.base_length_by_edge[second] +
    first_candidate.length +
    second_candidate.length,
  })
}

///|
/// `pairScoreIsBetter`.
fn pair_score_is_better(candidate : PairScore, best : PairScore) -> Bool {
  candidate.crossings < best.crossings ||
  (
    candidate.crossings == best.crossings &&
    (
      candidate.bends < best.bends ||
      (candidate.bends == best.bends && candidate.length < best.length)
    )
  )
}

///|
/// The best pair of routes for two edges that do not get in each other's
/// way, or `best`: `bestScoreForOptionPair`.
fn best_score_for_option_pair(
  context : PairScoring,
  first : Int32,
  first_candidates : Array[PairCandidate],
  second : Int32,
  second_candidates : Array[PairCandidate],
  best : PairScore,
) -> PairScore {
  let mut pair_best = best
  for first_candidate in first_candidates {
    for second_candidate in second_candidates {
      // `pairCandidatesAreCompatible`
      if !(conflicts_only_with(first_candidate, second) &&
        conflicts_only_with(second_candidate, first) &&
        !share_track(first_candidate.segments, second_candidate.segments)) {
        continue
      }
      if score_pair_replacement(
          context, first, first_candidate, second, second_candidate,
        )
        is Some(score) &&
        pair_score_is_better(score, pair_best) {
        pair_best = score
      }
    }
  }
  pair_best
}

///|
/// The best routes for two edges of a group of crossing routes:
/// `bestPairedReplacement`.
fn CrossingContext::best_paired_replacement(
  self : CrossingContext,
  current : CrossingSnapshot,
  base_segments : Array[Array[@model.Seg]],
) -> Array[(Int32, Array[@model.Pt])]? {
  let visible = self.visible
  let routes = visible.map(route_of)
  let current_bends = total_bends(visible, Map([]))
  let mut current_length = 0.0
  for route in routes {
    current_length = current_length + manhattan_route_length(route)
  }
  // `currentCrossingsByEdge`
  let crossing_count_by_edge : Map[Int32, Int32] = Map([])
  for pair in current.pairs {
    crossing_count_by_edge[pair.first] = crossing_count_by_edge
      .get(pair.first)
      .unwrap_or(0) +
      pair.count
    crossing_count_by_edge[pair.second] = crossing_count_by_edge
      .get(pair.second)
      .unwrap_or(0) +
      pair.count
  }
  let base_bends_by_edge = routes.map(fn(route) {
    @model.count_orthogonal_bends(route)
  })
  let base_length_by_edge = routes.map(manhattan_route_length)
  let options_by_edge : Map[Int32, Array[PairCandidate]] = Map([])
  let groups = pair_search_groups(visible, current)
  for group in groups {
    for edge in group {
      if options_by_edge.contains(edge) {
        continue
      }
      let candidates = self.pair_candidates_for(
        edge, current, base_segments, crossing_count_by_edge,
      )
      if candidates.length() > 0 {
        options_by_edge[edge] = candidates
      }
    }
  }
  let mut best : PairScore = {
    replacements: [],
    crossings: current.count,
    bends: current_bends,
    length: current_length,
  }
  let context : PairScoring = {
    current,
    current_bends,
    current_length,
    base_bends_by_edge,
    base_length_by_edge,
    base_segments,
  }
  for group in groups {
    let options = group.filter(fn(edge) { options_by_edge.contains(edge) })
    for i in 0..<options.length() {
      let first = options[i]
      for j in (i + 1)..<options.length() {
        let second = options[j]
        // `crossingEdgeSet`: the edges of the group that cross.
        if !current.edge_set.contains(first) &&
          !current.edge_set.contains(second) {
          continue
        }
        best = best_score_for_option_pair(
          context,
          first,
          options_by_edge[first],
          second,
          options_by_edge[second],
          best,
        )
      }
    }
  }
  if best.replacements.length() > 0 {
    Some(best.replacements)
  } else {
    None
  }
}

///|
/// Reroute edges whose routes cross: the single new route that removes
/// the most crossings (then bends) when there is one, otherwise the best
/// new routes for a pair of edges of a group of crossing routes. Up to four
/// rounds. `resolveRenderedOrthogonalCrossings`.
pub fn resolve_rendered_orthogonal_crossings(
  edges : Array[@model.Edge],
  node_by_id : Map[String, @model.Node],
) -> Unit {
  let real_nodes : Array[@model.NodeInfo] = []
  for node in node_by_id.values() {
    if node.is_group || node.is_edge_label {
      continue
    }
    if @model.node_bounds_info_for(node) is Some(info) {
      real_nodes.push(info)
    }
  }
  if real_nodes.length() == 0 {
    return
  }
  let node_info_by_id : Map[String, @model.NodeInfo] = Map([])
  for node in real_nodes {
    node_info_by_id[node.id] = node
  }
  let context : CrossingContext = {
    visible: visible_edges(edges),
    node_info_by_id,
    real_node_rects: real_nodes.map(fn(node) {
      { id: node.id, rect: node.rect, }
    }),
    outside_top: min_of(real_nodes.map(fn(node) { node.rect.top })) - ANCHOR,
    outside_bottom: max_of(real_nodes.map(fn(node) { node.rect.bottom })) +
    ANCHOR,
    outside_left: min_of(real_nodes.map(fn(node) { node.rect.left })) - ANCHOR,
    outside_right: max_of(real_nodes.map(fn(node) { node.rect.right })) + ANCHOR,
  }
  let visible = context.visible
  for _iteration in 0..<4 {
    // `currentSegmentsByEdge`
    let base_segments = visible.map(fn(edge) { segments_for(route_of(edge)) })
    let current = crossing_snapshot(base_segments)
    let current_crossings = current.count
    if current_crossings == 0 {
      return
    }
    let mut best : (Int32, Array[@model.Pt])? = None
    let mut best_crossings = current_crossings
    let mut best_bends = 2147483647
    for edge_index in current.edges {
      let edge = visible[edge_index]
      let current_edge_bends = @model.count_orthogonal_bends(
        route_of(edge),
        epsilon=EPS_LOCAL,
      )
      for candidate in context.candidate_paths_for(edge) {
        if context.path_hits_node(edge, candidate) ||
          path_has_segment_conflict(edge_index, candidate, base_segments) {
          continue
        }
        let candidate_crossings = crossing_count_with_single_replacement(
          current, edge_index, candidate, base_segments,
        )
        let candidate_bends = @model.count_orthogonal_bends(
          candidate,
          epsilon=EPS_LOCAL,
        )
        let improves_current_edge = candidate_crossings < current_crossings ||
          (
            candidate_crossings == current_crossings &&
            candidate_bends < current_edge_bends
          )
        if !improves_current_edge {
          continue
        }
        if candidate_crossings > best_crossings ||
          (
            candidate_crossings == best_crossings &&
            candidate_bends >= best_bends
          ) {
          continue
        }
        best = Some((edge_index, candidate))
        best_crossings = candidate_crossings
        best_bends = candidate_bends
      }
    }
    if best is Some((edge_index, path)) {
      visible[edge_index].points = Some(path)
      continue
    }
    guard context.best_paired_replacement(current, base_segments)
      is Some(replacements) else {
      return
    }
    for replacement in replacements {
      let (edge_index, points) = replacement
      visible[edge_index].points = Some(points)
    }
  }
}
