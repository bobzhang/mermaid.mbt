// Ranking: `phase2.laneAwareCompact.ts` (the default), `phase2.longestPath.ts`
// and `phase2.gravity.ts` (with `swimlane.ignoreCrossLaneEdges: false`),
// and the long edges split by placeholders (`phase2.dummies.ts`).

///|
/// The layers of a ranking and the rank of every node.
priv struct Layering {
  layers : Array[Array[String]]
  rank_of : Map[String, Int32]
  /// The placeholders of long edges.
  dummy : Array[String]
}

///|
/// A topological order by generations: every node whose predecessors are
/// all placed, generation by generation, each in `localeCompare` order:
/// `topoSortByGenerationIfAcyclic`.
fn topo_sort_by_generation_if_acyclic(g : Graph) -> Array[String]? {
  let indeg = build_in_degree_map(g)
  let adj = build_sorted_successor_map(g)
  let mut frontier = sorted_zero_in_degree_nodes(g, indeg)
  let order = []
  while !frontier.is_empty() {
    let next_frontier = []
    for u in frontier {
      order.push(u)
      for v in adj.get(u).unwrap_or([]) {
        indeg[v] = indeg.get(v).unwrap_or(0) - 1
        if indeg.get(v).unwrap_or(0) == 0 {
          next_frontier.push(v)
        }
      }
    }
    @d3.js_sort(next_frontier, @model.locale_compare)
    frontier = next_frontier
  }
  if order.length() == g.nodes.length() {
    Some(order)
  } else {
    None
  }
}

///|
/// The nodes sorted as `[...g.nodes].sort()` sorts them.
fn sorted_ids(g : Graph) -> Array[String] {
  let ids = g.nodes.copy()
  @d3.js_sort(ids, @model.code_unit_compare)
  ids
}

///|
/// Every node one rank below its lowest predecessor in the same lane and
/// below the nodes already placed in its lane: `assignLayers_LaneAwareCompact`.
fn assign_layers_lane_aware_compact(
  g_acyclic : Graph,
  ignore_cross_lane_edges~ : Bool,
  direction~ : String?,
) -> Layering {
  let g = normalize_graph(g_acyclic)
  let order = if direction == Some("LR") {
    match topo_sort_by_generation_if_acyclic(g) {
      Some(order) => order
      None => sorted_ids(g)
    }
  } else {
    match topo_sort_if_acyclic(g) {
      Some(order) => order
      None => sorted_ids(g)
    }
  }
  let top_lane_of = create_top_lane_resolver(g)
  let lane_of = (id : String) => {
    match top_lane_of(id) {
      Some(lane) => lane
      None => id
    }
  }
  let rank_of : Map[String, Int32] = Map([])
  let next_free : Map[String, Int32] = Map([])
  let edge_weight = (u : String, v : String) => {
    if ignore_cross_lane_edges {
      if lane_of(u) == lane_of(v) {
        1
      } else {
        0
      }
    } else {
      1
    }
  }
  for v in order {
    if g.node_by_id.get(v) is Some(node) && node.is_group {
      continue
    }
    let preds = incoming(g, v)
    let mut base = 0
    for e in preds {
      let u = e.src
      let ru = rank_of.get(u).unwrap_or(0)
      base = @cmp.maximum(base, ru + edge_weight(u, v))
    }
    let lane = lane_of(v)
    let nf = next_free.get(lane).unwrap_or(0)
    let l = @cmp.maximum(base, nf)
    rank_of[v] = l
    next_free[lane] = l + 1
  }
  let layers = build_layers_from_ranks(g, order, rank_of, skip_groups=true)
  { layers, rank_of, dummy: [], }
}

