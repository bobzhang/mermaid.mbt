// The unified renderer with the cose-bilkent layout: mermaid's
// `layout-algorithms/cose-bilkent/render.ts`, as mindmaps are drawn.

///|
/// Draw `data` into the first group of `svg`, laid out by cose-bilkent:
/// mermaid's `render` with the layout `cose-bilkent`. The nodes are drawn
/// and measured, laid out by `internal/cose`, and the edges drawn as basis
/// curves through the end points and middle cytoscape gives an edge
/// between two of its default nodes.
pub fn render_cose(
  data : LayoutData,
  svg : @dom.Element,
) -> Unit raise LayoutError {
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
  }
  element.append("g").attr("class", "subgraphs") |> ignore
  let edge_paths = element.append("g").attr("class", "edgePaths")
  let edge_labels = element.append("g").attr("class", "edgeLabels")
  let nodes_group = element.append("g").attr("class", "nodes")
  // Measure: every node is drawn once, at the origin.
  let index : Map[String, Int32] = Map([])
  let sizes = []
  for node in data.nodes {
    if node.is_group {
      raise LayoutError("cose-bilkent: groups are not supported")
    }
    let drawn = insert_node(nodes_group, node, env, data.direction)
    let box = drawn.bbox()
    index[node.id] = sizes.length()
    sizes.push((box.width, box.height))
  }
  let pairs = []
  for edge in data.edges {
    guard index.get(edge.start) is Some(start) &&
      index.get(edge.end) is Some(end) else {
      raise LayoutError("cose-bilkent: an edge to a node that is not drawn")
    }
    pairs.push((start, end))
  }
  // Lay out.
  let positions = @cose.layout(sizes, pairs) catch {
    @cose.Unsupported(message) => raise LayoutError(message)
  }
  let n = @dom.number
  for i, node in data.nodes {
    let (x, y) = positions[i]
    node.x = x
    node.y = y
    if node.element is Some(drawn) {
      drawn.attr("transform", "translate(\{n(x)}, \{n(y)})") |> ignore
    }
  }
  // Paint the edges.
  let label_env = {
    ..env,
    font_size: edge_label_font_size(data.diagram_type, env.font_size),
  }
  for i, edge in data.edges {
    insert_edge_label(edge_labels, edge, env, label_env) |> ignore
    let (start, end) = pairs[i]
    guard @cose.straight_edge(positions[start], positions[end]) is Some(points) else {
      // Cytoscape reports no end points for nodes this close.
      raise LayoutError("cose-bilkent: an edge between overlapping nodes")
    }
    edge.points = points.map(point => { x: point.0, y: point.1, })
    // `resolveEdgeCurveType`
    let curve = if edge.curve != "" {
      edge.curve
    } else {
      data.config.text("flowchart.curve").unwrap_or("basis")
    }
    let mut line_data = edge.points.filter(p => !p.y.is_nan())
    if curve != "rounded" {
      line_data = fix_corners(line_data)
    }
    let path = if curve == "rounded" {
      rounded_path(apply_marker_offsets(line_data, edge), 5.0)
    } else {
      // An unknown curve is drawn as a basis curve.
      let points = offset_line_points(line_data, edge)
      match @d3.line(curve, points) {
        Some(path) => path
        None => @d3.line("basis", points).unwrap_or("")
      }
    }
    insert_edge(edge_paths, edge, data, path~) |> ignore
  }
}
