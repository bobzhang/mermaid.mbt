// The dagre layout of the unified renderer: mermaid's
// `layout-algorithms/dagre/index.js`. Nodes are drawn first to learn their
// sizes, groups cut out of the graph are laid out and drawn by themselves
// (recursively) and placed as one node, the graph is laid out by dagre,
// and everything is moved into place and the edges drawn along their
// routes.

///|
/// The groups a graph is drawn into, and what is the same for all of its
/// drawing.
priv struct DagreMeasured {
  root : @dom.Element
  clusters : @dom.Element
  edge_paths : @dom.Element
  edge_labels : @dom.Element
  merge_self_loops : Bool
  /// `subGraphTitleTotalMargin`.
  title_margin : Double
}

///|
/// The layout names the dagre layout answers to: `dagre`, and every name
/// mermaid has no layout for, which falls back to it.
pub fn is_dagre_layout(layout : String) -> Bool {
  !(layout
  is ("elk"
  | "elk.stress"
  | "elk.force"
  | "elk.mrtree"
  | "elk.sporeOverlap"
  | "elk.box"
  | "elk.rectpacking"
  | "swimlane"
  | "cose-bilkent"))
}

///|
/// `nodesep` and `ranksep` of the graph: a top-level setting, else what the
/// diagram's renderer asks for, else the flowchart's.
fn dagre_spacing(data : LayoutData) -> (Double?, Double?) {
  let config = data.config
  let truthy = (value : Double?) => {
    match value {
      Some(value) if value != 0.0 && !value.is_nan() => Some(value)
      _ => None
    }
  }
  let own = (key : String, default : Double, nullish : Bool) => {
    let value = config.number(key)
    if nullish {
      Some(value.unwrap_or(default))
    } else {
      Some(truthy(value).unwrap_or(default))
    }
  }
  let (node_spacing, rank_spacing) = match data.diagram_type {
    "flowchart" | "flowchart-v2" =>
      (
        own("flowchart.nodeSpacing", 50.0, false),
        own("flowchart.rankSpacing", 50.0, false),
      )
    "classDiagram" | "stateDiagram" =>
      (
        own("state.nodeSpacing", 50.0, false),
        own("state.rankSpacing", 50.0, false),
      )
    "agentflow" =>
      (
        own("agentflow.nodeSpacing", 50.0, false),
        own("agentflow.rankSpacing", 50.0, false),
      )
    "requirement" =>
      (
        own("state.nodeSpacing", 50.0, true),
        own("state.rankSpacing", 50.0, true),
      )
    // The mindmap db's `getData` puts fixed spacings on the layout data.
    "mindmap" => (Some(50.0), Some(50.0))
    // The use case renderer passes its own setting, which has a default.
    "usecase" =>
      (
        own("usecase.nodeSpacing", 50.0, false),
        own("usecase.rankSpacing", 50.0, false),
      )
    _ => (None, None)
  }
  // The ER renderer writes its spacing into the flowchart's settings.
  let (flow_node, flow_rank) = if data.diagram_type == "er" {
    (own("er.nodeSpacing", 140.0, false), own("er.rankSpacing", 80.0, false))
  } else {
    (
      config.number("flowchart.nodeSpacing"),
      config.number("flowchart.rankSpacing"),
    )
  }
  let pick = (top : Double?, own : Double?, flow : Double?) => {
    match truthy(top) {
      Some(value) => Some(value)
      None =>
        match truthy(own) {
          Some(value) => Some(value)
          None => flow
        }
    }
  }
  (
    pick(config.number("nodeSpacing"), node_spacing, flow_node),
    pick(config.number("rankSpacing"), rank_spacing, flow_rank),
  )
}

///|
/// A copy of an edge of the diagram, with nothing measured.
fn fresh_edge(edge : Edge) -> Edge {
  { ..edge, terminals: [], points: [], position: None, }
}

