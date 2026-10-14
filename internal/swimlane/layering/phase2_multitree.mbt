// The layer orders of the longest-path ranking: the driving tree
// (`driving-tree.ts`), crossings per subtree (`phase2.crossCounts.ts`), the
// tree order (`phase2.multitree.core.ts`, `phase2.multitree.order.ts`), and
// the rank changes that reduce crossings (`phase2.crossOptimization.ts`,
// `phase2.crossLaneAdjust.ts`). Only used with
// `swimlane.ignoreCrossLaneEdges: false`.

///|
/// The spanning forest the tree order follows: `buildDrivingTree`, reduced
/// to what its callers read.
priv struct DrivingTree {
  parent : Map[String, String?]
  children : Map[String, Array[String]]
  roots : Array[String]
}

///|
/// `buildDrivingTree`: every node hangs below one of its predecessors,
/// preferably one in its own lane, then the one ranked lowest.
fn build_driving_tree(
  graph : Graph,
  lane_of : (String) -> String?,
  rank_hint : Map[String, Int32],
) -> DrivingTree {
  let g = normalize_graph(graph)
  let (preds, _) = build_predecessor_successor_maps(g)
  for _, arr in preds {
    @d3.js_sort(arr, @model.locale_compare)
  }
  let topo_order = match topo_sort_if_acyclic(g) {
    Some(order) => order
    None => {
      let ids = g.nodes.copy()
      @d3.js_sort(ids, @model.locale_compare)
      ids
    }
  }
  let topo_index : Map[String, Int32] = Map([])
  for idx, id in topo_order {
    topo_index[id] = idx
  }
  let parent : Map[String, String?] = Map([])
  let children : Map[String, Array[String]] = Map([])
  for node in g.nodes {
    children[node] = []
  }
  for node in topo_order {
    let candidates = preds
      .get(node)
      .unwrap_or([])
      .filter(p => parent.contains(p))
    if !candidates.is_empty() {
      let chosen = choose_parent(
        node, candidates, lane_of, rank_hint, topo_index,
      )
      parent[node] = Some(chosen)
      children[chosen].push(node)
    } else if !parent.contains(node) {
      parent[node] = None
    }
  }
  for node in g.nodes {
    if !parent.contains(node) {
      parent[node] = None
    }
  }
  let root_set : Set[String] = Set([])
  for node in g.nodes {
    if parent.get(node) is (None | Some(None)) {
      root_set.add(node)
    }
  }
  let roots = root_set.iter().collect()
  @d3.js_sort(roots, (a, b) => {
    let ta = topo_index.get(a).unwrap_or(0)
    let tb = topo_index.get(b).unwrap_or(0)
    if ta == tb {
      @model.locale_compare(a, b)
    } else {
      (ta - tb).to_double()
    }
  })
  { parent, children, roots, }
}

///|
/// `chooseParent`.
fn choose_parent(
  node : String,
  candidates : Array[String],
  lane_of : (String) -> String?,
  rank_hint : Map[String, Int32],
  topo_index : Map[String, Int32],
) -> String {
  let lane_node = lane_of(node)
  let sorted = candidates.copy()
  @d3.js_sort(sorted, (a, b) => {
    let same_lane = (x : String) => {
      lane_of(x) is Some(lane) && lane_node == Some(lane)
    }
    let same_lane_a = same_lane(a)
    let same_lane_b = same_lane(b)
    if same_lane_a != same_lane_b {
      return if same_lane_a { -1.0 } else { 1.0 }
    }
    if rank_hint.get(a) is Some(rank_a) &&
      rank_hint.get(b) is Some(rank_b) &&
      rank_a != rank_b {
      return (rank_b - rank_a).to_double()
    }
    let idx_a = topo_index.get(a).unwrap_or(0)
    let idx_b = topo_index.get(b).unwrap_or(0)
    if idx_a != idx_b {
      return (idx_a - idx_b).to_double()
    }
    @model.locale_compare(a, b)
  })
  sorted[0]
}

