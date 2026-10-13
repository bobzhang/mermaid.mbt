// Shapes built on a rectangle: mermaid's text block, card, lined, divided,
// stacked and tagged rectangles, window pane, data store and note.

///|
/// `size ? size : fallback`: a size the node already has, unless it is
/// zero.
fn size_or(size : Double?, fallback : Double) -> Double {
  match size {
    Some(size) if size != 0.0 && !size.is_nan() => size
    _ => fallback
  }
}

///|
/// Whether the node came with a size of its own: `node.width ||
/// node.height`. Shapes then draw into that size instead of around the
/// label.
fn has_size(node : Node) -> Bool {
  size_or(node.width, 0.0) != 0.0 || size_or(node.height, 0.0) != 0.0
}

///|
/// Mermaid's `intersect.rect` on the node as it is when asked.
fn node_intersect_rect(node : Node) -> (Point) -> Point {
  point => {
    intersect_rect(
      node.x,
      node.y,
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
      point,
    )
  }
}

///|
/// Move the label of a shape to exactly `x`, `y`.
fn place_label_at(labelled : Labelled, x : Double, y : Double) -> Unit {
  let n = @dom.number
  labelled.label.attr("transform", "translate(\{n(x)}, \{n(y)})") |> ignore
}

///|
/// Move the label of a shape so that its box starts at `x`, `y`: most
/// shapes subtract where the label's own box starts, which is the origin
/// for HTML labels and the text's box for SVG ones.
fn place_label(labelled : Labelled, x : Double, y : Double) -> Unit {
  place_label_at(labelled, x - labelled.offset_x, y - labelled.offset_y)
}

///|
/// Text in a rectangle that shows only through the styles it is given.
fn text_block(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let total_width = (labelled.bbox.width + node.padding).max(
    size_or(node.width, 0.0),
  )
  let total_height = (labelled.bbox.height + node.padding).max(
    size_or(node.height, 0.0),
  )
  let rect = labelled.shape_svg
    .insert_first("rect")
    .attr("class", "text")
    .attr("style", styles.node_styles)
    .attr("rx", "0")
    .attr("ry", "0")
    .attr_number("x", -total_width / 2.0)
    .attr_number("y", -total_height / 2.0)
    .attr_number("width", total_width)
    .attr_number("height", total_height)
  update_node_bounds(node, rect)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}

///|
/// A rectangle with its top left corner cut off.
fn card(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let neo = node.look == "neo"
  let notch = 12.0
  polygon_shape(parent, node, env, box => {
    let label_padding_x = if neo { 28.0 } else { node.padding }
    let label_padding_y = if neo { 24.0 } else { node.padding }
    let w = node.width.unwrap_or(box.width) +
      (if neo { label_padding_x * 2.0 } else { label_padding_x + notch })
    let h = node.height.unwrap_or(box.height) +
      (if neo { label_padding_y * 2.0 } else { label_padding_y })
    (
      w,
      h,
      [
        { x: notch, y: -h, },
        { x: w, y: -h, },
        { x: w, y: 0.0, },
        { x: 0.0, y: 0.0, },
        { x: 0.0, y: -h + notch, },
        { x: notch, y: -h, },
      ],
    )
  })
}

///|
/// A rectangle with a second line inside its left edge.
fn shaded_process(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let frame = 8.0
  let padding_x = if neo { 16.0 } else { node.padding }
  let padding_y = if neo { 12.0 } else { node.padding }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let total_width = node.width.unwrap_or(box.width) +
    padding_x * 2.0 +
    (if neo { frame } else { frame * 2.0 })
  let total_height = node.height.unwrap_or(box.height) + padding_y * 2.0
  let w = total_width - frame
  let h = total_height
  let x = frame - total_width / 2.0
  let y = -total_height / 2.0
  let outline = @rough.polygon(
    [
      (x, y),
      (x + w, y),
      (x + w, y + h),
      (x - frame, y + h),
      (x - frame, y),
      (x, y),
      (x, y + h),
    ],
    rough_options(node, env),
  )
  prepend(labelled.shape_svg, outline)
  outline
  .attr("class", "basic label-container outer-path")
  .attr("style", node.css_styles.join(","))
  |> ignore
  // Upstream writes the compiled styles here whether or not there are any.
  for path in outline.descendants(["path"]) {
    path.attr("style", styles.node_styles) |> ignore
  }
  // The label sits in the part right of the line.
  place_label(labelled, frame / 2.0 - box.width / 2.0, -(box.height / 2.0))
  update_node_bounds(node, outline)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}

///|
/// A rectangle with a strip divided off along its top.
fn divided_rectangle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let padding_x = if neo { 16.0 } else { node.padding }
  let padding_y = if neo { 16.0 } else { node.padding }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let w = box.width + padding_x
  let h = box.height + padding_y
  let rect_offset = h * 0.2
  let x = -w / 2.0
  let y = -h / 2.0 - rect_offset / 2.0
  let outline = insert_rough_outline(
    labelled.shape_svg,
    @rough.polygon(
      [
        (x, y + rect_offset),
        (-x, y + rect_offset),
        (-x, -y),
        (x, -y),
        (x, y),
        (-x, y),
        (-x, y + rect_offset),
      ],
      rough_options(node, env),
    ),
    node,
    styles,
  )
  place_label(
    labelled,
    x + node.padding / 2.0,
    y + rect_offset + node.padding / 2.0,
  )
  update_node_bounds(node, outline)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}

