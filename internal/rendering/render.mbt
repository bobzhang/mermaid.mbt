// The unified renderer: measure, lay out with ELK, paint. Mermaid's
// `rendering-util/render.ts` with its ELK layout.

///|
/// The diagram could not be laid out.
pub(all) suberror LayoutError {
  LayoutError(String)
  /// Upstream fails as well, with this message: an image that cannot be
  /// decoded.
  UpstreamError(String)
} derive(Eq, Debug)

///|
/// The definitions the look's stylesheet rules point at: mermaid's
/// `insertLookDefs`.
fn insert_look_defs(svg : @dom.Element, data : LayoutData) -> Unit {
  let theme_name = data.config.text("theme").unwrap_or("")
  let theme = data.config.theme()
  let id = data.diagram_id
  let flood_color = if theme_name.contains("dark") {
    "#FFFFFF"
  } else {
    "#000000"
  }
  let drop_shadow = (id : String, size : String, offset : String) => {
    svg
    .append("defs")
    .append("filter")
    .attr("id", id)
    .attr("height", size)
    .attr("width", size)
    .append("feDropShadow")
    .attr("dx", offset)
    .attr("dy", offset)
    .attr("stdDeviation", "0")
    .attr("flood-opacity", "0.06")
    .attr("flood-color", flood_color)
    |> ignore
  }
  drop_shadow("\{id}-drop-shadow", "130%", "4")
  drop_shadow("\{id}-drop-shadow-small", "150%", "2")
  if !theme.flag("useGradient") {
    return
  }
  let gradient = svg
    .append("linearGradient")
    .attr("id", "\{id}-gradient")
    .attr("gradientUnits", "objectBoundingBox")
    .attr("x1", "0%")
    .attr("y1", "0%")
    .attr("x2", "100%")
    .attr("y2", "0%")
  gradient
  .append("stop")
  .attr("offset", "0%")
  .attr("stop-color", theme.text("gradientStart"))
  .attr("stop-opacity", "1")
  |> ignore
  gradient
  .append("stop")
  .attr("offset", "100%")
  .attr("stop-color", theme.text("gradientStop"))
  .attr("stop-opacity", "1")
  |> ignore
}

///|
/// Size the `<svg>` to its content plus padding: mermaid's
/// `setupViewPortForSVG`.
pub fn setup_viewport(
  svg : @dom.Element,
  padding : Double,
  css_class : String,
  use_max_width : Bool,
) -> Unit {
  svg.attr("class", css_class) |> ignore
  let bounds = svg.bbox()
  let width = bounds.width + padding * 2.0
  let height = bounds.height + padding * 2.0
  if use_max_width {
    svg
    .attr("width", "100%")
    .attr("style", "max-width: \{@dom.number(width)}px;")
    |> ignore
  } else {
    svg.attr_number("height", height).attr_number("width", width) |> ignore
  }
  let n = @dom.number
  svg.attr(
    "viewBox",
    "\{n(bounds.x - padding)} \{n(bounds.y - padding)} \{n(width)} \{n(height)}",
  )
  |> ignore
}

///|
/// The direction of the flow around a node: that of the nearest group
/// around it that sets one, else the diagram's. Mermaid's `resolveNodeDir`.
fn node_dir(node : Node, by_id : Map[String, Node], diagram : String) -> String {
  let seen : Set[String] = Set([])
  let mut current = node
  while true {
    if current.dir is Some(dir) && dir != "" {
      return dir
    }
    guard current.parent_id is Some(parent_id) &&
      parent_id != "" &&
      !seen.contains(parent_id) else {
      break
    }
    seen.add(parent_id)
    guard by_id.get(parent_id) is Some(parent) else { break }
    current = parent
  }
  diagram
}

