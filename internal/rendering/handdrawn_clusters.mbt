// Frames of groups in the hand-drawn look.

///|
/// The frame of a subgraph in the hand-drawn look: a sketched rectangle
/// (a rounded one with no radius) hachured in the colours of clusters. The
/// strokes take the group's border styles, the hachure its background
/// colour as a stroke.
fn sketched_cluster_rect(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @dom.Element {
  let theme = env.config.theme()
  let options = rough_options(node, env)
  options.fill = theme.text("clusterBkg")
  options.stroke = theme.text("clusterBorder")
  options.fill_weight = 3.0
  let frame = @rough.path(rounded_rect_path(x, y, width, height, 0.0), options)
  prepend(shape_svg, frame)
  let (border, background) = border_and_background(node)
  let paths = frame.child_elements()
  if paths.get(1) is Some(path) {
    path.attr("style", border) |> ignore
  }
  if paths.get(0) is Some(path) {
    path.attr("style", background.replace(old="fill", new="stroke")) |> ignore
  }
  frame
}

///|
/// A theme colour for rough.js: none when the theme leaves it undefined.
fn rough_color(env : Env, name : String) -> String {
  match env.config.theme().get(name) {
    String(color) => color
    _ => ""
  }
}

///|
/// The seed of the hand-drawn look.
fn hand_drawn_seed(env : Env) -> Int32 {
  env.config.number("handDrawnSeed").unwrap_or(0.0).to_int()
}

///|
/// A composite state of the hand-drawn look: a sketched frame (with
/// rounded corners filled in the title colour when the node has radii, a
/// rough black rectangle otherwise) put first, and a sketched body
/// appended last; the alternative body of a concurrent state is hachured.
/// Returns the frame, the element the layout measures.
fn sketched_rounded_with_title(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  inner_y : Double,
  inner_height : Double,
) -> @dom.Element {
  let seed = hand_drawn_seed(env)
  let alt = node.css_classes.contains("statediagram-cluster-alt")
  let rounded = node.rx.unwrap_or(0.0) != 0.0 || node.ry.unwrap_or(0.0) != 0.0
  let outer_options = @rough.Options::new()
  outer_options.seed = seed
  let outer = if rounded {
    outer_options.roughness = 0.7
    outer_options.fill = rough_color(env, "compositeTitleBackground")
    outer_options.fill_style = "solid"
    outer_options.stroke = rough_color(env, "nodeBorder")
    @rough.path(rounded_rect_path(x, y, width, height, 10.0), outer_options)
  } else {
    @rough.rectangle(x, y, width, height, outer_options)
  }
  let inner_options = @rough.Options::new()
  inner_options.fill = rough_color(
    env,
    if alt {
      "altBackground"
    } else {
      "compositeBackground"
    },
  )
  inner_options.fill_style = if alt { "hachure" } else { "solid" }
  inner_options.stroke = rough_color(env, "nodeBorder")
  inner_options.seed = seed
  let inner = @rough.rectangle(x, inner_y, width, inner_height, inner_options)
  prepend(shape_svg, outer)
  shape_svg.append_child(inner)
  outer.attr("class", "outer") |> ignore
  inner.attr("class", "inner") |> ignore
  outer
}

///|
/// A region of a composite state in the hand-drawn look: a dashed sketched
/// rectangle, plainly filled.
fn sketched_divider(
  shape_svg : @dom.Element,
  env : Env,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @dom.Element {
  let options = @rough.Options::new()
  options.fill = match env.config.theme().get("altBackground") {
    String(color) => color
    _ => "#efefef"
  }
  options.fill_style = "solid"
  options.roughness = 0.5
  options.stroke_line_dash = Some([5.0])
  options.stroke = rough_color(env, "nodeBorder")
  options.seed = hand_drawn_seed(env)
  let frame = @rough.rectangle(x, y, width, height, options)
  prepend(shape_svg, frame)
  frame.attr("class", "divider")
}

///|
/// An agentflow container in the hand-drawn look: an unfilled sketched
/// frame with rounded corners. Its second path, which an unfilled frame
/// does not have, would take the border styles.
fn sketched_flow_group(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  stroke : String,
) -> @dom.Element {
  let options = rough_options(node, env)
  options.roughness = 0.7
  options.fill = "none"
  options.stroke = stroke
  options.stroke_width = "0.75"
  options.fill_weight = 0.0
  let frame = @rough.path(rounded_rect_path(x, y, width, height, 10.0), options)
  prepend(shape_svg, frame)
  if frame.child_elements().get(1) is Some(path) {
    path.attr("style", border_and_background(node).0) |> ignore
  }
  frame
}