///|
/// The longest-path ranking: `assignLayers_LongestPath`.
fn assign_layers_longest_path(
  g_acyclic : Graph,
  compact_single_input~ : Bool,
  ignore_cross_lane_edges~ : Bool,
  optimize_ranks_by_crossings~ : Bool,
) -> Layering {
  let g = normalize_graph(g_acyclic)
  let order = match topo_sort_if_acyclic(g) {
    Some(order) => order
    None => sorted_ids(g)
  }
  let top_lane_of = create_top_lane_resolver(g)
  let mut rank_of : Map[String, Int32] = Map([])
  for v in order {
    let inc_all = incoming(g, v)
    let inc = if ignore_cross_lane_edges {
      inc_all.filter(e => {
        let lane_src = top_lane_of(e.src)
        let lane_dst = top_lane_of(v)
        match (lane_src, lane_dst) {
          (Some(a), Some(b)) if a != "" && b != "" => a == b
          _ => true
        }
      })
    } else {
      inc_all
    }
    if inc.is_empty() {
      rank_of[v] = 0
    } else if compact_single_input && inc.length() == 1 {
      let u = inc[0].src
      if top_lane_of(u) != top_lane_of(v) {
        rank_of[v] = rank_of.get(u).unwrap_or(0)
      } else {
        rank_of[v] = rank_of.get(u).unwrap_or(0) + 1
      }
    } else {
      let mut mx = None
      for e in inc {
        let r = rank_of.get(e.src).unwrap_or(0) + 1
        mx = Some(
          match mx {
            Some(m) => @cmp.maximum(m, r)
            None => r
          },
        )
      }
      rank_of[v] = mx.unwrap_or(0)
    }
  }
  if optimize_ranks_by_crossings {
    rank_of = optimize_ranks(g, rank_of)
  }
  if ignore_cross_lane_edges {
    adjust_cross_lane_sources(g, rank_of)
  }
  let layers = build_multitree_layer_order(g, rank_of, top_lane_of)
  { layers, rank_of, dummy: [], }
}

///|
/// The longest-path ranking relaxed towards the average rank of the
/// neighbours: `assignLayers_Gravity`.
fn assign_layers_gravity(
  g_acyclic : Graph,
  compact_single_input~ : Bool,
  ignore_cross_lane_edges~ : Bool,
  optimize_ranks_by_crossings~ : Bool,
) -> Layering {
  let g = normalize_graph(g_acyclic)
  let base = assign_layers_longest_path(
    g,
    compact_single_input~,
    ignore_cross_lane_edges~,
    optimize_ranks_by_crossings~,
  )
  let rank_of = base.rank_of.copy()
  let top_lane_of = create_top_lane_resolver(g)
  let (preds, succs) = build_predecessor_successor_maps(g, include_edge=e => {
    if ignore_cross_lane_edges {
      let lane_src = top_lane_of(e.src)
      let lane_dst = top_lane_of(e.dst)
      if lane_src is Some(a) &&
        a != "" &&
        lane_dst is Some(b) &&
        b != "" &&
        a != b {
        return false
      }
    }
    true
  })
  let order = match topo_sort_if_acyclic(g) {
    Some(order) => order
    None => g.nodes.copy()
  }
  let rev_order = order.copy()
  rev_order.rev_in_place()
  let rank = (v : String) => rank_of.get(v).unwrap_or(0).to_double()
  // Ranks are whole numbers here, kept as doubles while `Infinity` and
  // averages are involved.
  let clamp_feasible = (v : String, desired : Double) => {
    let mut lb = 0.0
    for u in preds.get(v).unwrap_or([]) {
      lb = @model.js_max(lb, rank(u) + 1.0)
    }
    let mut ub = @double.infinity
    let s = succs.get(v).unwrap_or([])
    if !s.is_empty() {
      for w in s {
        ub = @model.js_min(ub, rank(w) - 1.0)
      }
    }
    if ub.is_inf() || ub.is_nan() {
      ub = @model.js_max(lb, desired)
    }
    @model.js_min(@model.js_max(desired, lb), ub)
  }
  let relax_order = (node_order : Array[String]) => {
    let mut changed = false
    for v in node_order {
      let ps = preds.get(v).unwrap_or([])
      let ss = succs.get(v).unwrap_or([])
      if ps.is_empty() && ss.is_empty() {
        continue
      }
      let pred_avg = if !ps.is_empty() {
        let mut a = 0.0
        for u in ps {
          a = a + rank(u) + 1.0
        }
        a / ps.length().to_double()
      } else {
        rank(v)
      }
      let succ_avg = if !ss.is_empty() {
        let mut a = 0.0
        for w in ss {
          a = a + rank(w) - 1.0
        }
        a / ss.length().to_double()
      } else {
        rank(v)
      }
      let desired = @model.js_round((pred_avg + succ_avg) / 2.0)
      let clamped = clamp_feasible(v, desired)
      if rank_of.get(v).map(r => r.to_double()) != Some(clamped) {
        rank_of[v] = clamped.to_int()
        changed = true
      }
    }
    changed
  }
  for _ in 0..<GRAVITY_ITERATIONS {
    let forward_changed = relax_order(order)
    let backward_changed = relax_order(rev_order)
    if !forward_changed && !backward_changed {
      break
    }
  }
  for v in order {
    let mut lb = 0
    for u in preds.get(v).unwrap_or([]) {
      lb = @cmp.maximum(lb, rank_of.get(u).unwrap_or(0) + 1)
    }
    if rank_of.get(v).unwrap_or(0) < lb {
      rank_of[v] = lb
    }
  }
  for v in rev_order {
    let s = succs.get(v).unwrap_or([])
    if !s.is_empty() {
      let mut ub = rank_of.get(s[0]).unwrap_or(0) - 1
      for w in s {
        ub = @cmp.minimum(ub, rank_of.get(w).unwrap_or(0) - 1)
      }
      if rank_of.get(v).unwrap_or(0) > ub {
        rank_of[v] = ub
      }
    }
  }
  let layers = build_layers_from_ranks(g, order, rank_of)
  { layers, rank_of, dummy: [], }
}

