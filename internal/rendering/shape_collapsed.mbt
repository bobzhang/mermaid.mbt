// A container drawn folded into one node: mermaid's
// `shapes/collapsedGroup.ts`.

///|
/// The rows below the title of a collapsed container.
const COLLAPSED_INDICATOR_ROW_HEIGHT : Double = 20.0

///|
const COLLAPSED_SEPARATOR_GAP : Double = 8.0

///|
const COLLAPSED_MIN_WIDTH : Double = 80.0

///|
/// A collapsed container: its title, a dashed separator and three dots.
/// An agentflow `flow` keeps the look of its expanded frame.
fn collapsed_group(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let container_type = match node.data {
    Container(metadata~) =>
      match metadata.get("containerType") {
        Some(String(kind)) => Some(kind)
        _ => None
      }
    _ => None
  }
  let theme = env.config.theme()
  let (radius, fill, stroke, stroke_width, css_class) = match container_type {
    Some("flow") =>
      (
        "10",
        "none",
        flow_container_stroke(env),
        Some("0.75px"),
        "flow-collapsed",
      )
    _ =>
      (
        "8",
        theme.text("clusterBkg"),
        theme.text("clusterBorder"),
        None,
        "collapsed-group",
      )
  }
  let styles = node_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let shape_svg = labelled.shape_svg
  stamp_color_slot(shape_svg, node.color_index, env)
  let box = labelled.bbox
  let padding = node.padding
  let title_height = box.height
  let total_width = (box.width + padding * 2.0)
    .max(COLLAPSED_MIN_WIDTH)
    .max(node.width.unwrap_or(0.0))
  let total_height = (title_height +
  COLLAPSED_SEPARATOR_GAP +
  COLLAPSED_INDICATOR_ROW_HEIGHT +
  padding * 2.0).max(node.height.unwrap_or(0.0))
  let x = -total_width / 2.0
  let y = -total_height / 2.0
  let label_shift_y = -(COLLAPSED_SEPARATOR_GAP + COLLAPSED_INDICATOR_ROW_HEIGHT) /
    2.0
  let n = @dom.number
  let html_labels = match env.config.get("htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
  let shift_x = if html_labels { n(-box.width / 2.0) } else { "0" }
  labelled.label.attr(
    "transform",
    "translate(\{shift_x}, \{n(-box.height / 2.0 + label_shift_y)})",
  )
  |> ignore
  let rect = if hand_drawn(node) {
    sketched_collapsed_frame(
      shape_svg,
      node,
      env,
      x,
      y,
      total_width,
      total_height,
      @string.parse_double(radius) catch {
        _ => 0.0
      },
      fill,
      stroke,
      stroke_width.map(width => width.replace(old="px", new="")),
      css_class,
    )
  } else {
    let rect = shape_svg
      .insert_first("rect")
      .attr("class", "basic label-container " + css_class)
      .attr("style", styles.node_styles)
      .attr("rx", radius)
      .attr("ry", radius)
      .attr_number("x", x)
      .attr_number("y", y)
      .attr_number("width", total_width)
      .attr_number("height", total_height)
      .attr("fill", fill)
      .attr("stroke", stroke)
    if stroke_width is Some(width) {
      rect.attr("stroke-width", width) |> ignore
    }
    rect
  }
  let separator_y = y + padding + title_height + COLLAPSED_SEPARATOR_GAP
  shape_svg
  .append("line")
  .attr("class", "collapsed-separator")
  .attr_number("x1", x + 8.0)
  .attr_number("y1", separator_y)
  .attr_number("x2", x + total_width - 8.0)
  .attr_number("y2", separator_y)
  .attr("stroke", stroke)
  .attr("stroke-dasharray", "3, 3")
  |> ignore
  let dot_y = separator_y + COLLAPSED_INDICATOR_ROW_HEIGHT / 2.0
  for i in -1..<=1 {
    shape_svg
    .append("circle")
    .attr("class", "collapsed-indicator")
    .attr_number("cx", i.to_double() * 10.0)
    .attr_number("cy", dot_y)
    .attr("r", "2.5")
    .attr("fill", stroke)
    |> ignore
  }
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
  shape_svg
}
