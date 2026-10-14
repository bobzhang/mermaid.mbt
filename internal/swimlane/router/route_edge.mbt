// Phase 1 of `routeEdgesOrthogonal`: route every edge on its own, in the
// routing order, through the pipes around the obstacles.

///|
/// The order edges are routed in: cross-lane edges first, then shorter
/// edges first.
fn Router::routing_order(self : Router) -> Array[Int32] {
  let order = self.edges.mapi((idx, edge) => {
    if edge.start == "" || edge.end == "" {
      return (idx, 0, 0.0, 0.0)
    }
    let src_node = self.node_by_id.get(edge.start)
    let dst_node = self.node_by_id.get(edge.end)
    let cross_lane = match
      (self.lane_by_node_id.get(edge.start), self.lane_by_node_id.get(edge.end)) {
      (Some(src_lane), Some(dst_lane)) if src_lane != dst_lane => 1
      _ => 0
    }
    match (src_node, dst_node) {
      (Some(src), Some(dst)) => {
        let dx = (dst.x.unwrap_or(0.0) - src.x.unwrap_or(0.0)).abs()
        let dy = (dst.y.unwrap_or(0.0) - src.y.unwrap_or(0.0)).abs()
        (idx, cross_lane, dx, dy)
      }
      _ => (idx, cross_lane, 0.0, 0.0)
    }
  })
  @d3.js_sort(order, (a, b) => {
    if a.1 != b.1 {
      return (b.1 - a.1).to_double()
    }
    let a_dist = a.2 + a.3
    let b_dist = b.2 + b.3
    if (a_dist - b_dist).abs() > 1.0 {
      return a_dist - b_dist
    }
    (a.0 - b.0).to_double()
  })
  order.map(entry => entry.0)
}

///|
/// The first obstacle, other than those of the given nodes, strictly
/// containing the point: `isPointInObstacle`.
fn Router::obstacle_containing(
  self : Router,
  pt : @model.Pt,
  exclude_node_ids : Array[String],
) -> Obstacle? {
  for obs in self.obstacles {
    if exclude_node_ids.contains(obs.node_id) {
      continue
    }
    if pt.x > obs.min_x &&
      pt.x < obs.max_x &&
      pt.y > obs.min_y &&
      pt.y < obs.max_y {
      return Some(obs)
    }
  }
  None
}

///|
/// Where an anchor caught in an obstacle moves to, past the obstacle's
/// corner, and whether the port leaves towards positive coordinates:
/// `obstacleDetour`.
fn obstacle_detour(
  port : @model.Pt,
  node : @model.Node,
  opposite : @model.Node,
  obs : Obstacle,
  port_is_vertical : Bool,
) -> (Double, Double, Bool) {
  if port_is_vertical {
    let leaves_positive_side = port.y > node.y.unwrap_or(0.0)
    let go_right = opposite.x.unwrap_or(0.0) >= port.x
    return (
      if go_right {
        obs.max_x + HORIZONTAL_PIPE_MARGIN
      } else {
        obs.min_x - HORIZONTAL_PIPE_MARGIN
      },
      if leaves_positive_side {
        obs.max_y + VERTICAL_PIPE_MARGIN
      } else {
        obs.min_y - VERTICAL_PIPE_MARGIN
      },
      leaves_positive_side,
    )
  }
  let leaves_positive_side = port.x > node.x.unwrap_or(0.0)
  let go_down = opposite.y.unwrap_or(0.0) >= port.y
  (
    if leaves_positive_side {
      obs.max_x + HORIZONTAL_PIPE_MARGIN
    } else {
      obs.min_x - HORIZONTAL_PIPE_MARGIN
    },
    if go_down {
      obs.max_y + VERTICAL_PIPE_MARGIN
    } else {
      obs.min_y - VERTICAL_PIPE_MARGIN
    },
    leaves_positive_side,
  )
}

