// dagre's `normalize.js`: an edge that spans more than one rank is cut
// into a chain of edges through dummy nodes, one per rank, so that every
// edge joins adjacent ranks; the chain becomes the route of the edge
// again once the dummies are placed.

///|
fn normalize_run(g : LayoutGraph) -> Unit raise LayoutError {
  g.graph().dummy_chains = []
  for edge in g.edges() {
    normalize_edge(g, edge)
  }
}

///|
fn normalize_edge(
  g : LayoutGraph,
  e : @graphlib.Edge,
) -> Unit raise LayoutError {
  let mut v = e.v
  let mut v_rank = rank_of(g, v)
  let w = e.w
  let w_rank = rank_of(g, w)
  let name = e.name
  let edge_label = ed(g, e)
  let label_rank = edge_label.label_rank
  if w_rank == v_rank + 1 {
    return
  }
  g.remove_edge(e)
  v_rank += 1
  let mut i = 0
  while v_rank < w_rank {
    edge_label.points = Some([])
    let attrs = NodeLabel::new(rank=v_rank)
    attrs.edge_label = Some(edge_label)
    attrs.edge_obj = Some(e)
    let dummy = add_dummy_node(g, "edge", attrs, "_d")
    if label_rank == Some(v_rank) {
      attrs.width = edge_label.width
      attrs.height = edge_label.height
      attrs.dummy = Some("edge-label")
      attrs.labelpos = Some(edge_label.labelpos)
    }
    let from = v
    graph_op(() => {
      g.set_edge(from, dummy, EdgeLabel::new(weight=edge_label.weight), name?)
    })
    if i == 0 {
      g.graph().dummy_chains.push(dummy)
    }
    v = dummy
    i += 1
    v_rank += 1
  }
  let from = v
  graph_op(() => {
    g.set_edge(from, w, EdgeLabel::new(weight=edge_label.weight), name?)
  })
}

///|
fn normalize_undo(g : LayoutGraph) -> Unit raise LayoutError {
  for start in g.graph().dummy_chains {
    let mut v = start
    let mut node = nd(g, v)
    guard node.edge_label is Some(orig_label) && node.edge_obj is Some(edge_obj) else {
      raise LayoutError("the dummy node \{v} stands for no edge")
    }
    graph_op(() => g.set_edge_obj(edge_obj, orig_label))
    while node.dummy is Some(dummy) {
      let w = g.successors(v)
      g.remove_node(v)
      match orig_label.points {
        Some(points) => points.push({ x: node.x, y: node.y, })
        None => raise LayoutError("the edge of \{v} has no route")
      }
      if dummy == "edge-label" {
        orig_label.x = Some(node.x)
        orig_label.y = Some(node.y)
        orig_label.width = node.width
        orig_label.height = node.height
      }
      guard w is [next, ..] else {
        raise LayoutError("the dummy node \{v} leads nowhere")
      }
      v = next
      node = nd(g, v)
    }
  }
}
