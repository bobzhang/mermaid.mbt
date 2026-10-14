// What the chart builder hands to the renderer: groups of rectangles,
// texts and paths, each under a path of nested `<g>` elements.

///|
priv struct Rect {
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
}

///|
fn Rect::new() -> Rect {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
}

///|
priv struct RectData {
  x : Double
  /// Absent where a bar has no value: the attribute is then left out.
  y : Double?
  width : Double
  height : Double
  fill : String
  stroke_fill : String
  stroke_width : Double
}

///|
priv struct TextData {
  text : String
  /// The position as JavaScript prints it, which for a point without a
  /// place on its axis is not a number.
  x : String
  y : String
  fill : String
  font_size : Double
  rotation : Double
  /// `top` or `middle`
  vertical_pos : String
  /// `left`, `center` or `right`
  horizontal_pos : String
}

///|
priv struct PathData {
  path : String
  stroke_fill : String
  stroke_width : Double
}

///|
priv enum Shapes {
  Rects(Array[RectData])
  Texts(Array[TextData])
  Paths(Array[PathData])
}

///|
priv struct Drawable {
  /// The classes of the nested groups the shapes go into.
  groups : Array[String]
  shapes : Shapes
}

///|
/// A scale value in arithmetic: one the scale has no value for is not a
/// number.
fn or_nan(value : Double?) -> Double {
  value.unwrap_or(@double.not_a_number)
}

///|
/// A scale value as JavaScript prints it in a template string.
fn printed(value : Double?) -> String {
  match value {
    Some(value) => @dom.number(value)
    None => "undefined"
  }
}
