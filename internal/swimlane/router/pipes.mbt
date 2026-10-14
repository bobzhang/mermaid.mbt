// Pipes and the obstacle tests the routing phase shares.

///|
/// The pipe of that orientation within 1 of `coord`, created when there is
/// none, with its span stretched over `span_min..span_max`: `getOrAddPipe`.
fn Router::get_or_add_pipe(
  self : Router,
  orientation : Orient,
  coord : Double,
  span_min : Double,
  span_max : Double,
) -> Pipe {
  let pipe = match
    self.pipes.search_by(p => {
      p.orientation == orientation && (p.coord - coord).abs() < 1.0
    }) {
    Some(index) => self.pipes[index]
    None => {
      // Upstream also names it `pipe-${orientation}-${coord.toFixed(0)}`,
      // a name nothing reads.
      let pipe = { orientation, coord, span_min, span_max, tracks: [], }
      self.pipes.push(pipe)
      pipe
    }
  }
  pipe.span_min = @model.js_min(pipe.span_min, span_min)
  pipe.span_max = @model.js_max(pipe.span_max, span_max)
  pipe
}

///|
/// Whether an obstacle other than those of the two given nodes lies across
/// the segment: `isSegmentBlocked`. The segment is taken as horizontal
/// unless its ends share x.
fn Router::is_segment_blocked(
  self : Router,
  p1 : @model.Pt,
  p2 : @model.Pt,
  exclude_start : String,
  exclude_end : String,
) -> Bool {
  let seg_min_x = @model.js_min(p1.x, p2.x)
  let seg_max_x = @model.js_max(p1.x, p2.x)
  let seg_min_y = @model.js_min(p1.y, p2.y)
  let seg_max_y = @model.js_max(p1.y, p2.y)
  self.obstacles
  .iter()
  .any(obs => {
    if exclude_start != "" && obs.node_id == exclude_start {
      return false
    }
    if exclude_end != "" && obs.node_id == exclude_end {
      return false
    }
    if (p1.x - p2.x).abs() > EPS7 {
      obs.min_y < p1.y &&
      obs.max_y > p1.y &&
      obs.max_x > seg_min_x &&
      obs.min_x < seg_max_x
    } else {
      obs.min_x < p1.x &&
      obs.max_x > p1.x &&
      obs.max_y > seg_min_y &&
      obs.min_y < seg_max_y
    }
  })
}

///|
/// The cost of crossing the edges routed so far with a step from `from` to
/// `to`: `crossingPenalty`.
fn Router::crossing_penalty(
  self : Router,
  edge_idx : Int32,
  from : @model.Pt,
  to : @model.Pt,
) -> Double {
  if self.all_routed_segments.length() == 0 {
    return 0.0
  }
  let is_horizontal = (from.y - to.y).abs() < EPS7
  let is_vertical = (from.x - to.x).abs() < EPS7
  if !is_horizontal && !is_vertical {
    return 0.0
  }
  let mut penalties = 0.0
  if is_horizontal {
    let y = from.y
    let min_x = @model.js_min(from.x, to.x) - EPS7
    let max_x = @model.js_max(from.x, to.x) + EPS7
    if max_x <= min_x {
      return 0.0
    }
    for seg in self.all_routed_segments {
      if seg.edge_index == edge_idx || seg.orientation != Vertical {
        continue
      }
      if seg.pipe.coord < min_x || seg.pipe.coord > max_x {
        continue
      }
      if seg.from - EPS7 <= y && seg.to + EPS7 >= y {
        penalties += CROSSING_PENALTY
      }
    }
  } else if is_vertical {
    let x = from.x
    let min_y = @model.js_min(from.y, to.y) - EPS7
    let max_y = @model.js_max(from.y, to.y) + EPS7
    if max_y <= min_y {
      return 0.0
    }
    for seg in self.all_routed_segments {
      if seg.edge_index == edge_idx || seg.orientation != Horizontal {
        continue
      }
      if seg.pipe.coord < min_y || seg.pipe.coord > max_y {
        continue
      }
      if seg.from - EPS7 <= x && seg.to + EPS7 >= x {
        penalties += CROSSING_PENALTY
      }
    }
  }
  penalties
}