///|
/// For every tree edge, how many graph edges cross the parent's layer in
/// the child's subtree: `computeSubtreeCrossCounts`.
fn compute_subtree_cross_counts(
  g : Graph,
  rank_of : Map[String, Int32],
  tree : DrivingTree,
) -> Map[String, Map[String, Int32]] {
  let nodes = g.nodes.copy()
  let index_of : Map[String, Int32] = Map([])
  for i, node in nodes {
    index_of[node] = i
  }
  let n = nodes.length()
  let parent_idx = Array::make(n, -1)
  let depth = Array::make(n, 0)
  let queue = []
  let seen : Set[String] = Set([])
  for node in nodes {
    let parent_id = match tree.parent.get(node) {
      Some(Some(p)) => Some(p)
      _ => None
    }
    guard index_of.get(node) is Some(idx) else { continue }
    if parent_id is None {
      parent_idx[idx] = -1
      depth[idx] = 0
      if !seen.contains(node) {
        seen.add(node)
        queue.push(node)
      }
    }
  }
  while !queue.is_empty() {
    let current = queue.remove(0)
    guard index_of.get(current) is Some(current_idx) else { continue }
    for child in tree.children.get(current).unwrap_or([]) {
      if seen.contains(child) {
        continue
      }
      guard index_of.get(child) is Some(child_idx) else { continue }
      parent_idx[child_idx] = current_idx
      depth[child_idx] = depth[current_idx] + 1
      seen.add(child)
      queue.push(child)
    }
  }
  for node in nodes {
    if seen.contains(node) {
      continue
    }
    guard index_of.get(node) is Some(idx) else { continue }
    parent_idx[idx] = -1
    depth[idx] = 0
    seen.add(node)
  }
  // `Math.max(1, Math.ceil(Math.log2(Math.max(1, n))) + 1)`
  let mut ceil_log2 = 0
  while 1 << ceil_log2 < @cmp.maximum(1, n) {
    ceil_log2 += 1
  }
  let max_log = @cmp.maximum(1, ceil_log2 + 1)
  let up : Array[Array[Int32]] = Array::makei(max_log, _ => Array::make(n, -1))
  for i in 0..<n {
    up[0][i] = parent_idx[i]
  }
  for k in 1..<max_log {
    for i in 0..<n {
      let prev = up[k - 1][i]
      up[k][i] = if prev == -1 { -1 } else { up[k - 1][prev] }
    }
  }
  let lca_index = (a_idx : Int32, b_idx : Int32) => {
    if a_idx == -1 || b_idx == -1 {
      return -1
    }
    let (a0, b0) = if depth[a_idx] < depth[b_idx] {
      (b_idx, a_idx)
    } else {
      (a_idx, b_idx)
    }
    let mut a = a0
    let mut b = b0
    let diff = depth[a] - depth[b]
    for k in 0..<max_log {
      if ((diff >> k) & 1) != 0 {
        a = up[k][a]
        if a == -1 {
          return -1
        }
      }
    }
    if a == b {
      return a
    }
    for k = max_log - 1; k >= 0; k = k - 1 {
      let up_a = up[k][a]
      let up_b = up[k][b]
      if up_a == -1 || up_b == -1 {
        continue
      }
      if up_a != up_b {
        a = up_a
        b = up_b
      }
    }
    up[0][a]
  }
  let own_counts : Array[Map[Int32, Int32]] = Array::makei(n, _ => Map([]))
  for edge in g.edges {
    guard rank_of.get(edge.src) is Some(ru0) &&
      rank_of.get(edge.dst) is Some(rv0) else {
      continue
    }
    let (src, dst, ru, rv) = if ru0 > rv0 {
      (edge.dst, edge.src, rv0, ru0)
    } else {
      (edge.src, edge.dst, ru0, rv0)
    }
    if ru == rv {
      continue
    }
    guard index_of.get(src) is Some(upper_idx) &&
      index_of.get(dst) is Some(lower_idx) else {
      continue
    }
    let lca = lca_index(upper_idx, lower_idx)
    if lca == -1 {
      continue
    }
    let bucket = own_counts[lca]
    for layer in ru..<rv {
      bucket[layer] = bucket.get(layer).unwrap_or(0) + 1
    }
  }
  let cross_counts : Map[String, Map[String, Int32]] = Map([])
  let visited : Set[String] = Set([])
  fn dfs(node : String) -> Map[Int32, Int32] {
    visited.add(node)
    let accumulator = match index_of.get(node) {
      Some(idx) => own_counts[idx].copy()
      None => Map([])
    }
    for child in tree.children.get(node).unwrap_or([]) {
      let child_map = dfs(child)
      if rank_of.get(node) is Some(parent_layer) {
        let map = match cross_counts.get(node) {
          Some(map) => map
          None => {
            let map = Map([])
            cross_counts[node] = map
            map
          }
        }
        let mut value = child_map.get(parent_layer).unwrap_or(0)
        if rank_of.get(child) is Some(child_layer) && child_layer > parent_layer {
          value += 1
        }
        map[child] = value
      }
      for layer, value in child_map {
        accumulator[layer] = accumulator.get(layer).unwrap_or(0) + value
      }
    }
    accumulator
  }

  for root in tree.roots {
    if !visited.contains(root) {
      dfs(root) |> ignore
    }
  }
  for node in nodes {
    if !visited.contains(node) {
      dfs(node) |> ignore
    }
  }
  cross_counts
}

