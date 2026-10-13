// Drawing the frames of groups: mermaid's `rendering-elements/clusters.js`.

///|
/// Mark an element with its slot in the theme's palette.
fn stamp_color_slot(
  element : @dom.Element,
  color_index : Int32?,
  env : Env,
) -> Unit {
  guard color_index is Some(index) else { return }
  guard env.config.text("theme") is Some("redux-color" | "redux-dark-color") else {
    return
  }
  guard env.config.theme().get("borderColorArray") is Array(palette) &&
    !palette.is_empty() else {
    return
  }
  element.attr("data-color-id", "color-\{index % palette.length()}") |> ignore
}

///|
/// The frame of a subgraph with its title: the `rect` cluster shape.
fn insert_cluster(parent : @dom.Element, node : Node, env : Env) -> Unit {
  let styles = node_styles(node)
  let shape_svg = parent
    .append("g")
    .attr("class", "cluster " + node.css_classes)
    .attr("id", node.dom_id)
    .attr("data-look", node.look)
  stamp_color_slot(shape_svg, node.color_index, env)
  let label = shape_svg.append("g").attr("class", "cluster-label ")
  let markdown = node.label_type == "markdown"
  let (fo, box) = if env.html_labels {
    let (fo, box) = create_html_label(
      label,
      node.label,
      env,
      width?=if markdown { node.width } else { None },
      style=node.label_style,
      markdown~,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    (Some(fo), box)
  } else {
    let text = create_svg_label(
      label,
      node.label,
      env,
      width?=if markdown { node.width } else { None },
      style=node.label_style,
      markdown~,
      anchor_middle=false,
    )
    let box : LabelBox = {
      width: text.text_box.width,
      height: text.text_box.height,
    }
    (None, box)
  }
  let node_width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  let width = if node_width <= box.width + node.padding {
    box.width + node.padding
  } else {
    node_width
  }
  shape_svg
  .insert_first("rect")
  .attr("style", styles.node_styles)
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
  if styles.label_styles != "" && fo is Some(fo) {
    for span in fo.child_elements() {
      for inner in span.child_elements() {
        if inner.tag == "span" {
          inner.attr("style", styles.label_styles) |> ignore
        }
      }
    }
  }
}
