// Phase 2 of `routeEdgesOrthogonal`: spread the segments sharing a pipe
// over its tracks so that they neither overlap nor cross at the nodes.

///|
/// `segmentsOverlap`: whether two spans overlap by more than a point.
fn spans_overlap(
  from1 : Double,
  to1 : Double,
  from2 : Double,
  to2 : Double,
) -> Bool {
  from1 < to2 && from2 < to1
}

///|
/// Whether a track reference stands for the segment.
fn TrackRef::is_of(self : TrackRef, seg : RoutedSeg) -> Bool {
  self.edge_index == seg.edge_index && self.segment_index == seg.segment_index
}

///|
/// A track's reference to the segment.
fn track_ref(seg : RoutedSeg) -> TrackRef {
  {
    edge_index: seg.edge_index,
    segment_index: seg.segment_index,
    from: seg.from,
    to: seg.to,
  }
}

///|
/// Swap two segments between their tracks when each fits on the other's:
/// `trySwapSegmentsAcrossTracks`.
fn try_swap_segments_across_tracks(
  s1 : RoutedSeg,
  s2 : RoutedSeg,
  t1 : Track,
  t2 : Track,
) -> Bool {
  let can_s1_go_t2 = !t2.segments
    .iter()
    .any(r => !r.is_of(s2) && spans_overlap(r.from, r.to, s1.from, s1.to))
  let can_s2_go_t1 = !t1.segments
    .iter()
    .any(r => !r.is_of(s1) && spans_overlap(r.from, r.to, s2.from, s2.to))
  if can_s1_go_t2 && can_s2_go_t1 {
    s1.track_index = t2.index
    s2.track_index = t1.index
    // `t1` and `t2` may be one track: each line reads what the previous
    // one wrote, as upstream.
    let segments1 = t1.segments.filter(r => !r.is_of(s1))
    segments1.push(track_ref(s2))
    t1.segments = segments1
    let segments2 = t2.segments.filter(r => !r.is_of(s2))
    segments2.push(track_ref(s1))
    t2.segments = segments2
    return true
  }
  false
}

///|
/// Add a track to the pipe: `createNewTrack`.
fn create_new_track(pipe : Pipe) -> Int32 {
  let idx = pipe.tracks.length()
  pipe.tracks.push({ index: idx, segments: [], })
  idx
}

///|
/// `moveSegmentToTrack`.
fn move_segment_to_track(seg : RoutedSeg, track_idx : Int32) -> Unit {
  let old_track = seg.pipe.tracks[seg.track_index]
  old_track.segments = old_track.segments.filter(r => !r.is_of(seg))
  seg.track_index = track_idx
  seg.pipe.tracks[track_idx].segments.push(track_ref(seg))
}

///|
/// Move every segment of the edge in the segment's pipe to the track:
/// `moveSegmentChainToTrack`.
fn Router::move_segment_chain_to_track(
  self : Router,
  seg : RoutedSeg,
  track_idx : Int32,
) -> Unit {
  for idx in self.edge_segment_indices[seg.edge_index] {
    let s = self.all_routed_segments[idx]
    if physical_equal(s.pipe, seg.pipe) {
      move_segment_to_track(s, track_idx)
    }
  }
}

///|
/// The segments before and after the segment along its edge:
/// `getAdjacentSegmentsAlongEdge`.
fn Router::adjacent_segments_along_edge(
  self : Router,
  seg : RoutedSeg,
) -> Array[RoutedSeg] {
  let indices = self.edge_segment_indices[seg.edge_index]
  let idx_in_list = indices.search(seg.pos).unwrap_or(-1)
  let adj = []
  if idx_in_list > 0 {
    adj.push(self.all_routed_segments[indices[idx_in_list - 1]])
  }
  if idx_in_list < indices.length() - 1 {
    adj.push(self.all_routed_segments[indices[idx_in_list + 1]])
  }
  adj
}

///|
/// Whether two segments of different axes cross strictly inside both:
/// `haveAnyCrossing`.
fn have_any_crossing(seg_a : RoutedSeg, seg_b : RoutedSeg) -> Bool {
  if seg_a.orientation == seg_b.orientation {
    return false
  }
  let (h, v) = if seg_a.orientation == Horizontal {
    (seg_a, seg_b)
  } else {
    (seg_b, seg_a)
  }
  v.pipe.coord > h.from &&
  v.pipe.coord < h.to &&
  h.pipe.coord > v.from &&
  h.pipe.coord < v.to
}

///|
/// The first track of the pipe the segment fits on: `findAvailableTrack`.
fn find_available_track(pipe : Pipe, seg : RoutedSeg) -> Int32 {
  for track in pipe.tracks {
    let overlap = track.segments
      .iter()
      .any(r => !r.is_of(seg) && spans_overlap(r.from, r.to, seg.from, seg.to))
    if !overlap {
      return track.index
    }
  }
  -1
}

