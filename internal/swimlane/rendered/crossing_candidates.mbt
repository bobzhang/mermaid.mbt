// The other routes `resolveRenderedOrthogonalCrossings` tries for an edge:
// between every side of one end and every side of the other, directly and
// round the outside of all nodes, and routes that keep the first segment
// and go round the outside to any side of the target.

///|
/// How far beyond the nodes the outside tracks run, and the space between
/// them: `ANCHOR`.
const ANCHOR : Double = 20.0

///|
/// How many tracks beyond the first one each side has:
/// `EXTRA_CHANNEL_COUNT`.
const EXTRA_CHANNEL_COUNT : Int32 = 2

///|
/// The sides in the order the candidates are made: `sides`.
let crossing_sides : Array[@model.Side] = [Top, Bottom, Left, Right]

///|
/// What the crossing resolution works with.
priv struct CrossingContext {
  /// The drawn edges; edges are referred to by their position here.
  visible : Array[@model.Edge]
  node_info_by_id : Map[String, @model.NodeInfo]
  real_node_rects : Array[@model.RectEntry]
  /// `outsideTracks`: `ANCHOR` beyond the outermost node on each side.
  outside_top : Double
  outside_bottom : Double
  outside_left : Double
  outside_right : Double
}

///|
/// `outsideTracks[side]`.
fn CrossingContext::outside_track(
  self : CrossingContext,
  side : @model.Side,
) -> Double {
  match side {
    Top => self.outside_top
    Bottom => self.outside_bottom
    Left => self.outside_left
    Right => self.outside_right
  }
}

///|
/// -1 for the sides towards smaller coordinates.
fn outward_sign(side : @model.Side) -> Double {
  if side is (Left | Top) {
    -1.0
  } else {
    1.0
  }
}

///|
/// The outside track of a side and the ones beyond it:
/// `outwardTracksForSide`.
fn CrossingContext::outward_tracks_for_side(
  self : CrossingContext,
  side : @model.Side,
) -> Array[Double] {
  let outward = outward_sign(side)
  let tracks = []
  for channel in 0..<=EXTRA_CHANNEL_COUNT {
    tracks.push(
      self.outside_track(side) + outward * ANCHOR * channel.to_double(),
    )
  }
  tracks
}

///|
/// The tracks of both sides of an axis: `[...outwardTracksForSide(a),
/// ...outwardTracksForSide(b)]`.
fn CrossingContext::outward_tracks_for_sides(
  self : CrossingContext,
  a : @model.Side,
  b : @model.Side,
) -> Array[Double] {
  [..self.outward_tracks_for_side(a), ..self.outward_tracks_for_side(b)]
}

///|
/// Add the route when it stays orthogonal once simplified:
/// `pushOrthogonalCandidate`.
fn push_orthogonal_candidate(
  candidates : Array[Array[@model.Pt]],
  points : Array[@model.Pt],
) -> Unit {
  let candidate = @model.simplify_polyline(
    @model.dedupe_consecutive_points(points),
  )
  if segments_for(candidate).length() == candidate.length() - 1 {
    candidates.push(candidate)
  }
}

///|
/// `localTrackForSameSide`.
fn local_track_for_same_side(
  src : @model.Pt,
  side : @model.Side,
  dst : @model.Pt,
) -> Double {
  match side {
    Left => @model.js_min(src.x, dst.x) - ANCHOR
    Right => @model.js_max(src.x, dst.x) + ANCHOR
    Top => @model.js_min(src.y, dst.y) - ANCHOR
    Bottom => @model.js_max(src.y, dst.y) + ANCHOR
  }
}

///|
/// `addSameSideCandidates`.
fn CrossingContext::add_same_side_candidates(
  self : CrossingContext,
  candidates : Array[Array[@model.Pt]],
  src : @model.Pt,
  src_side : @model.Side,
  dst : @model.Pt,
) -> Unit {
  let outward = outward_sign(src_side)
  let track_seeds = [
    local_track_for_same_side(src, src_side, dst),
    self.outside_track(src_side),
  ]
  for seed in track_seeds {
    for channel in 0..<=EXTRA_CHANNEL_COUNT {
      push_orthogonal_candidate(
        candidates,
        @model.build_same_side_track_path(
          src,
          src_side,
          dst,
          seed + outward * ANCHOR * channel.to_double(),
        ),
      )
    }
  }
}