///|
/// Move an anchor `ANCHOR_OFFSET` off its port, away from the node.
fn offset_anchor(
  anchor : @model.Pt,
  port : @model.Pt,
  node : @model.Node,
  port_is_vertical : Bool,
) -> Unit {
  if port_is_vertical {
    let is_bottom = port.y > node.y.unwrap_or(0.0)
    anchor.y = if is_bottom {
      port.y + ANCHOR_OFFSET
    } else {
      port.y - ANCHOR_OFFSET
    }
  } else {
    let is_right = port.x > node.x.unwrap_or(0.0)
    anchor.x = if is_right {
      port.x + ANCHOR_OFFSET
    } else {
      port.x - ANCHOR_OFFSET
    }
  }
}

///|
/// Route edge `i`: an iteration of the routing loop. Edges drawn straight
/// get their points here; the others get their segments registered in
/// the pipes, to be spread over tracks and turned into points later.
fn Router::route_edge(self : Router, i : Int32) -> Unit {
  let e = self.edges[i]
  if e.start == "" || e.end == "" {
    return
  }
  if e.points is Some(points) && points.length() > 0 {
    return
  }
  if e.start == e.end {
    return
  }
  guard self.node_by_id.get(e.start) is Some(src) else { return }
  guard self.node_by_id.get(e.end) is Some(dst) else { return }
  let (p_src_port, p_dst_port, src_port_side, dst_port_side) = self.ports_for_edge(
    i, src, dst,
  )
  let p_src_anchor = p_src_port.copy()
  let p_dst_anchor = p_dst_port.copy()
  let src_port_is_vertical = side_is_vertical(src_port_side)
  let dst_port_is_vertical = side_is_vertical(dst_port_side)
  offset_anchor(p_src_anchor, p_src_port, src, src_port_is_vertical)
  offset_anchor(p_dst_anchor, p_dst_port, dst, dst_port_is_vertical)
  // An anchor inside another node's obstacle steps around it.
  let endpoint_ids = [e.start, e.end]
  let mut src_handle_waypoints : Array[@model.Pt] = []
  if self.obstacle_containing(p_src_anchor, endpoint_ids) is Some(obs) {
    if src_port_is_vertical {
      let (dx, dy, leaves_positive_side) = obstacle_detour(
        p_src_port, src, dst, obs, true,
      )
      p_src_anchor.x = dx
      p_src_anchor.y = dy
      let gap_y = if leaves_positive_side {
        @model.js_min(obs.min_y - 2.0, p_src_port.y + ANCHOR_OFFSET)
      } else {
        @model.js_max(obs.max_y + 2.0, p_src_port.y - ANCHOR_OFFSET)
      }
      src_handle_waypoints = [
        @model.pt(p_src_port.x, gap_y),
        @model.pt(dx, gap_y),
        @model.pt(dx, dy),
      ]
    } else {
      let (dx, dy, leaves_positive_side) = obstacle_detour(
        p_src_port, src, dst, obs, false,
      )
      let gap_x = if leaves_positive_side {
        @model.js_min(obs.min_x - 2.0, p_src_port.x + ANCHOR_OFFSET)
      } else {
        @model.js_max(obs.max_x + 2.0, p_src_port.x - ANCHOR_OFFSET)
      }
      p_src_anchor.x = dx
      p_src_anchor.y = dy
      src_handle_waypoints = [
        @model.pt(gap_x, p_src_port.y),
        @model.pt(gap_x, dy),
        @model.pt(dx, dy),
      ]
    }
  }
  let mut dst_handle_waypoints : Array[@model.Pt] = []
  if self.obstacle_containing(p_dst_anchor, endpoint_ids) is Some(obs) {
    if dst_port_is_vertical {
      let (dx, dy, _) = obstacle_detour(p_dst_port, dst, src, obs, true)
      p_dst_anchor.x = dx
      p_dst_anchor.y = dy
      dst_handle_waypoints = [@model.pt(dx, dy), @model.pt(p_dst_port.x, dy)]
    } else {
      let (dx, dy, _) = obstacle_detour(p_dst_port, dst, src, obs, false)
      p_dst_anchor.x = dx
      p_dst_anchor.y = dy
      dst_handle_waypoints = [@model.pt(dx, dy), @model.pt(dx, p_dst_port.y)]
    }
  }
  if src_handle_waypoints.length() == 0 &&
    dst_handle_waypoints.length() == 0 &&
    self.try_fast_path(
      i, e, p_src_port, p_dst_port, p_src_anchor, p_dst_anchor, src_port_side, dst_port_side,
    ) {
    return
  }
  let src_pipe = self.get_or_add_pipe(
    Vertical,
    p_src_anchor.x,
    p_src_anchor.y,
    p_src_anchor.y,
  )
  p_src_anchor.x = src_pipe.coord
  let dst_pipe = self.get_or_add_pipe(
    Vertical,
    p_dst_anchor.x,
    p_dst_anchor.y,
    p_dst_anchor.y,
  )
  p_dst_anchor.x = dst_pipe.coord
  let found_path = self.find_path(i, e, p_src_anchor, p_dst_anchor)
  let found_path = if found_path.length() > 4 {
    self.simplify_detour(e, found_path)
  } else {
    found_path
  }
  dst_handle_waypoints.rev_in_place()
  let full_points = [p_src_port]
  full_points.append(src_handle_waypoints)
  full_points.append(found_path)
  full_points.append(dst_handle_waypoints)
  full_points.push(p_dst_port)
  // A last point doubling back over the one before it is dropped.
  if full_points.length() >= 3 {
    let n = full_points.length()
    let c = full_points[n - 1]
    let b = full_points[n - 2]
    let a = full_points[n - 3]
    let is_horiz = (a.y - b.y).abs() < EPS7 && (b.y - c.y).abs() < EPS7
    let is_vert = (a.x - b.x).abs() < EPS7 && (b.x - c.x).abs() < EPS7
    if is_horiz {
      let sign_ab = js_sign(b.x - a.x)
      let sign_ac = js_sign(c.x - a.x)
      if sign_ab != 0.0 &&
        sign_ab == sign_ac &&
        (b.x - a.x).abs() > (c.x - a.x).abs() {
        full_points.remove(n - 2) |> ignore
      }
    } else if is_vert {
      let sign_ab = js_sign(b.y - a.y)
      let sign_ac = js_sign(c.y - a.y)
      if sign_ab != 0.0 &&
        sign_ab == sign_ac &&
        (b.y - a.y).abs() > (c.y - a.y).abs() {
        full_points.remove(n - 2) |> ignore
      }
    }
  }
  // Drop the middle points of straight runs, keeping the second point and
  // the turning points of runs that double back.
  let simplified = [full_points[0]]
  for k in 1..<(full_points.length() - 1) {
    if k == 1 {
      simplified.push(full_points[k])
      continue
    }
    let prev = simplified[simplified.length() - 1]
    let curr = full_points[k]
    let next = full_points[k + 1]
    if (prev.y - curr.y).abs() < EPS7 && (curr.y - next.y).abs() < EPS7 {
      let dir1 = curr.x > prev.x
      let dir2 = next.x > curr.x
      if dir1 != dir2 {
        simplified.push(curr)
      }
      continue
    }
    if (prev.x - curr.x).abs() < EPS7 && (curr.x - next.x).abs() < EPS7 {
      let dir1 = curr.y > prev.y
      let dir2 = next.y > curr.y
      if dir1 != dir2 {
        simplified.push(curr)
      }
      continue
    }
    simplified.push(curr)
  }
  simplified.push(full_points[full_points.length() - 1])
  // Register the segments in their pipes, all on track 0 for now.
  for k in 0..<(simplified.length() - 1) {
    let p1 = simplified[k]
    let p2 = simplified[k + 1]
    let orientation : Orient = if (p1.x - p2.x).abs() < EPS7 {
      Vertical
    } else {
      Horizontal
    }
    let (coord, from, to) = match orientation {
      Vertical => (p1.x, @model.js_min(p1.y, p2.y), @model.js_max(p1.y, p2.y))
      Horizontal => (p1.y, @model.js_min(p1.x, p2.x), @model.js_max(p1.x, p2.x))
    }
    let pipe = self.get_or_add_pipe(orientation, coord, from, to)
    let pos = self.all_routed_segments.length()
    self.all_routed_segments.push({
      edge_index: i,
      segment_index: k,
      orientation,
      pipe,
      track_index: 0,
      from,
      to,
      pos,
    })
    self.edge_segment_indices[i].push(pos)
    if pipe.tracks.length() == 0 {
      pipe.tracks.push({ index: 0, segments: [], })
    }
    pipe.tracks[0].segments.push({ edge_index: i, segment_index: k, from, to, })
  }
}