///|
/// A rectangle with a strip along its top and one along its left side.
fn window_pane(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let rect_offset = 10.0
  let padding_x = if neo { 16.0 } else { node.padding }
  let padding_y = if neo { 12.0 } else { node.padding }
  if has_size(node) {
    node.width = Some(
      (node.width.unwrap_or(0.0) - padding_x * 2.0 - rect_offset).max(10.0),
    )
    node.height = Some(
      (node.height.unwrap_or(0.0) - padding_y * 2.0 - rect_offset).max(10.0),
    )
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let total_width = size_or(node.width, box.width) +
    padding_x * 2.0 +
    rect_offset
  let total_height = size_or(node.height, box.height) +
    padding_y * 2.0 +
    rect_offset
  let w = total_width - rect_offset
  let h = total_height - rect_offset
  let x = -w / 2.0
  let y = -h / 2.0
  let outer = [
    { x: x - rect_offset, y: y - rect_offset, },
    { x: x - rect_offset, y: y + h, },
    { x: x + w, y: y + h, },
    { x: x + w, y: y - rect_offset, },
  ]
  let n = @dom.number
  let left = n(x - rect_offset)
  let top = n(y - rect_offset)
  let right = n(x + w)
  let bottom = n(y + h)
  let path = "M\{left},\{top} L\{right},\{top} L\{right},\{bottom} L\{left},\{bottom} L\{left},\{top} " +
    "M\{left},\{n(y)} L\{right},\{n(y)} " +
    "M\{n(x)},\{top} L\{n(x)},\{bottom}"
  let outline = @rough.path(path, rough_options(node, env))
  outline.attr(
    "transform",
    "translate(\{n(rect_offset / 2.0)}, \{n(rect_offset / 2.0)})",
  )
  |> ignore
  insert_rough_outline(labelled.shape_svg, outline, node, styles) |> ignore
  place_label(
    labelled,
    -(box.width / 2.0) + rect_offset / 2.0,
    -(box.height / 2.0) + rect_offset / 2.0,
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, outer, point))
  labelled.shape_svg
}

///|
/// One path in place of those rough.js drew, filled like the first that
/// has a fill and stroked like the first that has a stroke: mermaid's
/// `mergePaths`.
fn merge_paths(rough : @dom.Element) -> @dom.Element {
  let paths = rough.child_elements().filter(child => child.tag == "path")
  let group = @dom.Element::new("g")
  let merged = group.append("path")
  merged.attr("d", paths.filter_map(path => path.get_attr("d")).join(" "))
  |> ignore
  let copy = (from : @dom.Element, name : String, fallback : String?) => {
    let value = match from.get_attr(name) {
      Some(value) => Some(value)
      None => fallback
    }
    if value is Some(value) && value != "" {
      merged.attr(name, value) |> ignore
    }
  }
  if paths.search_by(path => path.get_attr("fill") != Some("none"))
    is Some(index) {
    copy(paths[index], "fill", None)
    copy(paths[index], "fill-opacity", Some("1"))
  }
  if paths.search_by(path => path.get_attr("stroke") != Some("none"))
    is Some(index) {
    copy(paths[index], "stroke", None)
    copy(paths[index], "stroke-width", Some("1"))
    copy(paths[index], "stroke-opacity", Some("1"))
  }
  group
}

