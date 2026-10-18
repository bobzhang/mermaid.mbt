///|
/// A side of a node an edge leaves it from.
pub(all) enum Direction {
  L
  R
  T
  B
} derive(Eq, Hash, Debug)

///|
fn direction_of(text : String) -> Direction {
  match text {
    "L" => L
    "R" => R
    "T" => T
    _ => B
  }
}

///|
pub fn Direction::to_string(self : Direction) -> String {
  match self {
    L => "L"
    R => "R"
    T => "T"
    B => "B"
  }
}

///|
/// Whether a side is the left or the right one.
fn Direction::is_x(self : Direction) -> Bool {
  self is (L | R)
}

///|
/// `isArchitectureDirectionXY`: one side is horizontal, the other vertical.
fn is_xy(a : Direction, b : Direction) -> Bool {
  a.is_x() != b.is_x()
}

///|
/// An edge between two nodes, as written.
pub(all) struct Edge {
  lhs_id : String
  lhs_dir : Direction
  lhs_into : Bool
  lhs_group : Bool
  rhs_id : String
  rhs_dir : Direction
  rhs_into : Bool
  rhs_group : Bool
  title : String?
} derive(Debug)

///|
/// The axis of an `align` directive.
pub(all) enum AlignDirection {
  Row
  Column
} derive(Eq, Debug)

///|
/// An `align` directive: nodes that share a row or a column.
pub(all) struct LayoutHint {
  direction : AlignDirection
  members : Array[String]
} derive(Debug)

///|
/// What a node is.
pub(all) enum NodeKind {
  Service(icon~ : String?, icon_text~ : String?, title~ : String?)
  Junction
} derive(Debug)

///|
/// A service or a junction.
pub struct Node {
  id : String
  kind : NodeKind
  /// The group the node is in.
  parent : String?
  /// The edges at the node, in the order they were added.
  edges : Array[Edge]
} derive(Debug)

///|
/// A group of nodes and groups.
pub struct Group {
  id : String
  icon : String?
  title : String?
  parent : String?
} derive(Debug)

///|
/// A pair of sides, `LR` for an edge that leaves its source on the left and
/// enters its target on the right; never a side twice.
priv struct Pair {
  source : Direction
  target : Direction
} derive(Eq, Hash)

///|
/// `getArchitectureDirectionPair`: none for an impossible pair.
fn pair_of(source : Direction, target : Direction) -> Pair? {
  if source == target {
    None
  } else {
    Some({ source, target, })
  }
}

///|
/// `shiftPositionByArchitectureDirectionPair`.
fn shift_position(position : (Int32, Int32), pair : Pair) -> (Int32, Int32) {
  let (x, y) = position
  let lhs = pair.source
  let rhs = pair.target
  if lhs.is_x() {
    let dx = if lhs == L { -1 } else { 1 }
    if !rhs.is_x() {
      (x + dx, y + (if rhs == T { 1 } else { -1 }))
    } else {
      (x + dx, y)
    }
  } else {
    let dy = if lhs == T { 1 } else { -1 }
    if rhs.is_x() {
      (x + (if rhs == L { 1 } else { -1 }), y + dy)
    } else {
      (x, y + dy)
    }
  }
}

///|
/// How two groups an edge joins are placed: side by side or one above the
/// other.
priv enum Alignment {
  Horizontal
  Vertical
} derive(Eq)

///|
/// `getArchitectureDirectionAlignment` for an edge that does not bend.
fn alignment_of(a : Direction, b : Direction) -> Alignment? {
  if is_xy(a, b) {
    None
  } else if a.is_x() {
    Some(Horizontal)
  } else {
    Some(Vertical)
  }
}

///|
/// `architectureGroupAlignmentKey`: the ids sorted, as JSON strings.
fn group_alignment_key(a : String, b : String) -> String {
  let (lower, upper) = if utf16_less(b, a) { (b, a) } else { (a, b) }
  "\{json_string(lower)}-\{json_string(upper)}"
}

///|
/// The order of `Array.prototype.sort` without a comparator: by UTF-16 code
/// units.
fn utf16_less(a : String, b : String) -> Bool {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return a[i] < b[i]
    }
  }
  a.length() < b.length()
}

///|
/// `JSON.stringify` of a string.
fn json_string(text : String) -> String {
  Json::string(text).stringify()
}

