///|
/// `(look === 'handDrawn' ? 'rough-node' : 'node') + ' ' + cssClasses + ' '`
fn node_classes(node : Node) -> String {
  let base = if node.look == "handDrawn" { "rough-node" } else { "node" }
  "\{base} \{node.css_classes} "
}

///|
/// A rectangle around the label, mermaid's `drawRect`.
fn draw_rect(
  parent : @dom.Element,
  node : Node,
  env : Env,
  label_padding_x~ : Double,
  label_padding_y~ : Double,
) -> @dom.Element {
  let styles = node_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let total_width = (labelled.bbox.width + label_padding_x * 2.0).max(
    node.width.unwrap_or(0.0),
  )
  let total_height = (labelled.bbox.height + label_padding_y * 2.0).max(
    node.height.unwrap_or(0.0),
  )
  labelled.shape_svg
  .insert_first("rect")
  .attr("class", "basic label-container")
  .attr("style", styles.node_styles)
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
/// Draw `node` with its shape into `parent` and return its element:
/// mermaid's `insertNode`.
fn insert_node(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  if node.shape == "rect" {
    node.shape = "squareRect"
  }
  let neo = node.look == "neo"
  let element = match node.shape {
    _ =>
      draw_rect(
        parent,
        node,
        env,
        label_padding_x=if neo { 16.0 } else { node.padding * 2.0 },
        label_padding_y=if neo { 12.0 } else { node.padding },
      )
  }
  element.attr("data-look", node.look) |> ignore
  if node.tooltip is Some(tooltip) {
    element.attr("title", tooltip) |> ignore
  }
  if node.have_callback {
    element.attr(
      "class",
      element.get_attr("class").unwrap_or("") + " clickable",
    )
    |> ignore
  }
  node.element = Some(element)
  element
}