///|
/// `compareByRankThenId`.
fn compare_by_rank_then_id(
  rank_of : Map[String, Int32],
) -> (String, String) -> Double {
  (a, b) => {
    let ra = rank_of.get(a).unwrap_or(0)
    let rb = rank_of.get(b).unwrap_or(0)
    if ra == rb {
      @model.locale_compare(a, b)
    } else {
      (ra - rb).to_double()
    }
  }
}

///|
/// The lowest rank in every subtree: `annotateMinimumLayers`.
fn annotate_minimum_layers(
  nodes : Array[String],
  children : Map[String, Array[String]],
  rank_of : Map[String, Int32],
) -> Map[String, Int32] {
  let min_layer : Map[String, Int32] = Map([])
  fn annotate(node : String) -> Unit {
    let mut min_l = rank_of.get(node).unwrap_or(0)
    let child_list = children.get(node).unwrap_or([]).copy()
    @d3.js_sort(child_list, compare_by_rank_then_id(rank_of))
    for child in child_list {
      annotate(child)
      if min_layer.get(child) is Some(child_min) {
        min_l = @cmp.minimum(min_l, child_min)
      }
    }
    min_layer[node] = min_l
  }

  for node in nodes {
    annotate(node)
  }
  min_layer
}

///|
/// The layers filled by a depth-first walk of the tree: `emitNodesInTreeOrder`.
fn emit_nodes_in_tree_order(
  roots : Array[String],
  all_nodes : Array[String],
  rank_of : Map[String, Int32],
  order_children : (String) -> Array[String],
) -> Array[Array[String]] {
  let mut max_rank = 0
  for node in all_nodes {
    let r = rank_of.get(node).unwrap_or(0)
    if r > max_rank {
      max_rank = r
    }
  }
  let layers : Array[Array[String]] = Array::makei(max_rank + 1, _ => [])
  let emitted : Set[String] = Set([])
  fn emit(node : String) -> Unit {
    if emitted.contains(node) {
      return
    }
    emitted.add(node)
    let layer = rank_of.get(node).unwrap_or(0)
    layers[layer].push(node)
    for child in order_children(node) {
      emit(child)
    }
  }

  for root in roots {
    emit(root)
  }
  for node in all_nodes {
    if !emitted.contains(node) {
      let layer = rank_of.get(node).unwrap_or(0)
      layers[layer].push(node)
      emitted.add(node)
    }
  }
  layers
}

///|
/// `deduplicateLayers`.
fn deduplicate_layers(layers : Array[Array[String]]) -> Array[Array[String]] {
  layers.map(layer => {
    let seen : Set[String] = Set([])
    let deduped = []
    for id in layer {
      if seen.contains(id) {
        continue
      }
      seen.add(id)
      deduped.push(id)
    }
    deduped
  })
}

