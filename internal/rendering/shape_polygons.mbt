// Shapes outlined by a path through points that rough.js draws: triangles,
// the notched pentagon, the sloped rectangle and the shapes with rounded
// ends.

///|
/// A label with a rough.js outline through `points` behind it. `transform`
/// moves the outline; `before_class` tells whether upstream sets it before
/// the class, which decides the order of the attributes.
fn rough_polygon(
  labelled : Labelled,
  node : Node,
  env : Env,
  styles : SplitStyles,
  points : Array[Point],
  classes~ : String = "basic label-container outer-path",
  transform? : String,
  before_class~ : Bool = false,
) -> @dom.Element {
  let outline = @rough.path(path_from_points(points), rough_options(node, env))
  if before_class && transform is Some(transform) {
    outline.attr("transform", transform) |> ignore
  }
  insert_rough_outline(labelled.shape_svg, outline, node, styles, classes~)
  |> ignore
  if !before_class && transform is Some(transform) {
    outline.attr("transform", transform) |> ignore
  }
  outline
}

///|
/// Whether triangles place their label as for HTML labels:
/// `evaluate(getConfig().flowchart?.htmlLabels)`, which is true when the
/// setting is absent.
fn flowchart_html_labels(env : Env) -> Bool {
  match env.config.get("flowchart.htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
}

///|
/// A triangle standing on its base, or on its tip when `flipped`.
fn triangle(
  parent : @dom.Element,
  node : Node,
  env : Env,
  flipped~ : Bool,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let label_padding_x = if node.look == "neo" {
    node.padding * 2.0
  } else {
    node.padding
  }
  if has_size(node) {
    let width = if flipped {
      node.width.unwrap_or(0.0) - label_padding_x - label_padding_x / 2.0
    } else {
      (node.width.unwrap_or(0.0) - label_padding_x) / 2.0
    }
    node.width = Some(if width < 10.0 { 10.0 } else { width })
    let height = node.height.unwrap_or(0.0)
    node.height = Some(if height < 10.0 { 10.0 } else { height })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let w = size_or(node.width, box.width) + label_padding_x
  let h = size_or(node.height, w + box.height)
  let points = if flipped {
    [{ x: 0.0, y: -h, }, { x: h, y: -h, }, { x: h / 2.0, y: 0.0, }]
  } else {
    [{ x: 0.0, y: 0.0, }, { x: h, y: 0.0, }, { x: h / 2.0, y: -h, }]
  }
  let n = @dom.number
  let outline = rough_polygon(
    labelled,
    node,
    env,
    styles,
    points,
    classes="outer-path",
    transform="translate(\{n(-h / 2.0)}, \{n(h / 2.0)})",
    before_class=true,
  )
  node.width = Some(w)
  node.height = Some(h)
  update_node_bounds(node, outline)
  // The label goes where the triangle is widest.
  if flipped {
    // Upstream adds the box's start here where every other shape
    // subtracts it.
    place_label_at(
      labelled,
      -box.width / 2.0 - labelled.offset_x,
      -h / 2.0 + node.padding / 2.0 + labelled.offset_y,
    )
  } else {
    let divisor = if flowchart_html_labels(env) { 2.0 } else { 1.0 }
    place_label_at(
      labelled,
      -box.width / 2.0 - labelled.offset_x,
      h / 2.0 - (box.height + node.padding / divisor - labelled.offset_y),
    )
  }
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A rectangle with its two top corners cut off: a loop limit.
fn trapezoidal_pentagon(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  if has_size(node) {
    let height = node.height.unwrap_or(0.0) - label_padding_y * 2.0
    node.height = Some(if height < 5.0 { 5.0 } else { height })
    let width = node.width.unwrap_or(0.0) - label_padding_x * 2.0
    node.width = Some(if width < 15.0 { 15.0 } else { width })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let w = size_or(node.width, labelled.bbox.width) + label_padding_x * 2.0
  let h = size_or(node.height, labelled.bbox.height) + label_padding_y * 2.0
  let points = [
    { x: -w / 2.0 * 0.8, y: -h / 2.0, },
    { x: w / 2.0 * 0.8, y: -h / 2.0, },
    { x: w / 2.0, y: -h / 2.0 * 0.6, },
    { x: w / 2.0, y: h / 2.0, },
    { x: -w / 2.0, y: h / 2.0, },
    { x: -w / 2.0, y: -h / 2.0 * 0.6, },
  ]
  let outline = rough_polygon(labelled, node, env, styles, points)
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A rectangle whose top rises to the right: manual input.
fn sloped_rect(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  if has_size(node) {
    node.width = Some(
      (node.width.unwrap_or(0.0) - label_padding_x * 2.0).max(10.0),
    )
    node.height = Some(
      (node.height.unwrap_or(0.0) / 1.5 - label_padding_y * 2.0).max(10.0),
    )
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let total_width = size_or(node.width, box.width) + label_padding_x * 2.0
  let total_height = (size_or(node.height, box.height) + label_padding_y * 2.0) *
    1.5
  let w = total_width
  let h = total_height / 1.5
  let x = -w / 2.0
  let y = -h / 2.0
  let points = [
    { x, y, },
    { x, y: y + h, },
    { x: x + w, y: y + h, },
    { x: x + w, y: y - h / 2.0, },
  ]
  let n = @dom.number
  let outline = rough_polygon(
    labelled,
    node,
    env,
    styles,
    points,
    // The two spaces are upstream's.
    classes="basic label-container  outer-path",
    transform="translate(0, \{n(h / 4.0)})",
  )
  place_label(labelled, -w / 2.0 + node.padding, -h / 4.0 + node.padding)
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// How far a round end of radius `radius` is from its tangent at the
/// corners of a label `label_height` tall.
fn cap_clearance(radius : Double, label_height : Double) -> Double {
  radius -
  0.0.max(radius * radius - label_height / 2.0 * (label_height / 2.0)).sqrt()
}

///|
/// A point on the left, a round end on the right: a display.
fn curved_trapezoid(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let h = 5.0
    .max(box.height + label_padding_y * 2.0)
    .max(node.height.unwrap_or(0.0))
  let radius = h / 2.0
  // The label is centred between the point and the round end, so the
  // larger of the two is reserved on both sides.
  let side_clearance = (h / 4.0).max(cap_clearance(radius, box.height))
  let w = 20.0
    .max(box.width + label_padding_x * 2.0 + side_clearance * 2.0)
    .max((box.width + label_padding_x * 2.0) * 1.25)
    .max(node.width.unwrap_or(0.0))
  let rw = w - radius
  let tw = h / 4.0
  let points = [
    { x: rw, y: 0.0, },
    { x: tw, y: 0.0, },
    { x: 0.0, y: h / 2.0, },
    { x: tw, y: h, },
    { x: rw, y: h, },
    ..circle_points(-rw, -h / 2.0, radius, 50, 270.0, 90.0),
  ]
  let n = @dom.number
  let outline = rough_polygon(
    labelled,
    node,
    env,
    styles,
    points,
    transform="translate(\{n(-w / 2.0)}, \{n(-h / 2.0)})",
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A rectangle with a round right end: a delay.
fn half_rounded_rectangle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let min_width = 15.0
  let min_height = 10.0
  let padding_x = if neo { 16.0 } else { node.padding }
  let padding_y = if neo { 12.0 } else { node.padding }
  if has_size(node) {
    let height = node.height.unwrap_or(0.0) - padding_y * 2.0
    node.height = Some(if height < min_height { min_height } else { height })
    let width = node.width.unwrap_or(0.0) - padding_x * 2.0
    node.width = Some(if width < min_width { min_width } else { width })
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let h = size_or(node.height, min_height.max(box.height)) + padding_y * 2.0
  let radius = h / 2.0
  // The label is centred, so what its corners need to clear the round end
  // is added twice.
  let w = size_or(
      node.width,
      min_width.max(box.width) + cap_clearance(radius, box.height) * 2.0,
    ) +
    padding_x * 2.0
  let points = [
    { x: -w / 2.0, y: -h / 2.0, },
    { x: w / 2.0 - radius, y: -h / 2.0, },
    ..circle_points(-w / 2.0 + radius, 0.0, radius, 50, 90.0, 270.0),
    { x: w / 2.0 - radius, y: h / 2.0, },
    { x: -w / 2.0, y: h / 2.0, },
  ]
  let outline = rough_polygon(labelled, node, env, styles, points)
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// Points along the arc of an ellipse with radii `rx` and `ry` from one
/// point to another: the bow tie's `generateArcPoints`.
fn elliptic_arc_points(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  rx : Double,
  ry : Double,
  clockwise : Bool,
) -> Array[Point] {
  let count = 20
  let pi = 3.141592653589793
  let side = if clockwise { -1.0 } else { 1.0 }
  let mid_x = (x1 + x2) / 2.0
  let mid_y = (y1 + y2) / 2.0
  let angle = @jsmath.atan2(y2 - y1, x2 - x1)
  // The chord on the unit circle. The bow tie's arcs span the ellipse's
  // full height, so it is never longer than the diameter.
  let unit_x = (x2 - x1) / 2.0 / rx
  let unit_y = (y2 - y1) / 2.0 / ry
  let distance = (unit_x * unit_x + unit_y * unit_y).sqrt()
  let centre_distance = (1.0 - distance * distance).sqrt()
  let centre_x = mid_x + centre_distance * ry * @jsmath.sin(angle) * side
  let centre_y = mid_y - centre_distance * rx * @jsmath.cos(angle) * side
  let start_angle = @jsmath.atan2((y1 - centre_y) / ry, (x1 - centre_x) / rx)
  let end_angle = @jsmath.atan2((y2 - centre_y) / ry, (x2 - centre_x) / rx)
  let mut range = end_angle - start_angle
  if clockwise && range < 0.0 {
    range = range + 2.0 * pi
  }
  if !clockwise && range > 0.0 {
    range = range - 2.0 * pi
  }
  let points = []
  for i in 0..<count {
    let t = i.to_double() / (count - 1).to_double()
    let angle = start_angle + t * range
    points.push({
      x: centre_x + rx * @jsmath.cos(angle),
      y: centre_y + ry * @jsmath.sin(angle),
    })
  }
  points
}

///|
/// A rectangle whose sides bow to the left: stored data.
fn bow_tie_rect(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 16.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let total_height = size_or(node.height, box.height) + label_padding_y
  let ry = total_height / 2.0
  let rx = ry / (2.5 + total_height / 50.0)
  // How far the arcs bulge: the sagitta of a chord as long as the height.
  let semi_major = rx.max(ry)
  let semi_minor = rx.min(ry)
  let ratio = total_height / semi_major / 2.0
  let sagitta = semi_minor * (1.0 - (1.0 - ratio * ratio).sqrt())
  let total_width = size_or(node.width, box.width) +
    label_padding_x * 2.0 +
    sagitta
  let w = total_width - sagitta
  let h = total_height
  let points = [
    { x: w / 2.0, y: -h / 2.0, },
    { x: -w / 2.0, y: -h / 2.0, },
    ..elliptic_arc_points(-w / 2.0, -h / 2.0, -w / 2.0, h / 2.0, rx, ry, false),
    { x: w / 2.0, y: h / 2.0, },
    ..elliptic_arc_points(w / 2.0, h / 2.0, w / 2.0, -h / 2.0, rx, ry, true),
  ]
  let n = @dom.number
  let outline = rough_polygon(
    labelled,
    node,
    env,
    styles,
    points,
    transform="translate(\{n(rx / 2.0)}, 0)",
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}
