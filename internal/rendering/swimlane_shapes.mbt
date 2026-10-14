// The shapes only the swimlane layout uses: lanes
// (`rendering-elements/clusters/swimlane.js`) and the nodes that carry the
// labels of edges (`rendering-elements/shapes/labelRect.ts`).

///|
/// A lane: a title band and a body, side by side when the diagram runs
/// left to right, else stacked: mermaid's `swimlane` cluster shape.
/// `model` is the layout's view of the lane, with where its content begins
/// and the diagram's direction.
fn swimlane_cluster(
  parent : @dom.Element,
  node : Node,
  model : @swimlane_model.Node,
  env : Env,
) -> Unit raise LayoutError {
  if node.look == "handDrawn" {
    raise LayoutError("The hand-drawn look is not supported yet.")
  }
  let theme = env.config.theme()
  let cluster_bkg = theme.text("clusterBkg")
  let lane_stroke = theme.text("clusterBorder")
  let styles = node_styles(node)
  let shape_svg = parent
    .append("g")
    .attr("class", "cluster swimlane " + node.css_classes)
    .attr("id", node.dom_id)
    .attr("data-id", node.id)
    .attr("data-et", "cluster")
    .attr("data-look", node.look)
  stamp_color_slot(shape_svg, node.color_index, env)
  let is_lr = model.direction == Some("LR")
  let label_el = shape_svg
    .append("g")
    .attr("class", "cluster-label swimlane-label")
  let node_width = node.width.unwrap_or(0.0)
  // The lane follows the flowchart's own (deprecated) setting alone, which
  // the configuration leaves out unless the diagram sets it: HTML labels
  // then, whatever the diagram-wide `htmlLabels` says.
  let html_labels = match env.config.get("flowchart.htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
  let (fo, bbox) = if html_labels {
    let (fo, box) = create_html_label(
      label_el,
      node.label,
      env,
      width=node_width,
      style=node.label_style,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    (Some(fo), box)
  } else {
    let text = create_svg_label(
      label_el,
      node.label,
      env,
      width=node_width,
      style=node.label_style,
      anchor_middle=false,
    )
    let box : LabelBox = {
      width: text.text_box.width,
      height: text.text_box.height,
    }
    (None, box)
  }
  let padding = node.padding
  let width = if node_width <= bbox.width + padding {
    bbox.width + padding
  } else {
    node_width
  }
  let height = node.height.unwrap_or(0.0)
  let lane_top = node.y - height / 2.0
  let lane_bottom = node.y + height / 2.0
  let lane_left = node.x - width / 2.0
  let content_top = match model.swimlane_content_top {
    Some(top) => top
    None => lane_top + height / 3.0
  }
  let title_padding_y = if is_lr { 4.0 } else { 0.0 }
  let desired_title_size = bbox.height + 2.0 * title_padding_y
  let n = @dom.number
  // Both rectangles go first in the group: the body before the title.
  let title_rect = shape_svg.insert_first("rect")
  let body_rect = shape_svg.insert_first("rect")
  if is_lr {
    let title_width = @swimlane_model.js_max(
      desired_title_size,
      bbox.height + 2.0 * title_padding_y,
    )
    let body_x = lane_left + title_width
    let body_width = @swimlane_model.js_max(0.0, width - title_width)
    title_rect
    .attr("class", "swimlane-title")
    .attr("style", styles.node_styles)
    .attr_number("x", lane_left)
    .attr_number("y", lane_top)
    .attr_number("width", title_width)
    .attr_number("height", height)
    .attr("fill", cluster_bkg)
    .attr("stroke", lane_stroke)
    |> ignore
    body_rect
    .attr("class", "swimlane-body")
    .attr("style", styles.node_styles)
    .attr_number("x", body_x)
    .attr_number("y", lane_top)
    .attr_number("width", body_width)
    .attr_number("height", height)
    .attr("fill", "none")
    .attr("stroke", lane_stroke)
    |> ignore
    let label_center_x = lane_left + title_width / 2.0
    let label_center_y = node.y
    label_el.attr(
      "transform",
      "translate(\{n(label_center_x)}, \{n(label_center_y)}) rotate(-90) translate(\{n(-bbox.width / 2.0)}, \{n(-bbox.height / 2.0)})",
    )
    |> ignore
  } else {
    let header_max_height = @swimlane_model.js_max(0.0, content_top - lane_top)
    let title_height = @swimlane_model.js_min(
      desired_title_size, header_max_height,
    )
    let body_y = lane_top + title_height
    let content_height = @swimlane_model.js_max(0.0, lane_bottom - body_y)
    let x = node.x - width / 2.0
    title_rect
    .attr("class", "swimlane-title")
    .attr("style", styles.node_styles)
    .attr_number("x", x)
    .attr_number("y", lane_top)
    .attr_number("width", width)
    .attr_number("height", title_height)
    .attr("fill", cluster_bkg)
    .attr("stroke", lane_stroke)
    |> ignore
    body_rect
    .attr("class", "swimlane-body")
    .attr("style", styles.node_styles)
    .attr_number("x", x)
    .attr_number("y", body_y)
    .attr_number("width", width)
    .attr_number("height", content_height)
    .attr("fill", "none")
    .attr("stroke", lane_stroke)
    |> ignore
    let label_x = node.x - bbox.width / 2.0
    let label_y = lane_top + (title_height - bbox.height) / 2.0
    label_el.attr("transform", "translate(\{n(label_x)}, \{n(label_y)})")
    |> ignore
  }
  if styles.label_styles != "" && fo is Some(fo) {
    // `labelEl.select("span")`: the first span of the label.
    for div in fo.child_elements() {
      for span in div.child_elements() {
        if span.tag == "span" {
          span.attr("style", styles.label_styles) |> ignore
          break
        }
      }
    }
  }
  node.width = Some(width)
  node.height = Some(height)
}

///|
/// The label of an edge, drawn as a node of its own: mermaid's `labelRect`.
/// A tiny rectangle stands for the node's outline.
fn label_rect(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  // The group is no `.node`: the stylesheet does not centre SVG text in
  // it, so the text starts at its anchor.
  let labelled = label_helper(parent, node, "label", {
    ..env,
    node_text_centred: false,
  })
  // The node's label style is the first style of its edge, absent when
  // the edge has none.
  if node.label_style == "" {
    labelled.label.remove_attr("style") |> ignore
  }
  let rect = labelled.shape_svg
    .insert_first("rect")
    .attr("width", "0.1")
    .attr("height", "0.1")
  labelled.shape_svg.attr("class", "label edgeLabel") |> ignore
  let n = @dom.number
  let bbox = labelled.bbox
  labelled.label.attr(
    "transform",
    "translate(\{n(-(bbox.width / 2.0) - labelled.offset_x)}, \{n(-(bbox.height / 2.0) - labelled.offset_y)})",
  )
  |> ignore
  update_node_bounds(node, rect)
  node.intersect = Some(point => {
    intersect_rect(
      node.x,
      node.y,
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
      point,
    )
  })
  labelled.shape_svg
}
