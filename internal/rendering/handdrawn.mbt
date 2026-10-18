// The hand-drawn look (`look: handDrawn`): rough.js sketches outlines,
// fills them with hachure lines and draws edges as wobbly curves. Its
// output is random unless `handDrawnSeed` is set; with no seed the port
// draws a repeatable stand-in (see `@rough.Options`).

///|
fn hand_drawn(node : Node) -> Bool {
  node.look == "handDrawn"
}

///|
/// The options mermaid's `userNodeOverrides` adds to rough.js's defaults
/// besides the colours: a light roughness and a dense hachure fill. Shapes
/// outside the hand-drawn look replace the first two by `roughness: 0` and
/// `fillStyle: 'solid'`.
fn sketch_fill(options : @rough.Options) -> Unit {
  options.roughness = 0.7
  options.fill_style = "hachure"
  options.fill_weight = 1.5
  options.hachure_gap = 1.5
  options.fill_line_dash = Some([0.0, 0.0])
}

///|
/// The outline of a rectangle in the hand-drawn look: `drawRect` sketches
/// a rectangle, or a path with arcs when the corners are rounded.
fn sketched_rect(
  shape_svg : @dom.Element,
  node : Node,
  env : Env,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double?,
  ry : Double?,
) -> @dom.Element {
  let options = rough_options(node, env)
  let radius = match (rx, ry) {
    (Some(rx), _) if rx != 0.0 => Some(rx)
    (_, Some(ry)) if ry != 0.0 => Some(rx.unwrap_or(0.0))
    _ => None
  }
  let outline = match radius {
    Some(radius) =>
      @rough.path(rounded_rect_path(x, y, width, height, radius), options)
    None => @rough.rectangle(x, y, width, height, options)
  }
  prepend(shape_svg, outline)
  outline
  .attr("class", "basic label-container")
  .attr("style", node.css_styles.join(","))
}

///|
/// An edge of the hand-drawn look: its path data redrawn by rough.js with
/// a little roughness, appended to `group` as the `<path>` rough.js made,
/// stroke attributes included. The stroke colour that marks the edge's
/// markers is then the whole first `stroke:` declaration of its styles.
fn sketched_edge(
  group : @dom.Element,
  line_path : String,
  edge : Edge,
  data : LayoutData,
) -> (@dom.Element, String?) {
  let options = @rough.Options::new()
  options.roughness = 0.3
  options.seed = data.config.number("handDrawnSeed").unwrap_or(0.0).to_int()
  let sketch = @rough.path(line_path, options)
  let path = match sketch.child_elements() {
    [path, ..] => path
    [] => @dom.Element::new("path")
  }
  path.remove()
  group.append_child(path)
  let stroke_color = edge.style
    .iter()
    .find_first(style => style.has_prefix("stroke:"))
  (path, stroke_color)
}

///|
/// `{ ...options, fillStyle: 'solid' }`.
fn solid_options(options : @rough.Options) -> @rough.Options {
  let copy = options.copy()
  copy.fill_style = "solid"
  copy
}

///|
/// Move every element whose id holds `-background` to where the element
/// of the id without it went: what the ER renderer does after the layout
/// for the background copies the hand-drawn look draws behind entities.
pub fn place_background_nodes(svg : @dom.Element) -> Unit {
  let found = []
  fn visit(element : @dom.Element) {
    for child in element.child_elements() {
      if child.get_attr("id") is Some(id) && id.contains("-background") {
        found.push(child)
      }
      visit(child)
    }
  }

  visit(svg)
  for element in found {
    guard element.get_attr("id") is Some(id) else { continue }
    let original = id.replace(old="-background", new="")
    if svg.find_by_id(original) is Some(target) &&
      target.get_attr("transform") is Some(transform) {
      element.attr("transform", transform) |> ignore
    }
  }
}
