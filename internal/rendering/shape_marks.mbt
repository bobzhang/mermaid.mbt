// Shapes that carry no text: the small marks flowcharts borrow from state
// and activity diagrams.

///|
/// The group of a node that has no label to hang its outline behind.
fn bare_node(
  parent : @dom.Element,
  node : Node,
  classes : String,
) -> @dom.Element {
  parent.append("g").attr("class", classes).attr("id", node.dom_id)
}

///|
/// The reference to the look's small drop shadow, for marks under 25 wide
/// in themes that shade nodes.
fn small_shadow(node : Node, env : Env) -> String? {
  if node.width.unwrap_or(0.0) < 25.0 && env.config.theme().flag("nodeShadow") {
    Some("filter:url(#\{env.diagram_id}-drop-shadow-small)")
  } else {
    None
  }
}

///|
/// Marks have a fixed size unless the node asks for a larger one: 14 on
/// both axes at least.
fn mark_size(node : Node) -> Unit {
  let width = node.width.unwrap_or(0.0)
  let height = node.height.unwrap_or(0.0)
  node.width = Some(if width < 14.0 { 14.0 } else { width })
  node.height = Some(if height < 14.0 { 14.0 } else { height })
}

///|
/// A small filled circle: where a flow starts.
fn state_start(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  mark_size(node)
  let shape_svg = bare_node(parent, node, "node default")
  let width = node.width.unwrap_or(14.0)
  let circle = shape_svg
    .insert_first("circle")
    .attr("class", "state-start")
    .attr_number("r", width / 2.0)
    .attr_number("width", width)
    .attr_number("height", node.height.unwrap_or(14.0))
  if small_shadow(node, env) is Some(filter) {
    circle.attr("style", filter) |> ignore
  }
  update_node_bounds(node, circle)
  node.intersect = Some(point => {
    let radius = node.width.unwrap_or(7.0) / 2.0
    intersect_ellipse(node, radius, radius, point)
  })
  shape_svg
}

///|
/// A filled circle inside a ring: where a flow stops.
fn state_end(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let theme = env.config.theme()
  mark_size(node)
  let shape_svg = bare_node(parent, node, "node default")
  let width = node.width.unwrap_or(0.0)
  let ring_options = rough_options(node, env)
  ring_options.stroke = theme.text("lineColor")
  ring_options.stroke_width = "2"
  let ring = @rough.circle(0.0, 0.0, width, ring_options)
  let inner_fill = match theme.get("stateBorder") {
    String(colour) => colour
    _ => theme.text("nodeBorder")
  }
  let dot_options = rough_options(node, env)
  dot_options.fill = inner_fill
  dot_options.stroke = inner_fill
  dot_options.stroke_width = "2"
  let dot = @rough.circle(0.0, 0.0, width * 5.0 / 14.0, dot_options)
  prepend(shape_svg, ring)
  ring.append_child(dot)
  ring.attr("class", "outer-path") |> ignore
  style_rough_paths(ring, node, styles)
  if small_shadow(node, env) is Some(filter) {
    ring.attr("style", filter) |> ignore
  }
  update_node_bounds(node, ring)
  node.intersect = Some(point => {
    let radius = node.width.unwrap_or(0.0) / 2.0
    intersect_ellipse(node, radius, radius, point)
  })
  shape_svg
}

