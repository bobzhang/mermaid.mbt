///|
/// The `c4` section of the configuration, as the renderer reads it.
priv struct Conf {
  diagram_margin_x : Double
  diagram_margin_y : Double
  shape_margin : Double
  shape_padding : Double
  /// The size shapes are drawn at unless their label needs more.
  width : Double
  height : Double
  next_line_padding_x : Double
  /// Whether texts of boundaries and relationships may wrap.
  wrap : Bool
  use_max_width : Bool
  boundary_font : Font
  message_font : Font
}

///|
fn Conf::new(config : @config.Config) -> Conf raise Unsupported {
  let number = (key : String) => {
    match config.get("c4.\{key}") {
      Number(value, ..) => value
      other => raise Unsupported("C4: c4.\{key} \{other.stringify()}")
    }
  }
  // Upstream picks how texts are drawn by a key the schema does not have.
  if !(config.get("c4.textPlacement") is Null) {
    raise Unsupported("C4: c4.textPlacement")
  }
  {
    diagram_margin_x: number("diagramMarginX"),
    diagram_margin_y: number("diagramMarginY"),
    shape_margin: number("c4ShapeMargin"),
    shape_padding: number("c4ShapePadding"),
    width: number("width"),
    height: number("height"),
    next_line_padding_x: number("nextLinePaddingX"),
    wrap: config.flag("c4.wrap"),
    use_max_width: config.flag("c4.useMaxWidth"),
    boundary_font: configured_font(config, "boundary"),
    message_font: configured_font(config, "message"),
  }
}
