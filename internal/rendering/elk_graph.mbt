// Building the graph handed to ELK: the first half of mermaid's
// `layout-algorithms/elk/render.ts`.

///|
/// Margin kept free at the ends of each side of a node, so that a port
/// cannot sit on a corner.
const PORTS_SURROUNDING_MARGIN : Double = 12.0

///|
const PORTS_SURROUNDING : String = "[top=12,left=12,bottom=12,right=12]"

///|
/// Padding between a subgraph frame and its children.
const SUBGRAPH_PADDING : Double = 24.0

///|
/// Where ELK put a node, in absolute coordinates.
priv struct Offset {
  mut pos_x : Double
  mut pos_y : Double
}

///|
/// The measured title of a group.
priv struct LabelData {
  width : Double
  height : Double
}

///|
/// ELK's view of a node: upstream's `nodeDb` entry, a copy of the layout
/// node taken after measuring.
priv struct ElkNode {
  node : Node
  children : Array[ElkNode]
  mut width : Double?
  mut height : Double?
  mut x : Double
  mut y : Double
  mut offset : Offset?
  /// Where ELK put a container whose drawn frame was moved afterwards.
  mut elk_origin : Point?
  mut label_data : LabelData?
  /// Whether the group was configured as a container.
  mut configured : Bool
  layout_options : Map[String, Json]
}

///|
/// An edge as handed to ELK, possibly the other way round.
priv struct ElkEdge {
  edge : Edge
  mut source : String
  mut target : String
  mut reversed : Bool
}

///|
/// The parent and children of every node inside a subgraph.
priv struct Tree {
  parent_by_id : Map[String, String]
  children_by_id : Map[String, Array[String]]
}

///|
priv struct ElkState {
  root_options : Map[String, Json]
  children : Array[ElkNode]
  edges : Array[ElkEdge]
  node_db : Map[String, ElkNode]
  tree : Tree
}

///|
fn dir_to_elk_direction(dir : String) -> String {
  match dir {
    "LR" => "RIGHT"
    "RL" => "LEFT"
    "BT" => "UP"
    _ => "DOWN"
  }
}

///|
/// The layout choices a preset makes: layering, root placement, container
/// placement, alignment, cycle breaking.
fn elk_preset(name : String?) -> (String, String, String, String, String) {
  match name {
    Some("legacy") =>
      ("NETWORK_SIMPLEX", "BRANDES_KOEPF", "BRANDES_KOEPF", "NONE", "GREEDY")
    Some("modelOrder") =>
      (
        "NETWORK_SIMPLEX", "NETWORK_SIMPLEX", "BRANDES_KOEPF", "NONE", "GREEDY_MODEL_ORDER",
      )
    Some("depthFirst") =>
      (
        "NETWORK_SIMPLEX", "NETWORK_SIMPLEX", "BRANDES_KOEPF", "NONE", "DEPTH_FIRST",
      )
    _ =>
      (
        "NETWORK_SIMPLEX", "BRANDES_KOEPF", "BRANDES_KOEPF", "BALANCED", "DEPTH_FIRST",
      )
  }
}

///|
/// Set an option unless the configuration leaves it undefined.
fn set_option(options : Map[String, Json], key : String, value : Json) -> Unit {
  if !(value is Null) {
    options[key] = value
  }
}

///|
fn text_or(value : Json, fallback : String) -> Json {
  match value {
    String(_) => value
    _ => Json::string(fallback)
  }
}

