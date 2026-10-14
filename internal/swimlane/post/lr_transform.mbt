// `swimlanes/direction/lrTransform.ts`: the layout is made top to bottom;
// the other directions turn or mirror it.

///|
/// The title band of a lane laid out left to right.
const TITLE_BAND_SIZE : Double = 36.0

///|
/// Whether an optional id is set and not empty (truthy upstream).
fn has_id(id : String?) -> Bool {
  id is Some(id) && id != ""
}

///|
/// The nodes by id, the last of a repeated id winning: `buildNodeMap`.
fn build_node_map(nodes : Array[@model.Node]) -> Map[String, @model.Node] {
  let map : Map[String, @model.Node] = Map([])
  for node in nodes {
    map[node.id] = node
  }
  map
}

///|
/// The outermost group above a node: `resolveTopLevelGroupId`.
fn resolve_top_level_group_id(
  node : @model.Node,
  node_by_id : Map[String, @model.Node],
) -> String? {
  let mut parent_id = node.parent_id
  let mut top_level_group_id = None
  while parent_id is Some(id) && id != "" {
    guard node_by_id.get(id) is Some(parent) && parent.is_group else { break }
    top_level_group_id = Some(parent.id)
    parent_id = parent.parent_id
  }
  top_level_group_id
}

///|
/// How many groups enclose a group: `groupDepth`.
fn group_depth(
  group : @model.Node,
  node_by_id : Map[String, @model.Node],
) -> Int32 {
  let mut depth = 0
  let mut parent_id = group.parent_id
  while parent_id is Some(id) && id != "" {
    guard node_by_id.get(id) is Some(parent) && parent.is_group else { break }
    depth += 1
    parent_id = parent.parent_id
  }
  depth
}

///|
/// The box around placed nodes: `{ minX, maxX, minY, maxY }`.
priv struct Bounds {
  min_x : Double
  max_x : Double
  min_y : Double
  max_y : Double
}

///|
/// The box around the placed ones of `children`: `boundsForChildren`.
fn bounds_for_children(children : Array[@model.Node]) -> Bounds? {
  let mut min_x = @double.infinity
  let mut max_x = -@double.infinity
  let mut min_y = @double.infinity
  let mut max_y = -@double.infinity
  for child in children {
    guard child.x is Some(cx) && child.y is Some(cy) else { continue }
    let w = child.width.unwrap_or(0.0)
    let h = child.height.unwrap_or(0.0)
    min_x = @model.js_min(min_x, cx - w / 2.0)
    max_x = @model.js_max(max_x, cx + w / 2.0)
    min_y = @model.js_min(min_y, cy - h / 2.0)
    max_y = @model.js_max(max_y, cy + h / 2.0)
  }
  if min_x == @double.infinity || min_y == @double.infinity {
    return None
  }
  Some({ min_x, max_x, min_y, max_y, })
}

///|
/// Fit a group around the box of its children: `applyGroupBounds`.
fn apply_group_bounds(group : @model.Node, bounds : Bounds) -> Unit {
  let pad = group.padding.unwrap_or(20.0)
  group.x = Some((bounds.min_x + bounds.max_x) / 2.0)
  group.y = Some((bounds.min_y + bounds.max_y) / 2.0)
  group.width = Some(@model.js_max(0.0, bounds.max_x - bounds.min_x) + pad)
  group.height = Some(@model.js_max(0.0, bounds.max_y - bounds.min_y) + pad)
}

///|
/// Refit the nested groups (not the lanes) around their children, the
/// deepest first: `recomputeNestedGroupBounds`.
fn recompute_nested_group_bounds(nodes : Array[@model.Node]) -> Unit {
  let node_by_id = build_node_map(nodes)
  let groups_by_depth = nodes.filter(node => {
    node.is_group && has_id(node.parent_id)
  })
  @d3.js_sort(groups_by_depth, (a, b) => {
    (group_depth(b, node_by_id) - group_depth(a, node_by_id)).to_double()
  })
  for group in groups_by_depth {
    let children = nodes.filter(node => {
      node.parent_id is Some(id) && id == group.id
    })
    if bounds_for_children(children) is Some(bounds) {
      apply_group_bounds(group, bounds)
    }
  }
}

