///|
const LAYOUT_OFFSET : Double = 10.0

///|
const COMMIT_STEP : Double = 40.0

///|
const PX : Double = 4.0

///|
const PY : Double = 2.0

///|
/// The number of branch color classes the classic themes cycle through.
const THEME_COLOR_LIMIT : Int32 = 8

///|
const REDUX_BRANCH_LABEL_PADDING_Y : Double = 12.0

///|
/// Where the first commit of a vertical graph sits.
const DEFAULT_POS : Double = 30.0

///|
/// The color class of branch number `raw_index`. The color themes keep
/// class 0 for the main branch and cycle the others through the rest.
fn color_index(
  raw_index : Int32,
  limit : Int32,
  avoid_default : Bool,
) -> String {
  if avoid_default && raw_index > 0 {
    // Upstream computes with numbers: a limit of 1 divides by zero.
    if limit == 1 {
      return "NaN"
    }
    return ((raw_index - 1) % (limit - 1) + 1).to_string()
  }
  if limit == 0 {
    return "NaN"
  }
  (raw_index % limit).to_string()
}

///|
priv struct Point {
  x : Double
  y : Double
}

///|
/// Where a commit is drawn: `along` is its position on the axis commits
/// advance on, which is `x` in a horizontal graph and `y` in a vertical
/// one.
priv struct CommitPosition {
  x : Double
  y : Double
  along : Double
}

///|
/// The state of one rendering: mermaid's `gitGraphRenderer.ts` keeps it in
/// module variables.
priv struct Renderer {
  graph : GitGraph
  config : @config.Config
  id : String
  theme_name : String
  dir : String
  /// The position and index of every branch, by name.
  branch_pos : Map[String, (Double, Int32)]
  commit_pos : Map[String, Point]
  /// Coordinates already taken by branch lines and rerouted arrows.
  lanes : Array[Double]
  mut max_pos : Double
  /// The family the `<svg>` element sets, which all text inherits.
  family : String
  /// The font size of the `<svg>` element: that of branch labels.
  font_size : Double
  commit_label_size : Double
  tag_label_size : Double
}

///|
fn Renderer::vertical(self : Renderer) -> Bool {
  self.dir is ("TB" | "BT")
}

///|
fn Renderer::setting(self : Renderer, name : String) -> Bool {
  self.config.flag("gitGraph.\{name}")
}

///|
fn Renderer::font(self : Renderer, bold~ : Bool = false) -> @font.Stack {
  @font.Stack::for_family(self.family, bold~)
}

///|
/// The weight the neo and redux themes give commit labels, and the redux
/// themes branch labels.
fn Renderer::note_weight_is_bold(self : Renderer) -> Bool {
  is_bold_weight(self.config.theme().get("noteFontWeight"))
}

///|
fn Renderer::branch(
  self : Renderer,
  name : String,
) -> (Double, Int32) raise GitError {
  match self.branch_pos.get(name) {
    Some(position) => position
    None => raise GitError("Position not found for branch \{name}")
  }
}

///|
/// The commits in the order they were made.
fn Renderer::sorted_commits(self : Renderer) -> Array[Commit] {
  let commits = self.graph.commits.values().collect()
  commits.sort_by((a, b) => a.seq.compare(b.seq))
  commits
}

///|
/// The parent a commit is placed after: the one furthest along.
fn Renderer::closest_parent(
  self : Renderer,
  parents : Array[String],
) -> String? {
  let bottom_up = self.dir == "BT"
  let mut closest = None
  let mut target = if bottom_up { @double.infinity } else { 0.0 }
  for parent in parents {
    guard self.commit_pos.get(parent) is Some(point) else { continue }
    let position = if self.vertical() { point.y } else { point.x }
    let closer = if bottom_up { position <= target } else { position >= target }
    if closer {
      closest = Some(parent)
      target = position
    }
  }
  closest
}

