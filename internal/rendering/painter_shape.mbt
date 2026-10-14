// What a diagram that draws its elements with the unified shapes but
// without `insertNode` needs besides the `Painter` (C4).

///|
/// Draw `node` into `parent` with the shape it names and return its
/// element: mermaid's `shapes[node.shape](parent, node, { config })`,
/// without what `insertNode` adds around a shape (the link, the look, the
/// tooltip). The node records its size and how to clip a line at its
/// outline.
pub fn Painter::draw_shape(
  self : Painter,
  parent : @dom.Element,
  node : Node,
) -> @dom.Element raise LayoutError {
  draw_shape(parent, node, self.env, self.data.direction)
}

///|
/// Mermaid's `intersect.rect`: where the line from the centre of a box
/// towards `point` leaves the box.
pub fn intersect_box(
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
  point : Point,
) -> Point {
  intersect_rect(x, y, width, height, point)
}
