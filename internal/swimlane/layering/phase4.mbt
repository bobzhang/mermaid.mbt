// Coordinates: `phase4.coordinates.ts`. Lanes are columns as wide as their
// widest layer, side by side; every layer is a row as high as its highest
// node.

///|
/// The centre of every node: `assignCoordinates`.
fn assign_coordinates(
  layers : Array[Array[String]],
  g_with_dummies : Graph,
  layer_gap~ : Double,
  node_gap~ : Double,
  direction~ : String,
  lane_order~ : Array[String]?,
) -> (Map[String, Double], Map[String, Double]) {
  let lane_gap = node_gap * 2.0
  let is_horizontal = direction == "LR" || direction == "RL"
  let x : Map[String, Double] = Map([])
  let y : Map[String, Double] = Map([])
  let get_width = (id : String) => {
    match g_with_dummies.node_by_id.get(id) {
      Some(node) => node.width.unwrap_or(0.0)
      None => 0.0
    }
  }
  let get_height = (id : String) => {
    match g_with_dummies.node_by_id.get(id) {
      Some(node) => node.height.unwrap_or(0.0)
      None => 0.0
    }
  }
  let top_lane_of = create_top_lane_resolver(g_with_dummies)
  let lane_order_global = resolve_top_lane_order(g_with_dummies, lane_order)
  let max_of = (layer : Array[String], f : (String) -> Double) => {
    let mut m = 0.0
    for v in layer {
      m = @model.js_max(m, f(v))
    }
    m
  }
  let layer_heights = layers.map(layer => max_of(layer, get_height))
  let extra_layer_gaps = []
  if is_horizontal {
    for i in 0..<(layers.length() - 1) {
      let this_layer_max_width = max_of(layers[i], get_width)
      let next_layer_max_width = max_of(layers[i + 1], get_width)
      let this_layer_max_height = layer_heights[i]
      let next_layer_max_height = layer_heights[i + 1]
      let normal_spacing = this_layer_max_height / 2.0 +
        next_layer_max_height / 2.0
      let required_spacing = (this_layer_max_width + next_layer_max_width) / 2.0
      let extra_needed = @model.js_max(
        0.0,
        required_spacing - normal_spacing - layer_gap,
      )
      extra_layer_gaps.push(extra_needed)
    }
  }
  let lanes_used_set : Set[String?] = Set([])
  for layer in layers {
    for id in layer {
      lanes_used_set.add(top_lane_of(id))
    }
  }
  let has_null_lane = lanes_used_set.contains(None)
  let lanes_used = lane_order_global.filter(l => {
    lanes_used_set.contains(Some(l))
  })
  let lane_order_columns : Array[String?] = (if has_null_lane {
      [None]
    } else {
      []
    }) +
    lanes_used.map(l => Some(l))
  // Upstream keys this by lane id with `null` as the key "null"; a lane
  // called "null" is refused before the layout starts.
  let lane_width : Map[String?, Double] = Map([])
  for l in lanes_used {
    lane_width[Some(l)] = 0.0
  }
  if has_null_lane {
    lane_width[None] = 0.0
  }
  for layer in layers {
    let per_lane : Map[String, Array[String]] = Map([])
    let null_ids = []
    for id in layer {
      match top_lane_of(id) {
        None => null_ids.push(id)
        Some(l) =>
          match per_lane.get(l) {
            Some(ids) => ids.push(id)
            None => per_lane[l] = [id]
          }
      }
    }
    for l, ids in per_lane {
      let mut s = 0.0
      for id in ids {
        s = s + get_width(id)
      }
      let total = s + node_gap * @cmp.maximum(0, ids.length() - 1).to_double()
      lane_width[Some(l)] = @model.js_max(
        lane_width.get(Some(l)).unwrap_or(0.0),
        total,
      )
    }
    if has_null_lane && !null_ids.is_empty() {
      let mut s = 0.0
      for id in null_ids {
        s = s + get_width(id)
      }
      let total_null = s +
        node_gap * @cmp.maximum(0, null_ids.length() - 1).to_double()
      lane_width[None] = @model.js_max(
        lane_width.get(None).unwrap_or(0.0),
        total_null,
      )
    }
  }
  let center_x : Map[String?, Double] = Map([])
  {
    let widths = lane_order_columns.map(l => lane_width.get(l).unwrap_or(0.0))
    let mut sum = 0.0
    for w in widths {
      sum = sum + w
    }
    let total_w = sum +
      lane_gap * @cmp.maximum(0, lane_order_columns.length() - 1).to_double()
    let mut cursor = -total_w / 2.0
    for i, l in lane_order_columns {
      let w = widths[i]
      let cx = cursor + w / 2.0
      center_x[l] = cx
      cursor = cursor + w
      if i < lane_order_columns.length() - 1 {
        cursor = cursor + lane_gap
      }
    }
  }
  let mut y_offset = 0.0
  for li, layer in layers {
    let layer_h = layer_heights[li]
    let by_lane : Map[String?, Array[String]] = Map([])
    for id in layer {
      let lane_id = top_lane_of(id)
      match by_lane.get(lane_id) {
        Some(arr) => arr.push(id)
        None => by_lane[lane_id] = [id]
      }
    }
    for l in lane_order_columns {
      let nodes_in_lane = by_lane.get(l).unwrap_or([])
      if nodes_in_lane.is_empty() {
        continue
      }
      // Every column has a centre.
      let cx = center_x[l]
      if nodes_in_lane.length() == 1 {
        let id = nodes_in_lane[0]
        x[id] = cx
        y[id] = y_offset + layer_h / 2.0
      } else {
        let widths = nodes_in_lane.map(get_width)
        let mut sum = 0.0
        for w in widths {
          sum = sum + w
        }
        let total = sum + node_gap * (nodes_in_lane.length() - 1).to_double()
        let mut start = cx - total / 2.0
        for i, id in nodes_in_lane {
          let w = widths[i]
          x[id] = start + w / 2.0
          y[id] = y_offset + layer_h / 2.0
          start = start + w + node_gap
        }
      }
    }
    let extra_gap = if li < extra_layer_gaps.length() {
      extra_layer_gaps[li]
    } else {
      0.0
    }
    y_offset = y_offset + layer_h + layer_gap + extra_gap
  }
  // Placeholders of one edge line up halfway between its ends.
  let by_ref : Map[String, Array[GEdge]] = Map([])
  for e in g_with_dummies.edges {
    let rid = e.ref_.id
    match by_ref.get(rid) {
      Some(list) => list.push(e)
      None => by_ref[rid] = [e]
    }
  }
  for _, chain_edges in by_ref {
    if chain_edges.is_empty() {
      continue
    }
    let ref_ = chain_edges[0].ref_
    let src = ref_.start
    let dst = ref_.end
    let mid_x = @model.js_round(
      (x.get(src).unwrap_or(0.0) + x.get(dst).unwrap_or(0.0)) / 2.0,
    )
    let involved : Set[String] = Set([])
    for e in chain_edges {
      involved.add(e.src)
      involved.add(e.dst)
    }
    for vid in involved {
      if vid == src || vid == dst {
        continue
      }
      if g_with_dummies.node_by_id.get(vid) is Some(node) && node.is_dummy {
        x[vid] = mid_x
      }
    }
  }
  (x, y)
}