///|
/// `setParallelBTPos`: with parallel commits, a bottom-to-top graph is
/// laid out top to bottom first, to find how tall it is, and then again
/// upwards from its roots.
fn Renderer::set_parallel_bt_pos(
  self : Renderer,
  commits : Array[Commit],
  default_pos : Double,
) -> Unit raise GitError {
  let mut cur_pos = default_pos
  let mut max_position = default_pos
  let roots = []
  for commit in commits {
    if commit.parents.length() > 0 {
      guard self.closest_parent(commit.parents) is Some(closest) else {
        raise GitError("Closest parent not found for commit \{commit.id}")
      }
      guard self.commit_pos.get(closest) is Some(point) else {
        raise GitError(
          "Closest parent position not found for commit \{commit.id}",
        )
      }
      cur_pos = point.y + COMMIT_STEP
      max_position = if cur_pos > max_position { cur_pos } else { max_position }
    } else {
      roots.push(commit)
    }
    let (x, _) = self.branch(commit.branch)
    self.commit_pos[commit.id] = { x, y: cur_pos + LAYOUT_OFFSET, }
  }
  cur_pos = max_position
  for commit in roots {
    let (x, _) = self.branch(commit.branch)
    self.commit_pos[commit.id] = { x, y: cur_pos + default_pos, }
  }
  for commit in commits {
    if commit.parents.length() == 0 {
      continue
    }
    // `findClosestParentBT`: the lowest parent.
    let mut closest = None
    let mut lowest = @double.infinity
    for parent in commit.parents {
      guard self.commit_pos.get(parent) is Some(point) else {
        raise GitError("Position not found for commit \{parent}")
      }
      if point.y <= lowest {
        closest = Some(point)
        lowest = point.y
      }
    }
    guard closest is Some(point) else {
      raise GitError("Closest parent not found for commit \{commit.id}")
    }
    cur_pos = point.y - COMMIT_STEP
    let (x, _) = self.branch(commit.branch)
    self.commit_pos[commit.id] = { x, y: cur_pos - LAYOUT_OFFSET, }
  }
}

///|
/// `calculatePosition`: where a commit goes with parallel commits, one
/// step after its closest parent.
fn Renderer::calculate_position(self : Renderer, commit : Commit) -> Double {
  let current_y = match self.commit_pos.get(commit.id) {
    Some(point) => point.y
    None => 0.0
  }
  if commit.parents.length() > 0 {
    if self.closest_parent(commit.parents) is Some(closest) {
      let parent = match self.commit_pos.get(closest) {
        Some(point) => point
        None => { x: 0.0, y: 0.0, }
      }
      return match self.dir {
        "TB" => parent.y + COMMIT_STEP
        "BT" => current_y - COMMIT_STEP
        _ => parent.x + COMMIT_STEP
      }
    }
    return 0.0
  }
  match self.dir {
    "TB" => DEFAULT_POS
    "BT" => current_y - COMMIT_STEP
    _ => 0.0
  }
}

///|
/// `getCommitPosition`
fn Renderer::commit_position(
  self : Renderer,
  commit : Commit,
  pos : Double,
  parallel : Bool,
) -> CommitPosition raise GitError {
  let along = if self.dir == "BT" && parallel {
    pos
  } else {
    pos + LAYOUT_OFFSET
  }
  guard self.branch_pos.get(commit.branch) is Some((branch, _)) else {
    raise GitError("Position were undefined for commit \{commit.id}")
  }
  if self.vertical() {
    { x: branch, y: along, along, }
  } else {
    let offset = if is_redux_theme(self.theme_name) {
      REDUX_BRANCH_LABEL_PADDING_Y / 2.0 + 1.0
    } else {
      -2.0
    }
    { x: along, y: branch + offset, along, }
  }
}

///|
/// `drawCommits`: place every commit, and with `modify` draw its bullet,
/// label and tags. Upstream runs it twice: once to learn the positions
/// the branches and arrows need, once to draw on top of them.
fn Renderer::draw_commits(
  self : Renderer,
  svg : @dom.Element,
  modify : Bool,
) -> Unit raise GitError {
  let bullets = svg.append("g").attr("class", "commit-bullets")
  let labels = svg.append("g").attr("class", "commit-labels")
  let mut pos = if self.vertical() { DEFAULT_POS } else { 0.0 }
  let parallel = self.setting("parallelCommits")
  let commits = self.sorted_commits()
  if self.dir == "BT" {
    if parallel {
      self.set_parallel_bt_pos(commits, pos)
    }
    commits.rev_in_place()
  }
  for commit in commits {
    if parallel {
      pos = self.calculate_position(commit)
    }
    let position = self.commit_position(commit, pos, parallel)
    if modify {
      self.draw_bullet(bullets, commit, position)
      self.draw_label(labels, commit, position, pos)
      self.draw_tags(labels, commit, position, pos)
    }
    self.commit_pos[commit.id] = if self.vertical() {
      { x: position.x, y: position.along, }
    } else {
      { x: position.along, y: position.y, }
    }
    pos = if self.dir == "BT" && parallel {
      pos + COMMIT_STEP
    } else {
      pos + COMMIT_STEP + LAYOUT_OFFSET
    }
    if pos > self.max_pos {
      self.max_pos = pos
    }
  }
}

///|
/// The class naming how a commit is drawn: `getCommitClassType`.
fn type_class(kind : CommitType) -> String {
  match kind {
    Normal => "commit-normal"
    Reverse => "commit-reverse"
    Highlight => "commit-highlight"
    Merge => "commit-merge"
    CherryPick => "commit-cherry-pick"
  }
}

