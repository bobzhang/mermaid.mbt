// Shapes whose hand-drawn outline is not the classic one passed through
// rough.js: where upstream has a `node.look === 'handDrawn'` branch that
// draws other elements than the classic look does.

///|
/// The node's `cssStyles` as an attribute value: an array is written as
/// its comma-joined text.
fn css_styles_text(node : Node) -> String {
  node.css_styles.join(",")
}

///|
/// A polygon of the hand-drawn look: the points as path data sketched by
/// rough.js, moved like `insertPolygonShape` moves its polygon.
fn sketched_polygon(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  styles : SplitStyles,
  points : Array[Point],
  dx : Double,
  dy : Double,
) -> @dom.Element {
  let n = @dom.number
  let outline = @rough.path(path_from_points(points), rough_options(node, env))
  prepend(shape_svg, outline)
  outline
  .attr("transform", "translate(\{n(dx)}, \{n(dy)})")
  .attr("style", css_styles_text(node))
  |> ignore
  if styles.node_styles != "" {
    outline.attr("style", styles.node_styles) |> ignore
  }
  outline
}

///|
/// A subroutine of the hand-drawn look: a sketched rectangle with a line
/// down each side, a frame width in.
fn sketched_subroutine(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  shape_styles(node) |> ignore
  let neo = node.look == "neo"
  let label_padding_x = if neo { 28.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let frame = 8.0
  let total_width = (box.width + 2.0 * frame + label_padding_x).max(
    node.width.unwrap_or(0.0),
  )
  let total_height = (box.height + label_padding_y).max(
    node.height.unwrap_or(0.0),
  )
  let w = total_width - 2.0 * frame
  let h = total_height
  let x = -total_width / 2.0
  let y = -total_height / 2.0
  let points : Array[Point] = [
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
  ]
  let options = rough_options(node, env)
  let rect = @rough.rectangle(x, y, w + 16.0, h, options)
  let left = @rough.line(x + frame, y, x + frame, y + h, options)
  let right = @rough.line(x + frame + w, y, x + frame + w, y + h, options)
  let shape_svg = labelled.shape_svg
  prepend(shape_svg, left)
  prepend(shape_svg, right)
  prepend(shape_svg, rect)
  rect
  .attr("class", "basic label-container")
  .attr("style", css_styles_text(node))
  |> ignore
  update_node_bounds(node, rect)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  shape_svg
}

///|
/// A circle of the hand-drawn look.
fn sketched_circle(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  radius : Double,
) -> @dom.Element {
  let outline = @rough.circle(0.0, 0.0, radius * 2.0, rough_options(node, env))
  prepend(shape_svg, outline)
  outline
  .attr("class", "basic label-container")
  .attr("style", css_styles_text(node))
}

///|
/// Two circles of the hand-drawn look, the outer one with a heavier
/// stroke, in a group classed like the node.
fn sketched_double_circle(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  outer_radius : Double,
  inner_radius : Double,
) -> @dom.Element {
  let outer_options = rough_options(node, env)
  outer_options.roughness = 0.2
  outer_options.stroke_width = "2.5"
  let inner_options = rough_options(node, env)
  inner_options.roughness = 0.2
  inner_options.stroke_width = "1.5"
  let outer = @rough.circle(0.0, 0.0, outer_radius * 2.0, outer_options)
  let inner = @rough.circle(0.0, 0.0, inner_radius * 2.0, inner_options)
  let group = shape_svg.insert_first("g")
  group.attr("class", node.css_classes).attr("style", css_styles_text(node))
  |> ignore
  group.append_child(outer)
  group.append_child(inner)
  group
}

///|
/// A cylinder of the hand-drawn look: the outline without the back of a
/// rim, and that rim as a path of its own (filled or not, classed or not).
/// Only the outline is returned to be moved into place; the rim stays
/// where rough.js drew it.
fn sketched_cylinder(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  outer_path : String,
  inner_path : String,
  inner_filled~ : Bool = false,
  inner_class? : String,
) -> @dom.Element {
  let outer = @rough.path(outer_path, rough_options(node, env))
  let inner_options = rough_options(node, env)
  if !inner_filled {
    inner_options.fill = "none"
  }
  let inner = @rough.path(inner_path, inner_options)
  prepend(shape_svg, inner)
  if inner_class is Some(class) {
    inner.attr("class", class) |> ignore
  }
  prepend(shape_svg, outer)
  outer.attr("class", "basic label-container") |> ignore
  outer.attr("style", css_styles_text(node)) |> ignore
  outer
}

///|
/// The paths of an upright cylinder of the hand-drawn look, `extra` added
/// to the outline (the second rim of a lined cylinder).
fn upright_cylinder_paths(
  w : Double,
  h : Double,
  rx : Double,
  ry : Double,
  extra~ : Array[String] = [],
) -> (String, String) {
  let n = @dom.number
  let outer = [
    "M0,\{n(ry)}",
    "M\{n(w)},\{n(ry)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(-w)},0",
    "l0,\{n(h)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(w)},0",
    "l0,\{n(-h)}",
    ..extra,
  ].join(" ")
  let inner = [
    "M\{n(0.0 - w / 2.0)},\{n(-h / 2.0)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 \{n(w)},0",
  ].join(" ")
  (outer, inner)
}

///|
/// The paths of a cylinder lying on its side in the hand-drawn look.
fn tilted_cylinder_paths(
  w : Double,
  h : Double,
  rx : Double,
  ry : Double,
) -> (String, String) {
  let n = @dom.number
  let outer = [
    "M0,0",
    "M\{n(w)},0",
    "a\{n(rx)},\{n(ry)} 0,0,0 0,\{n(-h)}",
    "l\{n(-w)},0",
    "a\{n(rx)},\{n(ry)} 0,0,0 0,\{n(h)}",
    "l\{n(w)},0",
  ].join(" ")
  let inner = [
    "M\{n(w / 2.0)},\{n(-h / 2.0)}",
    "a\{n(rx)},\{n(ry)} 0,0,0 0,\{n(h)}",
  ].join(" ")
  (outer, inner)
}

///|
/// The rims of a datastore in the hand-drawn look: the sketched outline
/// of the rectangle `drawRect` drew loses its stroke, and two sketched
/// lines along the top and the bottom of that stroke's box take its place.
/// They are appended after the label: the selector upstream inserts them
/// before matches nothing.
fn sketch_datastore_rims(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
) -> Unit {
  guard shape_svg.child_elements() is [outline, ..] &&
    outline.child_elements().get(1) is Some(border) else {
    return
  }
  let box = border.bbox()
  let options = rough_options(node, env)
  shape_svg.append_child(
    @rough.line(box.x, box.y, box.x + box.width, box.y, options),
  )
  shape_svg.append_child(
    @rough.line(
      box.x,
      box.y + box.height,
      box.x + box.width,
      box.y + box.height,
      options,
    ),
  )
  border.remove()
}

///|
/// The start of a state diagram in the hand-drawn look: a circle hachured
/// in the colour of lines (mermaid's `solidStateFill`), appended to the
/// node with the attributes of the classic `<circle>`.
fn sketched_state_start(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let width = node.width.unwrap_or(14.0)
  let line_color = env.config.theme().text("lineColor")
  let circle = @rough.circle(0.0, 0.0, width, solid_state_fill(line_color, env))
  shape_svg.append_child(circle)
  circle
  .attr("class", "state-start")
  .attr_number("r", width / 2.0)
  .attr_number("width", width)
  .attr_number("height", node.height.unwrap_or(14.0))
}

///|
/// mermaid's `solidStateFill(color)`: a dense hachure in one colour.
fn solid_state_fill(color : String, env : Env) -> @rough.Options {
  let options = @rough.Options::new()
  options.fill = color
  options.hachure_angle = 120.0
  options.hachure_gap = 1.5
  options.fill_weight = 1.5
  options.roughness = 0.7
  options.stroke = color
  options.seed = env.config.number("handDrawnSeed").unwrap_or(0.0).to_int()
  options
}

///|
/// The frame of a collapsed container in the hand-drawn look: a sketched
/// rounded rectangle, plainly filled unless it has no fill.
fn sketched_collapsed_frame(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  fill : String,
  stroke : String,
  stroke_width : String?,
  css_class : String,
) -> @dom.Element {
  let options = rough_options(node, env)
  options.fill = fill
  options.stroke = stroke
  if stroke_width is Some(width) {
    options.stroke_width = width
  }
  if fill == "none" {
    options.fill_weight = 0.0
  } else {
    options.fill_style = "solid"
  }
  let frame = @rough.path(
    rounded_rect_path(x, y, width, height, radius),
    options,
  )
  prepend(shape_svg, frame)
  frame
  .attr("class", "basic label-container " + css_class)
  .attr("style", css_styles_text(node))
}

///|
/// Path data that outlines a node, sketched in the hand-drawn look in
/// place of the classic `<path>`: the cloud and bang of mindmaps.
fn sketched_outline(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  path : String,
) -> @dom.Element {
  let outline = @rough.path(path, rough_options(node, env))
  prepend(shape_svg, outline)
  outline
  .attr("class", "basic label-container")
  .attr("style", css_styles_text(node))
}

///|
/// The styles of a class in the hand-drawn look: only the stroke of its
/// box and its dividers take them, the hachure keeps its colour.
fn style_sketched_class_box(
  shape_svg : @dom.Element,
  rect : @dom.Element,
  styles : String,
) -> Unit {
  if rect.child_elements().get(1) is Some(stroke) {
    stroke.attr("style", styles) |> ignore
  }
  for child in shape_svg.child_elements() {
    if child.get_attr("class").unwrap_or("").split(" ").any(c => c == "divider") &&
      child.descendants(["path"]) is [path, ..] {
      path.attr("style", styles) |> ignore
    }
  }
}

///|
/// The copy of an entity that the hand-drawn look draws behind it in the
/// background colour, so that the hachure does not show what is under the
/// entity: drawn in the default look, with an id ending in `-background`.
/// The ER renderer moves it under the entity once the layout is done.
fn er_background_node(node : Node, env : Env) -> Node {
  let background = env.config.theme().text("background")
  {
    ..node,
    id: node.id + "-background",
    dom_id: node.dom_id + "-background",
    look: "default",
    css_styles: ["stroke: none", "fill: \{background}"],
  }
}
