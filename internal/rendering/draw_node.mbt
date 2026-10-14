///|
/// The type a node's label is set in, for diagrams whose stylesheet gives
/// their nodes a font of their own.
pub(all) struct LabelFont {
  /// A CSS `font-family` list.
  family : String
  /// The size in pixels.
  size : Double
  bold : Bool
}

///|
/// Draw `node` into `parent` with the shape it names and return its
/// element: what diagrams that lay out their nodes themselves do with
/// mermaid's `shapes[node.shape](parent, node, { config })`. The node comes
/// back with its size and the function that clips lines against it.
///
/// `font` is the type the diagram's stylesheet sets the label in, the
/// theme's when not given.
pub fn draw_node(
  parent : @dom.Element,
  node : Node,
  config~ : @config.Config,
  diagram_id~ : String,
  font? : LabelFont,
) -> @dom.Element raise LayoutError {
  let env = Env::new(config, diagram_id)
  let env = match font {
    Some(font) =>
      {
        ..env,
        font_family: font.family,
        font_size: font.size,
        bold: font.bold,
      }
    None => env
  }
  if node.look == "handDrawn" {
    raise LayoutError("The hand-drawn look is not supported yet.")
  }
  draw_shape(parent, node, env, "TB")
}

///|
/// Where the line from the node's centre towards `point` leaves its
/// outline. The node must have been drawn.
pub fn Node::intersection(self : Node, point : Point) -> Point {
  match self.intersect {
    Some(intersect) => intersect(point)
    None => point
  }
}

///|
/// Move a drawn node: its centre is what its outline is clipped around.
pub fn Node::set_position(self : Node, x : Double, y : Double) -> Unit {
  self.x = x
  self.y = y
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