///|
/// `drawCommitBullet`
fn Renderer::draw_bullet(
  self : Renderer,
  bullets : @dom.Element,
  commit : Commit,
  position : CommitPosition,
) -> Unit {
  let redux = is_redux_theme(self.theme_name)
  let symbol = commit.custom_type.unwrap_or(commit.kind)
  let type_class = type_class(symbol)
  let branch_index = match self.branch_pos.get(commit.branch) {
    Some((_, index)) => index
    None => 0
  }
  let color = color_index(
    branch_index,
    THEME_COLOR_LIMIT,
    is_color_theme(self.theme_name),
  )
  let pick = (redux_value : Double, classic : Double) => {
    if redux {
      redux_value
    } else {
      classic
    }
  }
  let { x, y, .. } = position
  match symbol {
    Highlight => {
      bullets
      .append("rect")
      .attr_number("x", x - 10.0 + pick(3.0, 0.0))
      .attr_number("y", y - 10.0 + pick(3.0, 0.0))
      .attr_number("width", pick(14.0, 20.0))
      .attr_number("height", pick(14.0, 20.0))
      .attr(
        "class",
        "commit \{commit.id} commit-highlight\{color} \{type_class}-outer",
      )
      |> ignore
      bullets
      .append("rect")
      .attr_number("x", x - 6.0 + pick(2.0, 0.0))
      .attr_number("y", y - 6.0 + pick(2.0, 0.0))
      .attr_number("width", pick(8.0, 12.0))
      .attr_number("height", pick(8.0, 12.0))
      .attr("class", "commit \{commit.id} commit\{color} \{type_class}-inner")
      |> ignore
    }
    CherryPick => {
      let class_name = "commit \{commit.id} \{type_class}"
      let ink = if is_dark_theme(self.theme_name) { "#000000" } else { "#fff" }
      bullets
      .append("circle")
      .attr_number("cx", x)
      .attr_number("cy", y)
      .attr_number("r", pick(7.0, 10.0))
      .attr("class", class_name)
      |> ignore
      for dx in [-3.0, 3.0] {
        bullets
        .append("circle")
        .attr_number("cx", x + dx)
        .attr_number("cy", y + 2.0)
        .attr_number("r", pick(2.5, 2.75))
        .attr("fill", ink)
        .attr("class", class_name)
        |> ignore
      }
      for dx in [3.0, -3.0] {
        bullets
        .append("line")
        .attr_number("x1", x + dx)
        .attr_number("y1", y + 1.0)
        .attr_number("x2", x)
        .attr_number("y2", y - 5.0)
        .attr("stroke", ink)
        .attr("class", class_name)
        |> ignore
      }
    }
    _ => {
      bullets
      .append("circle")
      .attr_number("cx", x)
      .attr_number("cy", y)
      .attr_number("r", pick(7.0, 10.0))
      .attr("class", "commit \{commit.id} commit\{color}")
      |> ignore
      let marked = "commit \{type_class} \{commit.id} commit\{color}"
      if symbol == Merge {
        bullets
        .append("circle")
        .attr_number("cx", x)
        .attr_number("cy", y)
        .attr_number("r", pick(5.0, 6.0))
        .attr("class", marked)
        |> ignore
      }
      if symbol == Reverse {
        let n = @dom.number
        let c = pick(4.0, 5.0)
        bullets
        .append("path")
        .attr(
          "d",
          "M \{n(x - c)},\{n(y - c)}L\{n(x + c)},\{n(y + c)}M\{n(x - c)},\{n(y + c)}L\{n(x + c)},\{n(y - c)}",
        )
        .attr("class", marked)
        |> ignore
      }
    }
  }
}

///|
/// `drawCommitLabel`: the commit id on a translucent background, under
/// the bullet and turned 45 degrees unless `rotateCommitLabel` is off.
fn Renderer::draw_label(
  self : Renderer,
  labels : @dom.Element,
  commit : Commit,
  position : CommitPosition,
  pos : Double,
) -> Unit {
  // Cherry-picks have no label, merges only one that was asked for.
  if commit.kind == CherryPick ||
    (commit.kind == Merge && !commit.custom_id) ||
    !self.setting("showCommitLabel") {
    return
  }
  let n = @dom.number
  let neo = is_neo_theme(self.theme_name) || is_redux_theme(self.theme_name)
  let font = self.font(bold=neo && self.note_weight_is_bold())
  let size = self.commit_label_size
  let wrapper = labels.append("g")
  let background = wrapper.append("rect").attr("class", "commit-label-bkg")
  let text = wrapper
    .append("text")
    .attr_number("x", pos)
    .attr_number("y", position.y + 25.0)
    .attr("class", "commit-label")
    .text(commit.id)
  let (width, height) = text_size(font, commit.id, size)
  background
  .attr_number("x", position.along - width / 2.0 - PY)
  .attr_number("y", position.y + 13.5)
  .attr_number("width", width + 2.0 * PY)
  .attr_number("height", height + 2.0 * PY)
  |> ignore
  let (text_x, text_y) = if self.vertical() {
    background
    .attr_number("x", position.x - (width + 4.0 * PX + 5.0))
    .attr_number("y", position.y - 12.0)
    |> ignore
    (position.x - (width + 4.0 * PX), position.y + height - 12.0)
  } else {
    (position.along - width / 2.0, position.y + 25.0)
  }
  text.attr_number("x", text_x).attr_number("y", text_y) |> ignore
  place_text(text, font, size)
  if self.setting("rotateCommitLabel") {
    if self.vertical() {
      let rotation = "rotate(-45, \{n(position.x)}, \{n(position.y)})"
      text.attr("transform", rotation) |> ignore
      background.attr("transform", rotation) |> ignore
    } else {
      let r_x = -7.5 - (width + 10.0) / 25.0 * 9.5
      let r_y = 10.0 + width / 25.0 * 8.5
      wrapper.attr(
        "transform",
        "translate(\{n(r_x)}, \{n(r_y)}) rotate(-45, \{n(pos)}, \{n(position.y)})",
      )
      |> ignore
    }
  }
}

