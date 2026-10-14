// Ordering the nodes within their layers: `phase3.ordering.ts`.

///|
/// `median`: +∞ for no values.
fn median(values : Array[Int32]) -> Double {
  let n = values.length()
  if n == 0 {
    return @double.infinity
  }
  let a = values.copy()
  @d3.js_sort(a, (x, y) => (x - y).to_double())
  if n % 2 == 1 {
    return a[(n - 1) / 2].to_double()
  }
  0.5 * (a[n / 2 - 1].to_double() + a[n / 2].to_double())
}

///|
/// `barycenter`: +∞ for no values.
fn barycenter(values : Array[Int32]) -> Double {
  if values.is_empty() {
    return @double.infinity
  }
  let mut s = 0.0
  for v in values {
    s = s + v.to_double()
  }
  s / values.length().to_double()
}

///|
/// The positions of the neighbours in the fixed layer of every node of the
/// target layer: `neighborPositionsFor`.
fn neighbor_positions_for(
  target_nodes : Array[String],
  fixed_index : Map[String, Int32],
  edges : Array[GEdge],
  down : Bool,
) -> Map[String, Array[Int32]] {
  let neighbor_positions : Map[String, Array[Int32]] = Map([])
  for v in target_nodes {
    neighbor_positions[v] = []
  }
  for e in edges {
    if down {
      if fixed_index.get(e.src) is Some(i) &&
        neighbor_positions.get(e.dst) is Some(list) {
        list.push(i)
      }
    } else if fixed_index.get(e.dst) is Some(i) &&
      neighbor_positions.get(e.src) is Some(list) {
      list.push(i)
    }
  }
  neighbor_positions
}

///|
/// `currentOrderTieBreak`.
fn current_order_tie_break(
  a : String,
  b : String,
  current_layer_index : Map[String, Int32],
) -> Double {
  let ia = current_layer_index.get(a).unwrap_or(0)
  let ib = current_layer_index.get(b).unwrap_or(0)
  if ia != ib {
    (ia - ib).to_double()
  } else {
    @model.locale_compare(a, b)
  }
}

///|
/// The crossings between two adjacent layers: `countCrossingsBetweenAdjacent`
/// of `phase3.ordering.ts`.
fn count_crossings_between_adjacent(
  upper : Array[String],
  lower : Array[String],
  edges : Array[GEdge],
) -> Int32 {
  let upper_index = build_layer_index(upper)
  let lower_index = build_layer_index(lower)
  let pairs : Array[(Int32, Int32)] = []
  for e in edges {
    if upper_index.get(e.src) is Some(u) && lower_index.get(e.dst) is Some(v) {
      pairs.push((u, v))
    }
  }
  @d3.js_sort(pairs, (a, b) => {
    if a.0 == b.0 {
      (a.1 - b.1).to_double()
    } else {
      (a.0 - b.0).to_double()
    }
  })
  count_inversions(pairs.map(p => p.1))
}

///|
/// The nodes by the median position of their neighbours, those without
/// neighbours last: `sortByHeuristic`.
fn sort_by_heuristic(
  nodes : Array[String],
  neighbor_positions : Map[String, Array[Int32]],
  current_layer_index : Map[String, Int32],
) -> Array[String] {
  let sorted = nodes.copy()
  @d3.js_sort(sorted, (a, b) => {
    let sa = median(neighbor_positions.get(a).unwrap_or([]))
    let sb = median(neighbor_positions.get(b).unwrap_or([]))
    if sa == sb {
      return current_order_tie_break(a, b, current_layer_index)
    }
    if sa.is_inf() || sa.is_nan() {
      return 1.0
    }
    if sb.is_inf() || sb.is_nan() {
      return -1.0
    }
    sa - sb
  })
  sorted
}