///|
/// Mirror the layout along x (`x_axis`) or y between the extremes of its
/// content nodes, moving the points of the routes in place: `mirrorAxis`.
/// False when no content node is placed.
fn mirror_axis(layout : @model.Layout, x_axis : Bool) -> Bool {
  let nodes = layout.nodes
  let edges = layout.edges
  let get = (node : @model.Node) => if x_axis { node.x } else { node.y }
  let mut min = @double.infinity
  let mut max = -@double.infinity
  for node in nodes {
    if node.is_group {
      continue
    }
    guard get(node) is Some(value) else { continue }
    min = @model.js_min(min, value)
    max = @model.js_max(max, value)
  }
  if !is_finite(min) || !is_finite(max) {
    return false
  }
  let mirror = (value : Double) => min + max - value
  for node in nodes {
    if get(node) is Some(value) {
      if x_axis {
        node.x = Some(mirror(value))
      } else {
        node.y = Some(mirror(value))
      }
    }
    if node.group_title_rect is Some(title_rect) {
      node.group_title_rect = Some(
        if x_axis {
          {
            ..title_rect,
            left: mirror(title_rect.right),
            right: mirror(title_rect.left),
          }
        } else {
          {
            ..title_rect,
            top: mirror(title_rect.bottom),
            bottom: mirror(title_rect.top),
          }
        },
      )
    }
  }
  for edge in edges {
    guard edge.points is Some(points) else { continue }
    for point in points {
      if x_axis {
        point.x = mirror(point.x)
      } else {
        point.y = mirror(point.y)
      }
    }
  }
  true
}

///|
/// `applyBtDirectionTransform`: mirror the layout vertically.
pub fn apply_bt_direction_transform(layout : @model.Layout) -> Bool {
  if !layout.nodes.iter().any(node => !node.is_group) {
    return true
  }
  mirror_axis(layout, false)
}

///|
/// One lane with the extent of its content along y, after the turn.
priv struct LaneBounds {
  lane : @model.Node
  content_top : Double
  content_bottom : Double
  center_y : Double
}