///|
/// `addHorizontalToVerticalCandidates`.
fn CrossingContext::add_horizontal_to_vertical_candidates(
  self : CrossingContext,
  candidates : Array[Array[@model.Pt]],
  src : @model.Pt,
  src_side : @model.Side,
  dst : @model.Pt,
  dst_side : @model.Side,
) -> Unit {
  for x_track in self.outward_tracks_for_side(src_side) {
    for y_track in self.outward_tracks_for_side(dst_side) {
      push_orthogonal_candidate(candidates, [
        src,
        @model.pt(x_track, src.y),
        @model.pt(x_track, y_track),
        @model.pt(dst.x, y_track),
        dst,
      ])
    }
  }
}

///|
/// `addVerticalToHorizontalCandidates`.
fn CrossingContext::add_vertical_to_horizontal_candidates(
  self : CrossingContext,
  candidates : Array[Array[@model.Pt]],
  src : @model.Pt,
  src_side : @model.Side,
  dst : @model.Pt,
  dst_side : @model.Side,
) -> Unit {
  for y_track in self.outward_tracks_for_side(src_side) {
    for x_track in self.outward_tracks_for_side(dst_side) {
      push_orthogonal_candidate(candidates, [
        src,
        @model.pt(src.x, y_track),
        @model.pt(x_track, y_track),
        @model.pt(x_track, dst.y),
        dst,
      ])
    }
  }
}

///|
/// `addHorizontalPairCandidates`.
fn CrossingContext::add_horizontal_pair_candidates(
  self : CrossingContext,
  candidates : Array[Array[@model.Pt]],
  src : @model.Pt,
  src_side : @model.Side,
  dst : @model.Pt,
  dst_side : @model.Side,
) -> Unit {
  let y_tracks = self.outward_tracks_for_sides(Top, Bottom)
  for src_track in self.outward_tracks_for_side(src_side) {
    for dst_track in self.outward_tracks_for_side(dst_side) {
      for y_track in y_tracks {
        push_orthogonal_candidate(candidates, [
          src,
          @model.pt(src_track, src.y),
          @model.pt(src_track, y_track),
          @model.pt(dst_track, y_track),
          @model.pt(dst_track, dst.y),
          dst,
        ])
      }
    }
  }
}

///|
/// `addVerticalPairCandidates`.
fn CrossingContext::add_vertical_pair_candidates(
  self : CrossingContext,
  candidates : Array[Array[@model.Pt]],
  src : @model.Pt,
  src_side : @model.Side,
  dst : @model.Pt,
  dst_side : @model.Side,
) -> Unit {
  let x_tracks = self.outward_tracks_for_sides(Left, Right)
  for src_track in self.outward_tracks_for_side(src_side) {
    for dst_track in self.outward_tracks_for_side(dst_side) {
      for x_track in x_tracks {
        push_orthogonal_candidate(candidates, [
          src,
          @model.pt(src.x, src_track),
          @model.pt(x_track, src_track),
          @model.pt(x_track, dst_track),
          @model.pt(dst.x, dst_track),
          dst,
        ])
      }
    }
  }
}

///|
/// The candidates deduplicated, repeated routes and routes of fewer than
/// two points dropped: `dedupeCandidatePaths`.
fn dedupe_candidate_paths(
  candidates : Array[Array[@model.Pt]],
) -> Array[Array[@model.Pt]] {
  let seen : Set[String] = Set([])
  let result = []
  for raw in candidates {
    let candidate = @model.dedupe_consecutive_points(raw)
    let key = route_key(candidate)
    if seen.contains(key) || candidate.length() < 2 {
      continue
    }
    seen.add(key)
    result.push(candidate)
  }
  result
}

///|
/// The routes from the port on `src_side` to the port on `dst_side`:
/// `buildCandidatesForSides`.
fn CrossingContext::build_candidates_for_sides(
  self : CrossingContext,
  src : @model.Pt,
  src_side : @model.Side,
  dst : @model.Pt,
  dst_side : @model.Side,
) -> Array[Array[@model.Pt]] {
  let candidates = []
  if @model.build_orthogonal_port_path(
      src,
      src_side,
      dst,
      dst_side,
      ANCHOR,
      epsilon=EPS_LOCAL,
    )
    is Some(base) {
    push_orthogonal_candidate(candidates, base)
  }
  if src_side == dst_side {
    self.add_same_side_candidates(candidates, src, src_side, dst)
  }
  let src_horizontal = src_side.is_horizontal()
  let dst_horizontal = dst_side.is_horizontal()
  if src_horizontal && !dst_horizontal {
    self.add_horizontal_to_vertical_candidates(
      candidates, src, src_side, dst, dst_side,
    )
  } else if !src_horizontal && dst_horizontal {
    self.add_vertical_to_horizontal_candidates(
      candidates, src, src_side, dst, dst_side,
    )
  } else if src_horizontal {
    self.add_horizontal_pair_candidates(
      candidates, src, src_side, dst, dst_side,
    )
  } else {
    self.add_vertical_pair_candidates(candidates, src, src_side, dst, dst_side)
  }
  dedupe_candidate_paths(candidates)
}

