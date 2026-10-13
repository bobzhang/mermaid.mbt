///|
/// What a diagram renderer works with: the `<svg>` element to draw into
/// and the configuration in effect.
pub struct Context {
  /// The id of the `<svg>` element; ids inside the diagram derive from it.
  id : String
  config : @config.Config
  /// The root `<svg>` element.
  svg : @dom.Element
}

///|
pub fn Context::new(
  id : String,
  config : @config.Config,
  svg : @dom.Element,
) -> Context {
  { id, config, svg, }
}

///|
/// The theme variables in effect.
pub fn Context::theme(self : Context) -> @theme.Theme {
  self.config.theme()
}

///|
/// The font stack text in this diagram is measured with.
pub fn Context::font(
  self : Context,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> @font.Stack {
  ignore(self)
  @font.Stack::default(bold~, italic~)
}

///|
/// Size the `<svg>` element, like mermaid's `configureSvgSize`: either
/// responsive with a maximum width, or fixed.
pub fn configure_svg_size(
  svg : @dom.Element,
  height : Double,
  width : Double,
  use_max_width : Bool,
) -> Unit {
  if use_max_width {
    svg
    .attr("width", "100%")
    .attr("style", "max-width: \{@dom.number(width)}px;")
    |> ignore
  } else {
    svg.attr_number("height", height).attr_number("width", width) |> ignore
  }
}

///|
/// mermaid's `parseFontSize`: the leading integer of a size such as
/// `"17px"`, like JavaScript's `parseInt`.
pub fn parse_font_size(size : String) -> Double? {
  let text = size.trim().to_owned()
  let mut value = 0.0
  let mut digits = 0
  let mut negative = false
  for i, c in text {
    if i == 0 && (c == '-' || c == '+') {
      negative = c == '-'
      continue
    }
    guard c is ('0'..<='9') else { break }
    value = value * 10.0 + (c.to_int() - '0').to_double()
    digits += 1
  }
  if digits == 0 {
    None
  } else if negative {
    Some(-value)
  } else {
    Some(value)
  }
}

///|
/// `Number.prototype.toFixed(0)`: round to an integer, halves away from
/// zero.
pub fn to_fixed0(value : Double) -> String {
  let rounded = if value < 0.0 {
    -(-value + 0.5).floor()
  } else {
    (value + 0.5).floor()
  }
  @dom.number(rounded)
}