///|
fn root_layout_options(
  data : LayoutData,
  algorithm : String,
) -> Map[String, Json] {
  let config = data.config
  let (layering, placement, _, alignment, cycle_breaking) = elk_preset(
    config.text("elk.preset"),
  )
  let options : Map[String, Json] = Map([])
  options["elk.hierarchyHandling"] = "INCLUDE_CHILDREN"
  options["elk.algorithm"] = Json::string(algorithm)
  options["elk.layered.nodePlacement.strategy"] = text_or(
    config.get("elk.nodePlacementStrategy"),
    placement,
  )
  options["elk.layered.nodePlacement.bk.fixedAlignment"] = text_or(
    config.get("elk.nodePlacementAlignment"),
    alignment,
  )
  set_option(options, "elk.layered.mergeEdges", config.get("elk.mergeEdges"))
  options["elk.direction"] = Json::string(dir_to_elk_direction(data.direction))
  options["spacing.baseValue"] = 40
  set_option(
    options,
    "elk.layered.crossingMinimization.forceNodeModelOrder",
    config.get("elk.forceNodeModelOrder"),
  )
  set_option(
    options,
    "elk.layered.considerModelOrder.strategy",
    config.get("elk.considerModelOrder"),
  )
  options["elk.layered.unnecessaryBendpoints"] = true
  options["elk.layered.cycleBreaking.strategy"] = text_or(
    config.get("elk.cycleBreakingStrategy"),
    cycle_breaking,
  )
  options["elk.layered.layering.strategy"] = text_or(
    config.get("elk.layeringStrategy"),
    layering,
  )
  set_option(
    options,
    "elk.layered.layering.coffmanGraham.layerBound",
    config.get("elk.layeringLayerBound"),
  )
  options["elk.layered.wrapping.multiEdge.improveCuts"] = true
  options["elk.layered.wrapping.multiEdge.improveWrappedEdges"] = true
  options["elk.layered.edgeRouting.selfLoopDistribution"] = "EQUALLY"
  options["elk.layered.mergeHierarchyEdges"] = true
  options["elk.spacing.portsSurrounding"] = Json::string(PORTS_SURROUNDING)
  options
}

///|
/// The width the frame painter needs for a group's title.
fn ElkNode::title_width(self : ElkNode) -> Double {
  if !cluster_paints_title(self.node.shape) {
    return 0.0
  }
  let label_width = match self.label_data {
    Some(data) => data.width
    None => 0.0
  }
  label_width + self.node.padding
}

///|
/// A group is at least as wide as its title.
fn ElkNode::effective_width(self : ElkNode) -> Double {
  let width = self.width.unwrap_or(0.0)
  if self.node.is_group {
    width.max(self.title_width())
  } else {
    width
  }
}

///|
fn subgraph_layout_options(
  node : ElkNode,
  data : LayoutData,
  algorithm : String,
) -> Map[String, Json] {
  let config = data.config
  let (_, _, container_placement, alignment, cycle_breaking) = elk_preset(
    config.text("elk.preset"),
  )
  let options : Map[String, Json] = Map([])
  // Reserve the painted title width before routing.
  if cluster_paints_title(node.node.shape) {
    options["nodeSize.constraints"] = "[MINIMUM_SIZE, NODE_LABELS]"
    options["nodeSize.minimum"] = Json::string(
      "(\{@dom.number(node.title_width())}, 0)",
    )
  }
  options["spacing.baseValue"] = 24
  options["elk.layered.spacing.edgeNodeBetweenLayers"] = 30
  options["elk.spacing.edgeEdge"] = 20
  options["spacing.nodeNode"] = 50
  options["elk.padding"] = "[top=24,left=24,bottom=24,right=24]"
  options["nodeLabels.placement"] = "[H_CENTER V_TOP, INSIDE]"
  set_option(options, "elk.layered.mergeEdges", config.get("elk.mergeEdges"))
  options["elk.layered.nodePlacement.bk.fixedAlignment"] = text_or(
    config.get("elk.nodePlacementAlignment"),
    alignment,
  )
  options["elk.layered.nodePlacement.strategy"] = text_or(
    config.get("elk.nodePlacementStrategy"),
    container_placement,
  )
  options["elk.layered.cycleBreaking.strategy"] = text_or(
    config.get("elk.cycleBreakingStrategy"),
    cycle_breaking,
  )
  options["elk.layered.nodePlacement.networkSimplex.nodeFlexibility"] = "PORT_POSITION"
  options["elk.spacing.portsSurrounding"] = Json::string(PORTS_SURROUNDING)
  if node.node.dir is Some(dir) {
    // A subgraph with its own direction is laid out on its own.
    options["elk.algorithm"] = Json::string(algorithm)
    options["elk.direction"] = Json::string(dir_to_elk_direction(dir))
    options["elk.hierarchyHandling"] = "SEPARATE_CHILDREN"
  }
  options
}