///|
/// Three rectangles stacked behind one another.
fn multi_rect(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  let rect_offset = if neo { 10.0 } else { 5.0 }
  if has_size(node) {
    node.width = Some(
      (node.width.unwrap_or(0.0) - label_padding_x * 2.0 - 2.0 * rect_offset).max(
        10.0,
      ),
    )
    node.height = Some(
      (node.height.unwrap_or(0.0) - label_padding_y * 2.0 - 2.0 * rect_offset).max(
        10.0,
      ),
    )
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let total_width = size_or(node.width, box.width) +
    label_padding_x * 2.0 +
    2.0 * rect_offset
  let total_height = size_or(node.height, box.height) +
    label_padding_y * 2.0 +
    2.0 * rect_offset
  let w = total_width - 2.0 * rect_offset
  let h = total_height - 2.0 * rect_offset
  let x = -w / 2.0
  let y = -h / 2.0
  let outer = [
    { x: x - rect_offset, y: y + rect_offset, },
    { x: x - rect_offset, y: y + h + rect_offset, },
    { x: x + w - rect_offset, y: y + h + rect_offset, },
    { x: x + w - rect_offset, y: y + h, },
    { x: x + w, y: y + h, },
    { x: x + w, y: y + h - rect_offset, },
    { x: x + w + rect_offset, y: y + h - rect_offset, },
    { x: x + w + rect_offset, y: y - rect_offset, },
    { x: x + rect_offset, y: y - rect_offset, },
    { x: x + rect_offset, y, },
    { x, y, },
    { x, y: y + rect_offset, },
  ]
  let inner = [
    { x, y: y + rect_offset, },
    { x: x + w - rect_offset, y: y + rect_offset, },
    { x: x + w - rect_offset, y: y + h, },
    { x: x + w, y: y + h, },
    { x: x + w, y, },
    { x, y, },
  ]
  let options = rough_options(node, env)
  let stack = labelled.shape_svg.insert_first("g")
  stack.append_child(merge_paths(@rough.path(path_from_points(outer), options)))
  stack.append_child(merge_paths(@rough.path(path_from_points(inner), options)))
  stack.attr("class", "basic label-container outer-path") |> ignore
  style_rough_paths(stack, node, styles)
  place_label(
    labelled,
    -(box.width / 2.0) - rect_offset,
    -(box.height / 2.0) + rect_offset,
  )
  update_node_bounds(node, stack)
  node.intersect = Some(point => intersect_polygon(node, outer, point))
  labelled.shape_svg
}

///|
/// A rectangle with its bottom right corner folded over.
fn tagged_rect(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  // The tag's size relative to the height of the node.
  let tag_ratio = 0.2
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  if has_size(node) {
    let height = (node.height.unwrap_or(0.0) - label_padding_y * 2.0).max(10.0)
    node.height = Some(height)
    node.width = Some(
      (node.width.unwrap_or(0.0) -
      label_padding_x * 2.0 -
      tag_ratio * (height + label_padding_y * 2.0)).max(10.0),
    )
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let total_height = size_or(node.height, box.height) + label_padding_y * 2.0
  let tag_width = tag_ratio * total_height
  let tag_height = tag_ratio * total_height
  let total_width = size_or(node.width, box.width) +
    label_padding_x * 2.0 +
    tag_width
  let w = total_width - tag_width
  let h = total_height
  let x = -w / 2.0
  let y = -h / 2.0
  let rect_points = [
    { x: x - tag_width / 2.0, y, },
    { x: x + w + tag_width / 2.0, y, },
    { x: x + w + tag_width / 2.0, y: y + h, },
    { x: x - tag_width / 2.0, y: y + h, },
  ]
  let tag_points = [
    { x: x + w - tag_width / 2.0, y: y + h, },
    { x: x + w + tag_width / 2.0, y: y + h, },
    { x: x + w + tag_width / 2.0, y: y + h - tag_height, },
  ]
  let options = rough_options(node, env)
  let rect = @rough.path(path_from_points(rect_points), options)
  // The tag is the outer group; the rectangle goes inside it, first.
  let tag = @rough.path(path_from_points(tag_points), options)
  prepend(tag, rect)
  insert_rough_outline(labelled.shape_svg, tag, node, styles) |> ignore
  update_node_bounds(node, tag)
  node.intersect = Some(point => intersect_polygon(node, rect_points, point))
  labelled.shape_svg
}

///|
/// A rectangle with only its top and bottom drawn: the data store of data
/// flow diagrams. The sides are dashed away.
fn datastore(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let shape_svg = draw_rect(
    parent,
    node,
    env,
    label_padding_x=node.padding * 2.0,
    label_padding_y=node.padding,
  )
  let width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  if width > 0.0 &&
    height > 0.0 &&
    shape_svg.child_elements() is [rect, ..] &&
    rect.tag == "rect" {
    let n = @dom.number
    rect.attr("stroke-dasharray", "\{n(width)} \{n(height)}") |> ignore
  }
  shape_svg
}

///|
/// A note: a rectangle in the theme's note colours.
fn note(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let total_width = (box.width + node.padding * 2.0).max(
    node.width.unwrap_or(0.0),
  )
  let total_height = (box.height + node.padding * 2.0).max(
    node.height.unwrap_or(0.0),
  )
  let x = -total_width / 2.0
  let y = -total_height / 2.0
  let theme = env.config.theme()
  let options = rough_options(node, env)
  options.fill = theme.text("noteBkgColor")
  options.stroke = theme.text("noteBorderColor")
  let outline = insert_rough_outline(
    labelled.shape_svg,
    @rough.rectangle(x, y, total_width, total_height, options),
    node,
    styles,
  )
  labelled.label.attr("class", "label noteLabel") |> ignore
  place_label(labelled, -box.width / 2.0, -(box.height / 2.0))
  update_node_bounds(node, outline)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}

///|
/// The rectangle state diagrams draw around a composite state before it
/// is laid out; a flowchart node may ask for it by name.
fn composite(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let classes = if node.css_classes == "" {
    "node"
  } else {
    "node \{node.css_classes}"
  }
  let labelled = label_helper(parent, node, classes, env)
  let box = labelled.bbox
  let half_padding = node.padding / 2.0
  let rect = labelled.shape_svg
    .insert_first("rect")
    .attr("class", "basic cluster composite label-container")
    .attr_number("x", -box.width / 2.0 - half_padding)
    .attr_number("y", -box.height / 2.0 - half_padding)
    .attr_number("width", box.width + node.padding)
    .attr_number("height", box.height + node.padding)
  update_node_bounds(node, rect)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}