///|
/// The children of a node in the order the walk takes them: those whose
/// subtree reaches no lower layer than the node's first, then the others
/// by fewest crossings: `createChildOrderer`.
fn create_child_orderer(
  children : Map[String, Array[String]],
  rank_of : Map[String, Int32],
  cross_counts : Map[String, Map[String, Int32]],
  min_layer : Map[String, Int32],
) -> (String) -> Array[String] {
  node => {
    let raw = children.get(node).unwrap_or([])
    if raw.is_empty() {
      return []
    }
    let layer = rank_of.get(node).unwrap_or(0)
    let future : Array[(String, Int32)] = []
    let present = []
    let cross_map = cross_counts.get(node)
    for child in raw {
      let min_l = min_layer.get(child).unwrap_or(layer)
      if min_l > layer {
        future.push((child, min_l))
      } else {
        present.push(child)
      }
    }
    @d3.js_sort(future, (a, b) => {
      if a.1 == b.1 {
        @model.locale_compare(a.0, b.0)
      } else {
        (a.1 - b.1).to_double()
      }
    })
    @d3.js_sort(present, (a, b) => {
      let count = (x : String) => {
        match cross_map {
          Some(map) => map.get(x).unwrap_or(0)
          None => 0
        }
      }
      let ca = count(a)
      let cb = count(b)
      if ca != cb {
        return (ca - cb).to_double()
      }
      let ma = min_layer.get(a).unwrap_or(layer)
      let mb = min_layer.get(b).unwrap_or(layer)
      if ma != mb {
        return (ma - mb).to_double()
      }
      @model.locale_compare(a, b)
    })
    future.map(item => item.0) + present
  }
}

///|
/// `buildMultitreeLayerOrder`.
fn build_multitree_layer_order(
  g : Graph,
  rank_of : Map[String, Int32],
  lane_of : (String) -> String?,
) -> Array[Array[String]] {
  let tree = build_driving_tree(g, lane_of, rank_of)
  let children = tree.children
  for node in g.nodes {
    if !children.contains(node) {
      children[node] = []
    }
  }
  let cross_counts = compute_subtree_cross_counts(g, rank_of, tree)
  let roots_sorted = tree.roots.copy()
  @d3.js_sort(roots_sorted, compare_by_rank_then_id(rank_of))
  let min_layer = annotate_minimum_layers(roots_sorted, children, rank_of)
  let order_children = create_child_orderer(
    children, rank_of, cross_counts, min_layer,
  )
  let layers = emit_nodes_in_tree_order(
    roots_sorted,
    g.nodes,
    rank_of,
    order_children,
  )
  deduplicate_layers(layers)
}

///|
/// `countCrossingsBetweenAdjacent` of `phase2.crossOptimization.ts`.
fn count_crossings_between_layers(
  upper : Array[String],
  lower : Array[String],
  edges : Array[GEdge],
) -> Int32 {
  let upper_set : Set[String] = Set([])
  for id in upper {
    upper_set.add(id)
  }
  let lower_set : Set[String] = Set([])
  for id in lower {
    lower_set.add(id)
  }
  let li = build_layer_index(lower)
  let vs = []
  for e in edges {
    if upper_set.contains(e.src) && lower_set.contains(e.dst) {
      vs.push(li[e.dst])
    }
  }
  count_inversions(vs)
}

///|
/// `totalCrossings`: edges spanning several ranks count on each.
fn total_crossings(
  layers : Array[Array[String]],
  edges : Array[GEdge],
  rank_of : Map[String, Int32],
) -> Int32 {
  let expanded = []
  for e in edges {
    guard rank_of.get(e.src) is Some(ru) && rank_of.get(e.dst) is Some(rv) else {
      continue
    }
    if ru == rv {
      continue
    }
    let (upper, lower, r_upper, r_lower) = if ru > rv {
      (e.dst, e.src, rv, ru)
    } else {
      (e.src, e.dst, ru, rv)
    }
    for l in r_upper..<r_lower {
      expanded.push({
        id: "\{e.id}@\{l}",
        src: upper,
        dst: lower,
        ref_: e.ref_,
      })
    }
  }
  let mut sum = 0
  for i in 0..<(layers.length() - 1) {
    sum += count_crossings_between_layers(layers[i], layers[i + 1], expanded)
  }
  sum
}

