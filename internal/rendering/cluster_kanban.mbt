// The column of a kanban board: the `kanbanSection` cluster shape of
// mermaid's `rendering-elements/clusters.js`.

///|
/// A column with its title at the top, which the diagram stretches over
/// its items afterwards. The size of the title is recorded on the node.
fn kanban_section(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> ClusterFrame raise LayoutError {
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
  let height = node.height.unwrap_or(0.0)
  // Sections come without a padding, and a title that is wider than its
  // column does not widen it: `width <= bbox.width + undefined` is never
  // true.
  let width = node.width.unwrap_or(0.0)
  let x = node.x - width / 2.0
  let y = node.y - height / 2.0
  let frame = if node.look == "handDrawn" {
    let rough = @rough.path(
      rounded_rect_path(x, y, width, height, node.rx.unwrap_or(0.0)),
      kanban_section_rough_options(node, env),
    )
    prepend(shape_svg, rough)
    // The strokes take the node's border styles, the fill its background.
    let (border, background) = border_and_background(node)
    let paths = rough.child_elements()
    if paths.get(1) is Some(path) {
      path.attr("style", border) |> ignore
    }
    if paths.get(0) is Some(path) {
      path.attr("style", background.replace(old="fill", new="stroke")) |> ignore
    }
    rough
  } else {
    let rect = shape_svg.insert_first("rect").attr("style", styles.node_styles)
    if node.rx is Some(rx) {
      rect.attr_number("rx", rx) |> ignore
    }
    if node.ry is Some(ry) {
      rect.attr_number("ry", ry) |> ignore
    }
    rect
    .attr_number("x", x)
    .attr_number("y", y)
    .attr_number("width", width)
    .attr_number("height", height)
  }
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
  let frame_box = frame.bbox()
  node.width = Some(frame_box.width)
  node.height = Some(frame_box.height)
  node.intersect = Some(point => {
    intersect_rect(
      node.x,
      node.y,
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
      point,
    )
  })
  // Without a padding, upstream's `diff` is not a number; no layout
  // reads it.
  { outline: frame, diff: None, width: Some(frame_box.width), }
}

///|
/// The declarations of a node's styles for its border (those of a stroke)
/// and for its background (`fill`), as `styles2String` sorts them.
fn border_and_background(node : Node) -> (String, String) {
  let map = styles_map([..node.css_compiled_styles, ..node.css_styles])
  let border = []
  let background = []
  for key, value in map {
    guard !is_label_style(key) else { continue }
    if key.contains("stroke") {
      border.push("\{key}:\{value} !important")
    }
    if key == "fill" {
      background.push("\{key}:\{value} !important")
    }
  }
  (border.join(";"), background.join(";"))
}

///|
/// A rectangle with rounded corners as path data: mermaid's
/// `createRoundedRectPathD`.
fn rounded_rect_path(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
) -> String {
  let n = @dom.number
  let arc = (to_x : Double, to_y : Double) => {
    "A \{n(radius)} \{n(radius)} 0 0 1 \{n(to_x)} \{n(to_y)}"
  }
  [
    "M \{n(x + radius)} \{n(y)}",
    "H \{n(x + width - radius)}",
    arc(x + width, y + radius),
    "V \{n(y + height - radius)}",
    arc(x + width - radius, y + height),
    "H \{n(x + radius)}",
    arc(x, y + height - radius),
    "V \{n(y + radius)}",
    arc(x + radius, y),
    "Z",
  ].join(" ")
}

///|
/// How rough.js draws a column of the hand-drawn look: mermaid's
/// `userNodeOverrides` with a hachure fill in the colours of clusters.
fn kanban_section_rough_options(node : Node, env : Env) -> @rough.Options {
  let theme = env.config.theme()
  let map = styles_map([..node.css_compiled_styles, ..node.css_styles])
  let options = @rough.Options::new()
  options.roughness = 0.7
  options.fill = theme.text("clusterBkg")
  options.fill_style = "hachure"
  options.fill_weight = 4.0
  options.hachure_gap = 1.5
  options.stroke = theme.text("clusterBorder")
  options.seed = env.config.number("handDrawnSeed").unwrap_or(0.0).to_int()
  options.stroke_width = match map.get("stroke-width") {
    Some(width) if width.replace(old="px", new="") != "" =>
      width.replace(old="px", new="")
    _ => "1.3"
  }
  options.fill_line_dash = Some([0.0, 0.0])
  options.stroke_line_dash = Some(
    stroke_dash_array(map.get("stroke-dasharray")),
  )
  options
}
