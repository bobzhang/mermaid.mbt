// Straightening a long path that detours to one side into a single sweep
// around the obstacles: the `foundPath.length > 4` step of the routing
// loop.

///|
/// `Math.max(...values)`.
fn spread_max(values : Array[Double]) -> Double {
  values.fold(init=-@double.infinity, (acc, v) => @model.js_max(acc, v))
}

///|
/// `Math.min(...values)`.
fn spread_min(values : Array[Double]) -> Double {
  values.fold(init=@double.infinity, (acc, v) => @model.js_min(acc, v))
}

///|
/// The path made of one sweep out to the side the search detoured to and
/// back, when it is free of obstacles; otherwise the path as found.
fn Router::simplify_detour(
  self : Router,
  e : RouteEdge,
  found_path : Array[@model.Pt],
) -> Array[@model.Pt] {
  let start = found_path[0]
  let end = found_path[found_path.length() - 1]
  let mut min_x = @model.js_min(start.x, end.x)
  let mut max_x = @model.js_max(start.x, end.x)
  // Upstream also takes the y extent, which nothing reads.
  for pt in found_path {
    min_x = @model.js_min(min_x, pt.x)
    max_x = @model.js_max(max_x, pt.x)
  }
  let went_right = max_x > @model.js_max(start.x, end.x)
  let went_left = min_x < @model.js_min(start.x, end.x)
  if self.is_lr {
    // The sweep clears the obstacles as they will be drawn once the
    // layout is turned.
    let margin = VERTICAL_PIPE_MARGIN
    if went_right {
      let path_x = @model.js_max(start.x, end.x)
      let path_min_y = @model.js_min(start.y, end.y)
      let path_max_y = @model.js_max(start.y, end.y)
      let detour_obstacles = self.obstacles.filter(obs => {
        obs.min_x < path_x &&
        obs.max_x > path_x &&
        obs.min_y < path_max_y &&
        obs.max_y > path_min_y
      })
      if detour_obstacles.length() > 0 {
        let mut visual_max_x = @model.js_max(start.x, end.x)
        for obs in detour_obstacles {
          let obs_center_x = (obs.min_x + obs.max_x) / 2.0
          if obs.visual_x_half_extent.is_nan() {
            continue
          }
          let visual_right = obs_center_x + obs.visual_x_half_extent + margin
          visual_max_x = @model.js_max(visual_max_x, visual_right)
        }
        if !visual_max_x.is_nan() {
          max_x = visual_max_x
        }
      }
    }
    if went_left {
      let detour_obstacles = self.obstacles.filter(obs => {
        obs.min_x < @model.js_min(start.x, end.x) + margin &&
        obs.min_y < @model.js_max(start.y, end.y) &&
        obs.max_y > @model.js_min(start.y, end.y)
      })
      if detour_obstacles.length() > 0 {
        let mut visual_min_x = @model.js_min(start.x, end.x)
        for obs in detour_obstacles {
          let obs_center_x = (obs.min_x + obs.max_x) / 2.0
          let visual_left = obs_center_x - obs.visual_x_half_extent - margin
          visual_min_x = @model.js_min(visual_min_x, visual_left)
        }
        min_x = visual_min_x
      }
    }
  }
  let simplified = if went_right && !went_left {
    self.try_simplify_with_detour_x(e, start, end, max_x)
  } else if went_left && !went_right {
    self.try_simplify_with_detour_x(e, start, end, min_x)
  } else {
    None
  }
  match simplified {
    Some(path) => path
    None => found_path
  }
}

///|
/// The y at which a sweep out to `detour_x` comes back towards the end:
/// just past the obstacles between start and end, when that is before the
/// end; `findBestReturnY`.
fn Router::find_best_return_y(
  self : Router,
  start : @model.Pt,
  end : @model.Pt,
  detour_x : Double,
) -> Double {
  let going_down = end.y > start.y
  let relevant_obs = self.obstacles.filter(obs => {
    let obs_in_x_range = @model.js_min(start.x, end.x) < obs.max_x &&
      @model.js_max(start.x, end.x) > obs.min_x
    let obs_in_y_range = @model.js_min(start.y, end.y) < obs.max_y &&
      @model.js_max(start.y, end.y) > obs.min_y
    obs_in_x_range && obs_in_y_range
  })
  let mut filtered_obs = relevant_obs
  if self.is_lr && relevant_obs.length() > 0 {
    let obs_at_detour_x = relevant_obs.filter(obs => {
      obs.min_x < detour_x && obs.max_x > detour_x
    })
    if obs_at_detour_x.length() > 0 {
      filtered_obs = obs_at_detour_x
    }
  }
  if filtered_obs.length() == 0 {
    return end.y
  }
  let margin = HORIZONTAL_PIPE_MARGIN
  if going_down {
    let lowest_obs_bottom = spread_max(filtered_obs.map(obs => obs.max_y))
    let best_y = lowest_obs_bottom + margin
    if best_y < end.y - EPS7 {
      return best_y
    }
  } else {
    let highest_obs_top = spread_min(filtered_obs.map(obs => obs.min_y))
    let best_y = highest_obs_top - margin
    if best_y > end.y + EPS7 {
      return best_y
    }
  }
  end.y
}

///|
/// The sweep out to `detour_x` and back, when no obstacle is in its way:
/// `trySimplifyWithDetourX`.
fn Router::try_simplify_with_detour_x(
  self : Router,
  e : RouteEdge,
  start : @model.Pt,
  end : @model.Pt,
  detour_x : Double,
) -> Array[@model.Pt]? {
  let best_y = self.find_best_return_y(start, end, detour_x)
  let corner1 = @model.pt(detour_x, start.y)
  let corner2 = @model.pt(detour_x, best_y)
  let corner3 = @model.pt(end.x, best_y)
  let seg1_blocked = self.is_segment_blocked(start, corner1, e.start, e.end)
  let seg2_blocked = self.is_segment_blocked(corner1, corner2, e.start, e.end)
  let seg3_blocked = self.is_segment_blocked(corner2, corner3, e.start, e.end)
  let seg4_blocked = if best_y != end.y {
    self.is_segment_blocked(corner3, end, e.start, e.end)
  } else {
    false
  }
  if !seg1_blocked && !seg2_blocked && !seg3_blocked && !seg4_blocked {
    if (best_y - end.y).abs() < EPS7 {
      return Some([start, corner1, corner2, end])
    }
    return Some([start, corner1, corner2, corner3, end])
  }
  None
}
