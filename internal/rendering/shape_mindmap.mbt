// The shapes of mindmap nodes that no other diagram uses: mermaid's
// `defaultMindmapNode` and `mindmapCircle`.

///|
/// A node without brackets: a box with rounded corners and a line along
/// its bottom (in the neo look the bottom corners are square).
fn default_mindmap_node(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let half_padding = node.padding / 2.0
  let w = box.width + 8.0 * half_padding
  let h = box.height + 2.0 * half_padding
  let rd = 5.0
  let n = @dom.number
  // Upstream's template; the sanitizer trims the white space around it.
  let path = if node.look == "neo" {
    "M\{n(-w / 2.0)} \{n(h / 2.0 - rd)}\n" +
    "    v\{n(-h + 2.0 * rd)}\n" +
    "    q0,-\{n(rd)} \{n(rd)},-\{n(rd)}\n" +
    "    h\{n(w - 2.0 * rd)}\n" +
    "    q\{n(rd)},0 \{n(rd)},\{n(rd)}\n" +
    "    v\{n(h - rd)}\n" +
    "    H\{n(-w / 2.0)}\n" +
    "    Z"
  } else {
    "M\{n(-w / 2.0)} \{n(h / 2.0 - rd)}\n" +
    "    v\{n(-h + 2.0 * rd)}\n" +
    "    q0,-\{n(rd)} \{n(rd)},-\{n(rd)}\n" +
    "    h\{n(w - 2.0 * rd)}\n" +
    "    q\{n(rd)},0 \{n(rd)},\{n(rd)}\n" +
    "    v\{n(h - 2.0 * rd)}\n" +
    "    q0,\{n(rd)} \{n(-rd)},\{n(rd)}\n" +
    "    h\{n(-(w - 2.0 * rd))}\n" +
    "    q\{n(-rd)},0 \{n(-rd)},\{n(-rd)}\n" +
    "    Z"
  }
  // `node-` and the number of the node's type, which is that of a node
  // without brackets, 0, wherever this shape is drawn.
  let bg = labelled.shape_svg
    .append("path")
    .attr("id", node.dom_id)
    .attr("class", "node-bkg node-0")
    .attr("style", styles.node_styles)
    .attr("d", path)
  labelled.shape_svg
  .append("line")
  .attr("class", "node-line-")
  .attr_number("x1", -w / 2.0)
  .attr_number("y1", h / 2.0)
  .attr_number("x2", w / 2.0)
  .attr_number("y2", h / 2.0)
  |> ignore
  place_label_at(labelled, -box.width / 2.0, -box.height / 2.0)
  // The label goes last.
  labelled.label.remove()
  labelled.shape_svg.append_child(labelled.label)
  update_node_bounds(node, bg)
  node.intersect = Some(node_intersect_rect(node))
  labelled.shape_svg
}
