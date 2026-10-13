///|
/// A node handed to the layout and drawn by a shape: mermaid's
/// `rendering-util` `Node`.
pub struct Node {
  id : String
  /// Shapes that show no text clear it.
  mut label : String
  /// `text`, `string` or `markdown`.
  label_type : String
  parent_id : String?
  padding : Double
  css_styles : Array[String]
  css_compiled_styles : Array[String]
  css_classes : String
  dir : String?
  mut dom_id : String
  look : String
  is_group : Bool
  mut shape : String
  min_width : Double?
  /// Position of a subgraph in declaration order, for palette themes.
  color_index : Int32?
  link : String?
  link_target : String?
  tooltip : String?
  have_callback : Bool
  // Filled in while measuring and laying out.
  mut label_style : String
  mut width : Double?
  mut height : Double?
  /// The centre of the node.
  mut x : Double
  mut y : Double
  /// The size of a group's title.
  mut label_box : (Double, Double)?
  mut element : @dom.Element?
  /// Where a line from the centre towards a point leaves the shape.
  mut intersect : ((Point) -> Point)?
}

///|
pub fn Node::new(
  id~ : String,
  label~ : String,
  label_type~ : String = "text",
  parent_id? : String,
  padding~ : Double,
  css_styles~ : Array[String] = [],
  css_compiled_styles~ : Array[String] = [],
  css_classes~ : String = "",
  dir? : String,
  dom_id? : String,
  look~ : String,
  is_group~ : Bool = false,
  shape~ : String,
  min_width? : Double,
  color_index? : Int32,
  link? : String,
  link_target? : String,
  tooltip? : String,
  have_callback~ : Bool = false,
) -> Node {
  {
    id,
    label,
    label_type,
    parent_id,
    padding,
    css_styles,
    css_compiled_styles,
    css_classes,
    dir,
    dom_id: dom_id.unwrap_or(id),
    look,
    is_group,
    shape,
    min_width,
    color_index,
    link,
    link_target,
    tooltip,
    have_callback,
    label_style: "",
    width: None,
    height: None,
    x: 0.0,
    y: 0.0,
    label_box: None,
    element: None,
    intersect: None,
  }
}

///|
/// The same node with other styling.
pub fn Node::with_styles(
  self : Node,
  css_styles~ : Array[String],
  css_compiled_styles~ : Array[String],
  css_classes~ : String,
) -> Node {
  { ..self, css_styles, css_compiled_styles, css_classes, }
}

///|
/// A point of an edge's route.
pub(all) struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
/// An edge handed to the layout: mermaid's `rendering-util` `Edge`.
pub struct Edge {
  id : String
  start : String
  end : String
  mut label : String
  label_type : String
  /// `normal`, `thick`, `dotted` or `invisible`.
  thickness : String
  pattern : String
  classes : String
  arrow_type_start : String
  arrow_type_end : String
  css_compiled_styles : Array[String]
  style : Array[String]
  look : String
  animate : Bool
  animation : String?
  // Filled in while measuring and laying out.
  mut label_style : String
  mut curve : String
  mut points : Array[Point]
  /// The size of the label, zero without one.
  mut width : Double
  mut height : Double
  /// The centre of the label.
  mut position : Point?
}

///|
pub fn Edge::new(
  id~ : String,
  start~ : String,
  end~ : String,
  label~ : String = "",
  label_type~ : String = "text",
  thickness~ : String = "normal",
  pattern~ : String = "normal",
  classes~ : String = "",
  arrow_type_start~ : String = "none",
  arrow_type_end~ : String = "none",
  css_compiled_styles~ : Array[String] = [],
  style~ : Array[String] = [],
  look~ : String,
  animate~ : Bool = false,
  animation? : String,
) -> Edge {
  {
    id,
    start,
    end,
    label,
    label_type,
    thickness,
    pattern,
    classes,
    arrow_type_start,
    arrow_type_end,
    css_compiled_styles,
    style,
    look,
    animate,
    animation,
    label_style: "",
    curve: "",
    points: [],
    width: 0.0,
    height: 0.0,
    position: None,
  }
}

///|
/// Everything the unified renderer needs to lay out and draw a diagram.
pub(all) struct LayoutData {
  nodes : Array[Node]
  edges : Array[Edge]
  config : @config.Config
  /// The diagram type, part of marker ids.
  diagram_type : String
  diagram_id : String
  /// `TB`, `BT`, `LR` or `RL`.
  direction : String
  markers : Array[String]
}

///|
/// What shapes and labels need from the diagram being drawn.
priv struct Env {
  config : @config.Config
  /// The id of the `<svg>` element, which prefixes the ids of its filters.
  diagram_id : String
  font_family : String
  font_size : Double
  /// Whether labels are HTML in a `foreignObject` or SVG text.
  html_labels : Bool
}

///|
fn Env::new(config : @config.Config, diagram_id : String) -> Env {
  let theme = config.theme()
  let size = match theme.get("fontSize") {
    Number(n, ..) => n
    String(text) => {
      let mut value = 0.0
      for c in text {
        guard c is ('0'..<='9') else { break }
        value = value * 10.0 + (c.to_int() - '0').to_double()
      }
      if value == 0.0 {
        16.0
      } else {
        value
      }
    }
    _ => 16.0
  }
  let html_labels = match config.get("htmlLabels") {
    Null =>
      match config.get("flowchart.htmlLabels") {
        Null => true
        value => @config.evaluate(value)
      }
    value => @config.evaluate(value)
  }
  {
    config,
    diagram_id,
    font_family: theme.text("fontFamily"),
    font_size: size,
    html_labels,
  }
}

///|
/// The stack that measures label text.
fn Env::font(
  self : Env,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> @font.Stack {
  @font.Stack::for_family(self.font_family, bold~, italic~)
}
