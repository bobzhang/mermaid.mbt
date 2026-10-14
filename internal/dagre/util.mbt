// dagre's `util.js`.

///|
/// The layout graph: compound and with parallel edges.
type LayoutGraph = @graphlib.Graph[GraphLabel, NodeLabel, EdgeLabel]

///|
/// The label of a node that has one. dagre reads properties of what
/// `g.node(v)` returns without looking, and throws on a missing label.
fn[G, E] nd(
  g : @graphlib.Graph[G, NodeLabel, E],
  v : String,
) -> NodeLabel raise LayoutError {
  match g.node(v) {
    Some(label) if !label.missing => label
    _ => raise LayoutError("the node \{v} has no label")
  }
}

///|
/// The rank of a node that has one.
fn[G, E] rank_of(
  g : @graphlib.Graph[G, NodeLabel, E],
  v : String,
) -> Int32 raise LayoutError {
  match nd(g, v).rank {
    Some(rank) => rank
    None => raise LayoutError("the node \{v} has no rank")
  }
}

///|
/// The position in its rank of a node that has one.
fn[G, E] order_of(
  g : @graphlib.Graph[G, NodeLabel, E],
  v : String,
) -> Int32 raise LayoutError {
  match nd(g, v).order {
    Some(order) => order
    None => raise LayoutError("the node \{v} has no order")
  }
}

///|
/// The label of an edge the graph has.
fn[G, N, E] ed(
  g : @graphlib.Graph[G, N, E],
  e : @graphlib.Edge,
) -> E raise LayoutError {
  match g.edge(e) {
    Some(label) => label
    None => raise LayoutError("no edge from \{e.v} to \{e.w}")
  }
}

///|
/// graphlib's errors are the layout's.
fn[T] graph_op(f : () -> T raise @graphlib.GraphError) -> T raise LayoutError {
  f() catch {
    @graphlib.GraphError(message) => raise LayoutError(message)
  }
}

///|
/// Adds a dummy node to the graph and returns its id.
fn add_dummy_node(
  g : LayoutGraph,
  kind : String,
  attrs : NodeLabel,
  name : String,
) -> String {
  let mut v = unique_id(name)
  while g.has_node(v) {
    v = unique_id(name)
  }
  attrs.dummy = Some(kind)
  g.set_node(v, attrs)
  v
}

///|
/// The label of a node that an edge names and nothing else describes.
fn missing_node(_v : String) -> NodeLabel {
  NodeLabel::new(missing=true)
}

///|
/// What network simplex ranks: one edge between two nodes for all of
/// theirs, its weight their sum and its length the longest.
priv struct SimpleEdge {
  weight : Double
  minlen : Int32
}

///|
impl RankEdge for SimpleEdge with fn minlen(self) {
  self.minlen
}

///|
impl RankEdge for SimpleEdge with fn weight(self) {
  self.weight
}

///|
/// A graph of the same nodes (the labels are shared) with the parallel
/// edges merged.
fn[E : RankEdge] simplify(
  g : @graphlib.Graph[GraphLabel, NodeLabel, E],
) -> @graphlib.Graph[GraphLabel, NodeLabel, SimpleEdge] raise LayoutError {
  let simplified = @graphlib.Graph::new(g.graph(), default_node=missing_node)
  for v in g.nodes() {
    if g.node(v) is Some(label) {
      simplified.set_node(v, label)
    }
  }
  for e in g.edges() {
    let simple = simplified
      .edge_between(e.v, e.w)
      .unwrap_or({ weight: 0.0, minlen: 1, })
    let label = ed(g, e)
    let minlen = if simple.minlen > label.minlen() {
      simple.minlen
    } else {
      label.minlen()
    }
    graph_op(() => {
      simplified.set_edge(e.v, e.w, {
        weight: simple.weight + label.weight(),
        minlen,
      })
    })
  }
  simplified
}

