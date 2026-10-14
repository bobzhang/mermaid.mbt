// Cylinders, upright and lying down.

///|
/// Where the line from an upright cylinder's centre to a point leaves it:
/// through the box, pushed in to the ellipses that cap it.
fn cylinder_intersect(
  node : Node,
  rx : Double,
  ry : Double,
) -> (Point) -> Point {
  point => {
    let width = node.width.unwrap_or(0.0)
    let height = node.height.unwrap_or(0.0)
    let pos = intersect_rect(node.x, node.y, width, height, point)
    let x = pos.x - node.x
    if rx != 0.0 &&
      (
        x.abs() < width / 2.0 ||
        (x.abs() == width / 2.0 && (pos.y - node.y).abs() > height / 2.0 - ry)
      ) {
      let mut y = ry * ry * (1.0 - x * x / (rx * rx))
      if y > 0.0 {
        y = y.sqrt()
      }
      y = ry - y
      if point.y - node.y > 0.0 {
        y = -y
      }
      { x: pos.x, y: pos.y + y, }
    } else {
      pos
    }
  }
}

///|
/// A cylinder: an ellipse on top, straight sides, half an ellipse below.
fn cylinder(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding = if neo { 24.0 } else { node.padding }
  // A node that comes with a size keeps it: the label gets what the
  // padding and the caps leave.
  let original_width = node.width.unwrap_or(0.0)
  if size_or(node.width, 0.0) != 0.0 {
    let width = original_width - label_padding
    node.width = Some(if width < 8.0 { 8.0 } else { width })
  }
  if size_or(node.height, 0.0) != 0.0 {
    let rx = original_width / 2.0
    let ry = rx / (2.5 + original_width / 50.0)
    let height = node.height.unwrap_or(0.0) - label_padding - ry * 3.0
    node.height = Some(if height < 8.0 { 8.0 } else { height })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let w = node.width.unwrap_or(0.0).max(box.width) + label_padding
  let rx = w / 2.0
  let ry = rx / (2.5 + w / 50.0)
  let h = node.height.unwrap_or(0.0).max(box.height) + label_padding + ry
  let n = @dom.number
  let path_data = [
    "M0,\{n(ry)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(w)},0",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(-w)},0",
    "l0,\{n(h)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(w)},0",
    "l0,\{n(-h)}",
  ].join(" ")
  let element = labelled.shape_svg
    .insert_first("path")
    .attr("d", path_data)
    .attr("class", "basic label-container outer-path")
    .attr("style", styles.node_styles)
    .attr("transform", "translate(\{n(-w / 2.0)}, \{n(-(h / 2.0 + ry))})")
  update_node_bounds(node, element)
  labelled.label.attr(
    "transform",
    "translate(\{n(-(box.width / 2.0) - labelled.offset_x)}, \{n(-(box.height / 2.0) + node.padding / 1.5 - labelled.offset_y)})",
  )
  |> ignore
  node.intersect = Some(cylinder_intersect(node, rx, ry))
  labelled.shape_svg
}

///|
/// A cylinder with a second rim below the first: disk storage.
fn lined_cylinder(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 24.0 } else { node.padding }
  if has_size(node) {
    let original_width = node.width.unwrap_or(0.0)
    let width = original_width - label_padding_x
    node.width = Some(if width < 10.0 { 10.0 } else { width })
    // The height the caps take follows from the width.
    let rx = original_width / 2.0
    let ry = rx / (2.5 + original_width / 50.0)
    let height = node.height.unwrap_or(0.0) - label_padding_y - ry * 3.0
    node.height = Some(if height < 10.0 { 10.0 } else { height })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let w = size_or(node.width, box.width) + label_padding_x * 2.0
  let rx = w / 2.0
  let ry = rx / (2.5 + w / 50.0)
  let h = size_or(node.height, box.height) + ry + label_padding_y * 2.0
  let outer_offset = h * 0.1
  let n = @dom.number
  let path_data = [
    "M0,\{n(ry)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(w)},0",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(-w)},0",
    "l0,\{n(h)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(w)},0",
    "l0,\{n(-h)}",
    "M0,\{n(ry + outer_offset)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(w)},0",
  ].join(" ")
  let element = labelled.shape_svg
    .insert_first("path")
    .attr("d", path_data)
    .attr("class", "basic label-container outer-path")
    .attr("style", styles.node_styles)
    .attr("transform", "translate(\{n(-w / 2.0)}, \{n(-(h / 2.0 + ry))})")
  update_node_bounds(node, element)
  place_label(labelled, -(box.width / 2.0), -(box.height / 2.0) + ry)
  node.intersect = Some(cylinder_intersect(node, rx, ry))
  labelled.shape_svg
}

///|
/// A cylinder lying on its side: direct access storage.
fn tilted_cylinder(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let label_padding = if node.look == "neo" { 12.0 } else { node.padding / 2.0 }
  let original_height = node.height.unwrap_or(0.0)
  if size_or(node.height, 0.0) != 0.0 {
    let height = original_height - label_padding
    node.height = Some(if height < 5.0 { 5.0 } else { height })
  }
  if size_or(node.width, 0.0) != 0.0 {
    // The width the caps take follows from the height.
    let ry = original_height / 2.0
    let rx = ry / (2.5 + original_height / 50.0)
    let width = node.width.unwrap_or(0.0) - label_padding - rx * 3.0
    node.width = Some(if width < 10.0 { 10.0 } else { width })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let h = node.height.unwrap_or(0.0).max(box.height) + label_padding
  let ry = h / 2.0
  let rx = ry / (2.5 + h / 50.0)
  let w = node.width.unwrap_or(0.0).max(box.width) + rx + label_padding
  let n = @dom.number
  // Upstream writes the path on several indented lines.
  let path_data = [
    "M0,0",
    "a\{n(rx)},\{n(ry)} 0,0,1 0,\{n(-h)}",
    "l\{n(w)},0",
    "a\{n(rx)},\{n(ry)} 0,0,1 0,\{n(h)}",
    "M\{n(w)},\{n(-h)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 0,\{n(h)}",
    "l\{n(-w)},0",
  ].join("\n    ")
  let element = labelled.shape_svg
    .insert_first("path")
    .attr("d", path_data)
    .attr("class", "basic label-container outer-path")
    .attr("style", styles.node_styles)
    .attr("transform", "translate(\{n(-w / 2.0)}, \{n(h / 2.0)} )")
  place_label(labelled, -(box.width / 2.0) - rx, -(box.height / 2.0))
  update_node_bounds(node, element)
  node.intersect = Some(point => {
    let width = node.width.unwrap_or(0.0)
    let height = node.height.unwrap_or(0.0)
    let pos = intersect_rect(node.x, node.y, width, height, point)
    let y = pos.y - node.y
    if ry != 0.0 &&
      (
        y.abs() < height / 2.0 ||
        (y.abs() == height / 2.0 && (pos.x - node.x).abs() > width / 2.0 - rx)
      ) {
      let mut x = rx * rx * (1.0 - y * y / (ry * ry))
      if x != 0.0 {
        x = x.abs().sqrt()
      }
      x = rx - x
      if point.x - node.x > 0.0 {
        x = -x
      }
      { x: pos.x + x, y: pos.y, }
    } else {
      pos
    }
  })
  labelled.shape_svg
}
