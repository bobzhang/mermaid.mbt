// The shapes only block diagrams draw: mermaid's `blockArrow.ts`.

///|
/// The outline of an arrow pointing in `directions` around a label box:
/// mermaid's `getArrowPoints`. `x` and `y` stand for both directions of
/// their axis; a direction named twice counts once.
fn arrow_points(
  directions : Array[String],
  box : LabelBox,
  node_padding : Double,
  total_width : Double,
) -> Array[Point] {
  let unique : Array[String] = []
  let add = (direction : String) => {
    if !unique.contains(direction) {
      unique.push(direction)
    }
  }
  for direction in directions {
    match direction {
      "x" => {
        add("right")
        add("left")
      }
      "y" => {
        add("up")
        add("down")
      }
      other => add(other)
    }
  }
  let key = ["right", "left", "up", "down"]
    .filter(direction => unique.contains(direction))
    .join("|")
  let p = node_padding / 2.0
  let h = box.height + 4.0 * p
  let m = h / 2.0
  let w = total_width
  match key {
    "right|left|up|down" =>
      [
        { x: 0.0, y: 0.0, },
        { x: m, y: 0.0, },
        { x: w / 2.0, y: 2.0 * p, },
        { x: w - m, y: 0.0, },
        { x: w, y: 0.0, },
        { x: w, y: -h / 3.0, },
        { x: w + 2.0 * p, y: -h / 2.0, },
        { x: w, y: -2.0 * h / 3.0, },
        { x: w, y: -h, },
        { x: w - m, y: -h, },
        { x: w / 2.0, y: -h - 2.0 * p, },
        { x: m, y: -h, },
        { x: 0.0, y: -h, },
        { x: 0.0, y: -2.0 * h / 3.0, },
        { x: -2.0 * p, y: -h / 2.0, },
        { x: 0.0, y: -h / 3.0, },
      ]
    "right|left|up" =>
      [
        { x: m, y: 0.0, },
        { x: w - m, y: 0.0, },
        { x: w, y: -h / 2.0, },
        { x: w - m, y: -h, },
        { x: m, y: -h, },
        { x: 0.0, y: -h / 2.0, },
      ]
    "right|left|down" =>
      [
        { x: 0.0, y: 0.0, },
        { x: m, y: -h, },
        { x: w - m, y: -h, },
        { x: w, y: 0.0, },
      ]
    "right|up|down" =>
      [
        { x: 0.0, y: 0.0, },
        { x: w, y: -m, },
        { x: w, y: -h + m, },
        { x: 0.0, y: -h, },
      ]
    "left|up|down" =>
      [
        { x: w, y: 0.0, },
        { x: 0.0, y: -m, },
        { x: 0.0, y: -h + m, },
        { x: w, y: -h, },
      ]
    "right|left" =>
      [
        { x: m, y: 0.0, },
        { x: m, y: -p, },
        { x: w - m, y: -p, },
        { x: w - m, y: 0.0, },
        { x: w, y: -h / 2.0, },
        { x: w - m, y: -h, },
        { x: w - m, y: -h + p, },
        { x: m, y: -h + p, },
        { x: m, y: -h, },
        { x: 0.0, y: -h / 2.0, },
      ]
    "up|down" =>
      [
        { x: w / 2.0, y: 0.0, },
        { x: 0.0, y: -p, },
        { x: m, y: -p, },
        { x: m, y: -h + p, },
        { x: 0.0, y: -h + p, },
        { x: w / 2.0, y: -h, },
        { x: w, y: -h + p, },
        { x: w - m, y: -h + p, },
        { x: w - m, y: -p, },
        { x: w, y: -p, },
      ]
    "right|up" => [{ x: 0.0, y: 0.0, }, { x: w, y: -m, }, { x: 0.0, y: -h, }]
    "right|down" => [{ x: 0.0, y: 0.0, }, { x: w, y: 0.0, }, { x: 0.0, y: -h, }]
    "left|up" => [{ x: w, y: 0.0, }, { x: 0.0, y: -m, }, { x: w, y: -h, }]
    "left|down" => [{ x: w, y: 0.0, }, { x: 0.0, y: 0.0, }, { x: w, y: -h, }]
    "right" =>
      [
        { x: m, y: -p, },
        { x: m, y: -p, },
        { x: w - m, y: -p, },
        { x: w - m, y: 0.0, },
        { x: w, y: -h / 2.0, },
        { x: w - m, y: -h, },
        { x: w - m, y: -h + p, },
        { x: m, y: -h + p, },
        { x: m, y: -h + p, },
      ]
    "left" =>
      [
        { x: m, y: 0.0, },
        { x: m, y: -p, },
        { x: w - m, y: -p, },
        { x: w - m, y: -h + p, },
        { x: m, y: -h + p, },
        { x: m, y: -h, },
        { x: 0.0, y: -h / 2.0, },
      ]
    "up" =>
      [
        { x: m, y: -p, },
        { x: m, y: -h + p, },
        { x: 0.0, y: -h + p, },
        { x: w / 2.0, y: -h, },
        { x: w, y: -h + p, },
        { x: w - m, y: -h + p, },
        { x: w - m, y: -p, },
      ]
    "down" =>
      [
        { x: w / 2.0, y: 0.0, },
        { x: 0.0, y: -p, },
        { x: m, y: -p, },
        { x: m, y: -h + p, },
        { x: w - m, y: -h + p, },
        { x: w - m, y: -p, },
        { x: w, y: -p, },
      ]
    // No direction the shape knows: a single point.
    _ => [{ x: 0.0, y: 0.0, }]
  }
}

///|
/// An arrow around the label, pointing where the block says: mermaid's
/// `block_arrow`.
fn block_arrow(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let (positioned, directions, width_in_columns, style) = match node.data {
    Block(positioned~, directions~, width_in_columns~, style~) =>
      (positioned, directions, width_in_columns, Some(style))
    _ => (false, [], 1.0, None)
  }
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let height = box.height + 2.0 * node.padding
  let midpoint = height / 2.0
  let natural_width = box.width + 2.0 * midpoint + node.padding
  let node_width = node.width.unwrap_or(0.0)
  // An arrow spanning several columns is as wide as they are.
  let spanning = positioned &&
    width_in_columns > 1.0 &&
    node_width > natural_width
  let width = if spanning { node_width } else { natural_width }
  let points = arrow_points(directions, box, node.padding, width)
  let polygon = insert_polygon(labelled.shape_svg, width, height, points)
  if style is Some(style) {
    polygon.attr("style", style) |> ignore
  }
  update_node_bounds(node, polygon)
  node.intersect = Some(point => intersect_polygon(node, points, point))
  labelled.shape_svg
}
