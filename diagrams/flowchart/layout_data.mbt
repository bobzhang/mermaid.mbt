///|
/// The styles of several classes, in order: mermaid's `getCompiledStyles`.
fn FlowDb::compiled_styles(
  self : FlowDb,
  class_names : Array[String],
) -> Array[String] {
  let mut compiled : Array[String] = []
  for name in class_names {
    guard self.classes.get(name) is Some(style_class) else { continue }
    // Both lists exist on every class here, so both steps always run.
    compiled = [..compiled, ..style_class.styles].map(style => {
      style.trim().to_owned()
    })
    compiled = [..compiled, ..style_class.text_styles].map(style => {
      style.trim().to_owned()
    })
  }
  compiled
}

///|
/// The shape a vertex is drawn with: mermaid's `getTypeFromVertex`.
fn vertex_shape(vertex : Vertex) -> String {
  if vertex.img is Some(_) {
    return "imageSquare"
  }
  if vertex.icon is Some(_) {
    return match vertex.form {
      Some("circle") => "iconCircle"
      Some("square") => "iconSquare"
      Some("rounded") => "iconRounded"
      _ => "icon"
    }
  }
  match vertex.shape {
    None | Some("square") => "squareRect"
    Some("round") => "roundedRect"
    Some(shape) => shape
  }
}

///|
/// The markers at the two ends of an edge type.
fn arrow_types(kind : String?) -> (String, String) {
  match kind {
    Some("arrow_point" | "arrow_circle" | "arrow_cross" as kind) =>
      ("none", kind)
    Some("double_arrow_point") => ("arrow_point", "arrow_point")
    Some("double_arrow_circle") => ("arrow_circle", "arrow_circle")
    Some("double_arrow_cross") => ("arrow_cross", "arrow_cross")
    _ => ("none", "arrow_point")
  }
}