///|
/// The nearest container holding both nodes, `root` when there is none.
fn Tree::common_ancestor(self : Tree, id1 : String, id2 : String) -> String {
  if id1 == id2 {
    return self.parent_by_id.get(id1).unwrap_or("root")
  }
  let visited : Map[String, Unit] = Map([])
  let mut current = Some(id1)
  while current is Some(id) {
    visited[id] = ()
    if id == id2 {
      return id
    }
    current = self.parent_by_id.get(id)
  }
  current = Some(id2)
  while current is Some(id) {
    if visited.contains(id) {
      return id
    }
    current = self.parent_by_id.get(id)
  }
  "root"
}

///|
fn add_vertices(
  nodes : Array[Node],
  into : Array[ElkNode],
  node_db : Map[String, ElkNode],
  parent_id : String?,
) -> Unit {
  for node in nodes {
    guard node.parent_id == parent_id else { continue }
    let child : ElkNode = {
      node,
      children: [],
      width: if node.is_group {
        node.width
      } else {
        Some(node.width.unwrap_or(0.0))
      },
      height: if node.is_group {
        node.height
      } else {
        Some(node.height.unwrap_or(0.0))
      },
      x: node.x,
      y: node.y,
      offset: None,
      elk_origin: None,
      label_data: None,
      configured: false,
      layout_options: {},
    }
    into.push(child)
    node_db[node.id] = child
    if node.is_group {
      add_vertices(nodes, child.children, node_db, Some(node.id))
      child.label_data = match node.label_box {
        Some((width, height)) =>
          Some({ width, height: (height - 2.0).max(0.0), })
        None => Some({ width: 0.0, height: 0.0, })
      }
    }
  }
}

///|
/// Make the containers on the way from a node up to `ancestor` lay out
/// their children together, so that an edge can cross their borders.
fn include_children(
  node_db : Map[String, ElkNode],
  id : String,
  ancestor : String,
) -> Unit {
  guard node_db.get(id) is Some(node) else { return }
  node.layout_options["elk.hierarchyHandling"] = "INCLUDE_CHILDREN"
  if node.node.id != ancestor && node.node.parent_id is Some(parent) {
    include_children(node_db, parent, ancestor)
  }
}

///|
/// The child of `ancestor` that `id` lives in.
fn Tree::child_on_path(self : Tree, id : String, ancestor : String) -> String {
  let mut current = id
  while self.parent_by_id.get(current).unwrap_or("root") != ancestor {
    guard self.parent_by_id.get(current) is Some(parent) else { break }
    current = parent
  }
  current
}

///|
priv struct LevelEdge {
  index : Int32
  from : String
  to : String
  collapsed : Bool
}

