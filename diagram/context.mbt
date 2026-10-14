///|
/// What a diagram renderer works with: the `<svg>` element to draw into
/// and the configuration in effect.
pub struct Context {
  /// The id of the `<svg>` element; ids inside the diagram derive from it.
  id : String
  config : @config.Config
  /// The root `<svg>` element.
  svg : @dom.Element
  /// The moment of rendering, in milliseconds since the epoch: what
  /// `new Date()` is to a diagram that shows the present.
  now : Double
  /// The page the diagram is rendered in.
  page : Page
}

///|
/// The page a diagram is rendered in, for the diagrams whose geometry
/// depends on it.
///
/// mermaid renders into a block element appended to the body, holding an
/// `<svg width="100%">`. A Gantt chart takes the width of that element as
/// its own, and measures its labels while the browser has the `<svg>` laid
/// out at whatever size the page gives it — scrollbar included.
pub struct Page {
  /// The viewport, in pixels.
  viewport_width : Double
  viewport_height : Double
  /// The margin of the body.
  margin : Double
  /// The width a vertical scrollbar takes from the page.
  scrollbar : Double
}

///|
/// A page; the defaults describe the one the reference renderings are
/// made in: headless Chrome's default window on macOS, with the default
/// body margin and classic scrollbars.
pub fn Page::new(
  viewport_width~ : Double = 756.0,
  viewport_height~ : Double = 469.0,
  margin~ : Double = 8.0,
  scrollbar~ : Double = 15.0,
) -> Page {
  { viewport_width, viewport_height, margin, scrollbar, }
}

///|
pub fn Context::new(
  id : String,
  config : @config.Config,
  svg : @dom.Element,
  now~ : Double,
  page~ : Page,
) -> Context {
  { id, config, svg, now, page, }
}

///|
/// Blink's layout unit: lengths are kept in 64ths of a pixel, rounded
/// down.
fn floor_layout_unit(value : Double) -> Double {
  (value * 64.0).floor() / 64.0
}

///|
/// The width of the element the diagram is rendered into, before the
/// diagram has a size (`parentElement.offsetWidth` at the start of
/// drawing).
pub fn Context::container_width(self : Context) -> Double {
  self.page.viewport_width - 2.0 * self.page.margin
}

///|
/// The factor the browser draws the diagram's user units at once the
/// `<svg>` (still `width="100%"`, no height) has the view box
/// `0 0 width height`, the way the view box is fitted into the element
/// (`preserveAspectRatio` at its default).
///
/// The element is as wide as its container and as tall as the view box's
/// proportions make it; when that is taller than the viewport has room
/// for, the page gets a scrollbar, the container narrows and the diagram
/// shrinks with it. A diagram that measures text after setting its view
/// box gets its measurements at this scale.
pub fn Context::view_box_scale(
  self : Context,
  width : Double,
  height : Double,
) -> Double {
  let page = self.page
  let mut container = self.container_width()
  // Below the `<svg>`, an inline element, the line it stands on keeps
  // room for descenders in the font of the block mermaid renders into.
  let line_descent = match self.config.text("fontFamily") {
    Some(family) => @font.Stack::for_family(family).line_descent(16.0)
    // No font of its own: the default serif of the page.
    None => 4.0
  }
  let used_height = floor_layout_unit(container * height / width)
  // The page scrolls when its content, rounded to whole pixels, is
  // taller than the viewport; the scrollbar stays even if the narrower
  // content would fit again.
  if (used_height + line_descent + 2.0 * page.margin + 0.5).floor() >
    page.viewport_height {
    container -= page.scrollbar
  }
  let used_height = floor_layout_unit(container * height / width)
  // SVG lengths are single precision.
  let width = Float::from_double(width).to_double()
  let height = Float::from_double(height).to_double()
  if width / height < container / used_height {
    used_height / height
  } else {
    container / width
  }
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
  let family = self.theme().text("fontFamily")
  // A family emptied by the sanitizer (one with a hyphen in a theme
  // variable, such as `sans-serif`) leaves the stylesheet without a
  // `font-family`, and the text in the font of the page. Only its
  // regular face is embedded.
  if family.trim().is_empty() && !bold && !italic {
    return @font.Stack::page_default()
  }
  @font.Stack::for_family(family, bold~, italic~)
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
