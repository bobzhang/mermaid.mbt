// dagre's `add-border-segments.js`: a compound node gets a border node on
// its left and one on its right in every rank it spans, chained from rank
// to rank, which ordering and positioning then treat like any node.

///|
fn add_border_segments(g : LayoutGraph) -> Unit raise LayoutError {
  fn dfs(v : String) -> Unit raise LayoutError {
    let children = g.children(v)
    let node = nd(g, v)
    for child in children {
      dfs(child)
    }
    if node.min_rank is Some(min_rank) {
      let left = []
      let right = []
      node.border_left = Some(left)
      node.border_right = Some(right)
      // Undefined is not below any rank.
      guard node.max_rank is Some(max_rank) else { return }
      for rank in min_rank..<(max_rank + 1) {
        add_segment_node(g, "borderLeft", "_bl", v, left, rank)
        add_segment_node(g, "borderRight", "_br", v, right, rank)
      }
    }
  }

  for v in g.top_children() {
    dfs(v)
  }
}

///|
/// `borders` holds the border nodes of the ranks before `rank`, from the
/// first rank of the compound node.
fn add_segment_node(
  g : LayoutGraph,
  prop : String,
  prefix : String,
  sg : String,
  borders : Array[String],
  rank : Int32,
) -> Unit raise LayoutError {
  let label = NodeLabel::new(rank~)
  label.border_type = Some(prop)
  let prev = borders.last()
  let curr = add_dummy_node(g, "border", label, prefix)
  borders.push(curr)
  graph_op(() => g.set_parent(curr, parent=sg))
  if prev is Some(prev) {
    graph_op(() => g.set_edge(prev, curr, EdgeLabel::new(weight=1.0)))
  }
}