///|
/// Draw an edge whose anchors line up as a straight line when no obstacle
/// is in the way and its faces allow it: the fast path of the routing loop.
/// The edge then keeps its pipe coord and only its segment is recorded, for
/// the crossing penalty of later edges.
fn Router::try_fast_path(
  self : Router,
  i : Int32,
  e : RouteEdge,
  p_src_port : @model.Pt,
  p_dst_port : @model.Pt,
  p_src_anchor : @model.Pt,
  p_dst_anchor : @model.Pt,
  src_port_side : @model.Side,
  dst_port_side : @model.Side,
) -> Bool {
  let hp_margin = HORIZONTAL_PIPE_MARGIN
  let anchors_same_x = (p_src_anchor.x - p_dst_anchor.x).abs() < hp_margin
  let anchors_same_y = (p_src_anchor.y - p_dst_anchor.y).abs() < hp_margin
  let has_port_offset = self.port_offsets.get("\{i}:src") is Some(_) ||
    self.port_offsets.get("\{i}:dst") is Some(_)
  let src_face_total = self.face_count(e.start, src_port_side, "src") +
    self.face_count(e.start, src_port_side, "dst")
  let dst_face_total = self.face_count(e.end, dst_port_side, "src") +
    self.face_count(e.end, dst_port_side, "dst")
  let face_contested = src_face_total > 1 || dst_face_total > 1
  let src_incident_total = self.incident_edge_totals.get(e.start).unwrap_or(0)
  let dst_incident_total = self.incident_edge_totals.get(e.end).unwrap_or(0)
  let contested_face_has_label = (
      src_face_total > 1 && self.face_has_label_node(e.start, src_port_side)
    ) ||
    (dst_face_total > 1 && self.face_has_label_node(e.end, dst_port_side))
  let src_contest_allows_centered_straight = src_face_total <= 1 ||
    src_incident_total <= 2
  let dst_contest_allows_centered_straight = dst_face_total <= 1 ||
    dst_incident_total <= 2
  let can_preserve_simple_contested_straight = face_contested &&
    !contested_face_has_label &&
    src_contest_allows_centered_straight &&
    dst_contest_allows_centered_straight
  if !((anchors_same_x || anchors_same_y) &&
    !has_port_offset &&
    (!face_contested || can_preserve_simple_contested_straight)) {
    return false
  }
  if self.is_segment_blocked(p_src_port, p_dst_port, e.start, e.end) {
    return false
  }
  e.points = Some([
    p_src_port.copy(),
    p_src_anchor.copy(),
    p_dst_anchor.copy(),
    p_dst_port.copy(),
  ])
  self.straight_intra_lane_edges.add(i)
  let orientation : Orient = if anchors_same_y { Horizontal } else { Vertical }
  let (coord, from, to) = if anchors_same_y {
    (
      p_src_port.y,
      @model.js_min(p_src_port.x, p_dst_port.x),
      @model.js_max(p_src_port.x, p_dst_port.x),
    )
  } else {
    (
      p_src_port.x,
      @model.js_min(p_src_port.y, p_dst_port.y),
      @model.js_max(p_src_port.y, p_dst_port.y),
    )
  }
  // A pipe of its own, outside `pipes`; upstream names it
  // `fast-path-${orientation}-${coord.toFixed(0)}-${i}`.
  let pipe = { orientation, coord, span_min: from, span_max: to, tracks: [], }
  let pos = self.all_routed_segments.length()
  self.all_routed_segments.push({
    edge_index: i,
    segment_index: 0,
    orientation,
    pipe,
    track_index: 0,
    from,
    to,
    pos,
  })
  true
}