///|
/// The nodes and edges to lay out: mermaid's `FlowDB.getData`.
fn FlowDb::layout_data(
  self : FlowDb,
) -> (Array[@rendering.Node], Array[@rendering.Edge]) {
  let config = self.config
  let look = config.text("look").unwrap_or("classic")
  let nodes : Array[@rendering.Node] = []
  let edges : Array[@rendering.Edge] = []
  let sub_graphs = self.sub_graphs
  let parent_db : Map[String, String] = Map([])
  let sub_graph_db : Map[String, Bool] = Map([])
  // The parent of every nested subgraph.
  let sub_graph_parent : Map[String, String] = Map([])
  for sg in sub_graphs {
    for child in sg.nodes {
      if self.sub_graph_lookup.contains(child) {
        sub_graph_parent[child] = sg.id
      }
    }
  }
  // Number the subgraphs in declaration order, parents before children.
  let declaration_index : Map[String, Int32] = Map([])
  let children_of : Map[String, Array[String]] = Map([])
  for sg in sub_graphs {
    if sub_graph_parent.get(sg.id) is Some(parent) {
      match children_of.get(parent) {
        Some(children) => children.push(sg.id)
        None => children_of[parent] = [sg.id]
      }
    }
  }
  let next_index = Ref(0)
  fn walk(id : String) {
    declaration_index[id] = next_index.val
    next_index.val += 1
    for child in children_of.get(id).unwrap_or([]) {
      walk(child)
    }
  }
  for sg in sub_graphs {
    if !sub_graph_parent.contains(sg.id) {
      walk(sg.id)
    }
  }
  let is_collapsed = (id : String) => {
    match self.sub_graph_lookup.get(id) {
      Some(sg) => sg.metadata.get("view") is Some(String("collapsed"))
      None => false
    }
  }
  let outermost_collapsed = (id : String) => {
    let mut result : String? = None
    let seen : Map[String, Unit] = Map([])
    let mut current = Some(id)
    while current is Some(id) {
      if seen.contains(id) {
        break
      }
      seen[id] = ()
      if is_collapsed(id) {
        result = Some(id)
      }
      current = sub_graph_parent.get(id)
    }
    result
  }
  // What a collapsed subgraph hides, and what stands in for it.
  let hidden : Map[String, Unit] = Map([])
  let collapsed_ancestor : Map[String, String] = Map([])
  for sg in sub_graphs {
    guard outermost_collapsed(sg.id) is Some(ancestor) else { continue }
    if sg.id != ancestor {
      hidden[sg.id] = ()
      collapsed_ancestor[sg.id] = ancestor
    }
    for child in sg.nodes {
      if child == ancestor {
        continue
      }
      hidden[child] = ()
      collapsed_ancestor[child] = ancestor
    }
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
      parent_db[id] = sg.id
    }
  }
  for i = sub_graphs.length() - 1; i >= 0; i = i - 1 {
    let sg = sub_graphs[i]
    if hidden.contains(sg.id) {
      continue
    }
    let collapsed = is_collapsed(sg.id)
    nodes.push(
      @rendering.Node::new(
        id=sg.id,
        label=sg.title,
        label_type=sg.label_type,
        parent_id?=parent_db.get(sg.id),
        padding=8.0,
        css_compiled_styles=self.compiled_styles(sg.classes),
        css_classes=sg.classes.join(" "),
        shape=if collapsed { "collapsedGroup" } else { "rect" },
        dir?=sg.dir,
        is_group=!collapsed,
        look~,
        color_index?=declaration_index.get(sg.id),
      ),
    )
  }
  let padding = match config.number("flowchart.padding") {
    Some(padding) if padding != 0.0 => padding
    _ => 8.0
  }
  for _, vertex in self.vertices {
    if hidden.contains(vertex.id) {
      continue
    }
    let existing = nodes.search_by(node => node.id == vertex.id)
    if existing is Some(index) {
      // A subgraph of the same name takes the vertex's styling.
      nodes[index] = nodes[index].with_styles(
        css_styles=vertex.styles,
        css_compiled_styles=self.compiled_styles(vertex.classes),
        css_classes=vertex.classes.join(" "),
      )
      continue
    }
    let is_group = sub_graph_db.get(vertex.id).unwrap_or(false)
    nodes.push(
      @rendering.Node::new(
        id=vertex.id,
        label=vertex.text.unwrap_or(vertex.id),
        label_type=vertex.label_type,
        parent_id?=parent_db.get(vertex.id),
        padding~,
        css_styles=vertex.styles,
        css_compiled_styles=self.compiled_styles(
          ["default", "node", ..vertex.classes],
        ),
        css_classes="default " + vertex.classes.join(" "),
        dom_id=vertex.dom_id,
        look~,
        link?=vertex.link,
        link_target?=vertex.link_target,
        tooltip?=self.tooltips.get(vertex.id),
        have_callback=vertex.have_callback,
        is_group~,
        shape=if is_group { "rect" } else { vertex_shape(vertex) },
        min_width?=if is_group {
          None
        } else {
          config.number("flowchart.minNodeWidth")
        },
      ),
    )
  }
  for index, raw in self.edges {
    let (arrow_start, arrow_end) = arrow_types(raw.kind)
    let styles = self.default_style.unwrap_or([]).copy()
    let start = collapsed_ancestor.get(raw.start).unwrap_or(raw.start)
    let end = collapsed_ancestor.get(raw.end).unwrap_or(raw.end)
    if start == end &&
      (
        collapsed_ancestor.contains(raw.start) ||
        collapsed_ancestor.contains(raw.end)
      ) {
      continue
    }
    if raw.style is Some(style) {
      styles.append(style)
    }
    let invisible = raw.stroke == Some("invisible")
    let open = invisible || raw.kind == Some("arrow_open")
    edges.push(
      @rendering.Edge::new(
        id=edge_id(
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
        css_compiled_styles=self.compiled_styles(raw.classes),
        style=styles,
        look~,
        animate=raw.animate == Some(true),
        animation?=raw.animation,
      ),
    )
  }
  (nodes, edges)
}
