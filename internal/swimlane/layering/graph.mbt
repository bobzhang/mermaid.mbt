// The graph the ranking and ordering phases work on: `GraphView` of
// `swimlanes/helpers.ts` and the helpers of `phase0.helpers.ts`.

///|
/// An edge of the graph: `{ id, src, dst, ref }`, `ref` being the layout's
/// edge it comes from.
priv struct GEdge {
  id : String
  src : String
  dst : String
  ref_ : @model.Edge
}

///|
/// Node ids, edges and the nodes by id: `GraphView`.
priv struct Graph {
  nodes : Array[String]
  edges : Array[GEdge]
  layout : @model.Layout
  node_by_id : Map[String, @model.Node]
}

///|
/// The graph of a layout: groups first (in reverse order), then the other
/// nodes; edges carrying a label are left out (their label node's edges
/// stand for them). `toGraphView`.
fn to_graph_view(layout : @model.Layout) -> Graph {
  let node_by_id : Map[String, @model.Node] = Map([])
  for n in layout.nodes {
    node_by_id[n.id] = n
  }
  let edges = []
  for e in layout.edges {
    if e.start == "" || e.end == "" {
      continue
    }
    if e.label_node_id is Some(_) {
      continue
    }
    edges.push({ id: e.id, src: e.start, dst: e.end, ref_: e, })
  }
  let groups = layout.nodes.filter(n => n.is_group)
  groups.rev_in_place()
  let nodes = groups.map(n => n.id) +
    layout.nodes.filter(n => !n.is_group).map(n => n.id)
  { nodes, edges, layout, node_by_id, }
}

///|
/// The graph without edges to unknown nodes and repeated edges, its nodes
/// in the order of the node map: `normalizeGraph`.
fn normalize_graph(g : Graph) -> Graph {
  let node_by_id = g.node_by_id.copy()
  let seen : Set[String] = Set([])
  let edges = []
  for e in g.edges {
    if !node_by_id.contains(e.src) || !node_by_id.contains(e.dst) {
      continue
    }
    let key = "\{e.id}:\{e.src}->\{e.dst}"
    if seen.contains(key) {
      continue
    }
    seen.add(key)
    edges.push(e)
  }
  let nodes = node_by_id.keys().collect()
  { nodes, edges, layout: g.layout, node_by_id, }
}

///|
/// The edges into `v`: `incoming`.
fn incoming(g : Graph, v : String) -> Array[GEdge] {
  g.edges.filter(e => e.dst == v)
}

///|
/// `buildSuccessorMap`.
fn build_successor_map(g : Graph) -> Map[String, Array[String]] {
  let succs : Map[String, Array[String]] = Map([])
  for v in g.nodes {
    succs[v] = []
  }
  for e in g.edges {
    succs[e.src].push(e.dst)
  }
  succs
}

///|
/// The successors, each list in `localeCompare` order:
/// `buildSortedSuccessorMap`.
fn build_sorted_successor_map(g : Graph) -> Map[String, Array[String]] {
  let succs = build_successor_map(g)
  for _, successors in succs {
    @d3.js_sort(successors, @model.locale_compare)
  }
  succs
}

///|
/// `buildInDegreeMap`.
fn build_in_degree_map(g : Graph) -> Map[String, Int32] {
  let indeg : Map[String, Int32] = Map([])
  for v in g.nodes {
    indeg[v] = 0
  }
  for e in g.edges {
    indeg[e.dst] = indeg.get(e.dst).unwrap_or(0) + 1
  }
  indeg
}

///|
/// The nodes without incoming edges in `localeCompare` order, except that
/// the unconnected ones keep their source order among the places they
/// take: `sortedZeroInDegreeNodes`.
fn sorted_zero_in_degree_nodes(
  g : Graph,
  indeg : Map[String, Int32],
) -> Array[String] {
  let sorted = indeg
    .iter()
    .filter(entry => entry.1 == 0)
    .map(entry => entry.0)
    .collect()
  @d3.js_sort(sorted, @model.locale_compare)
  let linked : Set[String] = Set([])
  for e in g.edges {
    linked.add(e.src)
    linked.add(e.dst)
  }
  let is_unconnected = (id : String) => {
    !linked.contains(id) &&
    !(g.node_by_id.get(id) is Some(node) && node.is_group)
  }
  let unconnected = indeg
    .keys()
    .filter(id => indeg.get(id) == Some(0) && is_unconnected(id))
    .collect()
  let mut next = 0
  sorted.map(id => {
    if is_unconnected(id) {
      let id = unconnected[next]
      next += 1
      id
    } else {
      id
    }
  })
}

