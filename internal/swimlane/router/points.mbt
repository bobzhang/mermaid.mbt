// Phase 3 of `routeEdgesOrthogonal`: give every track its coordinate and
// turn the segments into points.

///|
/// The coordinate of every segment, keyed by edge and segment index: the
/// tracks of each run of overlapping segments in a pipe spread to the side
/// their edges head to, the most neutral track staying on the pipe.
fn Router::segment_coords(self : Router) -> Map[(Int32, Int32), Double] {
  let segment_coords : Map[(Int32, Int32), Double] = Map([])
  for pipe in self.pipes {
    let segments : Array[(Int32, Int32, Int32, Double, Double)] = []
    for t in pipe.tracks {
      for s in t.segments {
        segments.push((s.edge_index, s.segment_index, t.index, s.from, s.to))
      }
    }
    @d3.js_sort(segments, (a, b) => a.3 - b.3)
    // Runs of overlapping segments.
    let clusters : Array[Array[(Int32, Int32, Int32, Double, Double)]] = []
    if segments.length() > 0 {
      let mut current_cluster = [segments[0]]
      let mut cluster_end = segments[0].4
      for k in 1..<segments.length() {
        let s = segments[k]
        if s.3 < cluster_end {
          current_cluster.push(s)
          cluster_end = @model.js_max(cluster_end, s.4)
        } else {
          clusters.push(current_cluster)
          current_cluster = [s]
          cluster_end = s.4
        }
      }
      clusters.push(current_cluster)
    }
    for cluster in clusters {
      let used_tracks : Set[Int32] = Set([])
      for s in cluster {
        used_tracks.add(s.2)
      }
      let track_scores : Map[Int32, Double] = Map([])
      for s in cluster {
        let info = self.get_dest_info(s.0)
        track_scores.set(s.2, track_scores.get(s.2).unwrap_or(0.0) + info.delta)
      }
      let score = t => track_scores.get(t).unwrap_or(0.0)
      let used = used_tracks.iter().collect()
      let left_tracks = used.filter(t => score(t) < -1.0)
      let right_tracks = used.filter(t => score(t) > 1.0)
      let neutral_tracks = used.filter(t => score(t).abs() <= 1.0)
      @d3.js_sort(left_tracks, (a, b) => score(b) - score(a))
      @d3.js_sort(right_tracks, (a, b) => score(a) - score(b))
      let assign_coord = (track_index : Int32, coord : Double) => {
        for s in cluster {
          if s.2 == track_index {
            let effective_coord = if self.straight_intra_lane_edges.contains(
                s.0,
              ) {
              pipe.coord
            } else {
              coord
            }
            segment_coords.set((s.0, s.1), effective_coord)
          }
        }
      }
      let mut left_count = 0
      for track_index in left_tracks {
        left_count += 1
        assign_coord(
          track_index,
          pipe.coord - left_count.to_double() * TRACK_SPACING,
        )
      }
      if neutral_tracks.length() == 0 && used_tracks.length() > 0 {
        let by_abs_score = used_tracks.iter().collect()
        @d3.js_sort(by_abs_score, (a, b) => score(a).abs() - score(b).abs())
        let best_track = by_abs_score[0]
        if left_tracks.search(best_track) is Some(left_idx) {
          left_tracks.remove(left_idx) |> ignore
        }
        if right_tracks.search(best_track) is Some(right_idx) {
          right_tracks.remove(right_idx) |> ignore
        }
        neutral_tracks.push(best_track)
      }
      let mut neutral_assigned = 0
      for track_index in neutral_tracks {
        if neutral_assigned == 0 {
          assign_coord(track_index, pipe.coord)
        } else {
          let dir = if neutral_assigned % 2 == 1 { 1.0 } else { -1.0 }
          let magnitude = (neutral_assigned.to_double() / 2.0).ceil()
          assign_coord(
            track_index,
            pipe.coord + dir * magnitude * TRACK_SPACING * 0.5,
          )
        }
        neutral_assigned += 1
      }
      let mut right_count = 0
      for track_index in right_tracks {
        right_count += 1
        assign_coord(
          track_index,
          pipe.coord + right_count.to_double() * TRACK_SPACING,
        )
      }
    }
  }
  segment_coords
}

///|
/// The end of `line` it shares with `next_line`: `sharedLineEndpointCoord`.
fn shared_line_endpoint_coord(line : Line, next_line : Line) -> Double {
  if (line.to - next_line.from).abs() < EPS7 ||
    (line.to - next_line.to).abs() < EPS7 {
    line.to
  } else {
    line.from
  }
}

