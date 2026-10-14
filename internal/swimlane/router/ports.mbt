// Ports: which side of its nodes every edge uses, and where on that side
// (Step 6 of `routeEdgesOrthogonal`).

///|
/// The side of `node` facing `target`, preferring top and bottom unless the
/// target is more than three times as far sideways: `chooseOrthogonalSide`.
fn choose_orthogonal_side(
  node : @model.Node,
  target : @model.Pt,
  fallback : @model.Side,
) -> @model.Side {
  let cx = node.x.unwrap_or(0.0)
  let cy = node.y.unwrap_or(0.0)
  let dx = target.x - cx
  let dy = target.y - cy
  let abs_dx = dx.abs()
  let abs_dy = dy.abs()
  if abs_dx < EPS7 && abs_dy < EPS7 {
    return fallback
  }
  let vertical_bias = 3.0
  if abs_dy > EPS7 && abs_dy * vertical_bias >= abs_dx {
    return if dy > 0.0 { Bottom } else { Top }
  }
  if abs_dx > EPS7 {
    return if dx > 0.0 { Right } else { Left }
  }
  fallback
}

///|
/// The middle of a side of the node: `portForSide`.
fn port_for_side(node : @model.Node, side : @model.Side) -> @model.Pt {
  let w = node.width.unwrap_or(10.0)
  let h = node.height.unwrap_or(10.0)
  let cx = node.x.unwrap_or(0.0)
  let cy = node.y.unwrap_or(0.0)
  match side {
    Top => @model.pt(cx, cy - h / 2.0)
    Bottom => @model.pt(cx, cy + h / 2.0)
    Left => @model.pt(cx - w / 2.0, cy)
    Right => @model.pt(cx + w / 2.0, cy)
  }
}

///|
/// `getOrthogonalPort`.
fn get_orthogonal_port(
  node : @model.Node,
  target : @model.Pt,
  is_source : Bool,
) -> @model.Pt {
  port_for_side(
    node,
    choose_orthogonal_side(node, target, if is_source { Bottom } else { Top }),
  )
}

///|
/// `determineSide`.
fn determine_side(node : @model.Node, target : @model.Pt) -> @model.Side {
  choose_orthogonal_side(node, target, Bottom)
}

///|
/// `${nodeId}:${side}`, the key of `sideLoad` and `sourceSideGroups`.
fn load_key(node_id : String, side : @model.Side) -> String {
  "\{node_id}:\{side_name(side)}"
}

///|
/// The key of `portGroups`: `${nodeId}:${side}:${role}`.
fn port_group_key(
  node_id : String,
  side : @model.Side,
  role : String,
) -> String {
  "\{node_id}:\{side_name(side)}:\{role}"
}

///|
/// How strongly an edge prefers the axis of its source side:
/// `preferenceStrength`.
fn preference_strength(info : SideInfo) -> Double {
  if side_is_vertical(info.src_side) {
    return if info.abs_dx == 0.0 {
      @double.infinity
    } else {
      info.abs_dy / info.abs_dx
    }
  }
  if info.abs_dy == 0.0 {
    @double.infinity
  } else {
    info.abs_dx / info.abs_dy
  }
}

///|
/// The side an edge leaves by when its preferred one is crowded:
/// `secondarySide`.
fn secondary_side(info : SideInfo) -> @model.Side {
  if side_is_vertical(info.src_side) {
    return if info.dx_sign >= 0.0 { Right } else { Left }
  }
  if info.dy_sign >= 0.0 {
    Bottom
  } else {
    Top
  }
}

///|
/// `isDiamondNode`.
fn is_diamond_node(node : @model.Node?) -> Bool {
  match node {
    Some(node) => node.shape == "question" || node.shape == "diamond"
    None => false
  }
}

