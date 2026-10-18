// Ordering the lanes to shorten the edges between them, with
// `swimlane.automaticLaneOrdering`: `laneOrdering.ts`.

///|
/// `AUTOMATIC_LANE_ORDERING_RESTARTS`
const AUTOMATIC_LANE_ORDERING_RESTARTS : Int32 = 8

///|
/// FNV-1a over the UTF-16 code units: `hashString`.
fn hash_string(input : String) -> UInt32 {
  let mut hash = 2166136261U
  for i in 0..<input.length() {
    hash = hash ^ input.code_unit_at(i).to_int().reinterpret_as_uint()
    hash = hash * 16777619U
  }
  hash
}

///|
/// The mulberry32 generator: `mulberry32`.
fn mulberry32(seed : UInt32) -> () -> Double {
  let mut state = seed
  () => {
    state = state + 1831565813U
    let mut t = state
    t = (t ^ (t >> 15)) * (t | 1U)
    t = t ^ (t + (t ^ (t >> 7)) * (t | 61U))
    (t ^ (t >> 14)).to_double() / 4294967296.0
  }
}

///|
/// A Fisher-Yates shuffle driven by mulberry32: `deterministicShuffle`.
fn deterministic_shuffle(order : Array[String], seed : UInt32) -> Array[String] {
  let shuffled = order.copy()
  let random = mulberry32(seed)
  for i = shuffled.length() - 1; i > 0; i = i - 1 {
    let j = (random() * (i + 1).to_double()).floor().to_int()
    shuffled.swap(i, j)
  }
  shuffled
}

///|
/// `sourceDistance`.
fn source_distance(
  order : Array[String],
  source_index : Map[String, Int32],
) -> Int32 {
  let mut distance = 0
  for index, lane_id in order {
    distance += (index - source_index.get(lane_id).unwrap_or(index)).abs()
  }
  distance
}

///|
/// The lanes an edge joins and how many edges join them.
priv struct LaneWeight {
  a : String
  b : String
  mut weight : Int32
}

///|
/// `laneArrangementCost`.
fn lane_arrangement_cost(
  order : Array[String],
  weights : Array[LaneWeight],
) -> Int32 {
  let position : Map[String, Int32] = Map([])
  for index, lane_id in order {
    position[lane_id] = index
  }
  let mut cost = 0
  for w in weights {
    guard position.get(w.a) is Some(ai) && position.get(w.b) is Some(bi) else {
      continue
    }
    cost += w.weight * (ai - bi).abs()
  }
  cost
}

///|
/// `buildWeightedLaneEdges`.
fn build_weighted_lane_edges(g : Graph) -> Array[LaneWeight] {
  let source_order = build_top_lane_order(g)
  if source_order.length() < 2 {
    return []
  }
  let source_index : Map[String, Int32] = Map([])
  for index, lane_id in source_order {
    source_index[lane_id] = index
  }
  let top_lane_of = create_top_lane_resolver(g)
  let weights : Map[String, LaneWeight] = Map([])
  for edge in g.layout.edges {
    if edge.is_layout_only {
      continue
    }
    let src = edge.start
    let dst = edge.end
    if src == "" ||
      dst == "" ||
      !g.node_by_id.contains(src) ||
      !g.node_by_id.contains(dst) {
      continue
    }
    guard top_lane_of(src) is Some(lane_a) &&
      lane_a != "" &&
      top_lane_of(dst) is Some(lane_b) &&
      lane_b != "" &&
      lane_a != lane_b else {
      continue
    }
    guard source_index.get(lane_a) is Some(ia) &&
      source_index.get(lane_b) is Some(ib) else {
      continue
    }
    let (a, b) = if ia <= ib { (lane_a, lane_b) } else { (lane_b, lane_a) }
    let key = "\{a}\u{0}\{b}"
    match weights.get(key) {
      Some(existing) => existing.weight += 1
      None => weights[key] = { a, b, weight: 1, }
    }
  }
  weights.values().collect()
}

///|
/// The result of one greedy descent.
priv struct LaneCandidate {
  order : Array[String]
  cost : Int32
  source_distance : Int32
}

///|
/// Adjacent swaps while they lower the cost: `greedySwitch`.
fn greedy_switch(
  start_order : Array[String],
  weights : Array[LaneWeight],
  source_index : Map[String, Int32],
) -> LaneCandidate {
  let order = start_order.copy()
  let mut cost = lane_arrangement_cost(order, weights)
  let mut changed = true
  let mut sweeps = 0
  let max_sweeps = @cmp.maximum(1, order.length())
  while changed && sweeps < max_sweeps {
    changed = false
    sweeps += 1
    for i in 0..<(order.length() - 1) {
      order.swap(i, i + 1)
      let next_cost = lane_arrangement_cost(order, weights)
      if next_cost < cost {
        cost = next_cost
        changed = true
      } else {
        order.swap(i, i + 1)
      }
    }
  }
  { order, cost, source_distance: source_distance(order, source_index), }
}

///|
/// `seedForRestart`.
fn seed_for_restart(
  source_order : Array[String],
  weights : Array[LaneWeight],
  restart_index : Int32,
) -> UInt32 {
  let sorted = weights.copy()
  @d3.js_sort(sorted, (x, y) => {
    if x.a == y.a {
      @model.locale_compare(x.b, y.b)
    } else {
      @model.locale_compare(x.a, y.a)
    }
  })
  let signature = sorted.map(w => "\{w.a}:\{w.b}:\{w.weight}").iter().join("|")
  hash_string("\{source_order.iter().join("|")}#\{signature}#\{restart_index}")
}

///|
/// The lane order with the shortest edges between lanes, from the source
/// order and eight shuffled starts: `optimizeTopLaneOrder`.
fn optimize_top_lane_order(g : Graph) -> Array[String] {
  let source_order = build_top_lane_order(g)
  if source_order.length() < 2 {
    return source_order
  }
  let weights = build_weighted_lane_edges(g)
  if weights.is_empty() {
    return source_order
  }
  let source_index : Map[String, Int32] = Map([])
  for index, lane_id in source_order {
    source_index[lane_id] = index
  }
  let mut best = greedy_switch(source_order, weights, source_index)
  for i in 0..<AUTOMATIC_LANE_ORDERING_RESTARTS {
    let seed = seed_for_restart(source_order, weights, i)
    let start = deterministic_shuffle(source_order, seed)
    let candidate = greedy_switch(start, weights, source_index)
    let better = if candidate.cost != best.cost {
      candidate.cost < best.cost
    } else {
      candidate.source_distance < best.source_distance
    }
    if better {
      best = candidate
    }
  }
  best.order
}
