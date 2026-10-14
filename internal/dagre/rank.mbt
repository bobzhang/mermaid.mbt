// dagre's `rank/`: every node gets a rank such that each edge spans at
// least its `minlen`, by network simplex (Gansner et al., "A Technique for
// Drawing Directed Graphs") unless another ranker is asked for.

///|
/// A graph being ranked: the layout graph without its compound nodes, or
/// that with its parallel edges merged.
type RankGraph[E] = @graphlib.Graph[GraphLabel, NodeLabel, E]

///|
/// Ranks by the longest path to a sink: fast, and with many long edges.
fn[E : RankEdge] longest_path(g : RankGraph[E]) -> Unit raise LayoutError {
  let visited : Map[String, Unit] = Map([])
  fn dfs(v : String) -> Int32 raise LayoutError {
    let label = nd(g, v)
    if visited.contains(v) {
      return match label.rank {
        Some(rank) => rank
        None => raise LayoutError("the node \{v} has no rank")
      }
    }
    visited[v] = ()
    let mut rank : Int32? = None
    for e in g.out_edges(v) {
      let candidate = dfs(e.w) - ed(g, e).minlen()
      if rank is Some(current) && current <= candidate {
        continue
      }
      rank = Some(candidate)
    }
    let rank = rank.unwrap_or(0)
    label.rank = Some(rank)
    rank
  }

  for v in g.sources() {
    dfs(v) |> ignore
  }
}

///|
/// How much longer an edge is than it has to be.
fn[E : RankEdge] slack(
  g : RankGraph[E],
  e : @graphlib.Edge,
) -> Int32 raise LayoutError {
  rank_of(g, e.w) - rank_of(g, e.v) - ed(g, e).minlen()
}

///|
/// A node of the spanning tree network simplex works on.
priv struct TreeNode {
  mut low : Int32
  mut lim : Int32
  mut parent : String?
}

///|
priv struct TreeEdge {
  mut cutvalue : Double
}

///|
type Tree = @graphlib.Graph[Unit, TreeNode, TreeEdge]

///|
fn tree_node(t : Tree, v : String) -> TreeNode raise LayoutError {
  match t.node(v) {
    Some(node) => node
    None => raise LayoutError("the node \{v} is not in the tree")
  }
}

///|
/// A spanning tree of tight edges; the ranks are shifted until there is
/// one.
fn[E : RankEdge] feasible_tree(g : RankGraph[E]) -> Tree raise LayoutError {
  let t : Tree = @graphlib.Graph::new(
    (),
    default_node=_ => { low: 0, lim: 0, parent: None, },
    directed=false,
  )
  // Choose arbitrary node from which to start our tree.
  guard g.nodes() is [start, ..] else { return t }
  let size = g.node_count()
  t.set_node(start, { low: 0, lim: 0, parent: None, })
  while tight_tree(t, g) < size {
    guard find_min_slack_edge(t, g) is Some(edge) else {
      raise LayoutError("the graph to rank is not connected")
    }
    let delta = if t.has_node(edge.v) {
      slack(g, edge)
    } else {
      -slack(g, edge)
    }
    for v in t.nodes() {
      let label = nd(g, v)
      label.rank = Some(rank_of(g, v) + delta)
    }
  }
  t
}

///|
/// Grows the tree by the tight edges at its nodes and returns its size.
fn[E : RankEdge] tight_tree(
  t : Tree,
  g : RankGraph[E],
) -> Int32 raise LayoutError {
  fn dfs(v : String) -> Unit raise LayoutError {
    for e in g.node_edges(v) {
      let w = if v == e.v { e.w } else { e.v }
      if !t.has_node(w) && slack(g, e) == 0 {
        t.set_node(w, { low: 0, lim: 0, parent: None, })
        graph_op(() => t.set_edge(v, w, { cutvalue: 0.0, }))
        dfs(w)
      }
    }
  }

  for v in t.nodes() {
    dfs(v)
  }
  t.node_count()
}

