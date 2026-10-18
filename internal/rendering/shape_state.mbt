// The shape of a state that has a description under its name: mermaid's
// `rendering-elements/shapes/rectWithTitle.ts`.

///|
/// The box of the first line of a label drawn as SVG text, the way
/// `getBoundingClientRect()` reports its `<tspan>`: the cells of its
/// items, from the ascent above the baseline to the descent below.
fn first_line_box(text : String, env : Env) -> LabelBox {
  let lines = non_markdown_to_lines(
    @dom.sanitized_text(@dom.placeholders_to_references(text)),
  )
  guard lines is [line, ..] else { return { width: 0.0, height: 0.0, } }
  let size = env.font_size
  let f = Float::from_double
  let baseline = em_to_px(-0.1, size) + em_to_px(1.1, size)
  let items = line_items_text(line)
  let widths = item_widths(items, env)
  let mut box : BoxF = { x: 0, y: 0, width: 0, height: 0, }
  let mut x = 0.0
  for k, item in items {
    let font = env.font(bold=item.bold, italic=item.italic)
    let (ascent, descent) = font.line_metrics(size)
    box = box.unite(
      BoxF::from_edges(
        f(x),
        baseline - f(ascent),
        f(x + widths[k]),
        baseline + f(descent),
      ),
    )
    x += widths[k]
  }
  { width: box.width.to_double(), height: box.height.to_double(), }
}

///|
/// A label of the shape: its element and the box upstream reads off it.
/// For HTML that is the `foreignObject` and the box of its `div`; for SVG
/// text the `<text>` and its own box.
fn title_label(
  label : @dom.Element,
  text : String,
  node : Node,
  env : Env,
) -> (@dom.Element, LabelBox) raise LayoutError {
  if env.html_labels {
    let (fo, box) = create_html_label(label, text, env, style=node.label_style)
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    return (fo, box)
  }
  let created = create_svg_label(
    label,
    text,
    env,
    style=node.label_style,
    anchor_middle=false,
    is_title=true,
  )
  let element = match created.group.child_elements() {
    [_, element, ..] => element
    _ => created.group
  }
  (element, { width: created.text_box.width, height: created.text_box.height, })
}

///|
/// A rectangle with a title, a line under it, and the description below.
fn rect_with_title(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
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
  let (title, title_box) = title_label(label, node.label, node, env)
  let description = node.description.join("<br/>")
  let (rows, rows_box) = title_label(label, description, node, env)
  // Upstream sizes the description by its first child whatever the kind
  // of label: for SVG text that is the first line alone.
  let rows_box = if env.html_labels {
    rows_box
  } else {
    let box = first_line_box(
      description,
      env.styled(node.label_style, faces=false),
    )
    rows.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    box
  }
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
  if hand_drawn(node) {
    let line_y = -box.height / 2.0 -
      half_padding +
      title_box.height +
      half_padding
    let rect = sketched_rect_with_title(
      shape_svg,
      node,
      env,
      x,
      y,
      box.width + node.padding,
      box.height + node.padding,
      -box.width / 2.0 - half_padding,
      box.width / 2.0 + half_padding,
      line_y,
    )
    update_node_bounds(node, rect)
    node.intersect = Some(node_intersect_rect(node))
    return shape_svg
  }
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