///|
/// Pull nodes up to their lowest feasible rank where that reduces the
/// crossings: `optimizeRanksByCrossings`.
fn optimize_ranks(
  g : Graph,
  initial_rank : Map[String, Int32],
) -> Map[String, Int32] {
  let rank_of = initial_rank.copy()
  let (preds, _) = build_predecessor_successor_maps(g)
  let lane_of = create_top_lane_resolver(g)
  let layers = build_multitree_layer_order(g, rank_of, lane_of)
  let mut best = total_crossings(layers, g.edges, rank_of)
  for _pass in 0..<MAX_CROSSING_OPTIMIZATION_PASSES {
    let mut changed = false
    let nodes_by_rank = g.nodes.copy()
    @d3.js_sort(nodes_by_rank, (a, b) => {
      (rank_of.get(b).unwrap_or(0) - rank_of.get(a).unwrap_or(0)).to_double()
    })
    for v in nodes_by_rank {
      let r = rank_of.get(v).unwrap_or(0)
      if r == 0 {
        continue
      }
      let mut lb = 0
      for u in preds.get(v).unwrap_or([]) {
        lb = @cmp.maximum(lb, rank_of.get(u).unwrap_or(0) + 1)
      }
      if lb >= r {
        continue
      }
      let old = r
      rank_of[v] = lb
      let trial_layers = build_multitree_layer_order(g, rank_of, lane_of)
      let score = total_crossings(trial_layers, g.edges, rank_of)
      if score < best {
        best = score
        changed = true
      } else {
        rank_of[v] = old
      }
    }
    if !changed {
      break
    }
  }
  rank_of
}

///|
/// A node whose edges all leave its lane, fed from its own lane, moves
/// down one rank per such edge: `adjustCrossLaneSources`.
fn adjust_cross_lane_sources(g : Graph, rank_of : Map[String, Int32]) -> Unit {
  let top_lane_of = create_top_lane_resolver(g)
  let nodes_by_rank = g.nodes.copy()
  @d3.js_sort(nodes_by_rank, (a, b) => {
    let d = rank_of.get(a).unwrap_or(0) - rank_of.get(b).unwrap_or(0)
    if d != 0 {
      d.to_double()
    } else {
      @model.locale_compare(a, b)
    }
  })
  for v in nodes_by_rank {
    guard top_lane_of(v) is Some(lane_v) && lane_v != "" else { continue }
    let out_edges = g.edges.filter(e => e.src == v)
    if out_edges.is_empty() {
      continue
    }
    let mut has_same_lane_succ = false
    let mut cross_lane_count = 0
    for e in out_edges {
      match top_lane_of(e.dst) {
        None => has_same_lane_succ = true
        Some(lane_dst) if lane_dst == lane_v => has_same_lane_succ = true
        Some(_) => cross_lane_count += 1
      }
    }
    if cross_lane_count == 0 || has_same_lane_succ {
      continue
    }
    let mut cross_lane_incoming = 0
    let mut has_same_lane_pred = false
    for e in g.edges {
      if e.dst != v {
        continue
      }
      guard top_lane_of(e.src) is Some(lane_src) && lane_src != "" else {
        continue
      }
      if lane_src == lane_v {
        has_same_lane_pred = true
      } else {
        cross_lane_incoming += 1
      }
    }
    if cross_lane_incoming > 0 || !has_same_lane_pred {
      continue
    }
    let current = rank_of.get(v).unwrap_or(0)
    let target = current + cross_lane_count
    let mut lb = 0
    for e in g.edges {
      if e.dst == v {
        lb = @cmp.maximum(lb, rank_of.get(e.src).unwrap_or(0) + 1)
      }
    }
    let new_rank = @cmp.maximum(current, @cmp.maximum(lb, target))
    if new_rank != current {
      rank_of[v] = new_rank
    }
  }
}
