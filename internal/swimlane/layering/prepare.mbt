// What the layout does before the nodes are measured:
// `prepareSwimlaneLayout` (`swimlanes/index.ts`), with
// `prepareLayoutForSwimlanes` (`helpers.ts`) and `createEdgeLabelNodes`
// (`edgeLabelNodes.ts`).

///|
/// The id of the lane made for the nodes outside every lane.
pub const DEFAULT_SWIMLANE_ID : String = "__swimlane_default__"

///|
/// Whether the node is inside a group (`node.parentId` is truthy).
fn has_parent(node : @model.Node) -> Bool {
  node.parent_id is Some(parent) && parent != ""
}

///|
/// Put every node outside a lane into a lane of its own and turn the
/// labels of edges into nodes: `prepareSwimlaneLayout`.
pub fn prepare(layout : @model.Layout) -> Unit {
  prepare_lanes(layout)
  create_edge_label_nodes(layout)
}

///|
/// Top-level groups become lanes, and nodes outside every group go to a
/// default lane: `prepareLayoutForSwimlanes`.
fn prepare_lanes(layout : @model.Layout) -> Unit {
  let direction = match layout.direction {
    Some(d) if d != "" => Some(d)
    _ => None
  }
  let nodes = layout.nodes
  for node in nodes {
    if node.is_group && !has_parent(node) {
      node.shape = "swimlane"
      if direction is Some(_) {
        node.direction = direction
      }
    }
  }
  let loose_nodes = nodes.filter(node => !node.is_group && !has_parent(node))
  if loose_nodes.is_empty() {
    return
  }
  match nodes.search_by(node => node.id == DEFAULT_SWIMLANE_ID) {
    None => {
      let mut max = -1
      for node in nodes {
        let index = node.color_index.unwrap_or(-1)
        if index > max {
          max = index
        }
      }
      let lane = @model.Node::new(
        id=DEFAULT_SWIMLANE_ID,
        is_group=true,
        shape="swimlane",
        padding=20.0,
        look?=layout.options.look,
        color_index=max + 1,
      )
      lane.direction = direction
      nodes.push(lane)
    }
    Some(index) => {
      let lane = nodes[index]
      if lane.is_group {
        lane.shape = "swimlane"
        if direction is Some(_) {
          lane.direction = direction
        }
      }
    }
  }
  for node in loose_nodes {
    node.parent_id = Some(DEFAULT_SWIMLANE_ID)
  }
}

///|
/// Every labelled edge gets a node for its label, placed by the layout
/// like any other node, and two edges through it that only steer the
/// layout: `createEdgeLabelNodes`.
fn create_edge_label_nodes(layout : @model.Layout) -> Unit {
  let nodes_to_add = []
  let layout_only_edges = []
  let node_by_id : Map[String, @model.Node] = Map([])
  for node in layout.nodes {
    node_by_id[node.id] = node
  }
  for edge in layout.edges {
    guard edge.label is Some(label) && label != "" else { continue }
    if edge.is_layout_only || edge.label_node_id is Some(_) {
      continue
    }
    let source = if edge.start != "" {
      node_by_id.get(edge.start)
    } else {
      None
    }
    let target = if edge.end != "" { node_by_id.get(edge.end) } else { None }
    guard source is Some(source) && target is Some(target) else { continue }
    let label_node_id = "edge-label-\{edge.start}-\{edge.end}-\{edge.id}"
    let is_cross_lane = source.parent_id != target.parent_id
    let label_lane = if is_cross_lane {
      target.parent_id
    } else {
      source.parent_id
    }
    let label_node = @model.Node::new(
      id=label_node_id,
      label~,
      edge_start=edge.start,
      edge_end=edge.end,
      shape="labelRect",
      width=0.0,
      height=0.0,
      is_edge_label=true,
      is_dummy=true,
      parent_id?=label_lane,
      label_style=edge.label_style,
      dir?=source.dir,
    )
    nodes_to_add.push(label_node)
    edge.label_node_id = Some(label_node_id)
    edge.label = None
    layout_only_edges.push(
      @model.Edge::new(
        id="\{edge.id}-to-label",
        start=edge.start,
        end=label_node_id,
        is_layout_only=true,
      ),
    )
    layout_only_edges.push(
      @model.Edge::new(
        id="\{edge.id}-from-label",
        start=label_node_id,
        end=edge.end,
        is_layout_only=true,
      ),
    )
  }
  layout.nodes = layout.nodes + nodes_to_add
  layout.edges = layout.edges + layout_only_edges
}