///|
/// `LAYERING.GRAVITY_ITERATIONS`
const GRAVITY_ITERATIONS : Int32 = 8

///|
/// `LAYERING.MAX_CROSSING_OPTIMIZATION_PASSES`
const MAX_CROSSING_OPTIMIZATION_PASSES : Int32 = 4

///|
/// Where upstream's layout throws: the message of the JavaScript error.
pub(all) suberror LayeringError {
  LayeringError(String)
} derive(Debug)

///|
/// The graph with every edge longer than one rank split by placeholders,
/// one per rank in between: `makeProperLayering`. The gravity ranking can
/// give negative ranks; a placeholder there is pushed onto a layer that
/// does not exist, and upstream throws.
fn make_proper_layering(
  layering : Layering,
  g_acyclic : Graph,
) -> (Layering, Graph) raise LayeringError {
  let g = normalize_graph(g_acyclic)
  let rank_of = layering.rank_of
  let layers = layering.layers.map(l => l.copy())
  let dummy_set : Set[String] = Set([])
  for id in layering.dummy {
    dummy_set.add(id)
  }
  let mut dummy_seq = 0
  let node_by_id = g.node_by_id.copy()
  let add_dummy_at = (l : Int32) => {
    if l < 0 {
      raise LayeringError(
        "Cannot read properties of undefined (reading 'push')",
      )
    }
    let id = "placeholder-\{dummy_seq}"
    dummy_seq += 1
    let dn = @model.Node::new(id~, is_dummy=true, width=0.0, height=0.0)
    node_by_id[id] = dn
    dummy_set.add(id)
    while layers.length() <= l {
      layers.push([])
    }
    layers[l].push(id)
    rank_of[id] = l
    id
  }
  let edges_sorted = g.edges.copy()
  @d3.js_sort(edges_sorted, (a, b) => {
    if a.id == b.id {
      if a.src == b.src {
        @model.locale_compare(a.dst, b.dst)
      } else {
        @model.locale_compare(a.src, b.src)
      }
    } else {
      @model.locale_compare(a.id, b.id)
    }
  })
  let new_edges = []
  for e in edges_sorted {
    let ru = rank_of.get(e.src).unwrap_or(0)
    let rv = rank_of.get(e.dst).unwrap_or(0)
    if rv - ru <= 1 {
      new_edges.push(e)
      continue
    }
    let mut prev = e.src
    let mut k = 0
    for l in (ru + 1)..<rv {
      let d = add_dummy_at(l)
      new_edges.push({ id: "\{e.id}#\{k}", src: prev, dst: d, ref_: e.ref_, })
      prev = d
      k += 1
    }
    let last_index = rv - ru - 2
    new_edges.push({
      id: "\{e.id}#\{@cmp.maximum(last_index + 1, 0)}",
      src: prev,
      dst: e.dst,
      ref_: e.ref_,
    })
  }
  let nodes = g.nodes.copy()
  for id in dummy_set {
    if !g.nodes.contains(id) {
      nodes.push(id)
    }
  }
  let dummy = dummy_set.iter().collect()
  (
    { layers, rank_of, dummy, },
    { nodes, edges: new_edges, layout: g.layout, node_by_id, },
  )
}