///|
/// A bar across the flow: where it forks or joins. `dir` is the direction
/// of the flow around the node.
fn fork_join(
  parent : @dom.Element,
  node : Node,
  env : Env,
  dir : String,
) -> @dom.Element {
  let styles = node_styles(node)
  node.label = ""
  let shape_svg = bare_node(parent, node, node_classes(node))
  // The long side faces the edges.
  let (long, short) = if dir is ("LR" | "RL") { (1, 0) } else { (0, 1) }
  let sizes = [70.0, 10.0]
  let width = sizes[long].max(node.width.unwrap_or(0.0))
  let height = sizes[short].max(node.height.unwrap_or(0.0))
  let x = -1.0 * width / 2.0
  let y = -1.0 * height / 2.0
  let options = rough_options(node, env)
  let line_color = env.config.theme().text("lineColor")
  options.stroke = line_color
  options.fill = line_color
  let bar = @rough.rectangle(x, y, width, height, options)
  prepend(shape_svg, bar)
  style_rough_paths(bar, node, styles)
  update_node_bounds(node, bar)
  // The layout sees the bar with some of the state diagram's padding.
  let padding = env.config.number("state.padding").unwrap_or(0.0)
  if node.width is Some(width) &&
    node.height is Some(height) &&
    width != 0.0 &&
    height != 0.0 {
    node.width = Some(width + padding / 2.0)
    node.height = Some(height + padding / 2.0)
  }
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

///|
/// Two triangles meeting at their tips.
fn hourglass(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  node.label = ""
  let labelled = label_helper(parent, node, node_classes(node), env)
  let w = 30.0.max(node.width.unwrap_or(0.0))
  let h = 30.0.max(node.height.unwrap_or(0.0))
  let points = [
    { x: 0.0, y: 0.0, },
    { x: w, y: 0.0, },
    { x: 0.0, y: h, },
    { x: w, y: h, },
  ]
  let outline = insert_rough_outline(
    labelled.shape_svg,
    @rough.path(path_from_points(points), rough_options(node, env)),
    node,
    styles,
  )
  let n = @dom.number
  outline.attr("transform", "translate(\{n(-w / 2.0)}, \{n(-h / 2.0)})")
  |> ignore
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A lightning bolt: a communication link.
fn lightning_bolt(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  node.label = ""
  let shape_svg = bare_node(parent, node, node_classes(node))
  let width = 35.0.max(node.width.unwrap_or(0.0))
  let height = 35.0.max(node.height.unwrap_or(0.0))
  let gap = 7.0
  let points = [
    { x: width, y: 0.0, },
    { x: 0.0, y: height + gap / 2.0, },
    { x: width - 2.0 * gap, y: height + gap / 2.0, },
    { x: 0.0, y: 2.0 * height, },
    { x: width, y: height - gap / 2.0, },
    { x: 2.0 * gap, y: height - gap / 2.0, },
  ]
  let outline = insert_rough_outline(
    shape_svg,
    @rough.path(path_from_points(points), rough_options(node, env)),
    node,
    styles,
    classes="outer-path",
  )
  let n = @dom.number
  outline.attr("transform", "translate(-\{n(width / 2.0)},\{n(-height)})")
  |> ignore
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  shape_svg
}

///|
/// A small disc in the colour of node borders: a junction.
fn filled_circle(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  node.label = ""
  let shape_svg = bare_node(parent, node, node_classes(node))
  let radius = 7.0
  let disc = @rough.circle(0.0, 0.0, radius * 2.0, rough_options(node, env))
  prepend(shape_svg, disc)
  let node_border = env.config.theme().text("nodeBorder")
  for path in disc.descendants(["path"]) {
    path.attr("style", "fill: \{node_border} !important;") |> ignore
    // Unlike elsewhere, an empty list of styles leaves the fill alone.
    if !node.css_styles.is_empty() {
      path.attr("style", node.css_styles.join(",")) |> ignore
    }
    if styles.node_styles != "" {
      path.attr("style", styles.node_styles) |> ignore
    }
  }
  update_node_bounds(node, disc)
  node.intersect = Some(point => intersect_ellipse(node, radius, radius, point))
  shape_svg
}

///|
/// A circle with a diagonal cross: a summary.
fn crossed_circle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  node.label = ""
  let shape_svg = bare_node(parent, node, node_classes(node))
  let radius = 30.0.max(node.width.unwrap_or(0.0))
  let ring = @rough.circle(0.0, 0.0, radius * 2.0, rough_options(node, env))
  // The ends of the two diagonals, one per quadrant.
  let pi = 3.141592653589793
  let x_axis = @jsmath.cos(pi / 4.0)
  let y_axis = @jsmath.sin(pi / 4.0)
  let half = radius * 2.0 / 2.0
  let n = @dom.number
  let q1 = "\{n(half * x_axis)},\{n(half * y_axis)}"
  let q2 = "\{n(-half * x_axis)},\{n(half * y_axis)}"
  let q3 = "\{n(-half * x_axis)},\{n(-half * y_axis)}"
  let q4 = "\{n(half * x_axis)},\{n(-half * y_axis)}"
  let cross = @rough.path(
    "M \{q2} L \{q4}\n M \{q1} L \{q3}",
    rough_options(node, env),
  )
  prepend(shape_svg, ring)
  ring.append_child(cross)
  ring.attr("class", "outer-path") |> ignore
  style_rough_paths(ring, node, styles)
  update_node_bounds(node, ring)
  node.intersect = Some(point => intersect_ellipse(node, radius, radius, point))
  shape_svg
}

///|
/// A dot too small to see: something for edges to attach to.
fn anchor(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  shape_styles(node) |> ignore
  let shape_svg = bare_node(parent, node, node_classes(node))
  let radius = 1.0
  let options = rough_options(node, env)
  options.fill = "black"
  options.stroke = "none"
  let dot = @rough.circle(0.0, 0.0, radius * 2.0, options)
  prepend(shape_svg, dot)
  dot.attr("class", "anchor").attr("style", node.css_styles.join(",")) |> ignore
  update_node_bounds(node, dot)
  node.intersect = Some(point => intersect_ellipse(node, radius, radius, point))
  shape_svg
}

///|
/// A small diamond: a choice between flows.
fn choice(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = node_styles(node)
  node.label = ""
  let shape_svg = bare_node(parent, node, node_classes(node))
  let s = 28.0.max(node.width.unwrap_or(0.0))
  let points = [
    { x: 0.0, y: s / 2.0, },
    { x: s / 2.0, y: 0.0, },
    { x: 0.0, y: -s / 2.0, },
    { x: -s / 2.0, y: 0.0, },
  ]
  let diamond = @rough.path(path_from_points(points), rough_options(node, env))
  prepend(shape_svg, diamond)
  style_rough_paths(diamond, node, styles)
  node.width = Some(28.0)
  node.height = Some(28.0)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  shape_svg
}
