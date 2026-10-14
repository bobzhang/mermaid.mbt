// The ranking and placement: `sugiyamaLayout` (`pipeline.ts`) and
// `writeBackToLayoutData` (`helpers.ts`).

///|
/// `TOP_LANE_TITLE_BAND_HEIGHT`
const TOP_LANE_TITLE_BAND_HEIGHT : Double = 21.0

///|
/// `MIN_TOP_LANE_HORIZONTAL_PADDING`
const MIN_TOP_LANE_HORIZONTAL_PADDING : Double = 20.0

///|
/// `topLaneHorizontalPadding`.
fn top_lane_horizontal_padding(lane : @model.Node) -> Double {
  @model.js_max(
    lane.padding.unwrap_or(MIN_TOP_LANE_HORIZONTAL_PADDING),
    MIN_TOP_LANE_HORIZONTAL_PADDING,
  )
}

///|
/// The band at the top of a lane its title goes in: `assignTopLaneTitleRect`.
fn assign_top_lane_title_rect(lane : @model.Node) -> Unit {
  guard lane.x is Some(x) &&
    lane.y is Some(y) &&
    lane.width is Some(width) &&
    lane.height is Some(height) &&
    lane.swimlane_content_top is Some(content_top) &&
    is_finite(x) &&
    is_finite(y) &&
    is_finite(width) &&
    is_finite(height) &&
    is_finite(content_top) &&
    width > 0.0 &&
    height > 0.0 else {
    lane.group_title_rect = None
    return
  }
  let top = y - height / 2.0
  let header_bottom = @model.js_min(content_top, y + height / 2.0)
  let title_height = @model.js_min(
    TOP_LANE_TITLE_BAND_HEIGHT,
    @model.js_max(0.0, header_bottom - top),
  )
  let bottom = top + title_height
  if bottom <= top {
    lane.group_title_rect = None
    return
  }
  lane.group_title_rect = Some({
    left: x - width / 2.0,
    right: x + width / 2.0,
    top,
    bottom,
  })
}

///|
fn is_finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
/// Rank, order and place the nodes, then size the groups and lanes:
/// `sugiyamaLayout` and `writeBackToLayoutData` as `runSwimlaneLayoutCore`
/// calls them.
pub fn rank_and_place(
  layout : @model.Layout,
  direction : String,
) -> Unit raise LayeringError {
  let g = to_graph_view(layout)
  let options = layout.options
  let node_gap = options.node_spacing.unwrap_or(40.0)
  let layer_gap = options.rank_spacing.unwrap_or(100.0)
  let g0 = normalize_graph(g)
  let lane_order = if options.automatic_lane_ordering {
    Some(optimize_top_lane_order(g0))
  } else {
    None
  }
  let (g_acyclic, _) = remove_cycles_dfs(g0)
  let layering = if options.ignore_cross_lane_edges {
    assign_layers_lane_aware_compact(
      g_acyclic,
      ignore_cross_lane_edges=true,
      direction=Some(direction),
    )
  } else {
    assign_layers_gravity(
      g_acyclic,
      compact_single_input=true,
      ignore_cross_lane_edges=false,
      optimize_ranks_by_crossings=options.optimize_ranks_by_crossings,
    )
  }
  let (proper_layering, graph_with_dummies) = make_proper_layering(
    layering, g_acyclic,
  )
  let ordered = order_layers(proper_layering, graph_with_dummies, lane_order)
  let (x, y) = assign_coordinates(
    ordered,
    graph_with_dummies,
    layer_gap~,
    node_gap~,
    direction~,
    lane_order~,
  )
  write_back(g, ordered, x, y, node_gap~, layer_gap~)
}