///|
/// The graph of the diagram: its nodes, nested, and its edges, a self loop
/// cut into three pieces through two nodes of its own. Mermaid's
/// `prepareLayoutForDagre`.
fn DagreState::prepare(self : DagreState) -> DagreGraph raise LayoutError {
  let data = self.data
  let (nodesep, ranksep) = dagre_spacing(data)
  let graph = new_dagre_graph({
    rankdir: Some(data.direction),
    nodesep,
    ranksep,
    marginx: 8.0,
    marginy: 8.0,
  })
  let set_parent = (v : String, parent : String?) => {
    graph.set_parent(v, parent?) catch {
      error => raise layout_error(error)
    }
  }
  for node in data.nodes {
    graph.set_node(node.id, Leaf({ ..node, element: None, intersect: None, }))
    if node.parent_id is Some(parent) && parent != "" {
      set_parent(node.id, Some(parent))
    }
  }
  let set_edge = (v : String, w : String, edge : DagreEdge, name : String) => {
    graph.set_edge(v, w, edge, name~) catch {
      error => raise layout_error(error)
    }
  }
  for edge in data.edges {
    if edge.start != edge.end {
      set_edge(
        edge.start,
        edge.end,
        {
          edge: fresh_edge(edge),
          from_cluster: None,
          to_cluster: None,
          self_loop: None,
          original: None,
        },
        edge.id,
      )
      continue
    }
    let node_id = edge.start
    guard graph.node(node_id) is Some(Leaf(node)) else {
      raise LayoutError("The self loop of \{node_id} has no node to go around.")
    }
    let parent = match node.parent_id {
      Some(parent) if parent != "" => Some(parent)
      _ => None
    }
    for suffix in ["1", "2"] {
      let id = node_id + "---" + node_id + "---" + suffix
      let dummy = Node::new(
        id~,
        dom_id=id,
        label="",
        parent_id?=node.parent_id,
        padding=0.0,
        look="",
        shape="labelRect",
      )
      dummy.width = Some(10.0)
      dummy.height = Some(10.0)
      graph.set_node(id, Leaf(dummy))
      set_parent(id, parent)
    }
    let special1 = node_id + "---" + node_id + "---1"
    let special2 = node_id + "---" + node_id + "---2"
    let original = fresh_edge(edge)
    let piece = (edge : Edge, order : Int32) => {
      edge,
      from_cluster: None,
      to_cluster: None,
      self_loop: Some((original.id, order)),
      original: Some(original),
    }
    let edge1 = piece(
      {
        ..fresh_edge(edge),
        id: node_id + "-cyclic-special-1",
        label: "",
        arrow_type_end: "none",
        end_label_left: "",
        end_label_right: "",
        start_label_left: "",
      },
      0,
    )
    let edge_mid = piece(
      {
        ..fresh_edge(edge),
        id: node_id + "-cyclic-special-mid",
        start_label_right: "",
        start_label_left: "",
        end_label_left: "",
        end_label_right: "",
        arrow_type_start: "none",
        arrow_type_end: "none",
      },
      1,
    )
    let edge2 = piece(
      {
        ..fresh_edge(edge),
        id: node_id + "-cyclic-special-2",
        label: "",
        start_label_right: "",
        start_label_left: "",
        arrow_type_start: "none",
      },
      2,
    )
    if node.is_group {
      edge1.from_cluster = Some(node_id)
      edge2.to_cluster = Some(node_id)
    }
    set_edge(node_id, special1, edge1, node_id + "-cyclic-special-0")
    set_edge(special1, special2, edge_mid, node_id + "-cyclic-special-1")
    set_edge(special2, node_id, edge2, node_id + "-cyclic-special-2")
  }
  self.adjust_clusters_and_edges(graph)
  graph
}

///|
/// Whether the pieces of self loops are drawn as one loop.
fn merges_self_loops(diagram_type : String) -> Bool {
  diagram_type
  is ("flowchart" | "flowchart-v2" | "stateDiagram" | "er" | "classDiagram")
}

