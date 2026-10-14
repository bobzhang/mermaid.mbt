// The frame of an agentflow container: the `flowGroup` cluster shape of
// mermaid's `rendering-elements/clusters.js`, which draws it through
// `createContainerGroup`.

///|
/// The stroke of agentflow containers, expanded or collapsed.
fn flow_container_stroke(env : Env) -> String {
  let theme = env.config.theme()
  match theme.get("flowContainerStroke") {
    String(stroke) if stroke != "" => stroke
    _ => theme.text("secondaryBorderColor")
  }
}

///|
/// An expanded agentflow container: an unfilled rounded frame with its
/// title at the top.
fn flow_group(parent : @dom.Element, node : Node, env : Env) -> Unit {
  let styles = node_styles(node)
  let shape_svg = parent
    .append("g")
    .attr("class", "cluster flow-cluster " + node.css_classes)
    .attr("id", node.dom_id)
    .attr("data-look", node.look)
  stamp_color_slot(shape_svg, node.color_index, env)
  let label = shape_svg.append("g").attr("class", "cluster-label")
  let has_label = node.label.trim() != ""
  let markdown = node.label_type == "markdown"
  let mut fo = None
  let box : LabelBox = if !has_label {
    { width: 0.0, height: 0.0, }
  } else if env.html_labels {
    let (element, box) = create_html_label(
      label,
      node.label,
      env,
      width?=if markdown { node.width } else { None },
      style=node.label_style,
      markdown~,
    )
    element.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    fo = Some(element)
    box
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
    { width: text.text_box.width, height: text.text_box.height, }
  }
  let node_width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  let width = if node_width <= box.width + node.padding {
    box.width + node.padding
  } else {
    node_width
  }
  let stroke = flow_container_stroke(env)
  shape_svg
  .insert_first("rect")
  .attr("rx", "10")
  .attr("ry", "10")
  .attr_number("x", node.x - width / 2.0)
  .attr_number("y", node.y - height / 2.0)
  .attr_number("width", width)
  .attr_number("height", height)
  .attr("fill", "none")
  .attr("stroke", stroke)
  .attr("stroke-width", "0.75px")
  |> ignore
  guard has_label else { return }
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
