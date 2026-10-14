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
