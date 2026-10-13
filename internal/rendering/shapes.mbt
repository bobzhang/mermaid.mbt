// Node shapes: mermaid's `rendering-elements/shapes/*`.

///|
/// `(look === 'handDrawn' ? 'rough-node' : 'node') + ' ' + cssClasses + ' '`
fn node_classes(node : Node) -> String {
  let base = if node.look == "handDrawn" { "rough-node" } else { "node" }
  "\{base} \{node.css_classes} "
}

///|
/// Record the size of the element that outlines the node: mermaid's
/// `updateNodeBounds`.
fn update_node_bounds(node : Node, element : @dom.Element) -> Unit {
  let box = element.bbox()
  node.width = Some(box.width)
  node.height = Some(box.height)
}

///|
/// A rectangle around the label, mermaid's `drawRect`.
fn draw_rect(
  parent : @dom.Element,
  node : Node,
  env : Env,
  label_padding_x~ : Double,
  label_padding_y~ : Double,
  radius? : Double,
) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let total_width = (labelled.bbox.width + label_padding_x * 2.0).max(
    node.width.unwrap_or(0.0),
  )
  let total_height = (labelled.bbox.height + label_padding_y * 2.0).max(
    node.height.unwrap_or(0.0),
  )
  let rect = labelled.shape_svg
    .insert_first("rect")
    .attr("class", "basic label-container")
    .attr("style", styles.node_styles)
  if radius is Some(radius) && radius != 0.0 {
    rect.attr_number("rx", radius).attr_number("ry", radius) |> ignore
  }
  rect
  .attr_number("x", -total_width / 2.0)
  .attr_number("y", -total_height / 2.0)
  .attr_number("width", total_width)
  .attr_number("height", total_height)
  |> ignore
  node.width = Some(total_width)
  node.height = Some(total_height)
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

///|
/// mermaid's `insertPolygonShape`: a polygon behind the label, moved so
/// that its box of `w` by `h` is centred.
fn insert_polygon(
  shape_svg : @dom.Element,
  w : Double,
  h : Double,
  points : Array[Point],
) -> @dom.Element {
  let n = @dom.number
  shape_svg
  .insert_first("polygon")
  .attr("points", points.map(p => "\{n(p.x)},\{n(p.y)}").join(" "))
  .attr("class", "label-container")
  .attr("transform", "translate(\{n(-w / 2.0)},\{n(h / 2.0)})")
}

///|
/// A node outlined by a polygon: label, polygon, size and intersection.
/// `points` computes the outline from the label's box.
fn polygon_shape(
  parent : @dom.Element,
  node : Node,
  env : Env,
  outline : (LabelBox) -> (Double, Double, Array[Point]),
) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let (w, h, points) = outline(labelled.bbox)
  let polygon = insert_polygon(labelled.shape_svg, w, h, points)
  if styles.node_styles != "" {
    polygon.attr("style", styles.node_styles) |> ignore
  }
  update_node_bounds(node, polygon)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A diamond: mermaid's `question`.
fn question(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let w = labelled.bbox.width + node.padding
  let h = labelled.bbox.height + node.padding
  let s = w + h
  let outline = (s : Double) => {
    [
      { x: s / 2.0, y: 0.0, },
      { x: s, y: -s / 2.0, },
      { x: s / 2.0, y: -s, },
      { x: 0.0, y: -s / 2.0, },
    ]
  }
  let n = @dom.number
  let polygon = insert_polygon(labelled.shape_svg, s, s, outline(s)).attr(
    "transform",
    "translate(\{n(-s / 2.0 + 0.5)}, \{n(s / 2.0)})",
  )
  if styles.node_styles != "" {
    polygon.attr("style", styles.node_styles) |> ignore
  }
  update_node_bounds(node, polygon)
  // The outline follows the size the node ends up with.
  node.intersect = Some(point => {
    intersect_polygon(node, outline(node.width.unwrap_or(0.0)), point)
  })
  labelled.shape_svg
}

///|
/// A circle around the label.
fn circle(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(
    parent,
    node,
    node_classes(node),
    env,
    ignore_min_width=true,
  )
  let box = labelled.bbox
  let label_radius = (box.width * box.width + box.height * box.height).sqrt() /
    2.0
  let radius = if node.look == "neo" {
    label_radius + 16.0
  } else {
    label_radius + node.padding / 2.0
  }
  let element = labelled.shape_svg
    .insert_first("circle")
    .attr("class", "basic label-container")
    .attr("style", styles.node_styles)
    .attr_number("r", radius)
    .attr("cx", "0")
    .attr("cy", "0")
  update_node_bounds(node, element)
  node.intersect = Some(point => intersect_ellipse(node, radius, radius, point))
  labelled.shape_svg
}

///|
/// Two concentric circles around the label.
fn double_circle(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let gap = if neo { 12.0 } else { 5.0 }
  let label_padding = if neo { 16.0 } else { node.padding }
  let labelled = label_helper(
    parent,
    node,
    node_classes(node),
    env,
    ignore_min_width=true,
  )
  let box = labelled.bbox
  let label_radius = (box.width * box.width + box.height * box.height).sqrt() /
    2.0
  let inner_radius = (match node.width {
      Some(width) if width != 0.0 => width / 2.0
      _ => label_radius
    }) +
    label_padding
  let outer_radius = inner_radius + gap
  let group = labelled.shape_svg.insert_first("g")
  let outer = group.append("circle")
  let inner = group.append("circle")
  group.attr("class", "basic label-container").attr("style", styles.node_styles)
  |> ignore
  outer
  .attr("class", "outer-circle")
  .attr("style", styles.node_styles)
  .attr_number("r", outer_radius)
  .attr("cx", "0")
  .attr("cy", "0")
  |> ignore
  inner
  .attr("class", "inner-circle")
  .attr("style", styles.node_styles)
  .attr_number("r", inner_radius)
  .attr("cx", "0")
  .attr("cy", "0")
  |> ignore
  update_node_bounds(node, group)
  node.intersect = Some(point => {
    intersect_ellipse(node, outer_radius, outer_radius, point)
  })
  labelled.shape_svg
}