///|
/// The nodes of one connected part of the diagram on a grid, as the edge
/// sides place them: `ArchitectureSpatialMap`, in insertion order.
priv struct SpatialMap {
  ids : Array[String]
  positions : Map[String, (Int32, Int32)]
}

///|
/// `getDataStructures`.
priv struct DataStructures {
  spatial_maps : Array[SpatialMap]
  group_alignments : Map[String, Alignment]
}

///|
/// The diagram: upstream's `ArchitectureDB`.
pub struct Db {
  /// Services and junctions in the order they were added.
  nodes : Map[String, Node]
  groups : Map[String, Group]
  edges : Array[Edge]
  layout_hints : Array[LayoutHint]
  /// What each id names: a node or a group.
  registered : Map[String, Bool]
  mut title : String
  mut acc_title : String
  mut acc_description : String
}

///|
fn Db::new() -> Db {
  {
    nodes: Map([]),
    groups: Map([]),
    edges: [],
    layout_hints: [],
    registered: Map([]),
    title: "",
    acc_title: "",
    acc_description: "",
  }
}

///|
/// What an id is registered as, in upstream's words.
fn Db::registered_as(self : Db, id : String) -> String {
  match self.registered.get(id) {
    Some(true) => "node"
    Some(false) => "group"
    None => "undefined"
  }
}

///|
/// The checks of a parent shared by services, junctions and groups.
fn Db::check_parent(
  self : Db,
  kind : String,
  id : String,
  parent : String?,
) -> Unit raise ArchitectureError {
  guard parent is Some(parent) else { return }
  if id == parent {
    raise Invalid("The \{kind} [\{id}] cannot be placed within itself")
  }
  if !self.registered.contains(parent) {
    raise Invalid(
      "The \{kind} [\{id}]'s parent does not exist. Please make sure the parent is created before this \{kind}",
    )
  }
  if self.registered.get(parent) == Some(true) {
    raise Invalid("The \{kind} [\{id}]'s parent is not a group")
  }
}

///|
/// `addService`.
fn Db::add_service(
  self : Db,
  id : String,
  icon : String?,
  icon_text : String?,
  title : String?,
  parent : String?,
) -> Unit raise ArchitectureError {
  if self.registered.contains(id) {
    raise Invalid(
      "The service id [\{id}] is already in use by another \{self.registered_as(id)}",
    )
  }
  self.check_parent("service", id, parent)
  self.registered[id] = true
  self.nodes[id] = {
    id,
    kind: Service(icon~, icon_text~, title~),
    parent,
    edges: [],
  }
}

///|
/// `addJunction`.
fn Db::add_junction(
  self : Db,
  id : String,
  parent : String?,
) -> Unit raise ArchitectureError {
  if self.registered.contains(id) {
    raise Invalid(
      "The junction id [\{id}] is already in use by another \{self.registered_as(id)}",
    )
  }
  self.check_parent("junction", id, parent)
  self.registered[id] = true
  self.nodes[id] = { id, kind: Junction, parent, edges: [], }
}

///|
/// `addGroup`.
fn Db::add_group(
  self : Db,
  id : String,
  icon : String?,
  title : String?,
  parent : String?,
) -> Unit raise ArchitectureError {
  if self.registered.contains(id) {
    raise Invalid(
      "The group id [\{id}] is already in use by another \{self.registered_as(id)}",
    )
  }
  self.check_parent("group", id, parent)
  self.registered[id] = false
  self.groups[id] = { id, icon, title, parent, }
}