///|
/// The graph without its compound nodes: the nodes that have no children
/// (their labels shared) and every edge.
fn as_non_compound_graph(g : LayoutGraph) -> LayoutGraph raise LayoutError {
  let simplified = @graphlib.Graph::new(
    g.graph(),
    default_node=missing_node,
    multigraph=g.is_multigraph(),
  )
  for v in g.nodes() {
    if g.children(v).is_empty() && g.node(v) is Some(label) {
      simplified.set_node(v, label)
    }
  }
  for e in g.edges() {
    let label = ed(g, e)
    graph_op(() => simplified.set_edge_obj(e, label))
  }
  simplified
}

///|
/// Where the line from the centre of a rectangle towards a point crosses
/// its border.
fn intersect_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  point : Pt,
) -> Pt raise LayoutError {
  let dx = point.x - x
  let dy = point.y - y
  let mut w = width / 2.0
  let mut h = height / 2.0
  if !truthy(dx) && !truthy(dy) {
    raise LayoutError(
      "Not possible to find intersection inside of the rectangle",
    )
  }
  let (sx, sy) = if dy.abs() * w > dx.abs() * h {
    // The intersection is at the top or the bottom of the rectangle.
    if dy < 0.0 {
      h = -h
    }
    (h * dx / dy, h)
  } else {
    // At the left or the right.
    if dx < 0.0 {
      w = -w
    }
    (w, w * dy / dx)
  }
  { x: x + sx, y: y + sy, }
}

///|
/// The nodes of each rank, in their order.
fn build_layer_matrix(g : LayoutGraph) -> Array[Array[String]] {
  let layering : Array[Array[String]] = match max_rank(g) {
    Some(max) => range(0, max + 1).map(_ => [])
    None => []
  }
  for v in g.nodes() {
    guard g.node(v) is Some(node) else { continue }
    guard node.rank is Some(rank) && node.order is Some(order) else { continue }
    guard rank >= 0 && rank < layering.length() && order >= 0 else { continue }
    let layer = layering[rank]
    // `layer[order] = v` of a JavaScript array.
    while layer.length() <= order {
      layer.push("")
    }
    layer[order] = v
  }
  layering
}

///|
/// Shifts the ranks so that the smallest is zero.
fn normalize_ranks(g : LayoutGraph) -> Unit {
  let ranks = g.nodes().map(v => g.node(v).bind(node => node.rank))
  guard min_int(ranks) is Some(min) else { return }
  for v in g.nodes() {
    if g.node(v) is Some(node) && node.rank is Some(rank) {
      node.rank = Some(rank - min)
    }
  }
}

///|
/// Closes the gaps the nesting graph left between ranks, except at the
/// ranks that are multiples of its factor.
fn remove_empty_ranks(g : LayoutGraph) -> Unit {
  let ranks = g.nodes().map(v => g.node(v).bind(node => node.rank))
  // Not a number without a rank to start from; no rank is an index then.
  guard min_int(ranks) is Some(offset) else { return }
  let layers : Array[Array[String]?] = []
  for v in g.nodes() {
    guard g.node(v) is Some(node) && node.rank is Some(rank) else { continue }
    let rank = rank - offset
    while layers.length() <= rank {
      layers.push(None)
    }
    match layers[rank] {
      Some(layer) => layer.push(v)
      None => layers[rank] = Some([v])
    }
  }
  let mut delta = 0
  let factor = g.graph().node_rank_factor
  for i, vs in layers {
    let on_factor = match factor {
      Some(factor) => factor != 0 && i % factor == 0
      // `i % undefined` is not a number, which is not zero.
      None => false
    }
    if vs is None && !on_factor {
      delta -= 1
    } else if delta != 0 && vs is Some(vs) {
      for v in vs {
        if g.node(v) is Some(node) && node.rank is Some(rank) {
          node.rank = Some(rank + delta)
        }
      }
    }
  }
}

///|
/// A node of no size at the border of a compound node.
fn add_border_node(g : LayoutGraph, prefix : String) -> String {
  add_dummy_node(g, "border", NodeLabel::new(), prefix)
}

///|
/// The largest rank of a node, if any node has one.
fn max_rank(g : LayoutGraph) -> Int32? {
  max_int(g.nodes().map(v => g.node(v).bind(node => node.rank)))
}