///|
/// Draw a node to learn its size: mermaid's `insertMeasuredNode`.
fn DagreState::insert_measured_node(
  self : DagreState,
  group : @dom.Element,
  node : Node,
  dir : String,
) -> Unit raise LayoutError {
  let element = insert_node(group, node, self.env, dir)
  if node.look == "" {
    // `data-look` of a node without a look is removed again.
    element.remove_attr("data-look") |> ignore
  }
  self.node_elements[node.id] = element
  let box = element.bbox()
  node.width = Some(box.width)
  node.height = Some(box.height)
}

///|
/// Create the groups of a graph, draw its nodes (laying out and drawing
/// the groups cut out of it) and its edge labels: mermaid's
/// `measureDagreGraph`.
fn DagreState::measure_graph(
  self : DagreState,
  element : @dom.Element,
  graph : DagreGraph,
  parent_cluster : ClusterNode?,
) -> DagreMeasured raise LayoutError {
  let dir = graph.graph().rankdir
  let root = element.append("g").attr("class", "root")
  let clusters = root.append("g").attr("class", "clusters")
  let edge_paths = root.append("g").attr("class", "edgePaths")
  let edge_labels = root.append("g").attr("class", "edgeLabels")
  let nodes = root.append("g").attr("class", "nodes")
  let merge_self_loops = merges_self_loops(self.data.diagram_type)
  for v in graph.nodes() {
    let node = graph.node(v)
    if parent_cluster is Some(parent) {
      // Every node of the graph is nested in a copy of the group.
      graph.set_node(
        parent.id,
        Leaf({ ..parent.data, element: None, intersect: None, }),
      )
      if graph.parent(v) is None {
        graph.set_parent(v, parent=parent.id) catch {
          error => raise layout_error(error)
        }
      }
    }
    match node {
      Some(Extracted(cluster)) => {
        let label = graph.graph()
        let inner = cluster.graph.graph()
        cluster.graph.set_graph({
          ..inner,
          ranksep: label.ranksep.map(ranksep => ranksep + 25.0),
          nodesep: label.nodesep,
        })
        let (element, diff) = self.render_subgraph(
          nodes,
          cluster.graph,
          cluster,
        )
        let box = element.bbox()
        cluster.width = box.width
        cluster.height = box.height
        cluster.diff = match diff {
          Some(diff) if diff != 0.0 && !diff.is_nan() => diff
          _ => 0.0
        }
        self.node_elements[cluster.id] = element
      }
      _ if !graph.children(v).is_empty() => {
        guard node is Some(Leaf(group)) else {
          raise LayoutError("The group \{v} has no node of its own.")
        }
        self.cluster_db[group.id] = {
          id: find_non_cluster_child(group.id, graph, None),
          cluster_data: None,
          external_connections: false,
          node,
        }
      }
      Some(Leaf(leaf)) =>
        self.insert_measured_node(nodes, leaf, dir.unwrap_or("undefined"))
      _ => raise LayoutError("The node \{v} has no label to draw.")
    }
  }
  // The labels of all edges are made at once: each edge's centre label
  // first, then, one terminal label of every edge at a time, the terminal
  // labels, in the order the browser finishes measuring them.
  let labelled : Array[Edge] = []
  for e in graph.edges() {
    guard graph.edge(e) is Some(edge) else { continue }
    if merge_self_loops && edge.self_loop is Some((id, order)) {
      if order != 1 {
        continue
      }
      let original = edge.original.unwrap_or(edge.edge)
      let label_edge = {
        ..edge.edge,
        id,
        start_label_left: original.start_label_left,
        start_label_right: original.start_label_right,
        end_label_left: original.end_label_left,
        end_label_right: original.end_label_right,
        terminals: [],
      }
      self.insert_centre_label(edge_labels, label_edge)
      labelled.push(label_edge)
      edge.edge.width = label_edge.width
      edge.edge.height = label_edge.height
      edge.edge.label_style = label_edge.label_style
      continue
    }
    self.insert_centre_label(edge_labels, edge.edge)
    labelled.push(edge.edge)
  }
  self.insert_terminal_labels_in_rounds(edge_labels, labelled)
  let top = self.data.config
    .number("flowchart.subGraphTitleMargin.top")
    .unwrap_or(0.0)
  let bottom = self.data.config
    .number("flowchart.subGraphTitleMargin.bottom")
    .unwrap_or(0.0)
  {
    root,
    clusters,
    edge_paths,
    edge_labels,
    merge_self_loops,
    title_margin: top + bottom,
  }
}

