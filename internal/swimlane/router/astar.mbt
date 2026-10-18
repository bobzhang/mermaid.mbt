// The path between two anchors: an L when one is free, else an A* search
// over the crossings of the pipes around the obstacles.

///|
/// The key of a grid point in the search: `getKey`.
fn grid_key(x : Double, y : Double) -> String {
  "\{@d3.to_fixed(x, 1)},\{@d3.to_fixed(y, 1)}"
}

///|
/// The path from anchor to anchor of edge `i`: the part of the routing loop
/// from the routing box to the fallback path. Adds the pipes of the
/// obstacles in the routing box.
fn Router::find_path(
  self : Router,
  i : Int32,
  e : RouteEdge,
  p_src_anchor : @model.Pt,
  p_dst_anchor : @model.Pt,
) -> Array[@model.Pt] {
  // The routing box: the anchors' box grown by 50, and around every
  // obstacle that box overlaps.
  let mut bb_min_x = @model.js_min(p_src_anchor.x, p_dst_anchor.x) - 50.0
  let mut bb_max_x = @model.js_max(p_src_anchor.x, p_dst_anchor.x) + 50.0
  let mut bb_min_y = @model.js_min(p_src_anchor.y, p_dst_anchor.y) - 50.0
  let mut bb_max_y = @model.js_max(p_src_anchor.y, p_dst_anchor.y) + 50.0
  for obs in self.obstacles {
    let path_min_x = @model.js_min(p_src_anchor.x, p_dst_anchor.x)
    let path_max_x = @model.js_max(p_src_anchor.x, p_dst_anchor.x)
    let path_min_y = @model.js_min(p_src_anchor.y, p_dst_anchor.y)
    let path_max_y = @model.js_max(p_src_anchor.y, p_dst_anchor.y)
    let obs_blocks_path = obs.min_x < path_max_x &&
      obs.max_x > path_min_x &&
      obs.min_y < path_max_y &&
      obs.max_y > path_min_y
    if obs_blocks_path {
      bb_min_x = @model.js_min(bb_min_x, obs.min_x - ROUTING_MARGIN)
      bb_max_x = @model.js_max(bb_max_x, obs.max_x + ROUTING_MARGIN)
      bb_min_y = @model.js_min(bb_min_y, obs.min_y - ROUTING_MARGIN)
      bb_max_y = @model.js_max(bb_max_y, obs.max_y + ROUTING_MARGIN)
    }
  }
  for obs in self.obstacles {
    if obs.max_x < bb_min_x ||
      obs.min_x > bb_max_x ||
      obs.max_y < bb_min_y ||
      obs.min_y > bb_max_y {
      continue
    }
    let h_margin = HORIZONTAL_PIPE_MARGIN
    self.get_or_add_pipe(Horizontal, obs.min_y - h_margin, bb_min_x, bb_max_x)
    |> ignore
    self.get_or_add_pipe(Horizontal, obs.max_y + h_margin, bb_min_x, bb_max_x)
    |> ignore
    let v_margin = VERTICAL_PIPE_MARGIN
    self.get_or_add_pipe(Vertical, obs.min_x - v_margin, bb_min_y, bb_max_y)
    |> ignore
    self.get_or_add_pipe(Vertical, obs.max_x + v_margin, bb_min_y, bb_max_y)
    |> ignore
  }
  self.get_or_add_pipe(Horizontal, p_src_anchor.y, bb_min_x, bb_max_x) |> ignore
  self.get_or_add_pipe(Horizontal, p_dst_anchor.y, bb_min_x, bb_max_x) |> ignore
  let h_pipes = self.pipes.filter(p => {
    p.orientation == Horizontal && p.coord >= bb_min_y && p.coord <= bb_max_y
  })
  let v_pipes = self.pipes.filter(p => {
    p.orientation == Vertical && p.coord >= bb_min_x && p.coord <= bb_max_x
  })
  // An L either way round when one is free.
  let corner_hv = @model.pt(p_dst_anchor.x, p_src_anchor.y)
  let seg1_hv_blocked = self.is_segment_blocked(
    p_src_anchor,
    corner_hv,
    e.start,
    e.end,
  )
  let seg2_hv_blocked = self.is_segment_blocked(
    corner_hv,
    p_dst_anchor,
    e.start,
    e.end,
  )
  let path_hv_blocked = seg1_hv_blocked || seg2_hv_blocked
  let corner_vh = @model.pt(p_src_anchor.x, p_dst_anchor.y)
  let seg1_vh_blocked = self.is_segment_blocked(
    p_src_anchor,
    corner_vh,
    e.start,
    e.end,
  )
  let seg2_vh_blocked = self.is_segment_blocked(
    corner_vh,
    p_dst_anchor,
    e.start,
    e.end,
  )
  let path_vh_blocked = seg1_vh_blocked || seg2_vh_blocked
  let mut found_path : Array[@model.Pt] = []
  if !path_hv_blocked {
    if (p_src_anchor.y - p_dst_anchor.y).abs() < EPS7 ||
      (p_src_anchor.x - p_dst_anchor.x).abs() < EPS7 {
      found_path = [p_src_anchor, p_dst_anchor]
    } else {
      found_path = [p_src_anchor, corner_hv, p_dst_anchor]
    }
  } else if !path_vh_blocked {
    if (p_src_anchor.x - p_dst_anchor.x).abs() < EPS7 {
      found_path = [p_src_anchor, p_dst_anchor]
    } else {
      found_path = [p_src_anchor, corner_vh, p_dst_anchor]
    }
  }
  if found_path.length() == 0 {
    found_path = self.a_star(i, e, p_src_anchor, p_dst_anchor, h_pipes, v_pipes)
  }
  if found_path.length() == 0 {
    found_path = [
      p_src_anchor,
      @model.pt(p_src_anchor.x, p_dst_anchor.y),
      p_dst_anchor,
    ]
  }
  found_path
}

