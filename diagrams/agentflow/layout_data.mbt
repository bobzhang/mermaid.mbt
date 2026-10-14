///|
/// The shape of a node that is no group: mermaid's `getTypeFromVertex`.
fn vertex_shape(vertex : @flowchart.Vertex) -> String {
  match vertex.shape.map(resolve_shape_alias) {
    None | Some("square") => "squareRect"
    Some("round") => "roundedRect"
    Some(shape) => shape
  }
}

///|
/// The nodes and edges to lay out: mermaid's `AgentFlowDB.getData`, shapes
/// normalised and palette slots assigned.
fn AgentDb::layout_data(
  self : AgentDb,
) -> (Array[@rendering.Node], Array[@rendering.Edge]) {
  let flow = self.flow
  let config = self.config
  let look = config.text("look").unwrap_or("")
  let nodes : Array[@rendering.Node] = []
  let edges : Array[@rendering.Edge] = []
  let sub_graphs = flow.sub_graphs
  let lookup = flow.sub_graph_lookup
  let parent_db : Map[String, String] = Map([])
  let sub_graph_db : Map[String, Bool] = Map([])
  let is_collapsed = (sg : @flowchart.SubGraph) => {
    sg.metadata.get("view") is Some(String("collapsed"))
  }
  // What a collapsed container hides, and what stands in for it.
  let hidden : Map[String, Unit] = Map([])
  let collapsed_ancestor : Map[String, String] = Map([])
  fn collect(id : String, ancestor : String, seen : Map[String, Unit]) {
    if seen.contains(id) {
      return
    }
    seen[id] = ()
    guard lookup.get(id) is Some(sg) else { return }
    for child in sg.nodes {
      if child == ancestor || seen.contains(child) {
        continue
      }
      hidden[child] = ()
      collapsed_ancestor[child] = ancestor
      collect(child, ancestor, seen)
    }
  }
  for sg in sub_graphs {
    if is_collapsed(sg) && !hidden.contains(sg.id) {
      collect(sg.id, sg.id, Map([]))
    }
  }
  // Whether `parent` is inside `child` already, so that nesting `child`
  // in it would close a loop.
  let closes_cycle = (child : String, parent : String) => {
    let seen : Map[String, Unit] = Map([])
    let mut current = Some(parent)
    let mut found = false
    while current is Some(id) && !seen.contains(id) {
      if id == child {
        found = true
        break
      }
      seen[id] = ()
      current = parent_db.get(id)
    }
    found
  }
  for i = sub_graphs.length() - 1; i >= 0; i = i - 1 {
    let sg = sub_graphs[i]
    if hidden.contains(sg.id) {
      continue
    }
    if sg.nodes.length() > 0 {
      sub_graph_db[sg.id] = true
    }
    for id in sg.nodes {
      // The nesting that would close a loop is dropped, with a warning
      // on the console.
      if closes_cycle(id, sg.id) {
        continue
      }
      parent_db[id] = sg.id
    }
  }
  let slot = self.container_slots(parent_db)
  for i = sub_graphs.length() - 1; i >= 0; i = i - 1 {
    let sg = sub_graphs[i]
    if hidden.contains(sg.id) {
      continue
    }
    let collapsed = is_collapsed(sg)
    let metadata = sg.metadata.copy()
    if collapsed {
      metadata["containerType"] = Json::string("flow")
    }
    nodes.push(
      @rendering.Node::new(
        id=sg.id,
        label=sg.title,
        label_type=sg.label_type,
        parent_id?=parent_db.get(sg.id),
        padding=8.0,
        css_compiled_styles=flow.compiled_styles(sg.classes),
        css_classes=sg.classes.join(" "),
        shape=if collapsed { "collapsedGroup" } else { "flowGroup" },
        dir?=sg.dir,
        is_group=!collapsed,
        look~,
        color_index=slot(sg.id),
        data=Container(metadata~),
      ),
    )
  }
  let padding = match config.number("flowchart.padding") {
    Some(padding) if padding != 0.0 => padding
    _ => 8.0
  }
  let node_look = if look == "" { "classic" } else { look }
  for _, vertex in flow.vertices {
    if hidden.contains(vertex.id) {
      continue
    }
    let existing = nodes.search_by(node => node.id == vertex.id)
    if existing is Some(index) {
      // A container of the same name takes the vertex's styling.
      nodes[index] = nodes[index].with_styles(
        css_styles=vertex.styles,
        css_compiled_styles=flow.compiled_styles(vertex.classes),
        css_classes=vertex.classes.join(" "),
      )
      continue
    }
    let is_group = sub_graph_db.get(vertex.id).unwrap_or(false)
    // Every node is marked with its kind, which the palette colours.
    let kind = if self.connectors.contains(vertex.id) {
      "connector"
    } else {
      vertex_kind(vertex.shape)
    }
    let classes = "default \{vertex.classes.join(" ")} af-kind-\{kind}"
      .split(" ")
      .filter(word => word != "")
      .map(word => word.to_owned())
      .collect()
    nodes.push(
      @rendering.Node::new(
        id=vertex.id,
        label=vertex.text.unwrap_or(vertex.id),
        label_type=vertex.label_type,
        parent_id?=parent_db.get(vertex.id),
        padding~,
        css_styles=vertex.styles,
        css_compiled_styles=flow.compiled_styles(
          ["default", "node", ..vertex.classes],
        ),
        css_classes=classes.join(" "),
        dom_id=vertex.dom_id,
        look=node_look,
        link?=vertex.link,
        link_target?=vertex.link_target,
        tooltip?=flow.tooltips.get(vertex.id),
        have_callback=vertex.have_callback,
        is_group~,
        shape=if is_group {
          "rect"
        } else {
          normalise_shape(vertex_shape(vertex))
        },
        color_index?=if is_group { Some(slot(vertex.id)) } else { None },
        min_width?=if is_group {
          None
        } else {
          config.number("agentflow.minNodeWidth")
        },
        wrapping_width?=if is_group {
          None
        } else {
          config.number("agentflow.wrappingWidth")
        },
      ),
    )
  }
  for index, raw in flow.edges {
    let start = collapsed_ancestor.get(raw.start).unwrap_or(raw.start)
    let end = collapsed_ancestor.get(raw.end).unwrap_or(raw.end)
    // An edge inside a collapsed container disappears with it.
    if start == end && raw.start != raw.end {
      continue
    }
    let (arrow_start, arrow_end) = @flowchart.arrow_types(raw.kind)
    let styles = flow.default_style().unwrap_or([]).copy()
    if raw.style is Some(style) {
      styles.append(style)
    }
    let invisible = raw.stroke == Some("invisible")
    let open = invisible || raw.kind == Some("arrow_open")
    edges.push(
      @rendering.Edge::new(
        id=@flowchart.edge_id(
          start,
          end,
          counter=index,
          id?=if raw.id == "" { None } else { Some(raw.id) },
        ),
        start~,
        end~,
        label=raw.text,
        label_type=raw.label_type,
        thickness=raw.stroke.unwrap_or("normal"),
        pattern=raw.stroke.unwrap_or("normal"),
        classes=if invisible {
          ""
        } else {
          "edge-thickness-normal edge-pattern-solid flowchart-link"
        },
        arrow_type_start=if open { "none" } else { arrow_start },
        arrow_type_end=if open { "none" } else { arrow_end },
        css_compiled_styles=flow.compiled_styles(raw.classes),
        style=styles,
        look~,
        animate=raw.animate == Some(true),
        animation?=raw.animation,
      ),
    )
  }
  (nodes, edges)
}

