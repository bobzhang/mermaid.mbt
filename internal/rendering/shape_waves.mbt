// Shapes with wavy edges: documents and the paper tape.

///|
/// Points along a sine wave from one point to another: mermaid's
/// `generateFullSineWavePoints`.
fn sine_wave_points(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  amplitude : Double,
  cycles : Double,
) -> Array[Point] {
  let steps = 50
  let delta_x = x2 - x1
  let delta_y = y2 - y1
  let cycle_length = delta_x / cycles
  let frequency = 2.0 * 3.141592653589793 / cycle_length
  let mid_y = y1 + delta_y / 2.0
  let points = []
  for i in 0..<=steps {
    let t = i.to_double() / steps.to_double()
    let x = x1 + t * delta_x
    let y = mid_y + amplitude * @jsmath.sin(frequency * (x - x1))
    points.push({ x, y, })
  }
  points
}

///|
/// Move the label of a shape; these shapes write the translation without
/// a space.
fn place_label_tight(labelled : Labelled, x : Double, y : Double) -> Unit {
  let n = @dom.number
  labelled.label.attr(
    "transform",
    "translate(\{n(x - labelled.offset_x)},\{n(y - labelled.offset_y)})",
  )
  |> ignore
}

///|
/// What documents have in common: the label's box with padding, shrunk
/// first when the node came with a size.
fn document_size(
  node : Node,
  box : LabelBox,
  padding_x : Double,
  padding_y : Double,
) -> (Double, Double) {
  (
    size_or(node.width, box.width) + padding_x * 2.0,
    size_or(node.height, box.height) + padding_y * 2.0,
  )
}