///|
/// Lay out and draw `data` into the first group of `svg`. `image_loader`
/// loads the images of image shapes whose size is not in their URL.
pub fn render(
  data : LayoutData,
  svg : @dom.Element,
  image_loader? : (String) -> Bytes?,
) -> Unit raise LayoutError {
  if data.config.text("layout") == Some("swimlane") {
    return render_swimlane(data, svg, image_loader)
  }
  // Ids are unique across the diagrams of a page.
  for node in data.nodes {
    node.dom_id = "\{data.diagram_id}-\{node.dom_id}"
  }
  insert_look_defs(svg, data)
  guard svg.child_elements().filter(child => child.tag == "g") is [element, ..] else {
    raise LayoutError("the svg element has no group to draw into")
  }
  insert_markers(
    element,
    data.markers,
    data.diagram_type,
    data.diagram_id,
    config=data.config,
  )
  let env = {
    ..Env::new(data.config, data.diagram_id),
    node_text_centred: node_text_centred(data.diagram_type),
    image_loader,
  }
  if is_dagre_layout(data.config.text("layout").unwrap_or("elk")) {
    let label_env = {
      ..env,
      font_size: edge_label_font_size(data.diagram_type, env.font_size),
    }
    return render_dagre(data, element, env, label_env)
  }
  // Measure: every node is drawn once to learn its size.
  let root = element.append("g").attr("class", "root")
  let clusters = root.append("g").attr("class", "clusters")
  let edge_paths = root.append("g").attr("class", "edges edgePaths")
  let edge_labels = root.append("g").attr("class", "edgeLabels")
  let nodes_group = root.append("g").attr("class", "nodes")
  let by_id : Map[String, Node] = Map([])
  for node in data.nodes {
    by_id[node.id] = node
  }
  for node in data.nodes {
    if node.is_group {
      measure_group_label(nodes_group, node, env)
    } else {
      let dir = node_dir(node, by_id, data.direction)
      let element = insert_node(nodes_group, node, env, dir)
      let box = element.bbox()
      node.width = Some(box.width)
      node.height = Some(box.height)
    }
  }
  let label_elements : Map[String, @dom.Element] = Map([])
  let label_env = {
    ..env,
    font_size: edge_label_font_size(data.diagram_type, env.font_size),
  }
  for edge in data.edges {
    // Line breaks in edge labels are plain newlines from here on.
    edge.label = normalize_breaks(edge.label)
    if has_edge_label(edge) {
      label_elements[edge.id] = insert_edge_labels(
        edge_labels,
        edge,
        env,
        label_env,
        data.diagram_type,
      )
    }
  }
  // Lay out.
  let state = build_elk_state(data, "elk.layered")
  let input = state.to_json()
  let traced = traced_input(input)
  let graph = @elk.new_elk_engine().layout(graph=input) catch {
    error => raise LayoutError(error.to_string())
  }
  trace_graph(traced, graph)
  let routed = result_edges(graph)
  apply_node_positions(json_items(graph, "children"), state, 0.0, 0.0)
  even_group_frames(state.children, state, routed)
  read_terminal_labels(state, graph)
  apply_edge_layout(data, state, routed)
  order_nodes_for_paint(data.nodes)
  // Paint.
  let n = @dom.number
  for node in data.nodes {
    if node.is_group {
      insert_cluster_shape(clusters, node, env) |> ignore
    } else if node.element is Some(element) {
      element.attr("transform", "translate(\{n(node.x)}, \{n(node.y)})")
      |> ignore
    }
  }
  let title_margin = data.config
    .number("flowchart.subGraphTitleMargin.top")
    .unwrap_or(0.0) +
    data.config.number("flowchart.subGraphTitleMargin.bottom").unwrap_or(0.0)
  let paths : Map[String, @dom.Element] = Map([])
  for edge in data.edges {
    let path = insert_edge(edge_paths, edge, data)
    if !paths.contains(edge.id) {
      paths[edge.id] = path
    }
    if edge.label != "" {
      let element = match label_elements.get(edge.id) {
        Some(element) => element
        None => {
          let element = insert_edge_label(
            edge_labels,
            edge,
            env,
            label_env,
            padding_x=label_background_padding(data.diagram_type),
            own_styles=edge_label_uses_own_styles(data.diagram_type),
          )
          label_elements[edge.id] = element
          element
        }
      }
      let position = edge.position.unwrap_or({ x: 0.0, y: 0.0, })
      element.attr(
        "transform",
        "translate(\{n(position.x)}, \{n(position.y + title_margin / 2.0)})",
      )
      |> ignore
    }
    position_terminal_labels(edge)
  }
  apply_line_jumps(data, paths)
}