///|
/// The palette slot of each container, by id: containers are numbered
/// parents first, in the order they were completed, which is not the
/// order of the nodes. Part of mermaid's `assignColorSlots`.
fn AgentDb::container_slots(
  self : AgentDb,
  parent_db : Map[String, String],
) -> (String) -> Int32 {
  let sub_graphs = self.flow.sub_graphs
  let order : Map[String, Int32] = Map([])
  let children : Map[String, Array[String]] = Map([])
  for sg in sub_graphs {
    if parent_db.get(sg.id) is Some(parent) {
      match children.get(parent) {
        Some(list) => list.push(sg.id)
        None => children[parent] = [sg.id]
      }
    }
  }
  fn walk(id : String) {
    if order.contains(id) {
      return
    }
    order[id] = order.length()
    for child in children.get(id).unwrap_or([]) {
      walk(child)
    }
  }
  for sg in sub_graphs {
    if !parent_db.contains(sg.id) {
      walk(sg.id)
    }
  }
  let palette_length = match self.config.theme().get("borderColorArray") {
    Array(colors) => colors.length()
    _ => 0
  }
  // Containers the walk did not reach are numbered after the others.
  let mut fallback = order.length()
  fn(id) {
    let n = match order.get(id) {
      Some(n) => n
      None => {
        fallback += 1
        fallback - 1
      }
    }
    container_slot(n, palette_length)
  }
}