///|
/// `buildPredecessorSuccessorMaps`: `(preds, succs)`.
fn build_predecessor_successor_maps(
  g : Graph,
  include_edge? : (GEdge) -> Bool,
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let preds : Map[String, Array[String]] = Map([])
  let succs : Map[String, Array[String]] = Map([])
  for v in g.nodes {
    preds[v] = []
    succs[v] = []
  }
  for e in g.edges {
    if include_edge is Some(keep) && !keep(e) {
      continue
    }
    succs[e.src].push(e.dst)
    preds[e.dst].push(e.src)
  }
  (preds, succs)
}

///|
/// The layers of a ranking, each in the given order:
/// `buildLayersFromRanks`.
fn build_layers_from_ranks(
  g : Graph,
  order : Array[String],
  rank_of : Map[String, Int32],
  skip_groups~ : Bool = false,
) -> Array[Array[String]] {
  let is_group = (v : String) => {
    g.node_by_id.get(v) is Some(node) && node.is_group
  }
  let mut max_rank = 0
  for v in g.nodes {
    if skip_groups && is_group(v) {
      continue
    }
    max_rank = @cmp.maximum(max_rank, rank_of.get(v).unwrap_or(0))
  }
  let layers : Array[Array[String]] = Array::makei(max_rank + 1, _ => [])
  for v in order {
    if skip_groups && is_group(v) {
      continue
    }
    layers[@cmp.maximum(0, rank_of.get(v).unwrap_or(0))].push(v)
  }
  layers
}

///|
/// A topological order (Kahn's algorithm, ties by `localeCompare` and
/// then by code units), or `None` when there is a cycle:
/// `topoSortIfAcyclic`.
fn topo_sort_if_acyclic(g : Graph) -> Array[String]? {
  let indeg = build_in_degree_map(g)
  let queue = sorted_zero_in_degree_nodes(g, indeg)
  let order = []
  let adj = build_sorted_successor_map(g)
  while !queue.is_empty() {
    let u = queue.remove(0)
    order.push(u)
    for v in adj.get(u).unwrap_or([]) {
      indeg[v] = indeg.get(v).unwrap_or(0) - 1
      if indeg.get(v).unwrap_or(0) == 0 {
        let mut i = 0
        while i < queue.length() && @model.code_unit_less(queue[i], v) {
          i += 1
        }
        queue.insert(i, v)
      }
    }
  }
  if order.length() == g.nodes.length() {
    Some(order)
  } else {
    None
  }
}

///|
/// The position of each id in a layer: `buildLayerIndex`.
fn build_layer_index(layer : Array[String]) -> Map[String, Int32] {
  let m : Map[String, Int32] = Map([])
  for index, id in layer {
    m[id] = index
  }
  m
}

///|
/// The number of inversions, sorting `values` by merge sort on the way:
/// `countInversions`.
fn count_inversions(values : Array[Int32]) -> Int32 {
  let tmp = Array::make(values.length(), 0)
  fn count(left : Int32, right : Int32) -> Int32 {
    if right - left <= 1 {
      return 0
    }
    let mid = (left + right) >> 1
    let mut inversions = count(left, mid) + count(mid, right)
    let mut i = left
    let mut j = mid
    let mut k = left
    while i < mid || j < right {
      if j >= right || (i < mid && values[i] <= values[j]) {
        tmp[k] = values[i]
        k += 1
        i += 1
      } else {
        tmp[k] = values[j]
        k += 1
        j += 1
        inversions += mid - i
      }
    }
    for t in left..<right {
      values[t] = tmp[t]
    }
    inversions
  }

  count(0, values.length())
}
