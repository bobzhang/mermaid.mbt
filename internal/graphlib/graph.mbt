// A transcription of graphlib's `Graph` as dagre-d3-es 7.0.14 ships it
// (`src/graphlib/graph.js`): a directed or undirected multigraph whose
// nodes may be nested. Everything a layout depends on is kept: the order
// of `nodes()`, `children()`, `predecessors()`, `successors()` and
// `edges()`, and where a node or an edge that is removed and added again
// ends up in them.

///|
/// The name of the edge between two nodes of a graph that is not a
/// multigraph, and the parent of the nodes that have none.
const DEFAULT_EDGE_NAME : String = "\u{00}"

///|
const GRAPH_NODE : String = "\u{00}"

///|
const EDGE_KEY_DELIM : String = "\u{01}"

///|
/// What identifies an edge: its ends and, in a multigraph, its name.
pub(all) struct Edge {
  v : String
  w : String
  name : String?
} derive(Eq, Hash, Debug)

///|
pub(all) suberror GraphError {
  GraphError(String)
} derive(Debug)

///|
/// A graph with a label of its own (`G`), one per node (`N`) and one per
/// edge (`E`).
pub struct Graph[G, N, E] {
  priv directed : Bool
  priv multigraph : Bool
  priv compound : Bool
  priv mut label : G
  /// The label of a node that is created without one.
  priv default_node : (String) -> N
  priv nodes : JsObject[N]
  priv parents : Map[String, String]
  priv children : Map[String, JsObject[Unit]]
  /// The edges into each node and out of it, by edge key.
  priv ins : Map[String, Map[String, Edge]]
  priv outs : Map[String, Map[String, Edge]]
  /// How many edges join each node to each of its neighbours.
  priv preds : Map[String, JsObject[Int32]]
  priv sucs : Map[String, JsObject[Int32]]
  priv edge_objs : Map[String, Edge]
  priv edge_labels : Map[String, E]
  priv mut node_count : Int32
  priv mut edge_count : Int32
}

///|
/// A graph without nodes. `default_node` labels the nodes that are created
/// as the end of an edge or as the parent of a node.
pub fn[G, N, E] Graph::new(
  label : G,
  default_node~ : (String) -> N,
  directed~ : Bool = true,
  multigraph~ : Bool = false,
  compound~ : Bool = false,
) -> Graph[G, N, E] {
  let children = Map([])
  if compound {
    children[GRAPH_NODE] = JsObject::new()
  }
  {
    directed,
    multigraph,
    compound,
    label,
    default_node,
    nodes: JsObject::new(),
    parents: Map([]),
    children,
    ins: Map([]),
    outs: Map([]),
    preds: Map([]),
    sucs: Map([]),
    edge_objs: Map([]),
    edge_labels: Map([]),
    node_count: 0,
    edge_count: 0,
  }
}

///|
pub fn[G, N, E] Graph::is_directed(self : Graph[G, N, E]) -> Bool {
  self.directed
}

///|
pub fn[G, N, E] Graph::is_multigraph(self : Graph[G, N, E]) -> Bool {
  self.multigraph
}

///|
pub fn[G, N, E] Graph::is_compound(self : Graph[G, N, E]) -> Bool {
  self.compound
}

///|
pub fn[G, N, E] Graph::set_graph(self : Graph[G, N, E], label : G) -> Unit {
  self.label = label
}

///|
/// The label of the graph.
pub fn[G, N, E] Graph::graph(self : Graph[G, N, E]) -> G {
  self.label
}

///|
pub fn[G, N, E] Graph::node_count(self : Graph[G, N, E]) -> Int32 {
  self.node_count
}

///|
/// The ids of the nodes, in the order of the keys of a JavaScript object.
pub fn[G, N, E] Graph::nodes(self : Graph[G, N, E]) -> Array[String] {
  self.nodes.keys()
}

///|
/// The nodes no edge points at.
pub fn[G, N, E] Graph::sources(self : Graph[G, N, E]) -> Array[String] {
  self.nodes().filter(v => self.ins.get(v) is Some(edges) && edges.is_empty())
}

