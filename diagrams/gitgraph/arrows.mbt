///|
/// `shouldRerouteArrow`: whether another commit sits where the arrow
/// would turn, on the branch whose line the turn follows.
fn Renderer::should_reroute(
  self : Renderer,
  from : Commit,
  to : Commit,
  p1 : Point,
  p2 : Point,
) -> Bool {
  let to_is_furthest = if self.vertical() { p1.x < p2.x } else { p1.y < p2.y }
  let branch = if to_is_furthest { to.branch } else { from.branch }
  for _, commit in self.graph.commits {
    if commit.seq > from.seq && commit.seq < to.seq && commit.branch == branch {
      return true
    }
  }
  false
}

///|
/// `findLane`: a coordinate between `y1` and `y2` that keeps 10 units
/// from every lane in use, tried ever closer to `y1`.
fn Renderer::find_lane(
  self : Renderer,
  y1 : Double,
  y2 : Double,
  depth~ : Int32 = 0,
) -> Double {
  let candidate = y1 + (y1 - y2).abs() / 2.0
  if depth > 5 {
    return candidate
  }
  if self.lanes.iter().all(lane => (lane - candidate).abs() >= 10.0) {
    self.lanes.push(candidate)
    return candidate
  }
  let diff = (y1 - y2).abs()
  self.find_lane(y1, y2 - diff / 5.0, depth=depth + 1)
}

