// dagre's `greedy-fas.js` and `data/list.js`: a feedback arc set by the
// heuristic of Eades, Lin and Smyth, for `acyclicer: greedy`.

///|
/// A node of the graph the heuristic takes apart: the weight of the edges
/// into it and out of it, and its place in one of the bucket lists.
priv struct FasEntry {
  v : String
  mut ins : Double
  mut out : Double
  mut prev : FasEntry?
  mut next : FasEntry?
}

///|
/// A queue of entries, linked through the entries themselves.
priv struct FasList {
  sentinel : FasEntry
}

///|
fn FasList::new() -> FasList {
  let sentinel = { v: "", ins: 0.0, out: 0.0, prev: None, next: None, }
  sentinel.prev = Some(sentinel)
  sentinel.next = Some(sentinel)
  { sentinel, }
}

///|
fn unlink(entry : FasEntry) -> Unit {
  if entry.prev is Some(prev) && entry.next is Some(next) {
    prev.next = Some(next)
    next.prev = Some(prev)
  }
  entry.next = None
  entry.prev = None
}

///|
fn FasList::dequeue(self : FasList) -> FasEntry? {
  guard self.sentinel.prev is Some(entry) else { return None }
  if physical_equal(entry, self.sentinel) {
    None
  } else {
    unlink(entry)
    Some(entry)
  }
}

///|
fn FasList::enqueue(self : FasList, entry : FasEntry) -> Unit {
  if entry.prev is Some(_) && entry.next is Some(_) {
    unlink(entry)
  }
  let sentinel = self.sentinel
  entry.next = sentinel.next
  if sentinel.next is Some(next) {
    next.prev = Some(entry)
  }
  sentinel.next = Some(entry)
  entry.prev = Some(sentinel)
}

///|
type FasGraph = @graphlib.Graph[Unit, FasEntry, Double]

///|
/// The edges to reverse so that no cycle is left.
fn greedy_fas(g : LayoutGraph) -> Array[@graphlib.Edge] raise LayoutError {
  if g.node_count() <= 1 {
    return []
  }
  let (graph, buckets, zero_idx) = fas_build_state(g)
  let results = do_greedy_fas(graph, buckets, zero_idx)
  let edges = []
  for pair in results {
    edges.append(g.out_edges(pair.0, w=pair.1))
  }
  edges
}

///|
fn do_greedy_fas(
  g : FasGraph,
  buckets : Array[FasList],
  zero_idx : Int32,
) -> Array[(String, String)] raise LayoutError {
  let results = []
  let sources = buckets[buckets.length() - 1]
  let sinks = buckets[0]
  while g.node_count() != 0 {
    while sinks.dequeue() is Some(entry) {
      fas_remove_node(g, buckets, zero_idx, entry, None)
    }
    while sources.dequeue() is Some(entry) {
      fas_remove_node(g, buckets, zero_idx, entry, None)
    }
    if g.node_count() != 0 {
      for i = buckets.length() - 2; i > 0; i = i - 1 {
        if buckets[i].dequeue() is Some(entry) {
          fas_remove_node(g, buckets, zero_idx, entry, Some(results))
          break
        }
      }
    }
  }
  results
}

///|
fn fas_remove_node(
  g : FasGraph,
  buckets : Array[FasList],
  zero_idx : Int32,
  entry : FasEntry,
  collect : Array[(String, String)]?,
) -> Unit raise LayoutError {
  for edge in g.in_edges(entry.v) {
    let weight = ed(g, edge)
    guard g.node(edge.v) is Some(u_entry) else { continue }
    if collect is Some(results) {
      results.push((edge.v, edge.w))
    }
    u_entry.out -= weight
    assign_bucket(buckets, zero_idx, u_entry)
  }
  for edge in g.out_edges(entry.v) {
    let weight = ed(g, edge)
    guard g.node(edge.w) is Some(w_entry) else { continue }
    w_entry.ins -= weight
    assign_bucket(buckets, zero_idx, w_entry)
  }
  g.remove_node(entry.v)
}

///|
fn fas_build_state(
  g : LayoutGraph,
) -> (FasGraph, Array[FasList], Int32) raise LayoutError {
  let fas_graph : FasGraph = @graphlib.Graph::new((), default_node=v => {
    v,
    ins: 0.0,
    out: 0.0,
    prev: None,
    next: None,
  })
  let mut max_in = 0.0
  let mut max_out = 0.0
  for v in g.nodes() {
    fas_graph.set_node(v, { v, ins: 0.0, out: 0.0, prev: None, next: None, })
  }
  // Edges that have the same ends are counted as one, with their weights
  // added up.
  for e in g.edges() {
    let prev_weight = fas_graph.edge_between(e.v, e.w).unwrap_or(0.0)
    let weight = ed(g, e).weight
    let edge_weight = (if truthy(prev_weight) { prev_weight } else { 0.0 }) +
      weight
    graph_op(() => fas_graph.set_edge(e.v, e.w, edge_weight))
    if fas_graph.node(e.v) is Some(entry) {
      entry.out += weight
      max_out = js_max(max_out, entry.out)
    }
    if fas_graph.node(e.w) is Some(entry) {
      entry.ins += weight
      max_in = js_max(max_in, entry.ins)
    }
  }
  let count = max_out + max_in + 3.0
  if count.is_nan() || count != count.floor() {
    raise LayoutError("the greedy acyclicer needs whole edge weights")
  }
  let buckets = range(0, count.to_int()).map(_ => FasList::new())
  let zero_idx = max_in.to_int() + 1
  for v in fas_graph.nodes() {
    if fas_graph.node(v) is Some(entry) {
      assign_bucket(buckets, zero_idx, entry)
    }
  }
  (fas_graph, buckets, zero_idx)
}

///|
fn assign_bucket(
  buckets : Array[FasList],
  zero_idx : Int32,
  entry : FasEntry,
) -> Unit raise LayoutError {
  if !truthy(entry.out) {
    buckets[0].enqueue(entry)
  } else if !truthy(entry.ins) {
    buckets[buckets.length() - 1].enqueue(entry)
  } else {
    let index = entry.out - entry.ins + zero_idx.to_double()
    guard index == index.floor() &&
      index >= 0.0 &&
      index < buckets.length().to_double() else {
      raise LayoutError("the greedy acyclicer needs whole edge weights")
    }
    buckets[index.to_int()].enqueue(entry)
  }
}