///|
/// Routes that leave vertically as the route does, then go round a side
/// track to any side of the target: `addVerticalDepartureOuterTrackCandidates`.
fn CrossingContext::add_vertical_departure_outer_track_candidates(
  self : CrossingContext,
  candidates : Array[Array[@model.Pt]],
  first : @model.Pt,
  departure : @model.Pt,
  dst_node : @model.NodeInfo,
) -> Unit {
  let external_x_tracks = self.outward_tracks_for_sides(Left, Right)
  let external_y_tracks = self.outward_tracks_for_sides(Top, Bottom)
  for side in crossing_sides {
    let dst = @model.port_for_rect_side(dst_node, side)
    let target_y_tracks = if side is (Top | Bottom) {
      self.outward_tracks_for_side(side)
    } else {
      external_y_tracks
    }
    for track in external_x_tracks {
      push_orthogonal_candidate(candidates, [
        first,
        departure,
        @model.pt(track, departure.y),
        @model.pt(track, dst.y),
        dst,
      ])
      for target_track in target_y_tracks {
        push_orthogonal_candidate(candidates, [
          first,
          departure,
          @model.pt(track, departure.y),
          @model.pt(track, target_track),
          @model.pt(dst.x, target_track),
          dst,
        ])
      }
    }
  }
}

///|
/// Routes that leave horizontally as the route does, then go round a top
/// or bottom track to any side of the target:
/// `addHorizontalDepartureOuterTrackCandidates`.
fn CrossingContext::add_horizontal_departure_outer_track_candidates(
  self : CrossingContext,
  candidates : Array[Array[@model.Pt]],
  first : @model.Pt,
  departure : @model.Pt,
  dst_node : @model.NodeInfo,
) -> Unit {
  let external_x_tracks = self.outward_tracks_for_sides(Left, Right)
  let external_y_tracks = self.outward_tracks_for_sides(Top, Bottom)
  for side in crossing_sides {
    let dst = @model.port_for_rect_side(dst_node, side)
    let target_x_tracks = if side is (Left | Right) {
      self.outward_tracks_for_side(side)
    } else {
      external_x_tracks
    }
    for track in external_y_tracks {
      push_orthogonal_candidate(candidates, [
        first,
        departure,
        @model.pt(departure.x, track),
        @model.pt(dst.x, track),
        dst,
      ])
      for target_track in target_x_tracks {
        push_orthogonal_candidate(candidates, [
          first,
          departure,
          @model.pt(departure.x, track),
          @model.pt(target_track, track),
          @model.pt(target_track, dst.y),
          dst,
        ])
      }
    }
  }
}

///|
/// `terminalPreservingOuterTrackCandidates`.
fn CrossingContext::terminal_preserving_outer_track_candidates(
  self : CrossingContext,
  edge : @model.Edge,
) -> Array[Array[@model.Pt]] {
  let dst_node = if edge.end == "" {
    None
  } else {
    self.node_info_by_id.get(edge.end)
  }
  guard edge.start != "" && dst_node is Some(dst_node) else { return [] }
  let points = route_of(edge)
  if points.length() < 4 {
    return []
  }
  let first = points[0]
  let departure = points[1]
  let candidates = []
  if @model.is_vertical_segment(first, departure, epsilon=EPS_LOCAL) {
    self.add_vertical_departure_outer_track_candidates(
      candidates, first, departure, dst_node,
    )
  } else if @model.is_horizontal_segment(first, departure, epsilon=EPS_LOCAL) {
    self.add_horizontal_departure_outer_track_candidates(
      candidates, first, departure, dst_node,
    )
  }
  candidates
}

///|
/// Every route the pass tries for the edge: `candidatePathsFor`.
fn CrossingContext::candidate_paths_for(
  self : CrossingContext,
  edge : @model.Edge,
) -> Array[Array[@model.Pt]] {
  guard edge.start != "" &&
    self.node_info_by_id.get(edge.start) is Some(src_node) &&
    edge.end != "" &&
    self.node_info_by_id.get(edge.end) is Some(dst_node) else {
    return []
  }
  let candidates = []
  for src_side in crossing_sides {
    let src_port = @model.port_for_rect_side(src_node, src_side)
    for dst_side in crossing_sides {
      candidates.append(
        self.build_candidates_for_sides(
          src_port,
          src_side,
          @model.port_for_rect_side(dst_node, dst_side),
          dst_side,
        ),
      )
    }
  }
  candidates.append(self.terminal_preserving_outer_track_candidates(edge))
  candidates
}
