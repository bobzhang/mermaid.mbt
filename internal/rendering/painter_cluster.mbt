// What a diagram that places its own groups needs besides the `Painter`
// (kanban).

///|
/// Draw the frame of the group `node` into `parent` with the cluster
/// shape it names and return its element: mermaid's `insertCluster`. The
/// node records the size of its title (`label_box`) where the shape
/// measures one.
pub fn Painter::insert_cluster(
  self : Painter,
  parent : @dom.Element,
  node : Node,
) -> @dom.Element raise LayoutError {
  check_node_quote_depth(node)
  insert_cluster_shape(parent, node, self.env) |> ignore
  guard parent.child_elements().last() is Some(element) else {
    raise LayoutError("A cluster shape that draws nothing.")
  }
  node.element = Some(element)
  element
}