///|
/// The nodes no edge leaves.
pub fn[G, N, E] Graph::sinks(self : Graph[G, N, E]) -> Array[String] {
  self.nodes().filter(v => self.outs.get(v) is Some(edges) && edges.is_empty())
}

///|
fn[G, N, E] Graph::add_node(
  self : Graph[G, N, E],
  v : String,
  value : N,
) -> Unit {
  self.nodes.set(v, value)
  if self.compound {
    self.parents[v] = GRAPH_NODE
    self.children[v] = JsObject::new()
    if self.children.get(GRAPH_NODE) is Some(top) {
      top.set(v, ())
    }
  }
  self.ins[v] = Map([])
  self.preds[v] = JsObject::new()
  self.outs[v] = Map([])
  self.sucs[v] = JsObject::new()
  self.node_count += 1
}

///|
/// `setNode(v, value)`: create the node or replace its label.
pub fn[G, N, E] Graph::set_node(
  self : Graph[G, N, E],
  v : String,
  value : N,
) -> Unit {
  if self.nodes.contains(v) {
    self.nodes.set(v, value)
  } else {
    self.add_node(v, value)
  }
}

///|
/// `setNode(v)`: create the node with the default label unless it exists.
pub fn[G, N, E] Graph::ensure_node(self : Graph[G, N, E], v : String) -> Unit {
  if !self.nodes.contains(v) {
    self.add_node(v, (self.default_node)(v))
  }
}

///|
/// The label of a node, if the graph has it.
pub fn[G, N, E] Graph::node(self : Graph[G, N, E], v : String) -> N? {
  self.nodes.get(v)
}

///|
pub fn[G, N, E] Graph::has_node(self : Graph[G, N, E], v : String) -> Bool {
  self.nodes.contains(v)
}

///|
/// Remove a node and the edges at it. Its children become children of
/// the graph.
pub fn[G, N, E] Graph::remove_node(self : Graph[G, N, E], v : String) -> Unit {
  guard self.nodes.contains(v) else { return }
  self.nodes.remove(v)
  if self.compound {
    self.remove_from_parents_child_list(v)
    self.parents.remove(v)
    for child in self.children(v) {
      // `setParent(child)` of a node that exists, to a parent that does.
      self.remove_from_parents_child_list(child)
      self.parents[child] = GRAPH_NODE
      if self.children.get(GRAPH_NODE) is Some(top) {
        top.set(child, ())
      }
    }
    self.children.remove(v)
  }
  if self.ins.get(v) is Some(edges) {
    for edge in edges.values().collect() {
      self.remove_edge(edge)
    }
  }
  self.ins.remove(v)
  self.preds.remove(v)
  if self.outs.get(v) is Some(edges) {
    for edge in edges.values().collect() {
      self.remove_edge(edge)
    }
  }
  self.outs.remove(v)
  self.sucs.remove(v)
  self.node_count -= 1
}

///|
/// `setParent(v, parent)`: nest `v` in `parent`, or in the graph itself
/// without one. Both nodes are created if they are missing.
pub fn[G, N, E] Graph::set_parent(
  self : Graph[G, N, E],
  v : String,
  parent? : String,
) -> Unit raise GraphError {
  if !self.compound {
    raise GraphError("Cannot set parent in a non-compound graph")
  }
  let parent = match parent {
    None => GRAPH_NODE
    Some(parent) => {
      let mut ancestor = Some(parent)
      while ancestor is Some(current) {
        if current == v {
          raise GraphError(
            "Setting \{parent} as parent of \{v} would create a cycle",
          )
        }
        ancestor = self.parent(current)
      }
      self.ensure_node(parent)
      parent
    }
  }
  self.ensure_node(v)
  self.remove_from_parents_child_list(v)
  self.parents[v] = parent
  if self.children.get(parent) is Some(children) {
    children.set(v, ())
  }
}

///|
fn[G, N, E] Graph::remove_from_parents_child_list(
  self : Graph[G, N, E],
  v : String,
) -> Unit {
  if self.parents.get(v) is Some(parent) &&
    self.children.get(parent) is Some(children) {
    children.remove(v)
  }
}

