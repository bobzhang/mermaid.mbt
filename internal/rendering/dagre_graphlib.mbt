// The graph mermaid hands to dagre and what it does to it before the
// layout: mermaid's `layout-algorithms/dagre/mermaid-graphlib.js`. A group
// whose nodes have no edge to the world outside it is cut out of the graph
// into a graph of its own, laid out by itself and placed in the outer
// layout as one node; an edge to a group that stays is redirected to a
// node inside it.

///|
/// The label of a graph: the options dagre lays it out with.
priv struct DagreGraphLabel {
  rankdir : String?
  nodesep : Double?
  ranksep : Double?
  marginx : Double
  marginy : Double
}

///|
/// A group cut out of its graph, standing for it in the outer layout:
/// `{ clusterNode: true, id, clusterData, graph }`.
priv struct ClusterNode {
  id : String
  /// The node of the group, as the outer graph had it.
  data : Node
  graph : DagreGraph
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  /// How much the frame of the group is wider than its layout.
  mut diff : Double
}

///|
/// The label of a node of the graph.
priv enum DagreNode {
  /// A copy of a node of the diagram, or one of the two nodes a self loop
  /// goes around; the layout writes its position into it.
  Leaf(Node)
  Extracted(ClusterNode)
  /// A node only an edge or a child names: graphlib's `undefined`.
  Unlabelled
}

///|
/// The label of an edge: a copy of an edge of the diagram, and what
/// mermaid adds to it.
priv struct DagreEdge {
  edge : Edge
  /// The group the edge was redirected from or to.
  mut from_cluster : String?
  mut to_cluster : String?
  /// For the three pieces a self loop is cut into: the id of the loop and
  /// the place of the piece.
  self_loop : (String, Int32)?
  /// The edge of the diagram a piece of a self loop comes from.
  original : Edge?
}

///|
type DagreGraph = @graphlib.Graph[DagreGraphLabel, DagreNode, DagreEdge]

///|
fn new_dagre_graph(label : DagreGraphLabel) -> DagreGraph {
  @graphlib.Graph::new(
    label,
    default_node=_ => Unlabelled,
    multigraph=true,
    compound=true,
  )
}

///|
/// What mermaid knows of a group: `clusterDb`.
priv struct ClusterEntry {
  /// The node edges to the group are redirected to.
  mut id : String?
  cluster_data : Node?
  mut external_connections : Bool
  /// The node of the group once it is measured, which is where the layout
  /// puts it.
  mut node : DagreNode?
}

///|
/// The state of one dagre rendering: mermaid's module-level maps.
priv struct DagreState {
  cluster_db : Map[String, ClusterEntry]
  descendants : Map[String, Array[String]]
  parents : Map[String, String]
  /// The label groups of the edges and their terminal labels, by edge id.
  edge_labels : Map[String, @dom.Element]
  terminal_labels : Map[String, Array[TerminalLabel]]
  /// The element of each node, by node id: `nodeElems`.
  node_elements : Map[String, @dom.Element]
  /// The frames of the groups drawn so far, by node id: what `insertCluster`
  /// leaves on the node.
  diffs : Map[String, Double]
  data : LayoutData
  env : Env
  label_env : Env
}

///|
fn layout_error(error : @graphlib.GraphError) -> LayoutError {
  let @graphlib.GraphError(message) = error
  LayoutError(message)
}

///|
fn DagreState::is_descendant(
  self : DagreState,
  id : String,
  ancestor_id : String,
) -> Bool {
  self.descendants.get(ancestor_id).unwrap_or([]).contains(id)
}

///|
fn DagreState::edge_in_cluster(
  self : DagreState,
  edge : @graphlib.Edge,
  cluster_id : String,
) -> Bool {
  let cluster_descendants = self.descendants.get(cluster_id).unwrap_or([])
  if edge.v == cluster_id || edge.w == cluster_id {
    return false
  }
  cluster_descendants.contains(edge.v) ||
  self.is_descendant(edge.v, cluster_id) ||
  self.is_descendant(edge.w, cluster_id) ||
  cluster_descendants.contains(edge.w)
}

