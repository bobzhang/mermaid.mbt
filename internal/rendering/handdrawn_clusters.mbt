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
