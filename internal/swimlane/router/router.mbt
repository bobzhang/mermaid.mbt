// The orthogonal edge router: `swimlanes/orthogonalRouter/router.ts`.
//
// Every drawn edge is routed as an axis-aligned polyline between ports on
// its nodes' borders: ports are spread over the faces the edges share
// (`ports.mbt`), each edge is routed on its own through pipes around the
// obstacles (`route_edge.mbt`, `astar.mbt`, `detour.mbt`), the segments
// sharing a pipe are spread over tracks (`tracks.mbt`) and finally turned
// into points (`points.mbt`).

///|
/// Route every drawn edge of the layout orthogonally between its nodes:
/// `routeEdgesOrthogonal`. Sets `points` of the layout's edges and drops
/// the layout-only edges from the layout.
pub fn route_edges_orthogonal(
  layout : @model.Layout,
  direction : String,
) -> Unit {
  let nodes = layout.nodes
  // The router works on copies of the drawn edges and writes their points
  // back at the end.
  let edges : Array[RouteEdge] = []
  for oe in layout.edges {
    if oe.is_layout_only {
      continue
    }
    edges.push({
      orig: oe,
      start: oe.start,
      end: oe.end,
      points: oe.points,
      label_node_id: oe.label_node_id,
    })
  }
  let node_by_id : Map[String, @model.Node] = Map([])
  for n in nodes {
    node_by_id.set(n.id, n)
  }
  // Every node of a lane (a top-level group) gets the lane's id.
  let lane_by_node_id : Map[String, String] = Map([])
  for group in nodes {
    if !(group.is_group && is_unset(group.parent_id)) {
      continue
    }
    fn assign_lane(n : @model.Node) -> Unit {
      lane_by_node_id.set(n.id, group.id)
      for child in nodes.filter(child => child.parent_id == Some(n.id)) {
        assign_lane(child)
      }
    }

    assign_lane(group)
  }
  let is_lr = direction == "LR"
  let obstacles = nodes
    .filter(n => !n.is_group && !n.is_edge_label)
    .map(n => {
      let w = n.width.unwrap_or(10.0)
      let h = n.height.unwrap_or(10.0)
      let x = n.x.unwrap_or(0.0)
      let y = n.y.unwrap_or(0.0)
      let padding = NODE_PADDING
      {
        node_id: n.id,
        min_x: x - w / 2.0 - padding,
        max_x: x + w / 2.0 + padding,
        min_y: y - h / 2.0 - padding,
        max_y: y + h / 2.0 + padding,
        visual_x_half_extent: if is_lr {
          h / 2.0 + padding
        } else {
          w / 2.0 + padding
        },
      }
    })
  let router : Router = {
    edges,
    node_by_id,
    lane_by_node_id,
    pipes: [],
    is_lr,
    obstacles,
    all_routed_segments: [],
    edge_segment_indices: Array::makei(edges.length(), _ => []),
    straight_intra_lane_edges: Set([]),
    incident_edge_totals: Map([]),
    side_info_by_idx: Map([]),
    port_groups: Map([]),
    port_offsets: Map([]),
    dest_info_cache: Map([]),
  }
  let routing_order = router.routing_order()
  router.assign_ports()
  for i in routing_order {
    router.route_edge(i)
  }
  router.untangle()
  let segment_coords = router.segment_coords()
  for i, e in edges {
    if router.edge_segment_indices[i].length() == 0 {
      continue
    }
    e.points = Some(router.edge_points(i, e, segment_coords))
  }
  for re in edges {
    if re.points is Some(points) {
      re.orig.points = Some(points)
    }
  }
  layout.edges = layout.edges.filter(e => !e.is_layout_only)
  // Ends left inside their node move onto its border.
  for edge in layout.edges {
    guard edge.points is Some(pts) && pts.length() >= 2 else { continue }
    if edge.start != "" && node_by_id.get(edge.start) is Some(src) {
      pts[0] = node_boundary_clamp(pts[0], src)
    }
    if edge.end != "" && node_by_id.get(edge.end) is Some(dst) {
      pts[pts.length() - 1] = node_boundary_clamp(pts[pts.length() - 1], dst)
    }
  }
}

///|
/// Whether an optional id is missing or empty, as `!n.parentId`.
fn is_unset(id : String?) -> Bool {
  match id {
    None | Some("") => true
    _ => false
  }
}