///|
/// `drawCommitTags`: tags stacked above the bullet, the last one nearest
/// to it, all as wide as the widest.
fn Renderer::draw_tags(
  self : Renderer,
  labels : @dom.Element,
  commit : Commit,
  position : CommitPosition,
  pos : Double,
) -> Unit {
  if commit.tags.is_empty() {
    return
  }
  let n = @dom.number
  let font = self.font()
  let size = self.tag_label_size
  let mut y_offset = 0.0
  let mut max_width = 0.0
  let mut max_height = 0.0
  let elements = []
  // Reversed in place, as upstream does.
  commit.tags.rev_in_place()
  for value in commit.tags {
    let polygon = labels.append("polygon")
    let hole = labels.append("circle")
    let y = position.y - 16.0 - y_offset
    let tag = labels
      .append("text")
      .attr_number("y", y)
      .attr("class", "tag-label")
      .text(value)
    let (width, height) = text_size(font, value, size)
    max_width = if width > max_width { width } else { max_width }
    max_height = if height > max_height { height } else { max_height }
    let x = position.along - width / 2.0
    tag.attr_number("x", x) |> ignore
    place_text(tag, font, size)
    elements.push((tag, hole, polygon, y_offset))
    y_offset += 20.0
  }
  let along = position.along
  for element in elements {
    let (tag, hole, polygon, y_offset) = element
    let h2 = max_height / 2.0
    let ly = position.y - 19.2 - y_offset
    // The points are written as upstream's template literal lays them
    // out, line breaks and indentation included.
    let points = (indent : String, corners : Array[(Double, Double)]) => {
      corners.map(corner => "\n\{indent}\{n(corner.0)},\{n(corner.1)}")
    }
    let tail = pos - max_width / 2.0 - PX / 2.0
    let near = along - max_width / 2.0 - PX
    let far = along + max_width / 2.0 + PX
    let horizontal = points("      ", [
      (tail, ly + PY),
      (tail, ly - PY),
      (near, ly - h2 - PY),
      (far, ly - h2 - PY),
      (far, ly + h2 + PY),
      (near, ly + h2 + PY),
    ])
    // The first corner is followed by two spaces.
    horizontal[0] = horizontal[0] + "  "
    polygon.attr("class", "tag-label-bkg").attr("points", horizontal.join(""))
    |> ignore
    hole
    .attr_number("cy", ly)
    .attr_number("cx", pos - max_width / 2.0 + PX / 2.0)
    .attr_number("r", 1.5)
    .attr("class", "tag-hole")
    |> ignore
    if self.vertical() {
      let y_origin = pos + y_offset
      let x = position.x
      let far = x + LAYOUT_OFFSET + max_width + 4.0
      let rotation = "rotate(45, \{n(x)},\{n(pos)})"
      polygon
      .attr("class", "tag-label-bkg")
      .attr(
        "points",
        points("        ", [
          (x, y_origin + 2.0),
          (x, y_origin - 2.0),
          (x + LAYOUT_OFFSET, y_origin - h2 - 2.0),
          (far, y_origin - h2 - 2.0),
          (far, y_origin + h2 + 2.0),
          (x + LAYOUT_OFFSET, y_origin + h2 + 2.0),
        ]).join(""),
      )
      .attr("transform", "translate(12,12) \{rotation}")
      |> ignore
      hole
      .attr_number("cx", x + PX / 2.0)
      .attr_number("cy", y_origin)
      .attr("transform", "translate(12,12) \{rotation}")
      |> ignore
      tag
      .attr_number("x", x + 5.0)
      .attr_number("y", y_origin + 3.0)
      .attr("transform", "translate(14,14) \{rotation}")
      |> ignore
      place_text(tag, font, size)
    }
  }
}