///|
/// The node `v` is nested in, if any.
pub fn[G, N, E] Graph::parent(self : Graph[G, N, E], v : String) -> String? {
  if self.compound &&
    self.parents.get(v) is Some(parent) &&
    parent != GRAPH_NODE {
    Some(parent)
  } else {
    None
  }
}

///|
/// The nodes nested directly in `v`. A node the graph does not have has
/// none.
pub fn[G, N, E] Graph::children(
  self : Graph[G, N, E],
  v : String,
) -> Array[String] {
  if self.compound && self.children.get(v) is Some(children) {
    children.keys()
  } else {
    []
  }
}

///|
/// `children()`: the nodes that are nested in no other.
pub fn[G, N, E] Graph::top_children(self : Graph[G, N, E]) -> Array[String] {
  if self.compound {
    self.children(GRAPH_NODE)
  } else {
    self.nodes()
  }
}

///|
/// The nodes with an edge to `v`, each once.
pub fn[G, N, E] Graph::predecessors(
  self : Graph[G, N, E],
  v : String,
) -> Array[String] {
  match self.preds.get(v) {
    Some(preds) => preds.keys()
    None => []
  }
}

///|
/// The nodes with an edge from `v`, each once.
pub fn[G, N, E] Graph::successors(
  self : Graph[G, N, E],
  v : String,
) -> Array[String] {
  match self.sucs.get(v) {
    Some(sucs) => sucs.keys()
    None => []
  }
}

///|
/// The predecessors of `v`, then the successors that are not among them.
pub fn[G, N, E] Graph::neighbors(
  self : Graph[G, N, E],
  v : String,
) -> Array[String] {
  let result = self.predecessors(v)
  let seen : Map[String, Unit] = Map([])
  for u in result {
    seen[u] = ()
  }
  for w in self.successors(v) {
    if !seen.contains(w) {
      seen[w] = ()
      result.push(w)
    }
  }
  result
}

///|
pub fn[G, N, E] Graph::edge_count(self : Graph[G, N, E]) -> Int32 {
  self.edge_count
}

///|
/// The edges, in the order they were added.
pub fn[G, N, E] Graph::edges(self : Graph[G, N, E]) -> Array[Edge] {
  self.edge_objs.values().collect()
}

///|
/// The key of an edge: `edgeArgsToId`.
fn edge_id(directed : Bool, v : String, w : String, name : String?) -> String {
  let (v, w) = if !directed && compare_strings(v, w) > 0 {
    (w, v)
  } else {
    (v, w)
  }
  v + EDGE_KEY_DELIM + w + EDGE_KEY_DELIM + name.unwrap_or(DEFAULT_EDGE_NAME)
}

///|
fn[G, N, E] Graph::insert_edge(
  self : Graph[G, N, E],
  v : String,
  w : String,
  name : String?,
  value : () -> E,
) -> Unit raise GraphError {
  let key = edge_id(self.directed, v, w, name)
  if name is Some(_) && !self.multigraph {
    raise GraphError("Cannot set a named edge when isMultigraph = false")
  }
  self.ensure_node(v)
  self.ensure_node(w)
  self.edge_labels[key] = value()
  // `edgeArgsToObj`: the ends in order for an undirected graph, and no
  // name when it is empty.
  let (v, w) = if !self.directed && compare_strings(v, w) > 0 {
    (w, v)
  } else {
    (v, w)
  }
  let edge = { v, w, name: if name is Some("") { None } else { name }, }
  self.edge_objs[key] = edge
  if self.preds.get(w) is Some(preds) {
    preds.set(v, preds.get(v).unwrap_or(0) + 1)
  }
  if self.sucs.get(v) is Some(sucs) {
    sucs.set(w, sucs.get(w).unwrap_or(0) + 1)
  }
  if self.ins.get(w) is Some(edges) {
    edges[key] = edge
  }
  if self.outs.get(v) is Some(edges) {
    edges[key] = edge
  }
  self.edge_count += 1
}

///|
/// `setEdge(v, w, value, name)`: create the edge or replace its label.
pub fn[G, N, E] Graph::set_edge(
  self : Graph[G, N, E],
  v : String,
  w : String,
  value : E,
  name? : String,
) -> Unit raise GraphError {
  let key = edge_id(self.directed, v, w, name)
  if self.edge_labels.contains(key) {
    self.edge_labels[key] = value
  } else {
    self.insert_edge(v, w, name, () => value)
  }
}

