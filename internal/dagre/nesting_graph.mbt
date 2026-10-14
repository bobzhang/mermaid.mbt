// dagre's `nesting-graph.js`: a compound graph is ranked as a flat one by
// giving every compound node a border node above and one below its
// children, tied to them by edges, and by hanging everything from one
// root. The ranks between the levels of nesting are removed again after
// ranking.

///|
fn nesting_graph_run(g : LayoutGraph) -> Unit raise LayoutError {
  let root = add_dummy_node(g, "root", NodeLabel::new(), "_root")
  let depths = tree_depths(g)
  let mut deepest = 0
  for _, depth in depths {
    if depth > deepest {
      deepest = depth
    }
  }
  let height = deepest - 1
  let node_sep = 2 * height + 1
  g.graph().nesting_root = Some(root)
  // Multiply minlen by nodeSep to align nodes on non-border ranks.
  for e in g.edges() {
    let label = ed(g, e)
    label.minlen = label.minlen * node_sep
  }
  // Calculate a weight that is sufficient to keep subgraphs vertically
  // compact.
  let weight = sum_weights(g) + 1.0
  // Create border nodes and link them up.
  for child in g.top_children() {
    nesting_dfs(g, root, node_sep, weight, height, depths, child)
  }
  // Save the multiplier for node layers for later removal of empty border
  // layers.
  g.graph().node_rank_factor = Some(node_sep)
}

///|
fn nesting_dfs(
  g : LayoutGraph,
  root : String,
  node_sep : Int32,
  weight : Double,
  height : Int32,
  depths : Map[String, Int32],
  v : String,
) -> Unit raise LayoutError {
  let children = g.children(v)
  if children.is_empty() {
    if v != root {
      graph_op(() => {
        g.set_edge(root, v, EdgeLabel::new(weight=0.0, minlen=node_sep))
      })
    }
    return
  }
  let top = add_border_node(g, "_bt")
  let bottom = add_border_node(g, "_bb")
  let label = nd(g, v)
  graph_op(() => g.set_parent(top, parent=v))
  label.border_top = Some(top)
  graph_op(() => g.set_parent(bottom, parent=v))
  label.border_bottom = Some(bottom)
  let depth = depths.get(v).unwrap_or(0)
  for child in children {
    nesting_dfs(g, root, node_sep, weight, height, depths, child)
    let child_node = nd(g, child)
    let child_top = child_node.border_top.unwrap_or(child)
    let child_bottom = child_node.border_bottom.unwrap_or(child)
    let this_weight = if child_node.border_top is Some(_) {
      weight
    } else {
      2.0 * weight
    }
    let minlen = if child_top != child_bottom { 1 } else { height - depth + 1 }
    graph_op(() => {
      g.set_edge(
        top,
        child_top,
        EdgeLabel::new(weight=this_weight, minlen~, nesting_edge=true),
      )
    })
    graph_op(() => {
      g.set_edge(
        child_bottom,
        bottom,
        EdgeLabel::new(weight=this_weight, minlen~, nesting_edge=true),
      )
    })
  }
  if g.parent(v) is None {
    graph_op(() => {
      g.set_edge(root, top, EdgeLabel::new(weight=0.0, minlen=height + depth))
    })
  }
}

///|
/// How deep every node is nested, from one for the outermost.
fn tree_depths(g : LayoutGraph) -> Map[String, Int32] {
  let depths = Map([])
  fn dfs(v : String, depth : Int32) -> Unit {
    for child in g.children(v) {
      dfs(child, depth + 1)
    }
    depths[v] = depth
  }

  for v in g.top_children() {
    dfs(v, 1)
  }
  depths
}

///|
fn sum_weights(g : LayoutGraph) -> Double raise LayoutError {
  let mut sum = 0.0
  for e in g.edges() {
    sum = sum + ed(g, e).weight
  }
  sum
}

///|
fn nesting_graph_cleanup(g : LayoutGraph) -> Unit raise LayoutError {
  let label = g.graph()
  if label.nesting_root is Some(root) {
    g.remove_node(root)
  }
  label.nesting_root = None
  for e in g.edges() {
    if ed(g, e).nesting_edge {
      g.remove_edge(e)
    }
  }
}