///|
/// The edges that re-enter a subgraph against the flow: once every edge is
/// lifted to the children of the container it crosses, those closing a
/// cycle. Mermaid's `findSubgraphFeedbackEdges`.
fn subgraph_feedback_edges(edges : Array[ElkEdge], tree : Tree) -> Array[Bool] {
  let flags = edges.map(_ => false)
  let levels : Map[String, Array[LevelEdge]] = Map([])
  for index, edge in edges {
    let source = edge.source
    let target = edge.target
    if source == target {
      continue
    }
    let ancestor = tree.common_ancestor(source, target)
    if ancestor == source || ancestor == target {
      continue
    }
    let from = tree.child_on_path(source, ancestor)
    let to = tree.child_on_path(target, ancestor)
    let level = match levels.get(ancestor) {
      Some(level) => level
      None => {
        let level = []
        levels[ancestor] = level
        level
      }
    }
    level.push({ index, from, to, collapsed: from != source || to != target, })
  }
  for _, level in levels {
    let successors : Map[String, Array[LevelEdge]] = Map([])
    let nodes = []
    let in_degree : Map[String, Int32] = Map([])
    for edge in level {
      for node in [edge.from, edge.to] {
        if !successors.contains(node) {
          successors[node] = []
          nodes.push(node)
          in_degree[node] = 0
        }
      }
      successors[edge.from].push(edge)
      in_degree[edge.to] = in_degree[edge.to] + 1
    }
    // 1: on the stack, 2: done.
    let state : Map[String, Int32] = Map([])
    let roots = [..nodes.filter(node => in_degree[node] == 0), ..nodes]
    for root in roots {
      if state.contains(root) {
        continue
      }
      state[root] = 1
      let stack : Array[(String, Ref[Int32])] = [(root, Ref(0))]
      while stack.last() is Some((node, next)) {
        let out = successors[node]
        if next.val >= out.length() {
          state[node] = 2
          stack.pop() |> ignore
          continue
        }
        let edge = out[next.val]
        next.val += 1
        match state.get(edge.to) {
          Some(1) => flags[edge.index] = edge.collapsed
          None => {
            state[edge.to] = 1
            stack.push((edge.to, Ref(0)))
          }
          _ => ()
        }
      }
    }
  }
  flags
}

///|
/// The entry node of every flow that loops back on itself, to be pinned to
/// the first layer. Mermaid's `findCyclicEntryNodes`.
fn cyclic_entry_nodes(
  nodes : Array[Node],
  edges : Array[Edge],
) -> Array[String] {
  let entries = []
  let groups : Map[String, Array[String]] = Map([])
  for node in nodes {
    let key = node.parent_id.unwrap_or("\u{0}")
    match groups.get(key) {
      Some(group) => group.push(node.id)
      None => groups[key] = [node.id]
    }
  }
  for _, ids in groups {
    let id_set : Map[String, Unit] = Map([])
    let in_degree : Map[String, Int32] = Map([])
    let neighbors : Map[String, Array[String]] = Map([])
    for id in ids {
      id_set[id] = ()
      in_degree[id] = 0
      neighbors[id] = []
    }
    let internal = []
    for edge in edges {
      let source = edge.start
      let target = edge.end
      if source == "" || target == "" || source == target {
        continue
      }
      if !id_set.contains(source) || !id_set.contains(target) {
        continue
      }
      in_degree[target] = in_degree[target] + 1
      neighbors[source].push(target)
      neighbors[target].push(source)
      internal.push((source, target))
    }
    let component : Map[String, Int32] = Map([])
    let mut count = 0
    for id in ids {
      if component.contains(id) {
        continue
      }
      let stack = [id]
      component[id] = count
      while stack.pop() is Some(current) {
        for next in neighbors[current] {
          if !component.contains(next) {
            component[next] = count
            stack.push(next)
          }
        }
      }
      count += 1
    }
    let has_source = Array::make(count, false)
    for id in ids {
      if in_degree[id] == 0 {
        has_source[component[id]] = true
      }
    }
    if !has_source.contains(false) {
      continue
    }
    let forward : Map[String, Array[String]] = Map([])
    let residual : Map[String, Int32] = Map([])
    for id in ids {
      forward[id] = []
      residual[id] = 0
    }
    let reaches = (from : String, to : String) => {
      let seen : Map[String, Unit] = Map([])
      seen[from] = ()
      let stack = [from]
      let mut found = false
      while stack.pop() is Some(current) {
        if current == to {
          found = true
          break
        }
        for next in forward[current] {
          if !seen.contains(next) {
            seen[next] = ()
            stack.push(next)
          }
        }
      }
      found
    }
    for pair in internal {
      let (source, target) = pair
      if reaches(target, source) {
        continue
      }
      forward[source].push(target)
      residual[target] = residual[target] + 1
    }
    let nominated = Array::make(count, false)
    for id in ids {
      let c = component[id]
      if !has_source[c] && !nominated[c] && residual[id] == 0 {
        entries.push(id)
        nominated[c] = true
      }
    }
  }
  entries
}