///|
/// `drawArrow`: the line from a commit to one of its children, turning
/// once with a quarter circle, or twice through a free lane when a
/// commit is in the way.
fn Renderer::draw_arrow(
  self : Renderer,
  arrows : @dom.Element,
  from : Commit,
  to : Commit,
) -> Unit raise GitError {
  guard self.commit_pos.get(from.id) is Some(p1) &&
    self.commit_pos.get(to.id) is Some(p2) else {
    raise GitError(
      "Commit positions not found for commits \{from.id} and \{to.id}",
    )
  }
  let n = @dom.number
  let index_of = (branch : String) => {
    match self.branch_pos.get(branch) {
      Some((_, index)) => index
      None => 0
    }
  }
  // An arrow into a merge from its second parent takes that branch's
  // color.
  let merging = to.kind == Merge && Some(from.id) != to.parents.get(0)
  let mut color = if merging {
    index_of(from.branch)
  } else {
    index_of(to.branch)
  }
  let p1x = n(p1.x)
  let p1y = n(p1.y)
  let p2x = n(p2.x)
  let p2y = n(p2.y)
  let line = if self.should_reroute(from, to, p1, p2) {
    let arc = "A 10 10, 0, 0, 0,"
    let arc2 = "A 10 10, 0, 0, 1,"
    let radius = 10.0
    let offset = 10.0
    let line_y = if p1.y < p2.y {
      self.find_lane(p1.y, p2.y)
    } else {
      self.find_lane(p2.y, p1.y)
    }
    let line_x = if p1.x < p2.x {
      self.find_lane(p1.x, p2.x)
    } else {
      self.find_lane(p2.x, p1.x)
    }
    let lx = n(line_x)
    let ly = n(line_y)
    match self.dir {
      "TB" =>
        if p1.x < p2.x {
          "M \{p1x} \{p1y} L \{n(line_x - radius)} \{p1y} \{arc2} \{lx} \{n(p1.y + offset)} L \{lx} \{n(p2.y - radius)} \{arc} \{n(line_x + offset)} \{p2y} L \{p2x} \{p2y}"
        } else {
          color = index_of(from.branch)
          "M \{p1x} \{p1y} L \{n(line_x + radius)} \{p1y} \{arc} \{lx} \{n(p1.y + offset)} L \{lx} \{n(p2.y - radius)} \{arc2} \{n(line_x - offset)} \{p2y} L \{p2x} \{p2y}"
        }
      "BT" =>
        if p1.x < p2.x {
          "M \{p1x} \{p1y} L \{n(line_x - radius)} \{p1y} \{arc} \{lx} \{n(p1.y - offset)} L \{lx} \{n(p2.y + radius)} \{arc2} \{n(line_x + offset)} \{p2y} L \{p2x} \{p2y}"
        } else {
          color = index_of(from.branch)
          "M \{p1x} \{p1y} L \{n(line_x + radius)} \{p1y} \{arc2} \{lx} \{n(p1.y - offset)} L \{lx} \{n(p2.y + radius)} \{arc} \{n(line_x - offset)} \{p2y} L \{p2x} \{p2y}"
        }
      _ =>
        if p1.y < p2.y {
          "M \{p1x} \{p1y} L \{p1x} \{n(line_y - radius)} \{arc} \{n(p1.x + offset)} \{ly} L \{n(p2.x - radius)} \{ly} \{arc2} \{p2x} \{n(line_y + offset)} L \{p2x} \{p2y}"
        } else {
          color = index_of(from.branch)
          "M \{p1x} \{p1y} L \{p1x} \{n(line_y + radius)} \{arc2} \{n(p1.x + offset)} \{ly} L \{n(p2.x - radius)} \{ly} \{arc} \{p2x} \{n(line_y - offset)} L \{p2x} \{p2y}"
        }
    }
  } else {
    let arc = "A 20 20, 0, 0, 0,"
    let arc2 = "A 20 20, 0, 0, 1,"
    let radius = 20.0
    let offset = 20.0
    let straight = "M \{p1x} \{p1y} L \{p2x} \{p2y}"
    match self.dir {
      "TB" =>
        if p1.x < p2.x {
          if merging {
            "M \{p1x} \{p1y} L \{p1x} \{n(p2.y - radius)} \{arc} \{n(p1.x + offset)} \{p2y} L \{p2x} \{p2y}"
          } else {
            "M \{p1x} \{p1y} L \{n(p2.x - radius)} \{p1y} \{arc2} \{p2x} \{n(p1.y + offset)} L \{p2x} \{p2y}"
          }
        } else if p1.x > p2.x {
          if merging {
            "M \{p1x} \{p1y} L \{p1x} \{n(p2.y - radius)} \{arc2} \{n(p1.x - offset)} \{p2y} L \{p2x} \{p2y}"
          } else {
            "M \{p1x} \{p1y} L \{n(p2.x + radius)} \{p1y} \{arc} \{p2x} \{n(p1.y + offset)} L \{p2x} \{p2y}"
          }
        } else {
          straight
        }
      "BT" =>
        if p1.x < p2.x {
          if merging {
            "M \{p1x} \{p1y} L \{p1x} \{n(p2.y + radius)} \{arc2} \{n(p1.x + offset)} \{p2y} L \{p2x} \{p2y}"
          } else {
            "M \{p1x} \{p1y} L \{n(p2.x - radius)} \{p1y} \{arc} \{p2x} \{n(p1.y - offset)} L \{p2x} \{p2y}"
          }
        } else if p1.x > p2.x {
          if merging {
            "M \{p1x} \{p1y} L \{p1x} \{n(p2.y + radius)} \{arc} \{n(p1.x - offset)} \{p2y} L \{p2x} \{p2y}"
          } else {
            "M \{p1x} \{p1y} L \{n(p2.x + radius)} \{p1y} \{arc2} \{p2x} \{n(p1.y - offset)} L \{p2x} \{p2y}"
          }
        } else {
          straight
        }
      _ =>
        if p1.y < p2.y {
          if merging {
            "M \{p1x} \{p1y} L \{n(p2.x - radius)} \{p1y} \{arc2} \{p2x} \{n(p1.y + offset)} L \{p2x} \{p2y}"
          } else {
            "M \{p1x} \{p1y} L \{p1x} \{n(p2.y - radius)} \{arc} \{n(p1.x + offset)} \{p2y} L \{p2x} \{p2y}"
          }
        } else if p1.y > p2.y {
          if merging {
            "M \{p1x} \{p1y} L \{n(p2.x - radius)} \{p1y} \{arc} \{p2x} \{n(p1.y - offset)} L \{p2x} \{p2y}"
          } else {
            "M \{p1x} \{p1y} L \{p1x} \{n(p2.y + radius)} \{arc2} \{n(p1.x + offset)} \{p2y} L \{p2x} \{p2y}"
          }
        } else {
          straight
        }
    }
  }
  let color = color_index(
    color,
    THEME_COLOR_LIMIT,
    is_color_theme(self.theme_name),
  )
  arrows.append("path").attr("d", line).attr("class", "arrow arrow\{color}")
  |> ignore
}

///|
/// `drawArrows`: one arrow per parent, in the order the commits were
/// recorded.
fn Renderer::draw_arrows(
  self : Renderer,
  svg : @dom.Element,
) -> Unit raise GitError {
  let arrows = svg.append("g").attr("class", "commit-arrows")
  for _, commit in self.graph.commits {
    for parent in commit.parents {
      guard self.graph.commits.get(parent) is Some(from) else {
        raise GitError("Commit not found for key \{parent}")
      }
      self.draw_arrow(arrows, from, commit)
    }
  }
}
