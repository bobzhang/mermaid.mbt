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
  html_labels? : Bool,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let labelled = label_helper(
    parent,
    node,
    node_classes(node),
    env,
    html_labels?,
  )
  let total_width = (labelled.bbox.width + label_padding_x * 2.0).max(
    node.width.unwrap_or(0.0),
  )
  let total_height = (labelled.bbox.height + label_padding_y * 2.0).max(
    node.height.unwrap_or(0.0),
  )
  // The radii the shape rounds its corners by, else those the node came
  // with, if any.
  let (rx, ry) = match radius {
    Some(radius) if radius != 0.0 => (Some(radius), Some(radius))
    _ => (node.rx, node.ry)
  }
  if hand_drawn(node) {
    let outline = sketched_rect(
      labelled.shape_svg,
      node,
      env,
      -total_width / 2.0,
      -total_height / 2.0,
      total_width,
      total_height,
      rx,
      ry,
    )
    update_node_bounds(node, outline)
    node.intersect = Some(point => {
      intersect_rect(
        node.x,
        node.y,
        node.width.unwrap_or(0.0),
        node.height.unwrap_or(0.0),
        point,
      )
    })
    return labelled.shape_svg
  }
  let rect = labelled.shape_svg
    .insert_first("rect")
    .attr("class", "basic label-container")
    .attr("style", styles.node_styles)
  if rx is Some(rx) {
    rect.attr_number("rx", rx) |> ignore
  }
  if ry is Some(ry) {
    rect.attr_number("ry", ry) |> ignore
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
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let (w, h, points) = outline(labelled.bbox)
  let polygon = if hand_drawn(node) {
    sketched_polygon(
      labelled.shape_svg,
      node,
      env,
      styles,
      points,
      -w / 2.0,
      h / 2.0,
    )
  } else {
    insert_polygon(labelled.shape_svg, w, h, points)
  }
  if styles.node_styles != "" {
    polygon.attr("style", styles.node_styles) |> ignore
  }
  update_node_bounds(node, polygon)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A diamond: mermaid's `question`.
fn question(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
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
  let polygon = if hand_drawn(node) {
    sketched_polygon(
      labelled.shape_svg,
      node,
      env,
      styles,
      outline(s),
      -s / 2.0 + 0.5,
      s / 2.0,
    )
  } else {
    let n = @dom.number
    insert_polygon(labelled.shape_svg, s, s, outline(s)).attr(
      "transform",
      "translate(\{n(-s / 2.0 + 0.5)}, \{n(s / 2.0)})",
    )
  }
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
/// A circle around the label, `padding` away from its corners (by default
/// half the node's padding); `mindmapCircle` asks for the whole padding.
fn circle(
  parent : @dom.Element,
  node : Node,
  env : Env,
  padding? : Double,
) -> @dom.Element raise LayoutError {
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
    label_radius + padding.unwrap_or(node.padding / 2.0)
  }
  let element = if hand_drawn(node) {
    sketched_circle(labelled.shape_svg, node, env, radius)
  } else {
    labelled.shape_svg
    .insert_first("circle")
    .attr("class", "basic label-container")
    .attr("style", styles.node_styles)
    .attr_number("r", radius)
    .attr("cx", "0")
    .attr("cy", "0")
  }
  update_node_bounds(node, element)
  node.intersect = Some(point => intersect_ellipse(node, radius, radius, point))
  labelled.shape_svg
}

///|
/// Two concentric circles around the label.
fn double_circle(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
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
  if hand_drawn(node) {
    let group = sketched_double_circle(
      labelled.shape_svg,
      node,
      env,
      outer_radius,
      inner_radius,
    )
    update_node_bounds(node, group)
    node.intersect = Some(point => {
      intersect_ellipse(node, outer_radius, outer_radius, point)
    })
    return labelled.shape_svg
  }
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
/// `M x,y L x,y ... Z` through points: mermaid's `createPathFromPoints`.
fn path_from_points(points : Array[Point]) -> String {
  let n = @dom.number
  let parts = points.mapi((i, p) => {
    let command = if i == 0 { "M" } else { "L" }
    "\{command}\{n(p.x)},\{n(p.y)}"
  })
  parts.push("Z")
  parts.join(" ")
}

///|
/// Points on an arc, mirrored through the origin: mermaid's
/// `generateCirclePoints`. The right curly brace has its own copy that
/// does not mirror.
fn circle_points(
  center_x : Double,
  center_y : Double,
  radius : Double,
  count : Int32,
  start_angle : Double,
  end_angle : Double,
  mirrored~ : Bool = true,
) -> Array[Point] {
  let pi = 3.141592653589793
  let start = start_angle * pi / 180.0
  let end = end_angle * pi / 180.0
  let step = (end - start) / (count - 1).to_double()
  let points = []
  for i in 0..<count {
    let angle = start + i.to_double() * step
    let x = center_x + radius * @jsmath.cos(angle)
    let y = center_y + radius * @jsmath.sin(angle)
    points.push(if mirrored { { x: -x, y: -y, } } else { { x, y, } })
  }
  points
}

///|
/// Put `child` first among `parent`'s children: d3's
/// `insert(() => child, ':first-child')`.
fn prepend(parent : @dom.Element, child : @dom.Element) -> Unit {
  match parent.child_elements() {
    [first, ..] => parent.insert_before(child, first)
    [] => parent.append_child(child)
  }
}

///|
/// Style every path rough.js drew the way shapes do outside the hand-drawn
/// look: the node's own styles, replaced by the compiled ones when there
/// are any.
fn style_rough_paths(
  outline : @dom.Element,
  node : Node,
  styles : SplitStyles,
) -> Unit {
  // The hand-drawn look keeps the colours rough.js gave the paths.
  if hand_drawn(node) {
    return
  }
  style_paths(outline, node, styles)
}

///|
/// Style every path of an outline with the node's own styles, replaced by
/// the compiled ones when there are any, whatever the look.
fn style_paths(
  outline : @dom.Element,
  node : Node,
  styles : SplitStyles,
) -> Unit {
  // An array of styles is written as its comma-joined text.
  let css_styles = node.css_styles.join(",")
  for path in outline.descendants(["path"]) {
    path.attr("style", css_styles) |> ignore
    if styles.node_styles != "" {
      path.attr("style", styles.node_styles) |> ignore
    }
  }
}

///|
/// Insert an outline drawn by rough.js behind the label, with the classes
/// and styles shapes that always go through rough.js give it.
fn insert_rough_outline(
  shape_svg : @dom.Element,
  outline : @dom.Element,
  node : Node,
  styles : SplitStyles,
  classes~ : String = "basic label-container outer-path",
) -> @dom.Element {
  prepend(shape_svg, outline)
  outline.attr("class", classes) |> ignore
  style_rough_paths(outline, node, styles)
  outline
}

///|
/// A rectangle with half circles for sides.
fn stadium(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let padding_x = if neo { 40.0 } else { node.padding }
  let padding_y = if neo { 24.0 } else { node.padding }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let arc_points = 50
  let h = box.height + padding_y
  let inscribed = h *
    @jsmath.cos(3.141592653589793 / (2.0 * (arc_points - 1).to_double()))
  let cap_width = 0.0
    .max(inscribed * inscribed - box.height * box.height)
    .sqrt()
  let w = (box.width + h / 4.0 + padding_x)
    .max(1.5 * h + (h - inscribed))
    .max(box.width + padding_x + h - cap_width)
  let radius = h / 2.0
  let points = [
    { x: -w / 2.0 + radius, y: -h / 2.0, },
    { x: w / 2.0 - radius, y: -h / 2.0, },
    ..circle_points(-w / 2.0 + radius, 0.0, radius, arc_points, 90.0, 270.0),
    { x: w / 2.0 - radius, y: h / 2.0, },
    ..circle_points(w / 2.0 - radius, 0.0, radius, arc_points, 270.0, 450.0),
  ]
  let outline = insert_rough_outline(
    labelled.shape_svg,
    @rough.path(path_from_points(points), rough_options(node, env)),
    node,
    styles,
  )
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// A flag: a rectangle with a notch cut into its left side.
fn rect_left_inv_arrow(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let neo = node.look == "neo"
  let label_padding_x = if neo { 21.0 } else { node.padding }
  let label_padding_y = if neo { 12.0 } else { node.padding }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let label_width = box.width +
    (if neo { label_padding_x * 2.0 } else { label_padding_x })
  let h = (box.height +
  (if neo { label_padding_y * 2.0 } else { label_padding_y })).max(
    node.height.unwrap_or(0.0),
  )
  let notch_width = h / 4.0
  let w = label_width.max(node.width.unwrap_or(0.0) - notch_width)
  let x = -w / 2.0
  let y = -h / 2.0
  let notch = y / 2.0
  let points = [
    { x: x + notch, y, },
    { x, y: 0.0, },
    { x: x + notch, y: -y, },
    { x: -x, y: -y, },
    { x: -x, y, },
  ]
  let outline = insert_rough_outline(
    labelled.shape_svg,
    @rough.path(path_from_points(points), rough_options(node, env)),
    node,
    styles,
  )
  let n = @dom.number
  outline.attr("transform", "translate(\{n(-notch / 2.0)},0)") |> ignore
  labelled.label.attr(
    "transform",
    "translate(\{n(-notch / 2.0 - box.width / 2.0 - labelled.offset_x)}, \{n(-(box.height / 2.0) - labelled.offset_y)})",
  )
  |> ignore
  update_node_bounds(node, outline)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}

///|
/// Draw the outline and label of `node` with the shape it asks for.
fn draw_shape(
  parent : @dom.Element,
  node : Node,
  env : Env,
  dir : String,
) -> @dom.Element raise LayoutError {
  let neo = node.look == "neo"
  let padding = node.padding
  // Shapes that belong to one diagram type are not in the shape table.
  match node.shape {
    "erBox" => return er_box(parent, node, env)
    "requirementBox" => return requirement_box(parent, node, env)
    "classBox" => return class_box(parent, node, env)
    "block_arrow" => return block_arrow(parent, node, env)
    "kanbanItem" => return kanban_item(parent, node, env)
    "usecaseActor"
    | "usecaseActorHollow"
    | "usecaseActorAwesome"
    | "usecaseActorIcon"
    | "usecaseEllipse"
    | "usecaseBusiness"
    | "usecaseJsonTable" => return usecase_shape(parent, node, env)
    _ => ()
  }
  guard shape_handler(node.shape) is Some(handler) else {
    raise LayoutError("No such shape: \{node.shape}. Please check your syntax.")
  }
  match handler {
    "squareRect" => {
      let shape_svg = draw_rect(
        parent,
        node,
        usecase_label_env(node, env),
        label_padding_x=if neo { 16.0 } else { padding * 2.0 },
        label_padding_y=if neo { 12.0 } else { padding },
      )
      // A use case rectangle, and a group drawn as a node (one without
      // children, under dagre), keep their slot in the palette.
      stamp_color_slot(shape_svg, node.color_index, env)
      shape_svg
    }
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
    "person" => person(parent, node, env)
    "stadium" => stadium(parent, node, env)
    "rect_left_inv_arrow" => rect_left_inv_arrow(parent, node, env)
    "circle" => circle(parent, node, env)
    "mindmapCircle" => circle(parent, node, env, padding~)
    "defaultMindmapNode" => default_mindmap_node(parent, node, env)
    "doublecircle" => double_circle(parent, node, env)
    "text" => text_block(parent, node, env)
    "card" => card(parent, node, env)
    "shadedProcess" => shaded_process(parent, node, env)
    "dividedRectangle" => divided_rectangle(parent, node, env)
    "windowPane" => window_pane(parent, node, env)
    "multiRect" => multi_rect(parent, node, env)
    "taggedRect" => tagged_rect(parent, node, env)
    "datastore" => datastore(parent, node, env)
    "note" => note(parent, node, env)
    "composite" => composite(parent, node, env)
    "triangle" => triangle(parent, node, env, flipped=false)
    "flippedTriangle" => triangle(parent, node, env, flipped=true)
    "trapezoidalPentagon" => trapezoidal_pentagon(parent, node, env)
    "slopedRect" => sloped_rect(parent, node, env)
    "curvedTrapezoid" => curved_trapezoid(parent, node, env)
    "halfRoundedRectangle" => half_rounded_rectangle(parent, node, env)
    "bowTieRect" => bow_tie_rect(parent, node, env)
    "waveEdgedRectangle" => wave_edged_rectangle(parent, node, env)
    "linedWaveEdgedRect" => lined_wave_edged_rect(parent, node, env)
    "multiWaveEdgedRectangle" => multi_wave_edged_rectangle(parent, node, env)
    "waveRectangle" => wave_rectangle(parent, node, env)
    "taggedWaveEdgedRectangle" => tagged_wave_edged_rectangle(parent, node, env)
    "tiltedCylinder" => tilted_cylinder(parent, node, env)
    "linedCylinder" => lined_cylinder(parent, node, env)
    "curlyBraceLeft" | "curlyBraceRight" | "curlyBraces" =>
      curly_brace(parent, node, env, handler)
    "folder" => folder(parent, node, env)
    "bucket" => bucket(parent, node, env)
    "cloud" => cloud(parent, node, env)
    "bang" => bang(parent, node, env)
    "browser" => browser(parent, node, env)
    "consoleWindow" => console_window(parent, node, env)
    "stateStart" => state_start(parent, node, env)
    "stateEnd" => state_end(parent, node, env)
    "forkJoin" => fork_join(parent, node, env, dir)
    "hourglass" => hourglass(parent, node, env)
    "lightningBolt" => lightning_bolt(parent, node, env)
    "filledCircle" => filled_circle(parent, node, env)
    "crossedCircle" => crossed_circle(parent, node, env)
    "anchor" => anchor(parent, node, env)
    "choice" => choice(parent, node, env)
    "rectWithTitle" => rect_with_title(parent, node, env)
    "collapsedGroup" => collapsed_group(parent, node, env)
    "labelRect" => label_rect(parent, node, env)
    "icon" | "iconCircle" | "iconRounded" | "iconSquare" =>
      icon_shape(parent, node, env, handler)
    "imageSquare" => image_square(parent, node, env)
    "subroutine" if hand_drawn(node) => sketched_subroutine(parent, node, env)
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
    "hexagon" => {
      let f = if neo { 3.5 } else { 4.0 }
      let label_padding_x = if neo { 70.0 } else { padding }
      let label_padding_y = if neo { 32.0 } else { padding }
      // A node that comes with a size keeps it: the label gets what the
      // slanted sides and the padding leave.
      if has_size(node) {
        let original_height = node.height.unwrap_or(0.0)
        let m = original_height / f
        node.width = Some(node.width.unwrap_or(0.0) - 2.0 * m - label_padding_y)
        node.height = Some(original_height - label_padding_x)
      }
      polygon_shape(parent, node, env, box => {
        let h = size_or(node.height, box.height) + label_padding_x
        let m = h / f
        let w = size_or(node.width, box.width) + 2.0 * m + label_padding_y
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
    }
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
/// `insertNode`. `dir` is the direction of the flow around the node.
fn insert_node(
  parent : @dom.Element,
  node : Node,
  env : Env,
  dir : String,
) -> @dom.Element raise LayoutError {
  if node.shape == "rect" {
    // With or without rounded corners.
    node.shape = match (node.rx, node.ry) {
      (Some(rx), Some(ry)) if rx != 0.0 && ry != 0.0 => "roundedRect"
      _ => "squareRect"
    }
  }
  let (outer, inner) = match node.link {
    Some(link) => {
      // Upstream also sets `target`, which the final sanitizing pass strips
      // from SVG anchors again, as it does an address it does not allow.
      let anchor = parent.append("a")
      if allowed_uri(link) {
        anchor.attr("xlink:href", link) |> ignore
      }
      (anchor, draw_shape(anchor, node, env, dir))
    }
    None => {
      let element = draw_shape(parent, node, env, dir)
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