///|
/// Create and measure the centre label of an edge: the first half of
/// mermaid's `insertEdgeLabel`.
fn DagreState::insert_centre_label(
  self : DagreState,
  group : @dom.Element,
  edge : Edge,
) -> Unit raise LayoutError {
  let element = if edge.label == "" && !self.label_env.html_labels {
    insert_empty_text_label(group, edge)
  } else {
    insert_edge_label(
      group,
      edge,
      self.env,
      self.label_env,
      padding_x=label_background_padding(self.data.diagram_type),
      own_styles=edge_label_uses_own_styles(self.data.diagram_type),
    )
  }
  self.edge_labels[edge.id] = element
}

///|
/// Create and measure the terminal labels of edges whose centre labels
/// are made: the second half of mermaid's `insertEdgeLabel`, run for all
/// edges at once, so that the first terminal label of every edge comes
/// before the second of any.
fn DagreState::insert_terminal_labels_in_rounds(
  self : DagreState,
  group : @dom.Element,
  edges : Array[Edge],
) -> Unit raise LayoutError {
  let env = {
    ..self.env,
    font_size: terminal_label_font_size(
      self.data.diagram_type,
      self.env.font_size,
    ),
  }
  let texts = edges.map(terminal_label_texts)
  let mut round = 0
  while texts.iter().any(entries => round < entries.length()) {
    for i, edge in edges {
      if texts[i].get(round) is Some((key, text)) {
        insert_terminal_label(group, edge, env, key, text)
        self.terminal_labels[edge.id] = edge.terminals
      }
    }
    round += 1
  }
}

///|
/// Create and measure the labels of an edge that had none made yet:
/// mermaid's `insertEdgeLabel`.
fn DagreState::insert_dagre_edge_label(
  self : DagreState,
  group : @dom.Element,
  edge : Edge,
) -> Unit raise LayoutError {
  self.insert_centre_label(group, edge)
  self.insert_terminal_labels_in_rounds(group, [edge])
}

///|
/// The width and height dagre reads of a node.
fn dagre_size(node : DagreNode?) -> (Double?, Double?) {
  match node {
    Some(Leaf(node)) => (node.width, node.height)
    Some(Extracted(cluster)) => (Some(cluster.width), Some(cluster.height))
    _ => (None, None)
  }
}