///|
/// `applyLrDirectionTransform`: turn the layout to run left to right
/// (mirrored for `RL`), stretching the new x axis by the aspect of the
/// average node, and stack the lanes as rows with their title band on the
/// left. False when there is nothing to transform.
pub fn apply_lr_direction_transform(
  layout : @model.Layout,
  direction : String,
) -> Bool {
  let nodes = layout.nodes
  let edges = layout.edges
  let content_nodes = nodes.filter(n => !n.is_group)
  let mut min_x = @double.infinity
  let mut min_y = @double.infinity
  for n in content_nodes {
    let x0 = n.x.unwrap_or(0.0)
    let y0 = n.y.unwrap_or(0.0)
    if x0 < min_x {
      min_x = x0
    }
    if y0 < min_y {
      min_y = y0
    }
  }
  if !is_finite(min_x) || !is_finite(min_y) {
    return false
  }
  let mut total_width = 0.0
  let mut total_height = 0.0
  for n in content_nodes {
    total_width += n.width.unwrap_or(0.0)
    total_height += n.height.unwrap_or(0.0)
  }
  let avg_width = total_width / content_nodes.length().to_double()
  let avg_height = total_height / content_nodes.length().to_double()
  let horizontal_scale_factor = if avg_height > 0.0 {
    @model.js_max(1.0, avg_width / avg_height)
  } else {
    1.0
  }
  for n in content_nodes {
    let x0 = n.x.unwrap_or(0.0)
    let y0 = n.y.unwrap_or(0.0)
    let new_x = (y0 - min_y) * horizontal_scale_factor + TITLE_BAND_SIZE
    let new_y = x0 - min_x
    n.x = Some(new_x)
    n.y = Some(new_y)
  }
  for e in edges {
    guard e.points is Some(points) else { continue }
    // In place: a point shared by two routes turns twice, as upstream.
    for p in points {
      let x0 = p.x
      let y0 = p.y
      let new_x = (y0 - min_y) * horizontal_scale_factor + TITLE_BAND_SIZE
      let new_y = x0 - min_x
      p.x = new_x
      p.y = new_y
    }
  }
  recompute_nested_group_bounds(nodes)
  let lane_nodes = nodes.filter(n => n.is_group && !has_id(n.parent_id))
  if lane_nodes.length() == 0 {
    if direction == "RL" {
      mirror_axis(layout, true) |> ignore
    }
    return true
  }
  let node_by_id = build_node_map(nodes)
  let children_by_lane : Map[String, Array[@model.Node]] = Map([])
  for n in nodes {
    if n.is_group {
      continue
    }
    guard resolve_top_level_group_id(n, node_by_id) is Some(lane_id) &&
      lane_id != "" else {
      continue
    }
    let bucket = children_by_lane.get(lane_id).unwrap_or([])
    bucket.push(n)
    children_by_lane[lane_id] = bucket
  }
  let mut max_pad = 0.0
  for lane in lane_nodes {
    let pad = lane.padding.unwrap_or(0.0)
    if pad > max_pad {
      max_pad = pad
    }
  }
  let lane_bounds : Array[LaneBounds] = []
  let mut global_min_x_child = @double.infinity
  let mut global_max_x_child = -@double.infinity
  for lane in lane_nodes {
    let children = children_by_lane.get(lane.id).unwrap_or([])
    guard bounds_for_children(children) is Some(bounds) else { continue }
    global_min_x_child = @model.js_min(global_min_x_child, bounds.min_x)
    global_max_x_child = @model.js_max(global_max_x_child, bounds.max_x)
    lane_bounds.push({
      lane,
      content_top: bounds.min_y,
      content_bottom: bounds.max_y,
      center_y: (bounds.min_y + bounds.max_y) / 2.0,
    })
  }
  if global_min_x_child == @double.infinity ||
    global_max_x_child == -@double.infinity {
    return true
  }
  let full_content_width = @model.js_max(
    0.0,
    global_max_x_child - global_min_x_child,
  )
  let horizontal_margin = @model.js_max(max_pad, 10.0)
  let body_width = full_content_width + 2.0 * horizontal_margin
  let lane_width = TITLE_BAND_SIZE + body_width
  let body_center = (global_min_x_child + global_max_x_child) / 2.0
  let body_left = body_center - body_width / 2.0
  let lane_left = body_left - TITLE_BAND_SIZE
  let center_x = lane_left + lane_width / 2.0
  let vertical_margin = @model.js_max(max_pad, TITLE_BAND_SIZE)
  @d3.js_sort(lane_bounds, (a, b) => a.center_y - b.center_y)
  for i in 0..<lane_bounds.length() {
    let curr = lane_bounds[i]
    let lane_top = if i == 0 {
      curr.content_top - vertical_margin
    } else {
      let prev = lane_bounds[i - 1]
      (prev.content_bottom + curr.content_top) / 2.0
    }
    let lane_bottom = if i == lane_bounds.length() - 1 {
      curr.content_bottom + vertical_margin
    } else {
      let next = lane_bounds[i + 1]
      (curr.content_bottom + next.content_top) / 2.0
    }
    let lane_height = @model.js_max(0.0, lane_bottom - lane_top)
    let center_y = (lane_top + lane_bottom) / 2.0
    curr.lane.x = Some(center_x)
    curr.lane.y = Some(center_y)
    curr.lane.width = Some(lane_width)
    curr.lane.height = Some(lane_height)
    curr.lane.swimlane_content_top = Some(curr.content_top)
    curr.lane.group_title_rect = Some({
      left: lane_left,
      right: lane_left + TITLE_BAND_SIZE,
      top: lane_top,
      bottom: lane_bottom,
    })
  }
  if direction == "RL" {
    mirror_axis(layout, true) |> ignore
  }
  true
}

///|
/// `Number.isFinite`.
fn is_finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}
