// The column of a kanban board: the `kanbanSection` cluster shape of
// mermaid's `rendering-elements/clusters.js`.

///|
/// A column with its title at the top, which the diagram stretches over
/// its items afterwards. The size of the title is recorded on the node.
fn kanban_section(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> Unit raise LayoutError {
  // The frame would be drawn by rough.js with a hachure fill.
  if node.look == "handDrawn" {
    raise LayoutError("The hand-drawn look is not supported yet.")
  }
  let styles = node_styles(node)
  let shape_svg = parent
    .append("g")
    .attr("class", "cluster " + node.css_classes)
    .attr("id", node.dom_id)
    .attr("data-look", node.look)
  let label = shape_svg.append("g").attr("class", "cluster-label ")
  // The title is markdown whatever the label type, and wraps at the
  // width of the column.
  let box : LabelBox = if env.html_labels {
    let (fo, box) = create_html_label(
      label,
      node.label,
      env,
      width?=node.width,
      style=node.label_style,
      markdown=true,
      auto_wrap=true,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    box
  } else {
    let text = create_svg_label(
      label,
      node.label,
      env,
      width?=node.width,
      style=node.label_style,
      markdown=true,
      anchor_middle=false,
      sanitize=false,
    )
    { width: text.text_box.width, height: text.text_box.height, }
  }
  let node_width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  // Sections come without a padding, and a title that is wider than its
  // column does not widen it: `width <= bbox.width + undefined` is never
  // true.
  let width = node_width
  let rect = shape_svg.insert_first("rect").attr("style", styles.node_styles)
  if node.rx is Some(rx) {
    rect.attr_number("rx", rx) |> ignore
  }
  if node.ry is Some(ry) {
    rect.attr_number("ry", ry) |> ignore
  }
  rect
  .attr_number("x", node.x - width / 2.0)
  .attr_number("y", node.y - height / 2.0)
  .attr_number("width", width)
  .attr_number("height", height)
  |> ignore
  let title_top = env.config
    .number("flowchart.subGraphTitleMargin.top")
    .unwrap_or(0.0)
  let n = @dom.number
  label.attr(
    "transform",
    "translate(\{n(node.x - box.width / 2.0)}, \{n(node.y - height / 2.0 + title_top)})",
  )
  |> ignore
  if styles.label_styles != "" {
    // `labelEl.select('span')`: the first one below the title.
    if label.descendants(["span"]) is [span, ..] {
      span.attr("style", styles.label_styles) |> ignore
    }
  }
  node.label_box = Some((box.width, box.height))
  let frame = rect.bbox()
  node.width = Some(frame.width)
  node.height = Some(frame.height)
  node.intersect = Some(point => {
    intersect_rect(
      node.x,
      node.y,
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
      point,
    )
  })
}