///|
/// Move the nodes of a group (and the group itself, below the root of the
/// copy) into `new_graph`, with the edges among them, removing them from
/// `graph`.
fn DagreState::copy(
  self : DagreState,
  cluster_id : String,
  graph : DagreGraph,
  new_graph : DagreGraph,
  root_id : String,
) -> Unit raise LayoutError {
  let nodes = graph.children(cluster_id)
  if cluster_id != root_id {
    nodes.push(cluster_id)
  }
  for node in nodes {
    if !graph.children(node).is_empty() {
      self.copy(node, graph, new_graph, root_id)
    } else {
      let data = graph.node(node).unwrap_or(Unlabelled)
      new_graph.set_node(node, data)
      let parent = graph.parent(node)
      if parent != Some(root_id) {
        new_graph.set_parent(node, parent?) catch {
          error => raise layout_error(error)
        }
      }
      if cluster_id != root_id && node != cluster_id {
        new_graph.set_parent(node, parent=cluster_id) catch {
          error => raise layout_error(error)
        }
      }
      // `graph.edges(node)` is every edge of the graph: graphlib's
      // `edges()` takes no node.
      for edge in graph.edges() {
        guard graph.edge(edge) is Some(data) else { continue }
        if self.edge_in_cluster(edge, root_id) {
          new_graph.set_edge(edge.v, edge.w, data, name?=edge.name) catch {
            error => raise layout_error(error)
          }
        }
      }
    }
    graph.remove_node(node)
  }
}

///|
fn DagreState::extract_descendants(
  self : DagreState,
  id : String,
  graph : DagreGraph,
) -> Array[String] {
  let children = graph.children(id)
  let result = children.copy()
  for child in children {
    self.parents[child] = id
    result.append(self.extract_descendants(child, graph))
  }
  result
}

///|
/// The edges at `id1`, with that end renamed `id2`, that `id2` also has.
/// Only whether there are any matters. An end that is `None` is
/// JavaScript's `undefined`, which no node is.
fn find_common_edges(graph : DagreGraph, id1 : String?, id2 : String?) -> Int32 {
  let edges = graph.edges()
  let edges1 = edges.filter(edge => Some(edge.v) == id1 || Some(edge.w) == id1)
  let edges2 = edges.filter(edge => Some(edge.v) == id2 || Some(edge.w) == id2)
  let primed = edges1.map(edge => {
    // The target keeps its name: `edge.w === id1 ? id1 : edge.w`.
    (if Some(edge.v) == id1 { id2 } else { Some(edge.v) }, edge.w)
  })
  primed
  .filter(pair => {
    edges2.iter().any(edge => pair.0 == Some(edge.v) && pair.1 == edge.w)
  })
  .length()
}

///|
/// A node inside the group `id` that is no group itself, preferring one
/// that shares no edge with `cluster_id`.
fn find_non_cluster_child(
  id : String,
  graph : DagreGraph,
  cluster_id : String?,
) -> String? {
  let children = graph.children(id)
  if children.is_empty() {
    return Some(id)
  }
  let mut reserve = None
  for child in children {
    let found = find_non_cluster_child(child, graph, cluster_id)
    let common_edges = find_common_edges(graph, cluster_id, found)
    if found is Some(found) && found != "" {
      if common_edges > 0 {
        reserve = Some(found)
      } else {
        return Some(found)
      }
    }
  }
  reserve
}

///|
fn DagreState::anchor_id(self : DagreState, id : String) -> String? {
  match self.cluster_db.get(id) {
    None => Some(id)
    Some(entry) if !entry.external_connections => Some(id)
    Some(entry) => entry.id
  }
}

///|
/// Redirect the edges at groups to nodes inside them and cut the groups
/// without edges to the outside out of the graph: mermaid's
/// `adjustClustersAndEdges`.
fn DagreState::adjust_clusters_and_edges(
  self : DagreState,
  graph : DagreGraph,
) -> Unit raise LayoutError {
  for id in graph.nodes() {
    if !graph.children(id).is_empty() {
      self.descendants[id] = self.extract_descendants(id, graph)
      let cluster_data = match graph.node(id) {
        Some(Leaf(node)) => Some(node)
        _ => None
      }
      self.cluster_db[id] = {
        id: find_non_cluster_child(id, graph, Some(id)),
        cluster_data,
        external_connections: false,
        node: None,
      }
    }
  }
  for id in graph.nodes() {
    let children = graph.children(id)
    let edges = graph.edges()
    if !children.is_empty() {
      for edge in edges {
        let d1 = self.is_descendant(edge.v, id)
        let d2 = self.is_descendant(edge.w, id)
        if d1 != d2 {
          if self.cluster_db.get(id) is Some(entry) {
            entry.external_connections = true
          }
        }
      }
    }
  }
  for id, entry in self.cluster_db {
    let non_cluster_child = entry.id
    let parent = non_cluster_child.bind(child => graph.parent(child))
    if parent != Some(id) &&
      parent.bind(parent => self.cluster_db.get(parent)) is Some(parent_entry) &&
      !parent_entry.external_connections {
      entry.id = parent
    }
    let has_direct_outgoing_edge = graph
      .edges()
      .iter()
      .any(edge => edge.v == id)
    if non_cluster_child is Some(child) &&
      child != "" &&
      entry.external_connections &&
      has_direct_outgoing_edge &&
      self.is_node_in_extractable_cluster(graph, child, id) {
      let safe_anchor = self.find_safe_anchor_node(
        graph,
        id,
        graph.parent(child),
      )
      if safe_anchor is Some(anchor) && anchor != "" {
        entry.id = Some(anchor)
      }
    }
  }
  for e in graph.edges() {
    guard graph.edge(e) is Some(edge) else { continue }
    if self.cluster_db.contains(e.v) || self.cluster_db.contains(e.w) {
      guard self.anchor_id(e.v) is Some(v) && self.anchor_id(e.w) is Some(w) else {
        raise LayoutError(
          "A group without a node to anchor its edges is not supported.",
        )
      }
      graph.remove_edge(e)
      if v != e.v {
        guard graph.parent(v).bind(parent => self.cluster_db.get(parent))
          is Some(parent_entry) else {
          raise LayoutError("The anchor of the group \{e.v} is not in a group.")
        }
        parent_entry.external_connections = true
        edge.from_cluster = Some(e.v)
      }
      if w != e.w {
        guard graph.parent(w).bind(parent => self.cluster_db.get(parent))
          is Some(parent_entry) else {
          raise LayoutError("The anchor of the group \{e.w} is not in a group.")
        }
        parent_entry.external_connections = true
        edge.to_cluster = Some(e.w)
      }
      graph.set_edge(v, w, edge, name?=e.name) catch {
        error => raise layout_error(error)
      }
    }
  }
  self.extractor(graph, 0)
}

