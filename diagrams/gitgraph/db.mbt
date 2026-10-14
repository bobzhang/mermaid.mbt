///|
/// How a commit is drawn. `Merge` and `CherryPick` are assigned by the
/// operations of those names; the others can be asked for with `type:`.
pub(all) enum CommitType {
  Normal
  Reverse
  Highlight
  Merge
  CherryPick
} derive(Eq, Debug)

///|
pub struct Commit {
  id : String
  message : String
  /// Position in the order the commits were made.
  seq : Int32
  kind : CommitType
  /// Drawn last to first; the renderer reverses the array in place, as
  /// upstream does.
  tags : Array[String]
  parents : Array[String]
  branch : String
  /// The `type:` of a merge, which keeps `kind` `Merge`.
  custom_type : CommitType?
  /// Whether a merge was given an `id:`; its label is drawn only then.
  custom_id : Bool
}

///|
/// An operation the history does not allow, worded as upstream words it.
pub(all) suberror GitError {
  GitError(String)
} derive(Eq, Debug)

///|
/// The git graph database: mermaid's `gitGraphAst.ts`.
pub struct GitGraph {
  /// Commits by id, in the order their ids first appeared.
  commits : Map[String, Commit]
  priv mut head : Commit?
  /// Branch names and their `order:`, in creation order.
  priv branch_config : Map[String, Double?]
  /// The id of the last commit of each branch, if it has one.
  priv branches : Map[String, String?]
  priv mut current_branch : String
  mut direction : String
  priv mut seq : Int32
  mut title : String
  mut acc_title : String
  mut acc_description : String
  priv ids : IdSource
  /// Whether `sanitizeText` writes angle brackets as entities.
  priv html_labels : Bool
}

///|
fn GitGraph::new(config : @config.Config) -> GitGraph {
  let main_branch = config.text("gitGraph.mainBranchName").unwrap_or("main")
  {
    commits: Map([]),
    head: None,
    branch_config: Map::from_array([
      (main_branch, config.number("gitGraph.mainBranchOrder")),
    ]),
    branches: Map::from_array([(main_branch, None)]),
    current_branch: main_branch,
    direction: "LR",
    seq: 0,
    title: "",
    acc_title: "",
    acc_description: "",
    ids: IdSource::new(),
    html_labels: match config.get("gitGraph.htmlLabels") {
      Null => true
      value => @config.evaluate(value)
    },
  }
}

///|
fn GitGraph::sanitize(
  self : GitGraph,
  text : String,
) -> String raise Unsupported {
  sanitize_text(text, self.html_labels)
}

///|
/// A generated commit id: the sequence number and seven hex digits.
fn GitGraph::generated_id(self : GitGraph) -> String {
  "\{self.seq}-\{self.ids.hex(7)}"
}

///|
fn GitGraph::record(self : GitGraph, commit : Commit) -> Unit {
  self.seq += 1
  self.head = Some(commit)
  self.commits[commit.id] = commit
  self.branches[self.current_branch] = Some(commit.id)
}

///|
/// The parents of a commit made now: the head, and `other` for a merge or
/// a cherry-pick. A branch without commits gives its first commit none.
fn GitGraph::parents(self : GitGraph, other? : String) -> Array[String] {
  match (self.head, other) {
    (None, _) => []
    (Some(head), None) => [head.id]
    (Some(head), Some(other)) => [head.id, other]
  }
}

///|
fn GitGraph::commit(
  self : GitGraph,
  id : String?,
  message : String,
  kind : CommitType,
  tags : Array[String],
) -> Unit raise Unsupported {
  let id = match id {
    Some(id) => self.sanitize(id)
    None => ""
  }
  let message = self.sanitize(message)
  let tags = tags.map(tag => self.sanitize(tag))
  // A repeated id replaces the earlier commit, as upstream's map does.
  self.record({
    id: if id != "" {
      id
    } else {
      self.generated_id()
    },
    message,
    seq: self.seq,
    kind,
    tags,
    parents: self.parents(),
    branch: self.current_branch,
    custom_type: None,
    custom_id: false,
  })
}

///|
fn GitGraph::branch(
  self : GitGraph,
  name : String,
  order : Double,
) -> Unit raise {
  let name = self.sanitize(name)
  if self.branches.contains(name) {
    raise GitError(
      "Trying to create an existing branch. (Help: Either use a new name if you want create a new branch or try using \"checkout \{name}\")",
    )
  }
  self.branches[name] = self.head.map(head => head.id)
  self.branch_config[name] = Some(order)
  self.checkout(name)
}

///|
/// The last commit of `branch`, when the branch exists and has one.
fn GitGraph::tip(self : GitGraph, branch : String) -> Commit? {
  match self.branches.get(branch) {
    Some(Some(id)) if id != "" => self.commits.get(id)
    _ => None
  }
}