///|
/// A cylinder: an ellipse on top, straight sides, half an ellipse below.
fn cylinder(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding = if neo { 24.0 } else { node.padding }
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
    "translate(\{n(-(box.width / 2.0))}, \{n(-(box.height / 2.0) + node.padding / 1.5)})",
  )
  |> ignore
  node.intersect = Some(point => {
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
  })
  labelled.shape_svg
}

///|
/// Draw the outline and label of `node` with the shape it asks for.
fn draw_shape(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let neo = node.look == "neo"
  let padding = node.padding
  guard shape_handler(node.shape) is Some(handler) else {
    raise LayoutError("No such shape: \{node.shape}. Please check your syntax.")
  }
  match handler {
    "squareRect" =>
      draw_rect(
        parent,
        node,
        env,
        label_padding_x=if neo { 16.0 } else { padding * 2.0 },
        label_padding_y=if neo { 12.0 } else { padding },
      )
    "roundedRect" =>
      draw_rect(
        parent,
        node,
        env,
        label_padding_x=padding,
        label_padding_y=padding,
        radius=env.config.theme().number("radius").unwrap_or(5.0),
      )
    "question" => question(parent, node, env)
    "cylinder" => cylinder(parent, node, env)
    "circle" => circle(parent, node, env)
    "doublecircle" => double_circle(parent, node, env)
    "subroutine" =>
      polygon_shape(parent, node, env, box => {
        let label_padding_x = if neo { 28.0 } else { padding }
        let label_padding_y = if neo { 12.0 } else { padding }
        let total_width = (box.width + 16.0 + label_padding_x).max(
          node.width.unwrap_or(0.0),
        )
        let h = (box.height + label_padding_y).max(node.height.unwrap_or(0.0))
        let w = total_width - 16.0
        (
          w,
          h,
          [
            { x: 0.0, y: 0.0, },
            { x: w, y: 0.0, },
            { x: w, y: -h, },
            { x: 0.0, y: -h, },
            { x: 0.0, y: 0.0, },
            { x: -8.0, y: 0.0, },
            { x: w + 8.0, y: 0.0, },
            { x: w + 8.0, y: -h, },
            { x: -8.0, y: -h, },
            { x: -8.0, y: 0.0, },
          ],
        )
      })
    "hexagon" =>
      polygon_shape(parent, node, env, box => {
        let f = if neo { 3.5 } else { 4.0 }
        let label_padding_x = if neo { 70.0 } else { padding }
        let label_padding_y = if neo { 32.0 } else { padding }
        let h = box.height + label_padding_x
        let m = h / f
        let w = box.width + 2.0 * m + label_padding_y
        (
          w,
          h,
          [
            { x: m, y: 0.0, },
            { x: w - m, y: 0.0, },
            { x: w, y: -h / 2.0, },
            { x: w - m, y: -h, },
            { x: m, y: -h, },
            { x: 0.0, y: -h / 2.0, },
          ],
        )
      })
    "lean_right" | "lean_left" | "trapezoid" | "inv_trapezoid" =>
      polygon_shape(parent, node, env, box => {
        let label_padding_x = if neo { padding * 2.0 } else { padding }
        let scale = if handler == "inv_trapezoid" { 2.0 } else { 1.0 }
        let h = (box.height + padding * scale).max(node.height.unwrap_or(0.0))
        let w = (box.width + label_padding_x * scale).max(
          node.width.unwrap_or(0.0) - h,
        )
        let slant = 3.0 * h / 6.0
        let points = match handler {
          "lean_right" =>
            [
              { x: -slant, y: 0.0, },
              { x: w, y: 0.0, },
              { x: w + slant, y: -h, },
              { x: 0.0, y: -h, },
            ]
          "lean_left" =>
            [
              { x: 0.0, y: 0.0, },
              { x: w + slant, y: 0.0, },
              { x: w, y: -h, },
              { x: -slant, y: -h, },
            ]
          "trapezoid" =>
            [
              { x: -slant, y: 0.0, },
              { x: w + slant, y: 0.0, },
              { x: w, y: -h, },
              { x: 0.0, y: -h, },
            ]
          _ =>
            [
              { x: 0.0, y: 0.0, },
              { x: w, y: 0.0, },
              { x: w + slant, y: -h, },
              { x: -slant, y: -h, },
            ]
        }
        (w, h, points)
      })
    other => raise LayoutError("The \{other} shape is not supported yet.")
  }
}

///|
/// Draw `node` into `parent` and return its element: mermaid's
/// `insertNode`.
fn insert_node(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  if node.shape == "rect" {
    node.shape = "squareRect"
  }
  let (outer, inner) = match node.link {
    Some(link) => {
      // Upstream also sets `target`, which the final sanitizing pass strips
      // from SVG anchors again.
      let anchor = parent.append("a").attr("xlink:href", link)
      (anchor, draw_shape(anchor, node, env))
    }
    None => {
      let element = draw_shape(parent, node, env)
      (element, element)
    }
  }
  outer.attr("data-look", node.look) |> ignore
  if node.tooltip is Some(tooltip) && tooltip != "" {
    inner.attr("title", tooltip) |> ignore
  }
  if node.have_callback {
    outer.attr(
      "class",
      outer.get_attr("class").unwrap_or("null") + " clickable",
    )
    |> ignore
  }
  node.element = Some(outer)
  outer
}