///|
/// Cut the groups without edges to the outside out of `graph`, and out of
/// the graphs cut out, ten levels deep at most.
fn DagreState::extractor(
  self : DagreState,
  graph : DagreGraph,
  depth : Int32,
) -> Unit raise LayoutError {
  if depth > 10 {
    return
  }
  let nodes = graph.nodes()
  let mut has_children = false
  for node in nodes {
    has_children = has_children || !graph.children(node).is_empty()
  }
  if !has_children {
    return
  }
  for node in nodes {
    guard self.cluster_db.get(node) is Some(entry) else { continue }
    if !entry.external_connections && !graph.children(node).is_empty() {
      let settings = graph.graph()
      let mut dir = if settings.rankdir == Some("TB") { "LR" } else { "TB" }
      if entry.cluster_data is Some(data) &&
        data.dir is Some(cluster_dir) &&
        cluster_dir != "" {
        dir = cluster_dir
      }
      let cluster_graph = new_dagre_graph({
        rankdir: Some(dir),
        nodesep: Some(50.0),
        ranksep: Some(50.0),
        marginx: 8.0,
        marginy: 8.0,
      })
      self.copy(node, graph, cluster_graph, node)
      guard entry.cluster_data is Some(data) else {
        raise LayoutError("The group \{node} has no node of its own.")
      }
      graph.set_node(
        node,
        Extracted({
          id: node,
          data,
          graph: cluster_graph,
          x: @double.not_a_number,
          y: @double.not_a_number,
          width: @double.not_a_number,
          height: @double.not_a_number,
          diff: 0.0,
        }),
      )
    }
  }
  for node in graph.nodes() {
    if graph.node(node) is Some(Extracted(cluster)) {
      self.extractor(cluster.graph, depth + 1)
    }
  }
}

///|
/// The nodes of the graph from the outermost in: the top level, then what
/// each of its nodes holds in turn. Mermaid's `sortNodesByHierarchy`.
fn sort_nodes_by_hierarchy(graph : DagreGraph) -> Array[String] {
  fn sorter(nodes : Array[String]) -> Array[String] {
    let result = nodes.copy()
    for node in nodes {
      result.append(sorter(graph.children(node)))
    }
    result
  }

  sorter(graph.top_children())
}

///|
fn DagreState::is_node_in_extractable_cluster(
  self : DagreState,
  graph : DagreGraph,
  node : String,
  root_id : String,
) -> Bool {
  let mut parent = graph.parent(node)
  while parent is Some(current) && current != "" && current != root_id {
    if self.cluster_db.get(current) is Some(cluster) &&
      !cluster.external_connections {
      return true
    }
    parent = graph.parent(current)
  }
  false
}

///|
fn DagreState::find_safe_anchor_node(
  self : DagreState,
  graph : DagreGraph,
  cluster_id : String,
  excluded_cluster : String?,
) -> String? {
  for child in graph.children(cluster_id) {
    let excluded = match excluded_cluster {
      Some(excluded) => child == excluded || self.is_descendant(child, excluded)
      // `isDescendant(child, undefined)`: no group is undefined.
      None => false
    }
    if excluded {
      continue
    }
    guard find_non_cluster_child(child, graph, Some(cluster_id))
      is Some(candidate) &&
      candidate != "" else {
      continue
    }
    if !self.is_node_in_extractable_cluster(graph, candidate, cluster_id) {
      return Some(candidate)
    }
  }
  None
}
