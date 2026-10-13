// Shapes that picture a thing: folder, browser and console windows.
// Outside the hand-drawn look they are plain SVG elements, not rough.js
// drawings.

///|
/// The colour of the details these shapes add to their outline.
fn accent_colour(env : Env) -> String {
  let theme = env.config.theme()
  match (theme.get("nodeBorder"), theme.get("lineColor")) {
    (String(colour), _) | (_, String(colour)) => colour
    _ => "currentColor"
  }
}

///|
/// A rectangle with a tab on the left of its top edge.
fn folder(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let padding = node.padding
  let w = (box.width + padding * 2.0).max(node.width.unwrap_or(0.0)).max(90.0)
  let content_height = box.height + padding * 2.0
  let tab_height = (content_height * 0.16).min(14.0).max(8.0)
  let total_height = (content_height + tab_height).max(
    node.height.unwrap_or(0.0),
  )
  let body_height = total_height - tab_height
  let tab_width = (w * 0.38).max(28.0)
  let top = -total_height / 2.0
  let points = [
    { x: -w / 2.0, y: top, },
    { x: -w / 2.0 + tab_width, y: top, },
    { x: -w / 2.0 + tab_width, y: top + tab_height, },
    { x: w / 2.0, y: top + tab_height, },
    { x: w / 2.0, y: total_height / 2.0, },
    { x: -w / 2.0, y: total_height / 2.0, },
  ]
  labelled.shape_svg
  .insert_first("path")
  .attr("d", path_from_points(points))
  .attr("class", "basic label-container")
  .attr("style", styles.node_styles)
  |> ignore
  // The outline is exactly as large as it was made.
  node.width = Some(w)
  node.height = Some(total_height)
  let body_centre = top + tab_height + body_height / 2.0
  place_label(labelled, -(box.width / 2.0), body_centre - box.height / 2.0)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// The rounded frame of a window, `band` taller than its content.
fn window_frame(
  labelled : Labelled,
  node : Node,
  styles : SplitStyles,
  band : Double,
) -> (@dom.Element, Double, Double) {
  let padding = node.padding
  let radius = 12.0
  let w = (labelled.bbox.width + padding * 2.0)
    .max(node.width.unwrap_or(0.0))
    .max(90.0)
  let h = (labelled.bbox.height + padding * 2.0 + band).max(
    node.height.unwrap_or(0.0),
  )
  let group = labelled.shape_svg
    .insert_first("g")
    .attr("class", "basic label-container")
  group
  .append("rect")
  .attr_number("x", -w / 2.0)
  .attr_number("y", -h / 2.0)
  .attr_number("width", w)
  .attr_number("height", h)
  .attr_number("rx", radius)
  .attr_number("ry", radius)
  .attr("style", styles.node_styles)
  |> ignore
  (group, w, h)
}

///|
/// Finish a window: measure it and centre the label below the band.
fn finish_window(
  labelled : Labelled,
  node : Node,
  group : @dom.Element,
  h : Double,
  band : Double,
) -> @dom.Element {
  update_node_bounds(node, group)
  let body_centre = -h / 2.0 + band + (h - band) / 2.0
  place_label(
    labelled,
    -(labelled.bbox.width / 2.0),
    body_centre - labelled.bbox.height / 2.0,
  )
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}

///|
/// A browser window: a bar with three dots and an address field.
fn browser(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let accent = accent_colour(env)
  let bar_height = 18.0
  let (group, w, h) = window_frame(labelled, node, styles, bar_height)
  let top = -h / 2.0
  group
  .append("line")
  .attr_number("x1", -w / 2.0)
  .attr_number("y1", top + bar_height)
  .attr_number("x2", w / 2.0)
  .attr_number("y2", top + bar_height)
  .attr("style", "stroke:\{accent};stroke-width:1px")
  |> ignore
  for i in 0..<3 {
    group
    .append("circle")
    .attr_number("cx", -w / 2.0 + 12.0 + i.to_double() * 9.0)
    .attr_number("cy", top + bar_height / 2.0)
    .attr("r", "2.5")
    .attr("style", "fill:\{accent};stroke:none")
    |> ignore
  }
  group
  .append("rect")
  .attr("class", "browser-address-bar")
  .attr_number("x", -w / 2.0 + 44.0)
  .attr_number("y", top + 4.0)
  .attr_number("width", (w - 56.0).max(10.0))
  .attr_number("height", bar_height - 8.0)
  .attr("rx", "3")
  .attr("ry", "3")
  .attr("style", "fill:none;stroke:\{accent};stroke-width:1px;opacity:0.6")
  |> ignore
  finish_window(labelled, node, group, h, bar_height)
}

///|
/// A terminal window: a prompt in its top left corner.
fn console_window(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let accent = accent_colour(env)
  let glyph_band = 20.0
  let (group, w, h) = window_frame(labelled, node, styles, glyph_band)
  // The prompt is not measured: it lies well inside the frame, which is at
  // least 90 wide and taller than the band, so the window's box is the
  // frame's whatever the monospace font is.
  group
  .append("text")
  .attr_number("x", -w / 2.0 + 12.0)
  .attr_number("y", -h / 2.0 + 16.0)
  .attr("class", "console-glyph")
  .attr(
    "style",
    "font-family:monospace;font-weight:bold;font-size:14px;fill:\{accent}",
  )
  .text(">_")
  |> ignore
  finish_window(labelled, node, group, h, glyph_band)
}