///|
/// The edge with the least slack among those with one end in the tree.
fn[E : RankEdge] find_min_slack_edge(
  t : Tree,
  g : RankGraph[E],
) -> @graphlib.Edge? raise LayoutError {
  let mut best : (@graphlib.Edge, Int32)? = None
  for e in g.edges() {
    if t.has_node(e.v) != t.has_node(e.w) {
      let value = slack(g, e)
      if best is Some((_, current)) && current <= value {
        continue
      }
      best = Some((e, value))
    }
  }
  best.map(pair => pair.0)
}

///|
/// The nodes of a graph in the order a depth-first search from `roots`
/// leaves them (`post`) or enters them: graphlib's `alg/dfs.js` for an
/// undirected graph.
fn tree_dfs(t : Tree, roots : Array[String], post : Bool) -> Array[String] {
  let acc = []
  let visited : Map[String, Unit] = Map([])
  fn visit(v : String) -> Unit {
    if visited.contains(v) {
      return
    }
    visited[v] = ()
    if !post {
      acc.push(v)
    }
    for w in t.neighbors(v) {
      visit(w)
    }
    if post {
      acc.push(v)
    }
  }

  for v in roots {
    visit(v)
  }
  acc
}

///|
fn[E : RankEdge] network_simplex(g : RankGraph[E]) -> Unit raise LayoutError {
  let g = simplify(g)
  longest_path(g)
  let t = feasible_tree(g)
  init_low_lim_values(t)
  init_cut_values(t, g)
  while leave_edge(t) is Some(e) {
    let f = enter_edge(t, g, e)
    exchange_edges(t, g, e, f)
  }
}

///|
/// Initializes cut values for all edges in the tree.
fn init_cut_values(
  t : Tree,
  g : RankGraph[SimpleEdge],
) -> Unit raise LayoutError {
  let vs = tree_dfs(t, t.nodes(), true)
  for i in 0..<(vs.length() - 1) {
    assign_cut_value(t, g, vs[i])
  }
}

///|
fn assign_cut_value(
  t : Tree,
  g : RankGraph[SimpleEdge],
  child : String,
) -> Unit raise LayoutError {
  guard tree_node(t, child).parent is Some(parent) else {
    raise LayoutError("the node \{child} has no parent in the tree")
  }
  let value = calc_cut_value(t, g, child, parent)
  match t.edge_between(child, parent) {
    Some(edge) => edge.cutvalue = value
    None => raise LayoutError("no tree edge from \{child} to \{parent}")
  }
}

///|
/// Given the tight tree, its graph, and a child in the graph calculate and
/// return the cut value for the edge between the child and its parent.
fn calc_cut_value(
  t : Tree,
  g : RankGraph[SimpleEdge],
  child : String,
  parent : String,
) -> Double raise LayoutError {
  // True if the child is on the tail end of the edge in the directed graph.
  let mut child_is_tail = true
  // The graph's view of the tree edge we're inspecting.
  let graph_edge = match g.edge_between(child, parent) {
    Some(edge) => edge
    None => {
      child_is_tail = false
      match g.edge_between(parent, child) {
        Some(edge) => edge
        None => raise LayoutError("no edge between \{child} and \{parent}")
      }
    }
  }
  let mut cut_value = graph_edge.weight
  for e in g.node_edges(child) {
    let is_out_edge = e.v == child
    let other = if is_out_edge { e.w } else { e.v }
    if other != parent {
      let points_to_head = is_out_edge == child_is_tail
      let other_weight = ed(g, e).weight
      cut_value = cut_value +
        (if points_to_head { other_weight } else { -other_weight })
      if t.has_edge(child, other) {
        guard t.edge_between(child, other) is Some(tree_edge) else { continue }
        let other_cut_value = tree_edge.cutvalue
        cut_value = cut_value +
          (if points_to_head { -other_cut_value } else { other_cut_value })
      }
    }
  }
  cut_value
}

///|
fn init_low_lim_values(t : Tree) -> Unit raise LayoutError {
  guard t.nodes() is [root, ..] else { return }
  let visited : Map[String, Unit] = Map([])
  dfs_assign_low_lim(t, visited, 1, root, None) |> ignore
}

