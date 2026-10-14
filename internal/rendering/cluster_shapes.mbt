// The frames state diagrams draw around composite states, their regions
// and notes: the `roundedWithTitle`, `divider` and `noteGroup` cluster
// shapes of mermaid's `rendering-elements/clusters.js`.

///|
/// Whether a cluster shape paints its label as a title above its children.
/// A note group's label is the note's text, which the note inside it
/// paints; a region has none. Mermaid's `clusterPaintsTitle`.
fn cluster_paints_title(shape : String) -> Bool {
  !(shape is ("noteGroup" | "divider"))
}

///|
/// A composite state: a frame with a title strip above its body.
fn rounded_with_title(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> ClusterFrame {
  let shape_svg = parent
    .append("g")
    .attr("class", node.css_classes)
    .attr("id", node.dom_id)
    .attr("data-id", node.id)
    .attr("data-look", node.look)
  stamp_color_slot(shape_svg, node.color_index, env)
  let outer_group = shape_svg.insert_first("g")
  let label = shape_svg.append("g").attr("class", "cluster-label")
  let inner = shape_svg.append("rect")
  // The title is plain text on one line, whatever the label type. The
  // rules of the group's classes reach the `span` of an HTML title.
  let box : LabelBox = if env.html_labels {
    let (fo, box) = create_html_label(
      label,
      node.label,
      env.styled(node.css_compiled_styles.join(";")),
      style=node.label_style,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    box
  } else {
    let text = create_svg_label(
      label,
      node.label,
      env,
      style=node.label_style,
      anchor_middle=false,
    )
    { width: text.text_box.width, height: text.text_box.height, }
  }
  let node_width = node.width.unwrap_or(0.0)
  let node_height = node.height.unwrap_or(0.0)
  let width = if node_width <= box.width + node.padding {
    box.width + node.padding
  } else {
    node_width
  }
  let height = node_height
  let inner_height = node_height - box.height - 6.0
  let x = node.x - width / 2.0
  let y = node.y - height / 2.0
  let inner_y = node.y - node_height / 2.0 + box.height + 2.0
  let outline = outer_group
    .insert_first("rect")
    .attr("class", "outer")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr_number("width", width)
    .attr_number("height", height)
    .attr("data-look", node.look)
  inner
  .attr("class", "inner")
  .attr_number("x", x)
  .attr_number("y", inner_y)
  .attr_number("width", width)
  .attr_number("height", inner_height)
  |> ignore
  let n = @dom.number
  let label_y = y + 1.0 - (if env.html_labels { 0.0 } else { 3.0 })
  label.attr(
    "transform",
    "translate(\{n(node.x - box.width / 2.0)}, \{n(label_y)})",
  )
  |> ignore
  let diff = if node_width <= box.width + node.padding {
    (width - node_width) / 2.0 - node.padding
  } else {
    -node.padding
  }
  { outline, diff: Some(diff), width: Some(width), }
}

///|
/// The invisible frame that keeps a note beside its state.
fn note_group(parent : @dom.Element, node : Node) -> ClusterFrame {
  let shape_svg = parent
    .append("g")
    .attr("class", "note-cluster")
    .attr("id", node.dom_id)
  let rect = shape_svg.insert_first("rect")
  if node.rx is Some(rx) {
    rect.attr_number("rx", rx) |> ignore
  }
  if node.ry is Some(ry) {
    rect.attr_number("ry", ry) |> ignore
  }
  let width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  rect
  .attr_number("x", node.x - width / 2.0)
  .attr_number("y", node.y - height / 2.0)
  .attr_number("width", width)
  .attr_number("height", height)
  .attr("fill", "none")
  |> ignore
  { outline: rect, diff: None, width: None, }
}

///|
/// One region of a composite state split by `--`.
fn divider(parent : @dom.Element, node : Node, env : Env) -> ClusterFrame {
  let shape_svg = parent
    .append("g")
    .attr("class", node.css_classes)
    .attr("id", node.dom_id)
    .attr("data-look", node.look)
  stamp_color_slot(shape_svg, node.color_index, env)
  let outer_group = shape_svg.insert_first("g")
  let width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  let outline = outer_group
    .insert_first("rect")
    .attr("class", "divider")
    .attr_number("x", node.x - width / 2.0)
    .attr_number("y", node.y - height / 2.0)
    .attr_number("width", width)
    .attr_number("height", height)
    .attr("data-look", node.look)
  { outline, diff: Some(-node.padding), width: Some(width), }
}

///|
/// Draw the frame of a group with the cluster shape it asks for: mermaid's
/// `insertCluster`.
fn insert_cluster_shape(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> ClusterFrame raise LayoutError {
  match node.shape {
    "rect" | "squareRect" | "" => insert_cluster(parent, node, env)
    "roundedWithTitle" => rounded_with_title(parent, node, env)
    "noteGroup" => note_group(parent, node)
    "divider" => divider(parent, node, env)
    "kanbanSection" => kanban_section(parent, node, env)
    "flowGroup" => flow_group(parent, node, env)
    "usecaseSystemBoundary" => usecase_system_boundary(parent, node, env)
    other =>
      raise LayoutError("The \{other} cluster shape is not supported yet.")
  }
}