///|
fn GitGraph::merge(
  self : GitGraph,
  other_branch : String,
  custom_id : String,
  override_type : CommitType?,
  tags : Array[String],
) -> Unit raise {
  let other_branch = self.sanitize(other_branch)
  let custom_id = if custom_id != "" {
    self.sanitize(custom_id)
  } else {
    custom_id
  }
  let current_commit = self.tip(self.current_branch)
  let other_commit = self.tip(other_branch)
  if current_commit is Some(current) &&
    other_commit is Some(_) &&
    current.branch == other_branch {
    raise GitError("Cannot merge branch '\{other_branch}' into itself.")
  }
  if self.current_branch == other_branch {
    raise GitError(
      "Incorrect usage of \"merge\". Cannot merge a branch to itself",
    )
  }
  guard current_commit is Some(current) else {
    raise GitError(
      "Incorrect usage of \"merge\". Current branch (\{self.current_branch})has no commits",
    )
  }
  if !self.branches.contains(other_branch) {
    raise GitError(
      "Incorrect usage of \"merge\". Branch to be merged (\{other_branch}) does not exist",
    )
  }
  guard other_commit is Some(other) else {
    raise GitError(
      "Incorrect usage of \"merge\". Branch to be merged (\{other_branch}) has no commits",
    )
  }
  // Both tips are looked up by id, so equal ids mean one commit.
  if current.id == other.id {
    raise GitError("Incorrect usage of \"merge\". Both branches have same head")
  }
  if custom_id != "" && self.commits.contains(custom_id) {
    raise GitError(
      "Incorrect usage of \"merge\". Commit with id:\{custom_id} already exists, use different custom id",
    )
  }
  let other_tip = match self.branches.get(other_branch) {
    Some(Some(id)) => id
    _ => ""
  }
  self.record({
    id: if custom_id != "" {
      custom_id
    } else {
      self.generated_id()
    },
    message: "merged branch \{other_branch} into \{self.current_branch}",
    seq: self.seq,
    kind: Merge,
    tags,
    parents: self.parents(other=other_tip),
    branch: self.current_branch,
    custom_type: override_type,
    custom_id: custom_id != "",
  })
}

///|
fn GitGraph::cherry_pick(
  self : GitGraph,
  source_id : String?,
  tags : Array[String]?,
  parent : String?,
) -> Unit raise {
  let source_id = match source_id {
    Some(id) => self.sanitize(id)
    None => ""
  }
  let tags = match tags {
    Some(tags) => Some(tags.map(tag => self.sanitize(tag)))
    None => None
  }
  let parent = match parent {
    Some(parent) => self.sanitize(parent)
    None => ""
  }
  guard source_id != "" && self.commits.get(source_id) is Some(source) else {
    raise GitError(
      "Incorrect usage of \"cherryPick\". Source commit id should exist and provided",
    )
  }
  if parent != "" && !source.parents.contains(parent) {
    raise GitError(
      "Invalid operation: The specified parent commit is not an immediate parent of the cherry-picked commit.",
    )
  }
  if source.kind == Merge && parent == "" {
    raise GitError(
      "Incorrect usage of cherry-pick: If the source commit is a merge commit, an immediate parent commit must be specified.",
    )
  }
  if source.branch == self.current_branch {
    raise GitError(
      "Incorrect usage of \"cherryPick\". Source commit is already on current branch",
    )
  }
  guard self.tip(self.current_branch) is Some(_) else {
    raise GitError(
      "Incorrect usage of \"cherry-pick\". Current branch (\{self.current_branch})has no commits",
    )
  }
  let tags = match tags {
    // An empty tag asks for no tag at all.
    Some(tags) => tags.filter(tag => tag != "")
    None => {
      let suffix = if source.kind == Merge { "|parent:\{parent}" } else { "" }
      ["cherry-pick:\{source.id}\{suffix}"]
    }
  }
  self.record({
    id: self.generated_id(),
    message: "cherry-picked \{source.message} into \{self.current_branch}",
    seq: self.seq,
    kind: CherryPick,
    tags,
    parents: self.parents(other=source.id),
    branch: self.current_branch,
    custom_type: None,
    custom_id: false,
  })
}

///|
fn GitGraph::checkout(self : GitGraph, branch : String) -> Unit raise {
  // `branch` passes names it has sanitized already; they are sanitized
  // again here, as upstream does.
  let branch = self.sanitize(branch)
  if !self.branches.contains(branch) {
    raise GitError(
      "Trying to checkout branch which is not yet created. (Help try using \"branch \{branch}\")",
    )
  }
  self.current_branch = branch
  self.head = self.tip(branch)
}

///|
/// The branches in drawing order: by `order:`, and for equal orders in
/// the order they were created. Upstream gives every `branch` statement
/// without an `order:` the order 0.
pub fn GitGraph::branch_names(self : GitGraph) -> Array[String] {
  let entries : Array[(String, Double)] = []
  let mut index = 0
  for name, order in self.branch_config {
    let order = match order {
      Some(order) => order
      // `parseFloat("0." + index)`
      None => @string.parse_double("0.\{index}") catch { _ => 0.0 }
    }
    // A stable insertion: after every entry that does not sort later.
    let mut at = entries.length()
    while at > 0 && entries[at - 1].1 > order {
      at -= 1
    }
    entries.insert(at, (name, order))
    index += 1
  }
  entries.map(entry => entry.0)
}

///|
/// Give the diagram a title, as a frontmatter `title` does when the text
/// has none.
pub fn GitGraph::set_title(
  self : GitGraph,
  title : String,
) -> Unit raise Unsupported {
  self.title = sanitize_common(title)
}
