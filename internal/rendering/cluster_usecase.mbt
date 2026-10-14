// The frame of a system boundary in a use case diagram: mermaid's
// `usecaseSystemBoundary` cluster shape.

///|
/// A system boundary: a rectangle, with a tab holding the title for the
/// `tabbed` kind; otherwise the title sits at the top of the frame.
fn usecase_system_boundary(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> Unit {
  let boundary_type = match node.data {
    Usecase(boundary_type~, ..) if boundary_type != "" => boundary_type
    _ => "rect"
  }
  let styles = node_styles(node)
  let styles_map = styles_map([..node.css_compiled_styles, ..node.css_styles])
  ignore(styles_map)
  let shape_svg = parent
    .append("g")
    .attr(
      "class",
      "cluster usecase-system-boundary usecase-system-boundary-\{boundary_type} \{node.css_classes}",
    )
    .attr("id", node.dom_id)
    .attr("data-boundary-type", boundary_type)
    .attr("data-look", node.look)
  stamp_color_slot(shape_svg, node.color_index, env)
  let label = shape_svg
    .append("g")
    .attr("class", "cluster-label system-boundary-title")
  // The title is markdown and wraps at `createText`'s default width,
  // whatever it was measured at before the layout.
  let (fo, box) = if env.html_labels {
    let (fo, box) = create_html_label(
      label,
      node.label,
      env,
      width=200.0,
      style=styles.label_styles,
      markdown=true,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    (Some(fo), box)
  } else {
    let text = create_svg_label(
      label,
      node.label,
      env,
      width=200.0,
      style=styles.label_styles,
      markdown=true,
      anchor_middle=false,
    )
    let box : LabelBox = {
      width: text.text_box.width,
      height: text.text_box.height,
    }
    (None, box)
  }
  let node_width = node.width.unwrap_or(0.0)
  let node_height = node.height.unwrap_or(0.0)
  let tabbed = boundary_type == "package"
  let horizontal_label_padding = if tabbed { 20.0 } else { node.padding }
  let tab_height = if tabbed { box.height + 10.0 } else { 0.0 }
  let width = node_width.max(box.width + horizontal_label_padding)
  let height = if tabbed {
    node_height.max(tab_height + node.padding * 2.0)
  } else {
    node_height
  }
  let x = node.x - width / 2.0
  let y = node.y - height / 2.0
  let body_y = y + tab_height
  let body_height = height - tab_height
  let tab_width = if tabbed {
    width.min(80.0.max(box.width + 20.0))
  } else {
    0.0
  }
  shape_svg
  .insert_first("rect")
  .attr("class", "boundary-body label-container")
  .attr("style", styles.node_styles)
  .attr_number("x", x)
  .attr_number("y", body_y)
  .attr_number("width", width)
  .attr_number("height", body_height)
  |> ignore
  if tabbed {
    shape_svg
    .insert_first("rect")
    .attr("class", "boundary-tab system-boundary-package-tab label-container")
    .attr("style", styles.node_styles)
    .attr_number("x", x)
    .attr_number("y", y)
    .attr_number("width", tab_width)
    .attr_number("height", tab_height)
    |> ignore
  }
  let n = @dom.number
  if tabbed {
    label.attr(
      "transform",
      "translate(\{n(x + (tab_width - box.width) / 2.0)}, \{n(y + (tab_height - box.height) / 2.0)})",
    )
    |> ignore
  } else {
    let title_top = env.config
      .number("flowchart.subGraphTitleMargin.top")
      .unwrap_or(0.0)
    label.attr(
      "transform",
      "translate(\{n(node.x - box.width / 2.0)}, \{n(y + title_top)})",
    )
    |> ignore
  }
  if styles.label_styles != "" {
    label.attr("style", styles.label_styles) |> ignore
    if fo is Some(fo) {
      // `labelEl.select("span")`: the first span inside.
      match fo.descendants(["span"]) {
        [span, ..] => span.attr("style", styles.label_styles) |> ignore
        [] => ()
      }
    }
  }
  node.width = Some(width)
  node.height = Some(height)
  node.label_box = Some((box.width, box.height))
}