///|
/// One sweep over a layer: lane by lane in lane order, then the nodes
/// outside lanes inserted by barycentre: `reorderLayer`.
fn reorder_layer(
  fixed_layer : Array[String],
  target_layer : Array[String],
  edges : Array[GEdge],
  down : Bool,
  top_lane_of : (String) -> String?,
  lane_order : Array[String],
) -> Array[String] {
  let fixed_index = build_layer_index(fixed_layer)
  let curr_index = build_layer_index(target_layer)
  let neighbor_positions = neighbor_positions_for(
    target_layer, fixed_index, edges, down,
  )
  if lane_order.is_empty() {
    return sort_by_heuristic(target_layer, neighbor_positions, curr_index)
  }
  let by_lane : Map[String, Array[String]] = Map([])
  let null_nodes = []
  for id in target_layer {
    match top_lane_of(id) {
      Some(lane) =>
        match by_lane.get(lane) {
          Some(arr) => arr.push(id)
          None => by_lane[lane] = [id]
        }
      None => null_nodes.push(id)
    }
  }
  let result = []
  for lane in lane_order {
    guard by_lane.get(lane) is Some(nodes_in_lane) && !nodes_in_lane.is_empty() else {
      continue
    }
    result.append(
      sort_by_heuristic(nodes_in_lane, neighbor_positions, curr_index),
    )
  }
  if !null_nodes.is_empty() {
    let sorted = sort_by_heuristic(null_nodes, neighbor_positions, curr_index)
    for nid in sorted {
      let bc = barycenter(neighbor_positions.get(nid).unwrap_or([]))
      let mut best_idx = result.length()
      if !bc.is_inf() && !bc.is_nan() {
        for i, rid in result {
          let r_bc = barycenter(neighbor_positions.get(rid).unwrap_or([]))
          if bc < r_bc {
            best_idx = i
            break
          }
        }
      }
      result.insert(best_idx, nid)
    }
  }
  result
}

///|
/// Swap neighbours of one lane while that removes crossings with the
/// layers on both sides: `transposeImprove`.
fn transpose_improve(
  upper : Array[String],
  current : Array[String],
  edges : Array[GEdge],
  next : Array[String]?,
  top_lane_of : (String) -> String?,
) -> Array[String] {
  let best = current.copy()
  let upper_set : Set[String] = Set([])
  for id in upper {
    upper_set.add(id)
  }
  let layer_set : Set[String] = Set([])
  for id in current {
    layer_set.add(id)
  }
  let next_set : Set[String]? = match next {
    Some(next) => {
      let set = Set([])
      for id in next {
        set.add(id)
      }
      Some(set)
    }
    None => None
  }
  let edges_in = edges.filter(e => {
    upper_set.contains(e.src) && layer_set.contains(e.dst)
  })
  let edges_out = match next_set {
    Some(set) =>
      Some(edges.filter(e => layer_set.contains(e.src) && set.contains(e.dst)))
    None => None
  }
  let crossing_score = (order : Array[String]) => {
    let mut score = count_crossings_between_adjacent(upper, order, edges_in)
    if edges_out is Some(out) && next is Some(next) {
      score += count_crossings_between_adjacent(order, next, out)
    }
    score
  }
  let lane_of : Map[String, String?] = Map([])
  for id in current {
    lane_of[id] = top_lane_of(id)
  }
  let mut improved = true
  let mut best_score = crossing_score(best)
  while improved {
    improved = false
    for i in 0..<(best.length() - 1) {
      if lane_of.get(best[i]) != lane_of.get(best[i + 1]) {
        continue
      }
      let prev = best_score
      best.swap(i, i + 1)
      let next_score = crossing_score(best)
      if next_score < prev {
        best_score = next_score
        improved = true
      } else {
        best.swap(i, i + 1)
      }
    }
  }
  best
}

///|
/// Three down-and-up sweeps of median ordering and transposition:
/// `orderLayers`.
fn order_layers(
  layering : Layering,
  g_with_dummies : Graph,
  lane_order : Array[String]?,
) -> Array[Array[String]] {
  let layers = layering.layers.map(l => l.copy())
  let edges = g_with_dummies.edges
  let top_lane_of = create_top_lane_resolver(g_with_dummies)
  let resolved_lane_order = resolve_top_lane_order(g_with_dummies, lane_order)
  let layer_at = (i : Int32) => {
    if i >= 0 && i < layers.length() {
      Some(layers[i])
    } else {
      None
    }
  }
  for _s in 0..<3 {
    for i in 1..<layers.length() {
      layers[i] = reorder_layer(
        layers[i - 1],
        layers[i],
        edges,
        true,
        top_lane_of,
        resolved_lane_order,
      )
      layers[i] = transpose_improve(
        layers[i - 1],
        layers[i],
        edges,
        layer_at(i + 1),
        top_lane_of,
      )
    }
    for i = layers.length() - 2; i >= 0; i = i - 1 {
      layers[i] = reorder_layer(
        layers[i + 1],
        layers[i],
        edges,
        false,
        top_lane_of,
        resolved_lane_order,
      )
      layers[i] = transpose_improve(
        layers[i + 1],
        layers[i],
        edges,
        layer_at(i - 1),
        top_lane_of,
      )
    }
  }
  layers
}