///|
/// `addEdge`.
fn Db::add_edge(self : Db, edge : Edge) -> Unit raise ArchitectureError {
  let { lhs_id, rhs_id, .. } = edge
  if !self.nodes.contains(lhs_id) && !self.groups.contains(lhs_id) {
    raise Invalid(
      "The left-hand id [\{lhs_id}] does not yet exist. Please create the service/group before declaring an edge to it.",
    )
  }
  if !self.nodes.contains(rhs_id) && !self.groups.contains(rhs_id) {
    raise Invalid(
      "The right-hand id [\{rhs_id}] does not yet exist. Please create the service/group before declaring an edge to it.",
    )
  }
  // Upstream reads the group of either end as a node's; a group has none
  // and the property access fails.
  guard self.nodes.get(lhs_id) is Some(lhs) else {
    raise Invalid("Cannot read properties of undefined (reading 'in')")
  }
  guard self.nodes.get(rhs_id) is Some(rhs) else {
    raise Invalid("Cannot read properties of undefined (reading 'in')")
  }
  let same_group = match (lhs.parent, rhs.parent) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
  if edge.lhs_group && same_group {
    raise Invalid(
      "The left-hand id [\{lhs_id}] is modified to traverse the group boundary, but the edge does not pass through two groups.",
    )
  }
  if edge.rhs_group && same_group {
    raise Invalid(
      "The right-hand id [\{rhs_id}] is modified to traverse the group boundary, but the edge does not pass through two groups.",
    )
  }
  self.edges.push(edge)
  lhs.edges.push(edge)
  rhs.edges.push(edge)
}

///|
/// `addLayoutHint`.
fn Db::add_layout_hint(
  self : Db,
  hint : LayoutHint,
) -> Unit raise ArchitectureError {
  let direction = match hint.direction {
    Row => "row"
    Column => "column"
  }
  let seen : Map[String, Unit] = Map([])
  for id in hint.members {
    if self.registered.get(id) != Some(true) {
      raise Invalid(
        "align \{direction} references [\{id}], which is not a service or junction",
      )
    }
    if seen.contains(id) {
      raise Invalid("align \{direction} lists [\{id}] more than once")
    }
    seen[id] = ()
  }
  self.layout_hints.push(hint)
}

///|
/// The services, in the order they were added.
fn Db::services(self : Db) -> Array[Node] {
  self.nodes.values().filter(node => node.kind is Service(..)).collect()
}

///|
/// The junctions, in the order they were added.
fn Db::junctions(self : Db) -> Array[Node] {
  self.nodes.values().filter(node => node.kind is Junction).collect()
}

///|
/// `getDataStructures`: the nodes of every connected part on a grid, and
/// how the groups joined by straight edges are placed.
fn Db::data_structures(self : Db) -> DataStructures {
  let group_alignments : Map[String, Alignment] = Map([])
  // The neighbours of every node by the pair of sides that join them; a
  // later edge with the same pair replaces the neighbour in its place.
  let adjacency : Map[String, Map[Pair, String]] = Map([])
  for id, node in self.nodes {
    let directions : Map[Pair, String] = Map([])
    for edge in node.edges {
      let lhs_group = self.nodes.get(edge.lhs_id).bind(node => node.parent)
      let rhs_group = self.nodes.get(edge.rhs_id).bind(node => node.parent)
      if lhs_group is Some(a) && rhs_group is Some(b) && a != b {
        if alignment_of(edge.lhs_dir, edge.rhs_dir) is Some(alignment) {
          group_alignments[group_alignment_key(a, b)] = alignment
        }
      }
      if edge.lhs_id == id {
        if pair_of(edge.lhs_dir, edge.rhs_dir) is Some(pair) {
          directions[pair] = edge.rhs_id
        }
      } else if pair_of(edge.rhs_dir, edge.lhs_dir) is Some(pair) {
        directions[pair] = edge.lhs_id
      }
    }
    adjacency[id] = directions
  }
  let visited : Map[String, Unit] = Map([])
  // Upstream's `notVisited` set: the ids not visited yet, in order.
  let not_visited : Map[String, Unit] = Map([])
  for id, _ in adjacency {
    not_visited[id] = ()
  }
  let spatial_maps = []
  while not_visited.iter().head() is Some((start, _)) {
    let map : SpatialMap = { ids: [start], positions: Map([(start, (0, 0))]), }
    let queue = [start]
    let mut next = 0
    while next < queue.length() {
      let id = queue[next]
      next += 1
      visited[id] = ()
      not_visited.remove(id)
      let position = map.positions.get(id).unwrap()
      for pair, rhs_id in adjacency.get(id).unwrap() {
        if !visited.contains(rhs_id) {
          if !map.positions.contains(rhs_id) {
            map.ids.push(rhs_id)
          }
          map.positions[rhs_id] = shift_position(position, pair)
          queue.push(rhs_id)
        }
      }
    }
    spatial_maps.push(map)
  }
  { spatial_maps, group_alignments, }
}