///|
/// The point of the line at `along`: `pointOnLine`.
fn point_on_line(line : Line, along : Double) -> @model.Pt {
  match line.orient {
    Vertical => @model.pt(line.coord, along)
    Horizontal => @model.pt(along, line.coord)
  }
}

///|
/// The points of a routed edge from its segments on their tracks, between
/// fresh ports.
fn Router::edge_points(
  self : Router,
  i : Int32,
  e : RouteEdge,
  segment_coords : Map[(Int32, Int32), Double],
) -> Array[@model.Pt] {
  let indices = self.edge_segment_indices[i]
  let src = self.node_by_id[e.start]
  let dst = self.node_by_id[e.end]
  let (p_src_port, p_dst_port, _, _) = self.ports_for_edge(i, src, dst)
  let lines = indices.map(idx => {
    let s = self.all_routed_segments[idx]
    let coord = segment_coords
      .get((s.edge_index, s.segment_index))
      .unwrap_or(s.pipe.coord)
    { orient: s.orientation, coord, from: s.from, to: s.to, }
  })
  let new_points = [p_src_port]
  for k in 0..<lines.length() {
    let line = lines[k]
    let prev_pt = new_points[new_points.length() - 1]
    let (prev_along, prev_track_coord) = match line.orient {
      Vertical => (prev_pt.y, prev_pt.x)
      Horizontal => (prev_pt.x, prev_pt.y)
    }
    let has_next_line = k < lines.length() - 1
    if (prev_track_coord - line.coord).abs() > EPS7 {
      new_points.push(point_on_line(line, prev_along))
    }
    if has_next_line && lines[k + 1].orient == line.orient {
      let next_line = lines[k + 1]
      if (line.coord - next_line.coord).abs() > EPS7 {
        // Jog between two parallel tracks.
        let junction = match line.orient {
          Vertical => (prev_along + next_line.from) / 2.0
          Horizontal => shared_line_endpoint_coord(line, next_line)
        }
        new_points.push(point_on_line(line, junction))
        new_points.push(point_on_line(next_line, junction))
      } else if k == 0 || k == lines.length() - 2 {
        new_points.push(
          point_on_line(line, shared_line_endpoint_coord(line, next_line)),
        )
      }
    } else if has_next_line {
      new_points.push(point_on_line(line, lines[k + 1].coord))
    } else {
      let end_along = if (line.from - prev_along).abs() <
        (line.to - prev_along).abs() {
        line.to
      } else {
        line.from
      }
      new_points.push(point_on_line(line, end_along))
    }
  }
  let last = new_points[new_points.length() - 1]
  if (last.x - p_dst_port.x).abs() > EPS7 ||
    (last.y - p_dst_port.y).abs() > EPS7 {
    new_points.push(p_dst_port)
  }
  let filtered = []
  if new_points.length() > 0 {
    filtered.push(new_points[0])
  }
  for k in 1..<new_points.length() {
    let p = new_points[k]
    let prev = filtered[filtered.length() - 1]
    if (p.x - prev.x).abs() > EPS7 || (p.y - prev.y).abs() > EPS7 {
      filtered.push(p)
    }
  }
  filtered
}

///|
/// A point inside the node's box moved to the nearest side of the box:
/// `nodeBoundaryClamp`. Other points are returned as they are.
fn node_boundary_clamp(p : @model.Pt, node : @model.Node) -> @model.Pt {
  let cx = node.x.unwrap_or(0.0)
  let cy = node.y.unwrap_or(0.0)
  let w = node.width.unwrap_or(0.0)
  let h = node.height.unwrap_or(0.0)
  if w <= 0.0 || h <= 0.0 {
    return p
  }
  let left = cx - w / 2.0
  let right = cx + w / 2.0
  let top = cy - h / 2.0
  let bottom = cy + h / 2.0
  if p.x < left || p.x > right || p.y < top || p.y > bottom {
    return p
  }
  let d_left = p.x - left
  let d_right = right - p.x
  let d_top = p.y - top
  let d_bottom = bottom - p.y
  let min_d = @model.js_min(
    @model.js_min(@model.js_min(d_left, d_right), d_top),
    d_bottom,
  )
  if min_d == d_left {
    return @model.pt(left, p.y)
  }
  if min_d == d_right {
    return @model.pt(right, p.y)
  }
  if min_d == d_top {
    return @model.pt(p.x, top)
  }
  @model.pt(p.x, bottom)
}