///|
/// A rectangle with a wavy bottom edge: a document.
fn wave_edged_rectangle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  // A node with a size of its own keeps it: the wave is cut out of it.
  let grow = !has_size(node)
  if !grow {
    let width = node.width.unwrap_or(0.0) - label_padding_x * 2.0
    node.width = Some(if width < 10.0 { 10.0 } else { width })
    let height = node.height.unwrap_or(0.0) - label_padding_y * 2.0
    node.height = Some(if height < 10.0 { 10.0 } else { height })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let (w, h) = document_size(
    node,
    labelled.bbox,
    label_padding_x,
    label_padding_y,
  )
  let amplitude = if neo { h / 4.0 } else { h / 8.0 }
  let final_h = h + (if grow { amplitude } else { -amplitude })
  // Never narrower than 14.
  let width_dif = 14.0 - w
  let extra_w = if width_dif > 0.0 { width_dif / 2.0 } else { 0.0 }
  let points = [
    { x: -w / 2.0 - extra_w, y: final_h / 2.0, },
    ..sine_wave_points(
      -w / 2.0 - extra_w,
      final_h / 2.0,
      w / 2.0 + extra_w,
      final_h / 2.0,
      amplitude,
      0.8,
    ),
    { x: w / 2.0 + extra_w, y: -final_h / 2.0, },
    { x: -w / 2.0 - extra_w, y: -final_h / 2.0, },
  ]
  let n = @dom.number
  let outline = rough_polygon(
    labelled,
    node,
    env,
    styles,
    points,
    transform="translate(0,\{n(-amplitude / 2.0)})",
  )
  place_label_tight(
    labelled,
    -w / 2.0 + node.padding,
    -h / 2.0 + node.padding - amplitude,
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A document with a line inside its left edge.
fn lined_wave_edged_rect(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  if has_size(node) {
    let width = node.width.unwrap_or(0.0) * 10.0 / 11.0 - label_padding_x * 2.0
    node.width = Some(if width < 10.0 { 10.0 } else { width })
    let height = node.height.unwrap_or(0.0) - label_padding_y * 2.0
    node.height = Some(if height < 10.0 { 10.0 } else { height })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let (w, h) = document_size(
    node,
    labelled.bbox,
    label_padding_x,
    label_padding_y,
  )
  let amplitude = if neo { h / 4.0 } else { h / 8.0 }
  let final_h = h + amplitude
  // The strip left of the line is a tenth of half the width.
  let left = -w / 2.0 - w / 2.0 * 0.1
  let right = w / 2.0 + w / 2.0 * 0.1
  let points = [
    { x: left, y: -final_h / 2.0, },
    { x: left, y: final_h / 2.0, },
    ..sine_wave_points(
      left,
      final_h / 2.0,
      right,
      final_h / 2.0,
      amplitude,
      0.8,
    ),
    { x: right, y: -final_h / 2.0, },
    { x: left, y: -final_h / 2.0, },
    { x: -w / 2.0, y: -final_h / 2.0, },
    { x: -w / 2.0, y: final_h / 2.0 * 1.1, },
    { x: -w / 2.0, y: -final_h / 2.0, },
  ]
  let outline = insert_rough_outline(
    labelled.shape_svg,
    @rough.polygon(points.map(p => (p.x, p.y)), rough_options(node, env)),
    node,
    styles,
  )
  let n = @dom.number
  outline.attr("transform", "translate(0,\{n(-amplitude / 2.0)})") |> ignore
  place_label_tight(
    labelled,
    -w / 2.0 + node.padding + w / 2.0 * 0.1 / 2.0,
    -h / 2.0 + node.padding - amplitude,
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// Three documents stacked behind one another.
fn multi_wave_edged_rectangle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  let grow = !has_size(node)
  if !grow {
    node.width = Some(node.width.unwrap_or(0.0) - label_padding_x * 2.0)
    node.height = Some(node.height.unwrap_or(0.0) - label_padding_y * 3.0)
  }
  let w = box.width.max(node.width.unwrap_or(0.0)) + label_padding_x * 2.0
  let h = box.height.max(node.height.unwrap_or(0.0)) + label_padding_y * 3.0
  let amplitude = if neo { h / 4.0 } else { h / 8.0 }
  let final_h = h + (if grow { amplitude / 2.0 } else { -amplitude / 2.0 })
  let x = -w / 2.0
  let y = -final_h / 2.0
  let rect_offset = 10.0
  let wave = sine_wave_points(
    x - rect_offset,
    y + final_h + rect_offset,
    x + w - rect_offset,
    y + final_h + rect_offset,
    amplitude,
    0.8,
  )
  let last_y = wave[wave.length() - 1].y
  let outer = [
    { x: x - rect_offset, y: y + rect_offset, },
    { x: x - rect_offset, y: y + final_h + rect_offset, },
    ..wave,
    { x: x + w - rect_offset, y: last_y - rect_offset, },
    { x: x + w, y: last_y - rect_offset, },
    { x: x + w, y: last_y - 2.0 * rect_offset, },
    { x: x + w + rect_offset, y: last_y - 2.0 * rect_offset, },
    { x: x + w + rect_offset, y: y - rect_offset, },
    { x: x + rect_offset, y: y - rect_offset, },
    { x: x + rect_offset, y, },
    { x, y, },
    { x, y: y + rect_offset, },
  ]
  let inner = [
    { x, y: y + rect_offset, },
    { x: x + w - rect_offset, y: y + rect_offset, },
    { x: x + w - rect_offset, y: last_y - rect_offset, },
    { x: x + w, y: last_y - rect_offset, },
    { x: x + w, y, },
    { x, y, },
  ]
  let options = rough_options(node, env)
  let outline = @rough.path(path_from_points(outer), options)
  outline.append_child(@rough.path(path_from_points(inner), options))
  insert_rough_outline(labelled.shape_svg, outline, node, styles) |> ignore
  let n = @dom.number
  outline.attr("transform", "translate(0,\{n(-amplitude / 2.0)})") |> ignore
  place_label(
    labelled,
    -(box.width / 2.0) - rect_offset,
    -(box.height / 2.0) + rect_offset - amplitude,
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, outer, point))
  labelled.shape_svg
}

///|
/// A rectangle with wavy top and bottom edges: a paper tape.
fn wave_rectangle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 20.0 } else { node.padding }
  if has_size(node) {
    let width = node.width.unwrap_or(0.0)
    let width = if width < 20.0 { 20.0 } else { width }
    let height = node.height.unwrap_or(0.0)
    let height = if height < 10.0 { 10.0 } else { height }
    // Leave room for the waves.
    let amplitude = (height * 0.2).min(height / 4.0)
    node.height = Some(
      (height - label_padding_y - amplitude * (20.0 / 9.0)).ceil(),
    )
    node.width = Some(width - label_padding_x * 2.0)
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let w = size_or(node.width, labelled.bbox.width) + label_padding_x * 2.0
  let h = size_or(node.height, labelled.bbox.height) + label_padding_y
  let amplitude = h / 8.0
  let final_h = h + amplitude * 2.0
  let points = [
    { x: -w / 2.0, y: final_h / 2.0, },
    ..sine_wave_points(
      -w / 2.0,
      final_h / 2.0,
      w / 2.0,
      final_h / 2.0,
      amplitude,
      1.0,
    ),
    { x: w / 2.0, y: -final_h / 2.0, },
    ..sine_wave_points(
      w / 2.0,
      -final_h / 2.0,
      -w / 2.0,
      -final_h / 2.0,
      amplitude,
      -1.0,
    ),
  ]
  let outline = rough_polygon(
    labelled,
    node,
    env,
    styles,
    points,
    classes="basic label-container",
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A document with its bottom right corner folded over.
fn tagged_wave_edged_rectangle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let w = (box.width + node.padding * 2.0).max(node.width.unwrap_or(0.0))
  let h = (box.height + node.padding * 2.0).max(node.height.unwrap_or(0.0))
  let amplitude = h / 8.0
  let tag_width = 0.2 * w
  let tag_height = 0.2 * h
  let final_h = h + amplitude
  let left = -w / 2.0 - w / 2.0 * 0.1
  let right = w / 2.0 + w / 2.0 * 0.1
  let points = [
    { x: left, y: final_h / 2.0, },
    ..sine_wave_points(
      left,
      final_h / 2.0,
      right,
      final_h / 2.0,
      amplitude,
      0.8,
    ),
    { x: right, y: -final_h / 2.0, },
    { x: left, y: -final_h / 2.0, },
  ]
  let x = -w / 2.0 + w / 2.0 * 0.1
  let y = -final_h / 2.0 - tag_height * 0.4
  let tag_points = [
    { x: x + w - tag_width, y: (y + h) * 1.3, },
    { x: x + w, y: y + h - tag_height, },
    { x: x + w, y: (y + h) * 0.9, },
    ..sine_wave_points(
      x + w,
      (y + h) * 1.25,
      x + w - tag_width,
      (y + h) * 1.3,
      -h * 0.02,
      0.5,
    ),
  ]
  let options = rough_options(node, env)
  let document = @rough.path(path_from_points(points), options)
  // The tag is the outer group; the document goes inside it, first.
  let tag = @rough.path(path_from_points(tag_points), solid_options(options))
  prepend(tag, document)
  insert_rough_outline(labelled.shape_svg, tag, node, styles) |> ignore
  let n = @dom.number
  tag.attr("transform", "translate(0,\{n(-amplitude / 2.0)})") |> ignore
  place_label_tight(
    labelled,
    -w / 2.0 + node.padding,
    -h / 2.0 + node.padding - amplitude / 2.0,
  )
  update_node_bounds(node, tag)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}