///|
/// Lay the graph out with dagre and write the positions back into its
/// nodes and edges: dagre's `layout` with its `updateInputGraph`.
fn run_dagre_layout(graph : DagreGraph) -> Unit raise LayoutError {
  let label = graph.graph()
  let attrs : @dagre.GraphAttrs = {
    rankdir: label.rankdir,
    nodesep: label.nodesep,
    edgesep: None,
    ranksep: label.ranksep,
    marginx: Some(label.marginx),
    marginy: Some(label.marginy),
    acyclicer: None,
    ranker: None,
    align: None,
  }
  let node_ids = graph.nodes()
  let nodes : Array[@dagre.NodeAttrs] = node_ids.map(v => {
    let (width, height) = dagre_size(graph.node(v))
    { id: v, width, height, parent: graph.parent(v), }
  })
  let edge_ids = graph.edges()
  let edges : Array[@dagre.EdgeAttrs] = []
  for e in edge_ids {
    guard graph.edge(e) is Some(edge) else { continue }
    let edge = edge.edge
    edges.push({
      v: e.v,
      w: e.w,
      name: e.name,
      minlen: edge.minlen,
      weight: None,
      width: Some(edge.width),
      height: Some(edge.height),
      labeloffset: None,
      labelpos: edge.labelpos,
    })
  }
  let result = @dagre.layout(attrs, nodes, edges) catch {
    @dagre.LayoutError(message) => raise LayoutError(message)
  }
  for i, v in node_ids {
    let out = result.nodes[i]
    match graph.node(v) {
      Some(Leaf(node)) => {
        node.x = out.x
        node.y = out.y
        if out.compound {
          node.width = Some(out.width)
          node.height = Some(out.height)
        }
      }
      Some(Extracted(cluster)) => {
        cluster.x = out.x
        cluster.y = out.y
        if out.compound {
          cluster.width = out.width
          cluster.height = out.height
        }
      }
      _ => ()
    }
  }
  for i, e in edge_ids {
    guard graph.edge(e) is Some(edge) else { continue }
    let out = result.edges[i]
    edge.edge.points = out.points.map(p => Point::{ x: p.x, y: p.y, })
    if out.label is Some(label) {
      edge.edge.position = Some({ x: label.x, y: label.y, })
    }
  }
}

///|
/// Move a node to where the layout put it: mermaid's `positionNode`.
fn DagreState::position_node(
  self : DagreState,
  node : DagreNode,
) -> Unit raise LayoutError {
  let n = @dom.number
  match node {
    Leaf(node) => {
      guard self.node_elements.get(node.id) is Some(element) else {
        raise LayoutError("The node \{node.id} was never drawn.")
      }
      element.attr("transform", "translate(\{n(node.x)}, \{n(node.y)})")
      |> ignore
    }
    Extracted(cluster) => {
      guard self.node_elements.get(cluster.id) is Some(element) else {
        raise LayoutError("The group \{cluster.id} was never drawn.")
      }
      let padding = 8.0
      element.attr(
        "transform",
        "translate(\{n(cluster.x + cluster.diff - cluster.width / 2.0)}, \{n(cluster.y - cluster.height / 2.0 - padding)})",
      )
      |> ignore
    }
    Unlabelled => raise LayoutError("A node without a label has no place.")
  }
}

///|
/// Draw the frame of a group: mermaid's `insertCluster`, which leaves its
/// size, how much its title widened it and how to clip edges at it on the
/// node.
fn DagreState::insert_dagre_cluster(
  self : DagreState,
  group : @dom.Element,
  node : Node,
) -> Unit raise LayoutError {
  let frame = insert_cluster_shape(group, node, self.env)
  let box = frame.outline.bbox()
  node.width = Some(frame.width.unwrap_or(box.width))
  node.height = Some(box.height)
  if frame.diff is Some(diff) {
    self.diffs[node.id] = diff
  }
  node.intersect = Some(node_intersect_rect(node))
}

