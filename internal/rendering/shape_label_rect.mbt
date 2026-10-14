///|
/// A point-sized node that only holds a label: what a self loop is routed
/// around in the dagre layout. Mermaid's `labelRect` shape.
fn label_rect(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let labelled = label_helper(parent, node, "label", env)
  let rect = labelled.shape_svg
    .insert_first("rect")
    .attr("width", "0.1")
    .attr("height", "0.1")
  labelled.shape_svg.attr("class", "label edgeLabel") |> ignore
  let n = @dom.number
  let box = labelled.bbox
  labelled.label.attr(
    "transform",
    "translate(\{n(-(box.width / 2.0) - labelled.offset_x)}, \{n(-(box.height / 2.0) - labelled.offset_y)})",
  )
  |> ignore
  update_node_bounds(node, rect)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}
