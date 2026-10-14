// The shape of a state that has a description under its name: mermaid's
// `rendering-elements/shapes/rectWithTitle.ts`.

///|
/// A rectangle with a title, a line under it, and the description below.
fn rect_with_title(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  if !env.html_labels {
    raise LayoutError(
      "States with descriptions are not supported with htmlLabels: false yet.",
    )
  }
  let styles = shape_styles(node)
  let classes = if node.css_classes == "" {
    "node default"
  } else {
    "node \{node.css_classes}"
  }
  let shape_svg = parent
    .append("g")
    .attr("class", classes)
    .attr("id", node.dom_id)
  let frame = shape_svg.append("g")
  let label = shape_svg
    .append("g")
    .attr("class", "label")
    .attr("style", styles.node_styles)
  let (title, title_box) = create_html_label(
    label,
    node.label,
    env,
    style=node.label_style,
  )
  title
  .attr_number("width", title_box.width)
  .attr_number("height", title_box.height)
  |> ignore
  let (rows, rows_box) = create_html_label(
    label,
    node.description.join("<br/>"),
    env,
    style=node.label_style,
  )
  rows
  .attr_number("width", rows_box.width)
  .attr_number("height", rows_box.height)
  |> ignore
  let half_padding = node.padding / 2.0
  let n = @dom.number
  let rows_x = if rows_box.width > title_box.width {
    0.0
  } else {
    (title_box.width - rows_box.width) / 2.0
  }
  rows.attr(
    "transform",
    "translate( \{n(rows_x)}, \{n(title_box.height + half_padding + 5.0)})",
  )
  |> ignore
  let title_x = if rows_box.width < title_box.width {
    0.0
  } else {
    -(title_box.width - rows_box.width) / 2.0
  }
  title.attr("transform", "translate( \{n(title_x)}, 0)") |> ignore
  // Title and description together.
  let box = label.bbox()
  label.attr(
    "transform",
    "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0 - half_padding + 3.0)})",
  )
  |> ignore
  let x = -box.width / 2.0 - half_padding
  let y = -box.height / 2.0 - half_padding
  let rect = frame
    .insert_first("rect")
    .attr("class", "outer title-state")
    .attr("style", styles.node_styles)
    .attr_number("x", x)
    .attr_number("y", y)
    .attr_number("width", box.width + node.padding)
    .attr_number("height", box.height + node.padding)
  let line_y = -box.height / 2.0 -
    half_padding +
    title_box.height +
    half_padding
  frame
  .append("line")
  .attr("class", "divider")
  .attr_number("x1", -box.width / 2.0 - half_padding)
  .attr_number("x2", box.width / 2.0 + half_padding)
  .attr_number("y1", line_y)
  .attr_number("y2", line_y)
  |> ignore
  update_node_bounds(node, rect)
  node.intersect = Some(node_intersect_rect(node))
  shape_svg
}
