// dagre's `order/index.js`, `order/init-order.js` and
// `order/cross-count.js`: the nodes of every rank are put in an order
// that keeps edge crossings low, by sweeping up and down over the layers
// (Gansner et al.) and keeping the best of the orders seen.

///|
fn order(g : LayoutGraph) -> Unit raise LayoutError {
  let max_rank = max_rank(g)
  // `_.range(1, maxRank + 1)` and `_.range(maxRank - 1, -1, -1)`. Without
  // a rank they are `_.range(1, NaN)` and `_.range(NaN, -1, -1)`, which
  // count from 1 down to 0 and from 0 down to -1.
  let (down_ranks, up_ranks) = match max_rank {
    Some(max) => {
      let up = []
      for rank = max - 1; rank > -1; rank = rank - 1 {
        up.push(rank)
      }
      (range(1, max + 1), up)
    }
    None => ([1], [0])
  }
  let down_layer_graphs = []
  for rank in down_ranks {
    down_layer_graphs.push(build_layer_graph(g, rank, true))
  }
  let up_layer_graphs = []
  for rank in up_ranks {
    up_layer_graphs.push(build_layer_graph(g, rank, false))
  }
  let mut layering = init_order(g)
  assign_order(g, layering)
  let mut best_cc = @double.infinity
  let mut best : Array[Array[String]] = []
  let mut i = 0
  let mut last_best = 0
  while last_best < 4 {
    sweep_layer_graphs(
      if i % 2 != 0 {
        down_layer_graphs
      } else {
        up_layer_graphs
      },
      i % 4 >= 2,
    )
    layering = build_layer_matrix(g)
    let cc = cross_count(g, layering)
    if cc < best_cc {
      last_best = 0
      best = layering.map(layer => layer.copy())
      best_cc = cc
    }
    i += 1
    last_best += 1
  }
  assign_order(g, best)
}

///|
fn sweep_layer_graphs(
  layer_graphs : Array[LayerGraph],
  bias_right : Bool,
) -> Unit raise LayoutError {
  let cg : ConstraintGraph = @graphlib.Graph::new((), default_node=_ => ())
  for lg in layer_graphs {
    let root = lg.graph()
    let sorted = sort_subgraph(lg, root, cg, bias_right)
    for i, v in sorted.vs {
      match lg.node(v) {
        Some(Leaf(label)) => label.order = Some(i)
        _ => raise LayoutError("the node \{v} has no place in its layer")
      }
    }
    add_subgraph_constraints(lg, cg, sorted.vs)
  }
}

///|
fn assign_order(
  g : LayoutGraph,
  layering : Array[Array[String]],
) -> Unit raise LayoutError {
  for layer in layering {
    for i, v in layer {
      nd(g, v).order = Some(i)
    }
  }
}

///|
/// An order to start from: the nodes without children as a depth-first
/// search from the nodes of the lowest ranks finds them.
fn init_order(g : LayoutGraph) -> Array[Array[String]] raise LayoutError {
  let visited : Map[String, Unit] = Map([])
  let simple_nodes = g.nodes().filter(v => g.children(v).is_empty())
  let mut top : Int32? = None
  for v in simple_nodes {
    if nd(g, v).rank is Some(rank) && !(top is Some(current) && current >= rank) {
      top = Some(rank)
    }
  }
  let layers : Array[Array[String]] = match top {
    Some(top) => range(0, top + 1).map(_ => [])
    None => []
  }
  fn dfs(v : String) -> Unit raise LayoutError {
    if visited.contains(v) {
      return
    }
    visited[v] = ()
    let rank = rank_of(g, v)
    guard rank >= 0 && rank < layers.length() else {
      raise LayoutError("the node \{v} is in no layer")
    }
    layers[rank].push(v)
    for w in g.successors(v) {
      dfs(w)
    }
  }

  let ranks : Map[String, Double] = Map([])
  for v in simple_nodes {
    ranks[v] = match nd(g, v).rank {
      Some(rank) => rank.to_double()
      None => @double.not_a_number
    }
  }
  let ordered_vs = sort_by(simple_nodes, v => {
    ranks.get(v).unwrap_or(@double.not_a_number)
  })
  for v in ordered_vs {
    dfs(v)
  }
  layers
}

///|
/// The weighted number of crossings between the edges of adjacent layers
/// (Barth et al., "Bilayer Cross Counting").
fn cross_count(
  g : LayoutGraph,
  layering : Array[Array[String]],
) -> Double raise LayoutError {
  let mut cc = 0.0
  for i in 1..<layering.length() {
    cc = cc + two_layer_cross_count(g, layering[i - 1], layering[i])
  }
  cc
}

///|
fn two_layer_cross_count(
  g : LayoutGraph,
  north_layer : Array[String],
  south_layer : Array[String],
) -> Double raise LayoutError {
  // Sort all of the edges between the north and south layers by their
  // position in the north layer and then the south. Map these edges to the
  // position of their head in the south layer.
  let south_pos : Map[String, Int32] = Map([])
  for i, v in south_layer {
    south_pos[v] = i
  }
  let south_entries : Array[(Int32, Double)] = []
  for v in north_layer {
    let entries = []
    for e in g.out_edges(v) {
      guard south_pos.get(e.w) is Some(pos) else {
        raise LayoutError("the edge from \{e.v} to \{e.w} skips a layer")
      }
      entries.push((pos, ed(g, e).weight))
    }
    south_entries.append(sort_by(entries, entry => entry.0.to_double()))
  }
  // Build the accumulator tree.
  let mut first_index = 1
  while first_index < south_layer.length() {
    first_index = first_index << 1
  }
  let tree_size = 2 * first_index - 1
  first_index -= 1
  let tree = Array::make(tree_size, 0.0)
  // Calculate the weighted crossings.
  let mut cc = 0.0
  for entry in south_entries {
    let mut index = entry.0 + first_index
    tree[index] = tree[index] + entry.1
    let mut weight_sum = 0.0
    while index > 0 {
      if index % 2 != 0 {
        weight_sum = weight_sum + tree[index + 1]
      }
      index = (index - 1) >> 1
      tree[index] = tree[index] + entry.1
    }
    cc = cc + entry.1 * weight_sum
  }
  cc
}
