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
  /// What shapes of one diagram type draw besides the label.
  data : NodeData
  /// The corner radii a diagram asks for; a `rect` with both is rounded.
  rx : Double?
  ry : Double?
  /// Whether the label is centred by its box whatever kind it is.
  center_label : Bool
  /// The width labels wrap at, when the diagram sets its own.
  wrapping_width : Double?
  /// The lines under the title of a state with a description.
  description : Array[String]
  /// The icon the node shows, which gives its label a background.
  icon : String?
  /// Whether ELK spreads the ports of the node around its centre.
  spread_ports : Bool
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
  data~ : NodeData = Plain,
  rx? : Double,
  ry? : Double,
  center_label~ : Bool = false,
  wrapping_width? : Double,
  description~ : Array[String] = [],
  icon? : String,
  spread_ports~ : Bool = false,
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
    data,
    rx,
    ry,
    center_label,
    wrapping_width,
    description,
    icon,
    spread_ports,
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
  /// `edge.animate` is truthy: the edge has the fast animation's class.
  animate : Bool
  /// `edge.animate === true`: the edge counts as animated, which keeps the
  /// neo look's dashes and marker margins off it.
  animate_is_true : Bool
  animation : String?
  /// The labels at the two ends of the edge, on the left and on the
  /// right of its direction.
  start_label_left : String
  start_label_right : String
  end_label_left : String
  end_label_right : String
  /// How many ranks the edge spans at least, and where its label goes
  /// along it (`l`, `c` or `r`), for the dagre layout; `None` when the
  /// diagram leaves them unset. A length that is not a number is one set
  /// to `undefined`.
  minlen : Double?
  labelpos : String?
  // Filled in while measuring and laying out.
  priv terminals : Array[TerminalLabel]
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
  animate_is_true? : Bool,
  animation? : String,
  start_label_left~ : String = "",
  start_label_right~ : String = "",
  end_label_left~ : String = "",
  end_label_right~ : String = "",
  minlen? : Double,
  labelpos? : String,
  curve~ : String = "",
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
    animate_is_true: animate_is_true.unwrap_or(animate),
    animation,
    start_label_left,
    start_label_right,
    end_label_left,
    end_label_right,
    minlen,
    labelpos,
    terminals: [],
    label_style: "",
    curve,
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
  /// Whether the diagram's stylesheet anchors the SVG text of node labels
  /// in the middle, as the flowchart's does.
  node_text_centred : Bool
  /// Whether the label being measured is bold or italic as a whole.
  bold : Bool
  italic : Bool
  /// What loads the images of image shapes: their bytes by URL, `None`
  /// for one that cannot be loaded (see `@mermaid.render`).
  image_loader : ((String) -> Bytes?)?
}

///|
fn Env::new(config : @config.Config, diagram_id : String) -> Env {
  let theme = config.theme()
  let size = match theme.get("fontSize") {
    // A number without a unit is no CSS length: the stylesheet's
    // `font-size` is dropped and text keeps the browser's size.
    Number(_, ..) => 16.0
    String(text) =>
      // The leading number as CSS writes one: `15.5px` is 15.5 pixels,
      // `+12px` and `1.2e1px` are 12.
      match @dom.css_dimension(text) {
        // A negative size is invalid: the browser's stays. Zero, with a
        // unit or without, is a size.
        Some((value, _)) if value >= 0.0 => value
        _ => 16.0
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
    node_text_centred: true,
    bold: false,
    italic: false,
    image_loader: None,
  }
}

///|
/// The stack that measures label text.
fn Env::font(
  self : Env,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> @font.Stack {
  @font.Stack::for_family(
    self.font_family,
    bold=bold || self.bold,
    italic=italic || self.italic,
  )
}