///|
/// Whether two segments of a pipe overlap on one track, or have
/// neighbouring segments that cross: `segmentsConflict`.
fn Router::segments_conflict(
  self : Router,
  s1 : RoutedSeg,
  s2 : RoutedSeg,
) -> Bool {
  if s1.track_index == s2.track_index {
    return spans_overlap(s1.from, s1.to, s2.from, s2.to)
  }
  let adj1 = self.adjacent_segments_along_edge(s1)
  let adj2 = self.adjacent_segments_along_edge(s2)
  adj1.iter().any(a1 => adj2.iter().any(a2 => have_any_crossing(a1, a2)))
}

///|
/// Swap the two segments' tracks, or else move the second to a track it
/// fits on (a new one if none): `resolveTrackConflict`. With `chain`, the
/// whole run of the second segment's edge in the pipe moves.
fn Router::resolve_track_conflict(
  self : Router,
  s1 : RoutedSeg,
  s2 : RoutedSeg,
  chain : Bool,
) -> Unit {
  if try_swap_segments_across_tracks(
      s1,
      s2,
      s1.pipe.tracks[s1.track_index],
      s2.pipe.tracks[s2.track_index],
    ) {
    return
  }
  let avail = find_available_track(s1.pipe, s2)
  let track = if avail != -1 { avail } else { create_new_track(s1.pipe) }
  if chain {
    self.move_segment_chain_to_track(s2, track)
  } else {
    move_segment_to_track(s2, track)
  }
}

///|
/// Resolve the conflicts between the end segments of edges meeting at one
/// node, in their order: `resolveHandleConflicts`.
fn Router::resolve_handle_conflicts(
  self : Router,
  handles : Array[RoutedSeg],
) -> Int32 {
  let mut crossings = 0
  for i in 0..<handles.length() {
    for j in (i + 1)..<handles.length() {
      let h1 = handles[i]
      let h2 = handles[j]
      if !physical_equal(h1.pipe, h2.pipe) {
        continue
      }
      if self.segments_conflict(h1, h2) {
        crossings += 1
        self.resolve_track_conflict(h1, h2, true)
      }
    }
  }
  crossings
}

///|
/// Where an edge heads: the far end of its first horizontal segment after
/// the first, relative to its first segment's pipe: `getDestInfo`.
fn Router::get_dest_info(self : Router, edge_idx : Int32) -> DestInfo {
  if self.dest_info_cache.get(edge_idx) is Some(info) {
    return info
  }
  let indices = self.edge_segment_indices[edge_idx]
  if indices.length() == 0 {
    let info = { dest: 0.0, deviation: 0.0, delta: 0.0, }
    self.dest_info_cache.set(edge_idx, info)
    return info
  }
  let first_seg = self.all_routed_segments[indices[0]]
  let base = first_seg.pipe.coord
  let mut dest = base
  for idx in 1..<indices.length() {
    let seg = self.all_routed_segments[indices[idx]]
    if seg.orientation == Horizontal {
      let candidate_a = seg.from
      let candidate_b = seg.to
      dest = if (candidate_a - base).abs() > (candidate_b - base).abs() {
        candidate_a
      } else {
        candidate_b
      }
      break
    }
  }
  let deviation = (dest - base).abs()
  let info = { dest, deviation, delta: dest - base, }
  self.dest_info_cache.set(edge_idx, info)
  info
}

///|
/// The Manhattan distance between the centres of an edge's nodes:
/// `getEdgeDistance`.
fn Router::edge_distance(self : Router, edge_idx : Int32) -> Double {
  let edge = self.edges[edge_idx]
  if edge.start == "" || edge.end == "" {
    return 0.0
  }
  guard self.node_by_id.get(edge.start) is Some(src_node) else { return 0.0 }
  guard self.node_by_id.get(edge.end) is Some(dst_node) else { return 0.0 }
  let dx = dst_node.x.unwrap_or(0.0) - src_node.x.unwrap_or(0.0)
  let dy = dst_node.y.unwrap_or(0.0) - src_node.y.unwrap_or(0.0)
  dx.abs() + dy.abs()
}