///|
/// Mermaid's `buildElkGraphFromLayoutData`.
fn build_elk_state(data : LayoutData, algorithm : String) -> ElkState {
  let node_db : Map[String, ElkNode] = Map([])
  let root_options = root_layout_options(data, algorithm)
  // The containment tree.
  let tree : Tree = { parent_by_id: {}, children_by_id: {}, }
  for subgraph in data.nodes {
    guard subgraph.is_group else { continue }
    for node in data.nodes {
      guard node.parent_id == Some(subgraph.id) else { continue }
      tree.parent_by_id[node.id] = subgraph.id
      match tree.children_by_id.get(subgraph.id) {
        Some(children) => children.push(node.id)
        None => tree.children_by_id[subgraph.id] = [node.id]
      }
    }
  }
  let children = []
  add_vertices(data.nodes, children, node_db, None)
  let edges : Array[ElkEdge] = data.edges.map(edge => {
    edge,
    source: edge.start,
    target: edge.end,
    reversed: false,
  })
  // Containers get their title, options and no size of their own.
  for layout_node in data.nodes {
    guard node_db.get(layout_node.id) is Some(node) else { continue }
    guard tree.children_by_id.contains(layout_node.id) else { continue }
    node.configured = true
    for key, value in subgraph_layout_options(node, data, algorithm) {
      node.layout_options[key] = value
    }
    node.x = 0.0
    node.y = 0.0
    node.width = None
    node.height = None
  }
  // Edges that cross a container border.
  for edge in edges {
    guard node_db.get(edge.source) is Some(source) else { continue }
    guard node_db.get(edge.target) is Some(target) else { continue }
    if source.node.parent_id != target.node.parent_id {
      let ancestor = tree.common_ancestor(edge.source, edge.target)
      include_children(node_db, edge.source, ancestor)
      include_children(node_db, edge.target, ancestor)
    }
  }
  if !(data.config.get("elk.orientFeedbackEdges") is False) {
    let flags = subgraph_feedback_edges(edges, tree)
    for index, edge in edges {
      if flags[index] {
        let source = edge.source
        edge.source = edge.target
        edge.target = source
        edge.reversed = true
      }
    }
  }
  if data.config.flag("elk.keepEntryNodeOnTop") {
    for id in cyclic_entry_nodes(data.nodes, data.edges) {
      if node_db.get(id) is Some(node) {
        node.layout_options["elk.layered.layering.layerConstraint"] = "FIRST"
      }
    }
  }
  { root_options, children, edges, node_db, tree, }
}

///|
fn ElkNode::to_json(self : ElkNode) -> Json {
  let object : Map[String, Json] = { "id": Json::string(self.node.id) }
  if self.width is Some(width) {
    object["width"] = Json::number(width)
  }
  if self.height is Some(height) {
    object["height"] = Json::number(height)
  }
  if self.node.is_group {
    object["children"] = Json::array(
      self.children.map(child => child.to_json()),
    )
  }
  if self.configured && self.label_data is Some(label) {
    object["labels"] = [
      {
        "text": Json::string(self.node.label),
        "width": Json::number(label.width),
        "height": Json::number(label.height),
      },
    ]
  }
  if !self.layout_options.is_empty() {
    object["layoutOptions"] = Json::object(self.layout_options)
  }
  Json::object(object)
}

///|
fn ElkState::to_json(self : ElkState) -> Json {
  let edges : Array[Json] = self.edges.map(edge => {
    let json : Json = {
      "id": Json::string(edge.edge.id),
      "sources": [Json::string(edge.source)],
      "targets": [Json::string(edge.target)],
      "labels": [
        {
          "width": Json::number(edge.edge.width),
          "height": Json::number(edge.edge.height),
          "text": Json::string(edge.edge.label),
          "layoutOptions": {
            "edgeLabels.inline": "true",
            "edgeLabels.placement": "CENTER",
          },
        },
      ],
    }
    json
  })
  {
    "id": "root",
    "layoutOptions": Json::object(self.root_options),
    "children": Json::array(self.children.map(child => child.to_json())),
    "edges": Json::array(edges),
  }
}