///|
/// Lay out and draw a group cut out of its graph, nested in a frame of its
/// own: mermaid's `renderDagreSubgraph`. Returns the group the graph was
/// drawn into and how much the title widened its frame.
fn DagreState::render_subgraph(
  self : DagreState,
  element : @dom.Element,
  graph : DagreGraph,
  parent_cluster : ClusterNode,
) -> (@dom.Element, Double?) raise LayoutError {
  let measured = self.measure_graph(element, graph, Some(parent_cluster))
  run_dagre_layout(graph)
  // `paintDagreLayoutCore`
  let margin = measured.title_margin
  for v in sort_nodes_by_hierarchy(graph) {
    match graph.node(v) {
      Some(Extracted(cluster) as node) => {
        cluster.y = cluster.y + margin
        if self.cluster_db.get(cluster.id) is Some(entry) {
          entry.node = Some(node)
        }
        self.position_node(node)
      }
      Some(Leaf(node) as label) if !graph.children(v).is_empty() => {
        node.height = node.height.map(height => height + margin)
        self.insert_dagre_cluster(measured.clusters, node)
        match self.cluster_db.get(node.id) {
          Some(entry) => entry.node = Some(label)
          None => raise LayoutError("The group \{node.id} is not known.")
        }
      }
      Some(Leaf(node) as label) => {
        node.y = node.y + margin / 2.0
        self.position_node(label)
      }
      _ => raise LayoutError("The node \{v} has no label to place.")
    }
  }
  let offset = margin / 2.0
  for entry in edges_to_render(graph, offset, measured.merge_self_loops) {
    let (edge, start, end) = entry
    edge.edge.points = edge.edge.points.map(point => {
      x: point.x,
      y: point.y + offset,
    })
    let paths = self.insert_dagre_edge(
      measured.edge_paths,
      edge,
      graph.node(start),
      graph.node(end),
    )
    self.position_edge_label(edge.edge, paths, margin)
  }
  let mut diff : Double? = None
  for v in graph.nodes() {
    if graph.node(v) is Some(Leaf(node)) && node.is_group {
      diff = self.diffs.get(node.id)
    }
  }
  (measured.root, diff)
}

///|
/// Lay out and draw `data` into `element` with dagre.
fn render_dagre(
  data : LayoutData,
  element : @dom.Element,
  env : Env,
  label_env : Env,
) -> Unit raise LayoutError {
  let state : DagreState = {
    cluster_db: Map([]),
    descendants: Map([]),
    parents: Map([]),
    edge_labels: Map([]),
    terminal_labels: Map([]),
    node_elements: Map([]),
    diffs: Map([]),
    data,
    env,
    label_env,
  }
  let graph = state.prepare()
  let measured = state.measure_graph(element, graph, None)
  run_dagre_layout(graph)
  // `applyDagreLayoutResult`
  let margin = measured.title_margin
  let by_id : Map[String, Node] = Map([])
  for node in data.nodes {
    by_id[node.id] = node
  }
  for v in sort_nodes_by_hierarchy(graph) {
    match graph.node(v) {
      Some(Extracted(cluster)) => cluster.y = cluster.y + margin
      Some(Leaf(node)) => {
        if !graph.children(v).is_empty() {
          node.height = node.height.map(height => height + margin)
        } else {
          node.y = node.y + margin / 2.0
        }
        if by_id.get(v) is Some(target) {
          target.x = node.x
          target.y = node.y
          target.width = node.width
          target.height = node.height
        }
      }
      _ => ()
    }
  }
  let offset = margin / 2.0
  let edges = edges_to_render(graph, offset, measured.merge_self_loops).map(entry => {
    let (edge, _, _) = entry
    let points = edge.edge.points.map(point => {
      x: point.x,
      y: point.y + offset,
    })
    { ..edge, edge: { ..edge.edge, points, }, }
  })
  // `paintLayoutData`
  for v in sort_nodes_by_hierarchy(graph) {
    match graph.node(v) {
      Some(Extracted(_) as node) => state.position_node(node)
      Some(Leaf(node)) if node.is_group && !graph.children(node.id).is_empty() =>
        state.insert_dagre_cluster(measured.clusters, node)
      Some(Leaf(_) as node) => state.position_node(node)
      _ => ()
    }
  }
  for edge in edges {
    let layout_edge = edge.edge
    let paths = state.insert_dagre_edge(
      measured.edge_paths,
      edge,
      graph.node(layout_edge.start),
      graph.node(layout_edge.end),
    )
    if has_edge_label(layout_edge) {
      if !state.edge_labels.contains(layout_edge.id) {
        state.insert_dagre_edge_label(measured.edge_labels, layout_edge)
      }
      state.position_edge_label(layout_edge, paths, margin)
    }
  }
}