///|
/// Decide the sides of every routable edge (Steps 6.1, 6.2 and 6.2b) and
/// spread the ports of edges sharing a face (Step 6.3).
fn Router::assign_ports(self : Router) -> Unit {
  for edge in self.edges {
    if edge.start == "" || edge.end == "" || edge.start == edge.end {
      continue
    }
    self.incident_edge_totals.set(
      edge.start,
      self.incident_edge_totals.get(edge.start).unwrap_or(0) + 1,
    )
    self.incident_edge_totals.set(
      edge.end,
      self.incident_edge_totals.get(edge.end).unwrap_or(0) + 1,
    )
  }
  // Step 6.1: the natural side of both ends.
  for i, e in self.edges {
    if e.start == "" || e.end == "" || e.start == e.end {
      continue
    }
    if e.points is Some(points) && points.length() > 0 {
      continue
    }
    guard self.node_by_id.get(e.start) is Some(src) else { continue }
    guard self.node_by_id.get(e.end) is Some(dst) else { continue }
    let dx = dst.x.unwrap_or(0.0) - src.x.unwrap_or(0.0)
    let dy = dst.y.unwrap_or(0.0) - src.y.unwrap_or(0.0)
    self.side_info_by_idx.set(i, {
      edge_idx: i,
      src_id: e.start,
      dst_id: e.end,
      src_side: determine_side(
        src,
        @model.pt(dst.x.unwrap_or(0.0), dst.y.unwrap_or(0.0)),
      ),
      dst_side: determine_side(
        dst,
        @model.pt(src.x.unwrap_or(0.0), src.y.unwrap_or(0.0)),
      ),
      abs_dx: dx.abs(),
      abs_dy: dy.abs(),
      dx_sign: js_sign(dx),
      dy_sign: js_sign(dy),
    })
  }
  // Step 6.2: siblings leaving by the same side move to their secondary
  // side while it is less loaded, weakest preference first.
  let source_side_groups : Map[String, Array[SideInfo]] = Map([])
  for _, info in self.side_info_by_idx {
    let key = load_key(info.src_id, info.src_side)
    match source_side_groups.get(key) {
      Some(group) => group.push(info)
      None => source_side_groups.set(key, [info])
    }
  }
  let side_load : Map[String, Int32] = Map([])
  for _, info in self.side_info_by_idx {
    side_load.set(
      load_key(info.src_id, info.src_side),
      side_load.get(load_key(info.src_id, info.src_side)).unwrap_or(0) + 1,
    )
    side_load.set(
      load_key(info.dst_id, info.dst_side),
      side_load.get(load_key(info.dst_id, info.dst_side)).unwrap_or(0) + 1,
    )
  }
  for _, group in source_side_groups {
    if group.length() < 2 {
      continue
    }
    @d3.js_sort(group, (a, b) => {
      let sa = preference_strength(a)
      let sb = preference_strength(b)
      if (sa - sb).abs() > 1.0e-9 {
        return sb - sa
      }
      (a.edge_idx - b.edge_idx).to_double()
    })
    for g in 1..<group.length() {
      let info = group[g]
      let secondary = secondary_side(info)
      let primary_load = side_load
        .get(load_key(info.src_id, info.src_side))
        .unwrap_or(0)
      let secondary_load = side_load
        .get(load_key(info.src_id, secondary))
        .unwrap_or(0)
      if secondary_load >= primary_load {
        continue
      }
      side_load.set(load_key(info.src_id, info.src_side), primary_load - 1)
      side_load.set(load_key(info.src_id, secondary), secondary_load + 1)
      info.src_side = secondary
    }
  }
  // Step 6.2b: an edge leaving a diamond by a side an edge enters by moves
  // to its secondary side when that side is free.
  let in_sides_by_node : Map[String, Array[@model.Side]] = Map([])
  for _, info in self.side_info_by_idx {
    match in_sides_by_node.get(info.dst_id) {
      Some(sides) =>
        if !sides.contains(info.dst_side) {
          sides.push(info.dst_side)
        }
      None => in_sides_by_node.set(info.dst_id, [info.dst_side])
    }
  }
  for _, info in self.side_info_by_idx {
    if !is_diamond_node(self.node_by_id.get(info.src_id)) {
      continue
    }
    guard in_sides_by_node.get(info.src_id) is Some(in_sides) else { continue }
    if !in_sides.contains(info.src_side) {
      continue
    }
    let secondary = secondary_side(info)
    if in_sides.contains(secondary) ||
      side_load.get(load_key(info.src_id, secondary)).unwrap_or(0) > 0 {
      continue
    }
    let primary_load = side_load
      .get(load_key(info.src_id, info.src_side))
      .unwrap_or(0)
    side_load.set(
      load_key(info.src_id, info.src_side),
      if primary_load - 1 > 0 {
        primary_load - 1
      } else {
        0
      },
    )
    side_load.set(load_key(info.src_id, secondary), 1)
    info.src_side = secondary
  }
  // Step 6.3: group the edges by face.
  for _, info in self.side_info_by_idx {
    let src = self.node_by_id[info.src_id]
    let dst = self.node_by_id[info.dst_id]
    let dst_coord = if side_is_vertical(info.src_side) {
      dst.x.unwrap_or(0.0)
    } else {
      dst.y.unwrap_or(0.0)
    }
    self.port_group(info.src_id, info.src_side, "src").entries.push({
      edge_idx: info.edge_idx,
      opposite_coord: dst_coord,
    })
    let src_coord = if side_is_vertical(info.dst_side) {
      src.x.unwrap_or(0.0)
    } else {
      src.y.unwrap_or(0.0)
    }
    self.port_group(info.dst_id, info.dst_side, "dst").entries.push({
      edge_idx: info.edge_idx,
      opposite_coord: src_coord,
    })
  }
  // Spread the ports of every face used by two edges or more, in the order
  // of their other ends.
  let min_port_spacing = 8.0
  for _, group in self.port_groups {
    let entries = group.entries
    if entries.length() < 2 {
      continue
    }
    @d3.js_sort(entries, (a, b) => a.opposite_coord - b.opposite_coord)
    guard self.node_by_id.get(group.node_id) is Some(node) else { continue }
    let is_vertical_side = group.side is (Left | Right)
    let side_length = if is_vertical_side {
      node.height.unwrap_or(10.0)
    } else {
      node.width.unwrap_or(10.0)
    }
    let is_diamond = node.shape == "question" || node.shape == "diamond"
    let effective_length = if is_diamond {
      side_length * 0.3
    } else {
      side_length
    }
    let max_port_spacing = 20.0
    let spacing = @model.js_min(
      max_port_spacing,
      @model.js_max(
        min_port_spacing,
        effective_length / (entries.length() + 1).to_double(),
      ),
    )
    let total_span = spacing * (entries.length() - 1).to_double()
    let start_offset = -total_span / 2.0
    for j, element in entries {
      let offset = start_offset + j.to_double() * spacing
      self.port_offsets.set("\{element.edge_idx}:\{group.role}", offset)
    }
  }
}

