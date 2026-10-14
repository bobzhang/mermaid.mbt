// dagre's `order/build-layer-graph.js` and
// `order/add-subgraph-constraints.js`.

///|
/// A node of a layer graph: a node of the layout graph (the label is
/// shared, so an order assigned here is seen there), a compound node with
/// its border nodes in this layer, or the root that only the layer graph
/// has.
priv enum LayerNode {
  Leaf(NodeLabel)
  Group(String, String)
  Missing
}

///|
/// The graph of one rank for a sweep: its nodes nested as in the layout
/// graph under one root, and the nodes of the adjacent rank they have
/// edges with, the weights of parallel edges added up.
type LayerGraph = @graphlib.Graph[String, LayerNode, Double]

///|
/// `relationship` is `inEdges` for a graph that holds the rank above
/// (`in_edges` true), `outEdges` for one that holds the rank below.
fn build_layer_graph(
  g : LayoutGraph,
  rank : Int32,
  in_edges : Bool,
) -> LayerGraph raise LayoutError {
  let root = create_root_node(g)
  let result : LayerGraph = @graphlib.Graph::new(
    root,
    default_node=v => {
      match g.node(v) {
        Some(label) if !label.missing => Leaf(label)
        _ => Missing
      }
    },
    compound=true,
  )
  for v in g.nodes() {
    let node = nd(g, v)
    let parent = g.parent(v)
    let in_rank = node.rank == Some(rank) ||
      (
        node.min_rank is Some(min) &&
        node.max_rank is Some(max) &&
        min <= rank &&
        rank <= max
      )
    guard in_rank else { continue }
    result.ensure_node(v)
    // `parent || root`.
    let parent = match parent {
      Some(parent) if parent != "" => parent
      _ => root
    }
    graph_op(() => result.set_parent(v, parent~))
    // This assumes we have only short edges!
    let edges = if in_edges { g.in_edges(v) } else { g.out_edges(v) }
    for e in edges {
      let u = if e.v == v { e.w } else { e.v }
      let weight = result.edge_between(u, v).unwrap_or(0.0)
      let total = ed(g, e).weight + weight
      graph_op(() => result.set_edge(u, v, total))
    }
    if node.min_rank is Some(min) {
      guard node.border_left is Some(left) &&
        node.border_right is Some(right) &&
        left.get(rank - min) is Some(bl) &&
        right.get(rank - min) is Some(br) else {
        raise LayoutError(
          "the compound node \{v} has no border at rank \{rank}",
        )
      }
      result.set_node(v, Group(bl, br))
    }
  }
  result
}

///|
fn create_root_node(g : LayoutGraph) -> String {
  let mut v = unique_id("_root")
  while g.has_node(v) {
    v = unique_id("_root")
  }
  v
}

///|
/// The graph of the constraints between compound nodes: an edge says its
/// source has to stay to the left of its target.
type ConstraintGraph = @graphlib.Graph[Unit, Unit, Unit]

///|
/// Keeps the compound nodes in the order the sorted layer `vs` has them
/// in, for the layers swept after it.
fn add_subgraph_constraints(
  g : LayerGraph,
  cg : ConstraintGraph,
  vs : Array[String],
) -> Unit raise LayoutError {
  let prev : Map[String, String] = Map([])
  let mut root_prev : String? = None
  for v in vs {
    let mut child = g.parent(v)
    while child is Some(current) && current != "" {
      let parent = g.parent(current)
      let prev_child = match parent {
        Some(parent) if parent != "" => {
          let before = prev.get(parent)
          prev[parent] = current
          before
        }
        _ => {
          let before = root_prev
          root_prev = Some(current)
          before
        }
      }
      if prev_child is Some(before) && before != "" && before != current {
        graph_op(() => cg.ensure_edge(before, current, () => ()))
        break
      }
      child = parent
    }
  }
}