///|
/// A* from anchor to anchor, stepping along pipes to the neighbouring
/// crossing pipe, with costs for crossings, steps away from the
/// destination and bends. Empty when the destination cannot be reached.
fn Router::a_star(
  self : Router,
  i : Int32,
  e : RouteEdge,
  p_src_anchor : @model.Pt,
  p_dst_anchor : @model.Pt,
  h_pipes : Array[Pipe],
  v_pipes : Array[Pipe],
) -> Array[@model.Pt] {
  let start_key = grid_key(p_src_anchor.x, p_src_anchor.y)
  let end_key = grid_key(p_dst_anchor.x, p_dst_anchor.y)
  let g_score : Map[String, Double] = Map([])
  let came_from : Map[String, @model.Pt] = Map([])
  // The axis of the step into a point: 'n' (none), 'h' or 'v'.
  let arrival_dir : Map[String, Char] = Map([])
  let open_set : Set[String] = Set([])
  let open_list : Array[OpenEntry] = []
  g_score.set(start_key, 0.0)
  arrival_dir.set(start_key, 'n')
  open_list.push({
    key: start_key,
    f: @jsmath.hypot(
      p_dst_anchor.x - p_src_anchor.x,
      p_dst_anchor.y - p_src_anchor.y,
    ),
    pt: p_src_anchor,
  })
  open_set.add(start_key)
  while open_list.length() > 0 {
    @d3.js_sort(open_list, (a, b) => a.f - b.f)
    let current = open_list.remove(0)
    open_set.remove(current.key)
    if current.key == end_key {
      let found_path = [p_dst_anchor]
      let mut curr_key = end_key
      while came_from.get(curr_key) is Some(prev) {
        found_path.insert(0, prev)
        curr_key = grid_key(prev.x, prev.y)
      }
      return found_path
    }
    let cx = current.pt.x
    let cy = current.pt.y
    // Upstream sorts the filtered pipes in place on every step.
    @d3.js_sort(v_pipes, (a, b) => a.coord - b.coord)
    let v_idx = v_pipes.search_by(p => (p.coord - cx).abs() < 1.0).unwrap_or(-1)
    @d3.js_sort(h_pipes, (a, b) => a.coord - b.coord)
    let h_idx = h_pipes.search_by(p => (p.coord - cy).abs() < 1.0).unwrap_or(-1)
    let neighbors : Array[@model.Pt] = []
    if v_idx > 0 {
      neighbors.push(@model.pt(v_pipes[v_idx - 1].coord, cy))
    }
    if v_idx >= 0 && v_idx < v_pipes.length() - 1 {
      neighbors.push(@model.pt(v_pipes[v_idx + 1].coord, cy))
    }
    if h_idx > 0 {
      neighbors.push(@model.pt(cx, h_pipes[h_idx - 1].coord))
    }
    if h_idx >= 0 && h_idx < h_pipes.length() - 1 {
      neighbors.push(@model.pt(cx, h_pipes[h_idx + 1].coord))
    }
    for neighbor in neighbors {
      let min_x = @model.js_min(cx, neighbor.x)
      let max_x = @model.js_max(cx, neighbor.x)
      let min_y = @model.js_min(cy, neighbor.y)
      let max_y = @model.js_max(cy, neighbor.y)
      let blocked = self.obstacles
        .iter()
        .any(obs => {
          if obs.node_id == e.start || obs.node_id == e.end {
            return false
          }
          if min_x != max_x {
            obs.min_y < cy &&
            obs.max_y > cy &&
            obs.max_x > min_x &&
            obs.min_x < max_x
          } else {
            obs.min_x < cx &&
            obs.max_x > cx &&
            obs.max_y > min_y &&
            obs.min_y < max_y
          }
        })
      if blocked {
        continue
      }
      let n_key = grid_key(neighbor.x, neighbor.y)
      let dist = (neighbor.x - cx).abs() + (neighbor.y - cy).abs()
      let penalty = self.crossing_penalty(i, current.pt, neighbor)
      let mut dir_penalty = 0.0
      let dest_dx = p_dst_anchor.x - p_src_anchor.x
      let dest_dy = p_dst_anchor.y - p_src_anchor.y
      let move_dx = neighbor.x - cx
      let move_dy = neighbor.y - cy
      if (dest_dy > 10.0 && move_dy < -5.0) ||
        (dest_dy < -10.0 && move_dy > 5.0) {
        dir_penalty = move_dy.abs() * 100.0
      }
      if (dest_dx > 10.0 && move_dx < -5.0) ||
        (dest_dx < -10.0 && move_dx > 5.0) {
        dir_penalty += move_dx.abs() * 50.0
      }
      let mut bend_penalty = 0.0
      let current_dir = arrival_dir.get(current.key).unwrap_or('n')
      let move_dir = if move_dx.abs() > EPS7 { 'h' } else { 'v' }
      if current_dir != 'n' && current_dir != move_dir {
        bend_penalty = 50.0
      }
      let step_cost = dist + penalty + dir_penalty + bend_penalty
      let tentative_g = g_score.get(current.key).unwrap_or(@double.infinity) +
        step_cost
      let h = (p_dst_anchor.x - neighbor.x).abs() +
        (p_dst_anchor.y - neighbor.y).abs()
      if tentative_g < g_score.get(n_key).unwrap_or(@double.infinity) {
        came_from.set(n_key, current.pt)
        g_score.set(n_key, tentative_g)
        arrival_dir.set(n_key, move_dir)
        if !open_set.contains(n_key) {
          open_list.push({ key: n_key, f: tentative_g + h, pt: neighbor, })
          open_set.add(n_key)
        } else {
          match open_list.search_by(x => x.key == n_key) {
            Some(idx) => open_list[idx].f = tentative_g + h
            None => ()
          }
        }
      }
    }
  }
  []
}