///|
/// Untangle the first segments of the edges leaving each node:
/// `fixSourceHandleCrossings`.
fn Router::fix_source_handle_crossings(self : Router) -> Int32 {
  let mut crossings = 0
  let edges_by_source : Map[String, Array[Int32]] = Map([])
  for i, e in self.edges {
    if self.edge_segment_indices[i].length() == 0 {
      continue
    }
    if e.start == "" {
      continue
    }
    match edges_by_source.get(e.start) {
      Some(grp) => grp.push(i)
      None => edges_by_source.set(e.start, [i])
    }
  }
  for _, grp in edges_by_source {
    @d3.js_sort(grp, (a, b) => {
      let info_a = self.get_dest_info(a)
      let info_b = self.get_dest_info(b)
      if (info_a.deviation - info_b.deviation).abs() > 1.0 {
        return info_a.deviation - info_b.deviation
      }
      if (info_a.dest - info_b.dest).abs() > 1.0 {
        return info_a.dest - info_b.dest
      }
      let dist_a = self.edge_distance(a)
      let dist_b = self.edge_distance(b)
      if (dist_a - dist_b).abs() > 1.0 {
        return dist_b - dist_a
      }
      let len_a = self.edge_segment_indices[a].length()
      let len_b = self.edge_segment_indices[b].length()
      if len_a != len_b {
        return (len_a - len_b).to_double()
      }
      if len_a == 1 {
        let seg_a = self.all_routed_segments[self.edge_segment_indices[a][0]]
        let seg_b = self.all_routed_segments[self.edge_segment_indices[b][0]]
        let dist_a2 = (seg_a.to - seg_a.from).abs()
        let dist_b2 = (seg_b.to - seg_b.from).abs()
        if (dist_a2 - dist_b2).abs() > 1.0 {
          return dist_a2 - dist_b2
        }
      }
      0.0
    })
    let handles = grp.map(ei => {
      self.all_routed_segments[self.edge_segment_indices[ei][0]]
    })
    crossings += self.resolve_handle_conflicts(handles)
  }
  crossings
}

///|
/// Untangle the last segments of the edges entering each node:
/// `fixTargetHandleCrossings`.
fn Router::fix_target_handle_crossings(self : Router) -> Int32 {
  let mut crossings = 0
  let edges_by_target : Map[String, Array[Int32]] = Map([])
  for i, e in self.edges {
    if self.edge_segment_indices[i].length() == 0 {
      continue
    }
    if e.end == "" {
      continue
    }
    match edges_by_target.get(e.end) {
      Some(grp) => grp.push(i)
      None => edges_by_target.set(e.end, [i])
    }
  }
  // The length of the segment before the last.
  let get_dist = (edge_idx : Int32) => {
    let indices = self.edge_segment_indices[edge_idx]
    if indices.length() < 2 {
      return 0.0
    }
    let prev = self.all_routed_segments[indices[indices.length() - 2]]
    (prev.to - prev.from).abs()
  }
  for _, grp in edges_by_target {
    @d3.js_sort(grp, (a, b) => {
      let score_a = get_dist(a)
      let score_b = get_dist(b)
      if (score_a - score_b).abs() > 0.1 {
        return score_a - score_b
      }
      (a - b).to_double()
    })
    let handles = grp.map(ei => {
      let indices = self.edge_segment_indices[ei]
      self.all_routed_segments[indices[indices.length() - 1]]
    })
    crossings += self.resolve_handle_conflicts(handles)
  }
  crossings
}

///|
/// Resolve the conflicts between all segments of each pipe:
/// `fixPipeCrossings`.
fn Router::fix_pipe_crossings(self : Router) -> Int32 {
  let mut crossings = 0
  for pipe in self.pipes {
    let pipe_segments = []
    for t in pipe.tracks {
      for r in t.segments {
        let found = self.edge_segment_indices[r.edge_index].search_by(ix => {
          self.all_routed_segments[ix].segment_index == r.segment_index
        })
        if found is Some(at) {
          pipe_segments.push(
            self.all_routed_segments[self.edge_segment_indices[r.edge_index][at]],
          )
        }
      }
    }
    @d3.js_sort(pipe_segments, (a, b) => {
      let by_edge = a.edge_index - b.edge_index
      (if by_edge != 0 { by_edge } else { a.segment_index - b.segment_index }).to_double()
    })
    for i in 0..<pipe_segments.length() {
      for j in (i + 1)..<pipe_segments.length() {
        let s1 = pipe_segments[i]
        let s2 = pipe_segments[j]
        if self.segments_conflict(s1, s2) {
          crossings += 1
          self.resolve_track_conflict(s1, s2, false)
        }
      }
    }
  }
  crossings
}

///|
/// Run the three untangling passes until nothing changes, at most ten
/// times.
fn Router::untangle(self : Router) -> Unit {
  let max_iter = 10
  for iterations = 0; iterations < max_iter; iterations = iterations + 1 {
    let mut changed = 0
    changed += self.fix_source_handle_crossings()
    changed += self.fix_target_handle_crossings()
    changed += self.fix_pipe_crossings()
    if changed == 0 {
      break
    }
  }
}
