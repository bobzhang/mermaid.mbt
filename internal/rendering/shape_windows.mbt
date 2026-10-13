// Shapes that picture a thing: folder, bucket, browser and console
// windows, cloud and bang. Outside the hand-drawn look they are plain
// SVG elements, not rough.js drawings.

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
/// An open container that narrows to a curved base, with an elliptical
/// rim.
fn bucket(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let accent = accent_colour(env)
  let padding = node.padding
  let w = (box.width + padding * 2.0).max(node.width.unwrap_or(0.0)).max(80.0)
  let rim_ry = (w * 0.08).min(12.0).max(5.0)
  let total_height = (box.height + padding * 2.0 + rim_ry).max(
    node.height.unwrap_or(0.0),
  )
  let top_y = -total_height / 2.0 + rim_ry
  let bottom_y = total_height / 2.0
  let bottom_w = w * 0.72
  let n = @dom.number
  let body = [
    "M\{n(-w / 2.0)},\{n(top_y)}",
    "L\{n(-bottom_w / 2.0)},\{n(bottom_y)}",
    "A\{n(bottom_w / 2.0)},\{n(rim_ry)} 0 0 0 \{n(bottom_w / 2.0)},\{n(bottom_y)}",
    "L\{n(w / 2.0)},\{n(top_y)}",
    "A\{n(w / 2.0)},\{n(rim_ry)} 0 0 0 \{n(-w / 2.0)},\{n(top_y)}",
    "Z",
  ].join(" ")
  let group = labelled.shape_svg
    .insert_first("g")
    .attr("class", "basic label-container")
  group.append("path").attr("d", body).attr("style", styles.node_styles)
  |> ignore
  group
  .append("ellipse")
  .attr("cx", "0")
  .attr_number("cy", top_y)
  .attr_number("rx", w / 2.0)
  .attr_number("ry", rim_ry)
  .attr("style", "fill:none;stroke:\{accent};stroke-width:1px")
  |> ignore
  update_node_bounds(node, group)
  let body_centre = top_y + (bottom_y - top_y) / 2.0
  place_label(labelled, -(box.width / 2.0), body_centre - box.height / 2.0)
  // Edges stop at the upper half of the rim, the sides and the lower half
  // of the base.
  let segments = 12
  let pi = 3.141592653589793
  let arc = (rx : Double, cy : Double, y_sign : Double) => {
    let points = []
    for i in 0..<=segments {
      let theta = pi - i.to_double() * pi / segments.to_double()
      points.push({
        x: rx * @jsmath.cos(theta),
        y: cy + y_sign * rim_ry * @jsmath.sin(theta),
      })
    }
    points
  }
  let base = arc(bottom_w / 2.0, bottom_y, 1.0)
  base.rev_in_place()
  let outline = [..arc(w / 2.0, top_y, -1.0), ..base]
  node.intersect = Some(point => intersect_polygon(node, outline, point))
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

///|
/// A cloud: arcs around the label.
fn cloud(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let half_padding = node.padding / 2.0
  let w = box.width + 2.0 * half_padding
  let h = box.height + 2.0 * half_padding
  let r1 = 0.15 * w
  let r2 = 0.25 * w
  let r3 = 0.35 * w
  let r4 = 0.2 * w
  let n = @dom.number
  // The line breaks and indentation are upstream's.
  let path = "M0 0 \n" +
    "    a\{n(r1)},\{n(r1)} 0 0,1 \{n(w * 0.25)},\{n(-1.0 * w * 0.1)}\n" +
    "    a\{n(r3)},\{n(r3)} 1 0,1 \{n(w * 0.4)},\{n(-1.0 * w * 0.1)}\n" +
    "    a\{n(r2)},\{n(r2)} 1 0,1 \{n(w * 0.35)},\{n(w * 0.2)}\n\n" +
    "    a\{n(r1)},\{n(r1)} 1 0,1 \{n(w * 0.15)},\{n(h * 0.35)}\n" +
    "    a\{n(r4)},\{n(r4)} 1 0,1 \{n(-1.0 * w * 0.15)},\{n(h * 0.65)}\n\n" +
    "    a\{n(r2)},\{n(r1)} 1 0,1 \{n(-1.0 * w * 0.25)},\{n(w * 0.15)}\n" +
    "    a\{n(r3)},\{n(r3)} 1 0,1 \{n(-1.0 * w * 0.5)},0\n" +
    "    a\{n(r1)},\{n(r1)} 1 0,1 \{n(-1.0 * w * 0.25)},\{n(-1.0 * w * 0.15)}\n\n" +
    "    a\{n(r1)},\{n(r1)} 1 0,1 \{n(-1.0 * w * 0.1)},\{n(-1.0 * h * 0.35)}\n" +
    "    a\{n(r4)},\{n(r4)} 1 0,1 \{n(w * 0.1)},\{n(-1.0 * h * 0.65)}\n" +
    "  H0 V0 Z"
  let element = labelled.shape_svg
    .insert_first("path")
    .attr("class", "basic label-container")
    .attr("style", styles.node_styles)
    .attr("d", path)
  place_label_at(labelled, -box.width / 2.0, -box.height / 2.0)
  element.attr("transform", "translate(\{n(-w / 2.0)}, \{n(-h / 2.0)})")
  |> ignore
  update_node_bounds(node, element)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}

///|
/// A bang: a burst of arcs around the label.
fn bang(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let half_padding = node.padding / 2.0
  let w = box.width + 10.0 * half_padding
  let h = box.height + 8.0 * half_padding
  let r = 0.15 * w
  let ew = w.max(box.width + 20.0)
  let eh = h.max(box.height + 20.0)
  place_label_at(labelled, -box.width / 2.0, -box.height / 2.0)
  let n = @dom.number
  let arc = "    a\{n(r)},\{n(r)} 1 0,0 "
  let small_arc = "    a\{n(r * 0.8)},\{n(r * 0.8)} 1 0,0 "
  // The line breaks and indentation are upstream's.
  let path = "M0 0 \n" +
    "\{arc}\{n(ew * 0.25)},\{n(-1.0 * eh * 0.1)}\n" +
    "\{arc}\{n(ew * 0.25)},0\n" +
    "\{arc}\{n(ew * 0.25)},0\n" +
    "\{arc}\{n(ew * 0.25)},\{n(eh * 0.1)}\n\n" +
    "\{arc}\{n(ew * 0.15)},\{n(eh * 0.33)}\n" +
    "\{small_arc}0,\{n(eh * 0.34)}\n" +
    "\{arc}\{n(-1.0 * ew * 0.15)},\{n(eh * 0.33)}\n\n" +
    "\{arc}\{n(-1.0 * ew * 0.25)},\{n(eh * 0.15)}\n" +
    "\{arc}\{n(-1.0 * ew * 0.25)},0\n" +
    "\{arc}\{n(-1.0 * ew * 0.25)},0\n" +
    "\{arc}\{n(-1.0 * ew * 0.25)},\{n(-1.0 * eh * 0.15)}\n\n" +
    "\{arc}\{n(-1.0 * ew * 0.1)},\{n(-1.0 * eh * 0.33)}\n" +
    "\{small_arc}0,\{n(-1.0 * eh * 0.34)}\n" +
    "\{arc}\{n(ew * 0.1)},\{n(-1.0 * eh * 0.33)}\n" +
    "  H0 V0 Z"
  let element = labelled.shape_svg
    .insert_first("path")
    .attr("class", "basic label-container")
    .attr("style", styles.node_styles)
    .attr("d", path)
    .attr("transform", "translate(\{n(-ew / 2.0)}, \{n(-eh / 2.0)})")
  update_node_bounds(node, element)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}