///|
fn dfs_assign_low_lim(
  tree : Tree,
  visited : Map[String, Unit],
  next_lim : Int32,
  v : String,
  parent : String?,
) -> Int32 raise LayoutError {
  let low = next_lim
  let label = tree_node(tree, v)
  let mut next_lim = next_lim
  visited[v] = ()
  for w in tree.neighbors(v) {
    if !visited.contains(w) {
      next_lim = dfs_assign_low_lim(tree, visited, next_lim, w, Some(v))
    }
  }
  label.low = low
  label.lim = next_lim
  next_lim += 1
  // `if (parent)`: an empty name is none.
  label.parent = if parent is Some("") { None } else { parent }
  next_lim
}

///|
fn leave_edge(tree : Tree) -> @graphlib.Edge? raise LayoutError {
  for e in tree.edges() {
    if ed(tree, e).cutvalue < 0.0 {
      return Some(e)
    }
  }
  None
}

///|
fn enter_edge(
  t : Tree,
  g : RankGraph[SimpleEdge],
  edge : @graphlib.Edge,
) -> @graphlib.Edge raise LayoutError {
  let mut v = edge.v
  let mut w = edge.w
  // For the rest of this function we assume that v is the tail and w is
  // the head, so if we don't have this edge in the graph we should flip it
  // to match the correct orientation.
  if !g.has_edge(v, w) {
    v = edge.w
    w = edge.v
  }
  let v_label = tree_node(t, v)
  let w_label = tree_node(t, w)
  let mut tail_label = v_label
  let mut flip = false
  // If the root is in the tail of the edge then we need to flip the logic
  // that checks for the head and tail nodes in the candidates function
  // below.
  if v_label.lim > w_label.lim {
    tail_label = w_label
    flip = true
  }
  let mut best : (@graphlib.Edge, Int32)? = None
  for candidate in g.edges() {
    guard flip == is_descendant(tree_node(t, candidate.v), tail_label) &&
      flip != is_descendant(tree_node(t, candidate.w), tail_label) else {
      continue
    }
    let value = slack(g, candidate)
    if best is Some((_, current)) && current <= value {
      continue
    }
    best = Some((candidate, value))
  }
  match best {
    Some((e, _)) => e
    None => raise LayoutError("network simplex found no edge to enter")
  }
}

///|
fn exchange_edges(
  t : Tree,
  g : RankGraph[SimpleEdge],
  e : @graphlib.Edge,
  f : @graphlib.Edge,
) -> Unit raise LayoutError {
  t.remove_edge_between(e.v, e.w)
  graph_op(() => t.set_edge(f.v, f.w, { cutvalue: 0.0, }))
  init_low_lim_values(t)
  init_cut_values(t, g)
  update_ranks(t, g)
}

///|
fn update_ranks(t : Tree, g : RankGraph[SimpleEdge]) -> Unit raise LayoutError {
  // dagre looks for the node whose label in the graph has no `parent`,
  // which none has: the first node of the tree.
  guard t.nodes() is [root, ..] else {
    raise LayoutError("the tree has no node")
  }
  let vs = tree_dfs(t, [root], false)
  for i in 1..<vs.length() {
    let v = vs[i]
    guard tree_node(t, v).parent is Some(parent) else {
      raise LayoutError("the node \{v} has no parent in the tree")
    }
    let (edge, flipped) = match g.edge_between(v, parent) {
      Some(edge) => (edge, false)
      None =>
        match g.edge_between(parent, v) {
          Some(edge) => (edge, true)
          None => raise LayoutError("no edge between \{v} and \{parent}")
        }
    }
    let label = nd(g, v)
    label.rank = Some(
      rank_of(g, parent) + (if flipped { edge.minlen } else { -edge.minlen }),
    )
  }
}

///|
/// Returns true if the specified node is descendant of the root node per
/// the assigned low and lim attributes in the tree.
fn is_descendant(v_label : TreeNode, root_label : TreeNode) -> Bool {
  root_label.low <= v_label.lim && v_label.lim <= root_label.lim
}

///|
/// Assigns a rank to each node in the input graph that respects the
/// "minlen" constraint specified on edges between nodes.
fn rank(g : LayoutGraph) -> Unit raise LayoutError {
  match g.graph().ranker {
    Some("tight-tree") => {
      longest_path(g)
      feasible_tree(g) |> ignore
    }
    Some("longest-path") => longest_path(g)
    _ => network_simplex(g)
  }
}