///|
/// The group of a face, created empty when missing.
fn Router::port_group(
  self : Router,
  node_id : String,
  side : @model.Side,
  role : String,
) -> PortGroup {
  let key = port_group_key(node_id, side, role)
  match self.port_groups.get(key) {
    Some(group) => group
    None => {
      let group = { node_id, side, role, entries: [], }
      self.port_groups.set(key, group)
      group
    }
  }
}

///|
/// How many edges use a face in a role: `portGroups.get(key)?.length ?? 0`.
fn Router::face_count(
  self : Router,
  node_id : String,
  side : @model.Side,
  role : String,
) -> Int32 {
  match self.port_groups.get(port_group_key(node_id, side, role)) {
    Some(group) => group.entries.length()
    None => 0
  }
}

///|
/// `edgeHasLabelNode`.
fn Router::edge_has_label_node(self : Router, edge_idx : Int32) -> Bool {
  match self.edges.get(edge_idx) {
    Some({ label_node_id: Some(id), .. }) => id != ""
    _ => false
  }
}

///|
/// Whether an edge using a face of the node has a label node:
/// `faceHasLabelNode`.
fn Router::face_has_label_node(
  self : Router,
  node_id : String,
  side : @model.Side,
) -> Bool {
  if node_id == "" {
    return false
  }
  let has = role => {
    match self.port_groups.get(port_group_key(node_id, side, role)) {
      Some(group) =>
        group.entries
        .iter()
        .any(entry => self.edge_has_label_node(entry.edge_idx))
      None => false
    }
  }
  has("src") || has("dst")
}

///|
/// Move a port along its side: `applyPortOffset`.
fn apply_port_offset(
  base_port : @model.Pt,
  side : @model.Side,
  offset : Double,
) -> @model.Pt {
  if side_is_vertical(side) {
    @model.pt(base_port.x + offset, base_port.y)
  } else {
    @model.pt(base_port.x, base_port.y + offset)
  }
}

///|
/// The ports of an edge and their sides: `portsForEdge`. Every call makes
/// new points.
fn Router::ports_for_edge(
  self : Router,
  edge_index : Int32,
  src : @model.Node,
  dst : @model.Node,
) -> (@model.Pt, @model.Pt, @model.Side, @model.Side) {
  let side_info = self.side_info_by_idx.get(edge_index)
  let src_target = @model.pt(dst.x.unwrap_or(0.0), dst.y.unwrap_or(0.0))
  let dst_target = @model.pt(src.x.unwrap_or(0.0), src.y.unwrap_or(0.0))
  let (src_side, dst_side, src_port, dst_port) = match side_info {
    Some(info) =>
      (
        info.src_side,
        info.dst_side,
        port_for_side(src, info.src_side),
        port_for_side(dst, info.dst_side),
      )
    None =>
      (
        determine_side(src, src_target),
        determine_side(dst, dst_target),
        get_orthogonal_port(src, src_target, true),
        get_orthogonal_port(dst, dst_target, false),
      )
  }
  let src_port = match self.port_offsets.get("\{edge_index}:src") {
    Some(offset) => apply_port_offset(src_port, src_side, offset)
    None => src_port
  }
  let dst_port = match self.port_offsets.get("\{edge_index}:dst") {
    Some(offset) => apply_port_offset(dst_port, dst_side, offset)
    None => dst_port
  }
  (src_port, dst_port, src_side, dst_side)
}
