// Breaking cycles (`phase1.cycles.ts`) and the lanes of nodes
// (`phase2.options.ts`).

///|
/// The graph made acyclic by reversing the back edges a depth-first search
/// finds, and the reversed edges: `removeCycles_DFS`.
fn remove_cycles_dfs(g : Graph) -> (Graph, Array[GEdge]) {
  let gn = normalize_graph(g)
  let adj : Map[String, Array[GEdge]] = Map([])
  for v in gn.nodes {
    adj[v] = []
  }
  for e in gn.edges {
    adj[e.src].push(e)
  }
  for _, arr in adj {
    @d3.js_sort(arr, (a, b) => {
      if a.dst == b.dst {
        @model.locale_compare(a.id, b.id)
      } else {
        @model.locale_compare(a.dst, b.dst)
      }
    })
  }
  let color : Map[String, Int32] = Map([])
  for v in gn.nodes {
    color[v] = 0
  }
  let reversed = []
  fn dfs(u : String) -> Unit {
    color[u] = 1
    for e in adj.get(u).unwrap_or([]) {
      let v = e.dst
      if color.get(v) == Some(0) {
        dfs(v)
      } else if color.get(v) == Some(1) {
        reversed.push(e)
      }
    }
    color[u] = 2
  }

  let in_degree = build_in_degree_map(gn)
  let seeds = gn.nodes.filter(v => in_degree.get(v).unwrap_or(0) == 0) +
    gn.nodes.filter(v => in_degree.get(v).unwrap_or(0) != 0)
  for v in seeds {
    if color.get(v) == Some(0) {
      dfs(v)
    }
  }
  let to_reverse : Set[String] = Set([])
  for e in reversed {
    to_reverse.add("\{e.id}:\{e.src}->\{e.dst}")
  }
  let acyc_edges = gn.edges.map(e => {
    if to_reverse.contains("\{e.id}:\{e.src}->\{e.dst}") {
      { id: e.id, src: e.dst, dst: e.src, ref_: e.ref_, }
    } else {
      e
    }
  })
  let acyclic = {
    nodes: gn.nodes.copy(),
    edges: acyc_edges,
    layout: gn.layout,
    node_by_id: gn.node_by_id.copy(),
  }
  (acyclic, reversed)
}

///|
/// The lane (top-level group) of every node, or `None` outside lanes:
/// `buildTopLaneMap`.
fn build_top_lane_map(g : Graph) -> Map[String, String?] {
  let cache : Map[String, String?] = Map([])
  fn resolve(id : String) -> String? {
    if cache.get(id) is Some(lane) {
      return lane
    }
    guard g.node_by_id.get(id) is Some(node) else {
      cache[id] = None
      return None
    }
    guard node.parent_id is Some(parent_id) && parent_id != "" else {
      cache[id] = None
      return None
    }
    let lane = match resolve(parent_id) {
      Some(lane) => lane
      None => parent_id
    }
    cache[id] = Some(lane)
    Some(lane)
  }

  for id in g.nodes {
    resolve(id) |> ignore
  }
  cache
}

///|
/// `createTopLaneResolver`.
fn create_top_lane_resolver(g : Graph) -> (String) -> String? {
  let top_lane_map = build_top_lane_map(g)
  id => {
    match top_lane_map.get(id) {
      Some(lane) => lane
      None => None
    }
  }
}

///|
/// The lanes in reverse source order: `buildTopLaneOrder`.
fn build_top_lane_order(g : Graph) -> Array[String] {
  let seen : Set[String] = Set([])
  for node in g.layout.nodes {
    if node.is_group && !has_parent(node) {
      seen.add(node.id)
    }
  }
  let lanes = seen.iter().collect()
  lanes.rev_in_place()
  lanes
}

///|
/// The lanes in the preferred order, then the others in source order:
/// `resolveTopLaneOrder`.
fn resolve_top_lane_order(
  g : Graph,
  preferred : Array[String]?,
) -> Array[String] {
  let source_order = build_top_lane_order(g)
  guard preferred is Some(preferred) && !preferred.is_empty() else {
    return source_order
  }
  let source_lane_ids : Set[String] = Set(source_order)
  let seen : Set[String] = Set([])
  let resolved = []
  for lane_id in preferred {
    if !source_lane_ids.contains(lane_id) || seen.contains(lane_id) {
      continue
    }
    seen.add(lane_id)
    resolved.push(lane_id)
  }
  for lane_id in source_order {
    if seen.contains(lane_id) {
      continue
    }
    resolved.push(lane_id)
  }
  resolved
}