///|
/// The positions back on the layout's nodes, every group sized around its
/// children and the lanes made as high as each other and wide enough for
/// their content: `writeBackToLayoutData`.
fn write_back(
  g : Graph,
  ordered : Array[Array[String]],
  coords_x : Map[String, Double],
  coords_y : Map[String, Double],
  node_gap~ : Double,
  layer_gap~ : Double,
) -> Unit {
  let layout = g.layout
  let node_map = g.node_by_id
  for layer_index, layer in ordered {
    for order_index, id in layer {
      guard node_map.get(id) is Some(node) else { continue }
      node.layer = Some(layer_index)
      node.order = Some(order_index)
      let x = coords_x.get(id).unwrap_or(order_index.to_double() * node_gap)
      let y = coords_y.get(id).unwrap_or(layer_index.to_double() * layer_gap)
      node.x = Some(x)
      node.y = Some(y)
    }
  }
  let all_nodes = layout.nodes
  let group_bounds : Map[String, (Double, Double, Double, Double)] = Map([])
  let top_level_groups = []
  for group in all_nodes {
    if !group.is_group {
      continue
    }
    if !has_parent(group) {
      top_level_groups.push(group)
    }
    let mut min_x = @double.infinity
    let mut max_x = @double.neg_infinity
    let mut min_y = @double.infinity
    let mut max_y = @double.neg_infinity
    for child in all_nodes {
      guard child.parent_id is Some(parent) && parent == group.id else {
        continue
      }
      let cx = match child.x {
        Some(cx) => Some(cx)
        None => coords_x.get(child.id)
      }
      let cy = match child.y {
        Some(cy) => Some(cy)
        None => coords_y.get(child.id)
      }
      let cw = child.width.unwrap_or(0.0)
      let ch = child.height.unwrap_or(0.0)
      if cx is Some(cx) && cy is Some(cy) {
        min_x = @model.js_min(min_x, cx - cw / 2.0)
        max_x = @model.js_max(max_x, cx + cw / 2.0)
        min_y = @model.js_min(min_y, cy - ch / 2.0)
        max_y = @model.js_max(max_y, cy + ch / 2.0)
      }
    }
    if min_x == @double.infinity || min_y == @double.infinity {
      if group.x is None {
        group.x = Some(0.0)
      }
      if group.y is None {
        group.y = Some(0.0)
      }
      if group.width is None {
        group.width = Some(0.0)
      }
      if group.height is None {
        group.height = Some(0.0)
      }
    } else {
      let pad = group.padding.unwrap_or(20.0)
      let horizontal_pad = if has_parent(group) {
        pad
      } else {
        2.0 * top_lane_horizontal_padding(group)
      }
      let vertical_pad = pad
      let w = @model.js_max(0.0, max_x - min_x) + horizontal_pad
      let h = @model.js_max(0.0, max_y - min_y) + vertical_pad
      group.x = Some((min_x + max_x) / 2.0)
      group.y = Some((min_y + max_y) / 2.0)
      group.width = Some(w)
      group.height = Some(h)
      group_bounds[group.id] = (min_x, max_x, min_y, max_y)
    }
  }
  if top_level_groups.is_empty() || group_bounds.is_empty() {
    return
  }
  let mut global_min_y = @double.infinity
  let mut global_max_y = @double.neg_infinity
  let mut max_pad = 0.0
  for lane in top_level_groups {
    let pad = lane.padding.unwrap_or(20.0)
    if pad > max_pad {
      max_pad = pad
    }
    guard group_bounds.get(lane.id) is Some((_, _, min_y, max_y)) else {
      continue
    }
    global_min_y = @model.js_min(global_min_y, min_y)
    global_max_y = @model.js_max(global_max_y, max_y)
  }
  if global_min_y == @double.infinity || global_max_y == @double.neg_infinity {
    return
  }
  let content_height = @model.js_max(0.0, global_max_y - global_min_y)
  let min_header_margin = 36.0
  let vertical_margin = @model.js_max(max_pad, min_header_margin)
  let lane_height = content_height + 2.0 * vertical_margin
  let center_y = (global_min_y + global_max_y) / 2.0
  for lane in top_level_groups {
    lane.y = Some(center_y)
    lane.height = Some(lane_height)
    lane.swimlane_content_top = Some(global_min_y)
  }
  let sorted_lanes = top_level_groups.copy()
  @d3.js_sort(sorted_lanes, (a, b) => a.x.unwrap_or(0.0) - b.x.unwrap_or(0.0))
  let lane_ids = []
  let centers = []
  let base_widths = []
  for lane in sorted_lanes {
    guard group_bounds.get(lane.id) is Some((min_x, max_x, _, _)) else {
      continue
    }
    let content_width = @model.js_max(0.0, max_x - min_x) +
      2.0 * top_lane_horizontal_padding(lane)
    lane_ids.push(lane.id)
    centers.push((min_x + max_x) / 2.0)
    base_widths.push(content_width)
  }
  let count = lane_ids.length()
  if count == 0 {
    return
  }
  let lane_widths : Map[String, Double] = Map([])
  if count == 1 {
    lane_widths[lane_ids[0]] = base_widths[0]
  } else {
    // Adjacent lanes meet halfway between their centres: with widths
    // w[i], w[i] + w[i+1] = 2 d[i]. The free parameter is picked to keep
    // every lane at least as wide as its content where possible.
    let d = []
    for i in 0..<(count - 1) {
      d.push(centers[i + 1] - centers[i])
    }
    let u = Array::make(count, 0.0)
    for i in 0..<(count - 1) {
      u[i + 1] = 2.0 * d[i] - u[i]
    }
    let mut lower_bound = 0.0
    let mut upper_bound = @double.infinity
    for i in 0..<count {
      let base_w = base_widths[i]
      if i % 2 == 0 {
        lower_bound = @model.js_max(lower_bound, base_w - u[i])
      } else {
        upper_bound = @model.js_min(upper_bound, u[i] - base_w)
      }
    }
    let x = if lower_bound <= upper_bound {
      (lower_bound + upper_bound) / 2.0
    } else {
      lower_bound
    }
    for i in 0..<count {
      let w = u[i] + (if i % 2 == 0 { x } else { -x })
      let final_width = @model.js_max(base_widths[i], w)
      lane_widths[lane_ids[i]] = final_width
    }
  }
  for lane in top_level_groups {
    if lane_widths.get(lane.id) is Some(w) {
      lane.width = Some(w)
    }
    assign_top_lane_title_rect(lane)
  }
}
