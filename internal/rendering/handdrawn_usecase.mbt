// Use case diagram shapes in the hand-drawn look.

///|
/// The figure of an actor in the hand-drawn look: each part sketched by
/// rough.js and put first in the glyph group (the icon actor's frame
/// included; its symbol is appended as in the classic look).
fn draw_sketched_actor_glyph(
  group : @dom.Element,
  variant : String,
  node : Node,
  env : Env,
) -> Unit {
  let sketch_path = (d : String, class_name : String, hollow : Bool) => {
    let options = rough_options(node, env)
    if hollow {
      options.fill = "none"
    }
    let path = @rough.path(d, options)
    prepend(group, path)
    path.attr("class", class_name) |> ignore
  }
  match variant {
    "normal" => sketch_path(STICK_FIGURE_PATH, "usecase-actor-stick", false)
    "awesome" =>
      sketch_path(
        AWESOME_SILHOUETTE_PATH,
        "usecase-actor-awesome-silhouette",
        false,
      )
    "hollow" => {
      let options = rough_options(node, env)
      options.fill = "none"
      let head = @rough.circle(0.0, -23.0, 18.0, options)
      prepend(group, head)
      head.attr("class", "usecase-actor-hollow-head") |> ignore
      sketch_path(HOLLOW_BODY_PATH, "usecase-actor-hollow-body", true)
    }
    _ => {
      let frame = @rough.rectangle(
        -26.0,
        -28.0,
        52.0,
        52.0,
        rough_options(node, env),
      )
      prepend(group, frame)
      frame.attr("class", "usecase-actor-icon-frame") |> ignore
      // The symbol as the classic look draws it, after the frame.
      let classic = @dom.Element::new("g")
      draw_actor_glyph(classic, variant)
      if classic.child_elements().get(1) is Some(symbol) {
        symbol.remove()
        group.append_child(symbol)
      }
    }
  }
}

///|
/// An ellipse of the use case diagram in the hand-drawn look, put first.
fn sketched_ellipse(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  radius_x : Double,
  radius_y : Double,
  class_name : String,
) -> @dom.Element {
  let ellipse = @rough.ellipse(
    0.0,
    0.0,
    radius_x * 2.0,
    radius_y * 2.0,
    rough_options(node, env),
  )
  prepend(shape_svg, ellipse)
  ellipse.attr("class", class_name)
}

///|
/// A cell of a use case JSON table in the hand-drawn look, put first.
fn sketched_cell(
  container : @dom.Element,
  node : Node,
  env : Env,
  class_name : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @dom.Element {
  let cell = @rough.rectangle(x, y, width, height, rough_options(node, env))
  prepend(container, cell)
  cell.attr("class", class_name)
}

///|
/// The parts of a system boundary in the hand-drawn look: rough.js
/// rectangles in the colours of clusters unless the boundary has its own,
/// with a stroke one pixel wide unless styled.
fn sketched_boundary_part(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  class_name : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  let map = styles_map([..node.css_compiled_styles, ..node.css_styles])
  let pick = (name : String, fallback : String) => {
    match map.get(name) {
      Some(value) if value != "" => value
      _ => fallback
    }
  }
  let options = rough_options(node, env)
  options.fill = pick("fill", rough_color(env, "clusterBkg"))
  options.stroke = pick("stroke", rough_color(env, "clusterBorder"))
  options.stroke_width = match map.get("stroke-width") {
    Some(width) if width.replace(old="px", new="") != "" =>
      width.replace(old="px", new="")
    _ => "1"
  }
  let part = @rough.rectangle(x, y, width, height, options)
  prepend(shape_svg, part)
  part.attr("class", class_name) |> ignore
}