///|
/// `setEdge(edge, value)`.
pub fn[G, N, E] Graph::set_edge_obj(
  self : Graph[G, N, E],
  edge : Edge,
  value : E,
) -> Unit raise GraphError {
  self.set_edge(edge.v, edge.w, value, name?=edge.name)
}

///|
/// `setEdge(v, w)` of a graph whose edges have no label of their own:
/// create the edge with `default` unless it exists.
pub fn[G, N, E] Graph::ensure_edge(
  self : Graph[G, N, E],
  v : String,
  w : String,
  default : () -> E,
  name? : String,
) -> Unit raise GraphError {
  let key = edge_id(self.directed, v, w, name)
  if !self.edge_labels.contains(key) {
    self.insert_edge(v, w, name, default)
  }
}

///|
/// The label of an edge, if the graph has it.
pub fn[G, N, E] Graph::edge(self : Graph[G, N, E], edge : Edge) -> E? {
  self.edge_labels.get(edge_id(self.directed, edge.v, edge.w, edge.name))
}

///|
/// The label of the edge from `v` to `w` called `name`.
pub fn[G, N, E] Graph::edge_between(
  self : Graph[G, N, E],
  v : String,
  w : String,
  name? : String,
) -> E? {
  self.edge_labels.get(edge_id(self.directed, v, w, name))
}

///|
pub fn[G, N, E] Graph::has_edge(
  self : Graph[G, N, E],
  v : String,
  w : String,
  name? : String,
) -> Bool {
  self.edge_labels.contains(edge_id(self.directed, v, w, name))
}

///|
pub fn[G, N, E] Graph::remove_edge(self : Graph[G, N, E], edge : Edge) -> Unit {
  self.remove_edge_between(edge.v, edge.w, name?=edge.name)
}

///|
pub fn[G, N, E] Graph::remove_edge_between(
  self : Graph[G, N, E],
  v : String,
  w : String,
  name? : String,
) -> Unit {
  let key = edge_id(self.directed, v, w, name)
  guard self.edge_objs.get(key) is Some(edge) else { return }
  self.edge_labels.remove(key)
  self.edge_objs.remove(key)
  if self.preds.get(edge.w) is Some(preds) {
    decrement_or_remove(preds, edge.v)
  }
  if self.sucs.get(edge.v) is Some(sucs) {
    decrement_or_remove(sucs, edge.w)
  }
  if self.ins.get(edge.w) is Some(edges) {
    edges.remove(key)
  }
  if self.outs.get(edge.v) is Some(edges) {
    edges.remove(key)
  }
  self.edge_count -= 1
}

///|
fn decrement_or_remove(counts : JsObject[Int32], key : String) -> Unit {
  let count = counts.get(key).unwrap_or(0) - 1
  if count == 0 {
    counts.remove(key)
  } else {
    counts.set(key, count)
  }
}

///|
/// The edges into `v`, only those from `u` when it is given.
pub fn[G, N, E] Graph::in_edges(
  self : Graph[G, N, E],
  v : String,
  u? : String,
) -> Array[Edge] {
  guard self.ins.get(v) is Some(edges) else { return [] }
  let edges = edges.values().collect()
  match u {
    // An empty name is no filter: `if (!u)`.
    None | Some("") => edges
    Some(u) => edges.filter(edge => edge.v == u)
  }
}

///|
/// The edges out of `v`, only those to `w` when it is given.
pub fn[G, N, E] Graph::out_edges(
  self : Graph[G, N, E],
  v : String,
  w? : String,
) -> Array[Edge] {
  guard self.outs.get(v) is Some(edges) else { return [] }
  let edges = edges.values().collect()
  match w {
    None | Some("") => edges
    Some(w) => edges.filter(edge => edge.w == w)
  }
}

///|
/// The edges into `v`, then those out of it.
pub fn[G, N, E] Graph::node_edges(
  self : Graph[G, N, E],
  v : String,
  w? : String,
) -> Array[Edge] {
  let edges = self.in_edges(v, u?=w)
  edges.append(self.out_edges(v, w?))
  edges
}
