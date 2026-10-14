// The passes after routing: `swimlanes/postProcessing.ts`, one named step
// at a time so that each can be compared with upstream's
// (`scripts/swimlane_oracle.js --stages`).

///|
/// The steps of `postProcessSwimlaneLayout` after the direction transform,
/// by the names `scripts/swimlane_oracle.js` gives their snapshots.
let post_steps : Array[String] = {
  let finalize = [
    "resolveRenderedOrthogonalCrossings", "separateSharedRenderedTerminalLanes",
    "reassignCrossingExternalRailChannels", "shortcutRedundantOrthogonalJogs", "anchorLabelsToPolyline",
    "prepareEdgeEndpointsForRenderer", "liftObstacleHuggingSameSideRails", "anchorLabelsToPolyline2",
    "prepareEdgeEndpointsForRenderer2",
  ]
  [
    "simplify", "simplifyDetouredEdges", "straightenCollinearSiblingDetours", "portSwapToLShape",
    "anchorLabelsToPolyline", "clipEdgeEndpointsToNodeBoundaries", "collapseShortTerminalStub",
    "nudgeSharedInteriorSubpaths", "separateSharedRenderedTerminalLanes", "collapseRedundantRectangularDoglegs",
    "liftObstacleHuggingSameSideRails", "swapDestinationTerminalTailsToReduceCrossings",
  ] +
  finalize.map(step => "f1." + step) +
  ["nudgeSharedInteriorSubpaths2"] +
  finalize.map(step => "f2." + step) +
  [
    "liftTopLaneTitleBandsAboveRails", "shiftLeftLaneTitleBandsLeftOfRails", "liftTopLaneTitleBandsAboveRails2",
    "shiftLeftLaneTitleBandsLeftOfRails2",
  ]
}

///|
/// An unknown step name.
pub(all) suberror UnknownStep {
  UnknownStep(String)
} derive(Debug)

///|
/// The name of a step without the round prefix (`f1.`) and the `2` that
/// tells a repeated step apart.
fn base_step(name : String) -> String {
  let name = match name.find(".") {
    Some(i) => name[i + 1:].to_owned()
    None => name
  }
  if name.has_suffix("2") {
    name[:name.length() - 1].to_owned()
  } else {
    name
  }
}

///|
/// Run one step of the layout after the ranking on `layout`, by the name
/// of its snapshot.
pub fn run_step(
  layout : @model.Layout,
  name : String,
  direction : String,
) -> Unit raise UnknownStep {
  let edges = layout.edges
  let nodes = layout.nodes
  let node_by_id : Map[String, @model.Node] = Map([])
  for node in nodes {
    node_by_id[node.id] = node
  }
  match base_step(name) {
    "route" => route(layout, direction)
    "direction" => transform_direction(layout, direction) |> ignore
    "simplify" => simplify_routes(edges)
    "simplifyDetouredEdges" => @post.simplify_detoured_edges(edges, nodes)
    "straightenCollinearSiblingDetours" =>
      @post.straighten_collinear_sibling_detours(edges, nodes)
    "portSwapToLShape" => @post.port_swap_to_l_shape(edges, nodes)
    "anchorLabelsToPolyline" =>
      @post.anchor_labels_to_polyline(edges, node_by_id)
    "clipEdgeEndpointsToNodeBoundaries" =>
      @post.clip_edge_endpoints_to_node_boundaries(edges, node_by_id)
    "collapseShortTerminalStub" =>
      @post.collapse_short_terminal_stub(edges, node_by_id)
    "nudgeSharedInteriorSubpaths" =>
      @post.nudge_shared_interior_subpaths(edges, node_by_id)
    "prepareEdgeEndpointsForRenderer" =>
      @post.prepare_edge_endpoints_for_renderer(edges, node_by_id)
    "separateSharedRenderedTerminalLanes" =>
      @rendered.separate_shared_rendered_terminal_lanes(edges, node_by_id)
    "collapseRedundantRectangularDoglegs" =>
      @rendered.collapse_redundant_rectangular_doglegs(edges, node_by_id)
    "liftObstacleHuggingSameSideRails" =>
      @rendered.lift_obstacle_hugging_same_side_rails(edges, node_by_id)
    "swapDestinationTerminalTailsToReduceCrossings" =>
      @rendered.swap_destination_terminal_tails_to_reduce_crossings(
        edges, node_by_id,
      )
    "resolveRenderedOrthogonalCrossings" =>
      @rendered.resolve_rendered_orthogonal_crossings(edges, node_by_id)
    "reassignCrossingExternalRailChannels" =>
      @rendered.reassign_crossing_external_rail_channels(edges, node_by_id)
    "shortcutRedundantOrthogonalJogs" =>
      @rendered.shortcut_redundant_orthogonal_jogs(edges, node_by_id)
    "liftTopLaneTitleBandsAboveRails" =>
      @rendered.lift_top_lane_title_bands_above_rails(
        edges, node_by_id, direction,
      )
    "shiftLeftLaneTitleBandsLeftOfRails" =>
      @rendered.shift_left_lane_title_bands_left_of_rails(
        edges, node_by_id, direction,
      )
    other => raise UnknownStep(other)
  }
}

///|
/// Route the edges, and draw the routes with rounded corners unless the
/// diagram picked another curve than the default: from
/// `runSwimlaneLayoutCore`.
fn route(layout : @model.Layout, direction : String) -> Unit {
  @router.route_edges_orthogonal(layout, direction)
  for edge in layout.edges {
    match edge.curve {
      None | Some("") | Some("basis") => edge.curve = Some("rounded")
      _ => ()
    }
  }
}

///|
/// Turn the top-to-bottom layout to the diagram's direction: false when
/// the post-processing stops there.
fn transform_direction(layout : @model.Layout, direction : String) -> Bool {
  let has_content = layout.nodes.iter().any(node => !node.is_group)
  if (direction == "LR" || direction == "RL") &&
    has_content &&
    !@post.apply_lr_direction_transform(layout, direction) {
    return false
  }
  if direction == "BT" &&
    has_content &&
    !@post.apply_bt_direction_transform(layout) {
    return false
  }
  true
}

///|
/// Square every route and drop its redundant points.
fn simplify_routes(edges : Array[@model.Edge]) -> Unit {
  for edge in edges {
    if edge.is_layout_only {
      continue
    }
    guard edge.points is Some(pts) && pts.length() >= 2 else { continue }
    edge.points = Some(
      @model.simplify_polyline(@model.orthogonalize_polyline(pts)),
    )
  }
}

///|
/// `postProcessSwimlaneLayout`, with a callback after each step.
pub fn post_process(
  layout : @model.Layout,
  direction : String,
  after_step? : (String) -> Unit,
) -> Unit {
  let after = (name : String) => if after_step is Some(f) { f(name) }
  if !transform_direction(layout, direction) {
    return
  }
  after("direction")
  for name in post_steps {
    run_step(layout, name, direction) catch {
      UnknownStep(_) => abort("unknown step \{name}")
    }
    after(name)
  }
}
