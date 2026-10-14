///|
/// How the browser fits a diagram's user space into the page. A point
/// in user units is scaled by `scale` and moved by `dx` and `dy` to its
/// place inside the `<svg>` element, whose top left corner is at `left`
/// and `top` in the viewport; together they are `getScreenCTM()`.
pub struct Placement {
  scale : Double
  dx : Double
  dy : Double
  left : Double
  top : Double
}

///|
/// The placement of a diagram whose `<svg>` has `width="100%"`, the view
/// box `0 0 width height` and a `max-width` style (in pixels), fitted
/// the way `preserveAspectRatio` does by default: scaled uniformly and
/// centred.
///
/// The element is as wide as its container allows, at most `max_width`,
/// and as tall as the view box's proportions make it, in whole layout
/// units. When that is taller than the viewport has room for, the page
/// gets a scrollbar and the container narrows.
pub fn Context::placement(
  self : Context,
  width : Double,
  height : Double,
  max_width~ : Double,
) -> Placement {
  let page = self.page
  let mut container = self.container_width()
  // Below the `<svg>`, an inline element, the line it stands on keeps
  // room for descenders in the font of the block mermaid renders into.
  let line_descent = match self.config.text("fontFamily") {
    Some(family) => @font.Stack::for_family(family).line_descent(16.0)
    // No font of its own: the default serif of the page.
    None => 4.0
  }
  let max_width = floor_layout_unit(max_width)
  let used = (container : Double) => {
    let used_width = container.min(max_width)
    (used_width, floor_layout_unit(used_width * height / width))
  }
  // The page scrolls when its content, rounded to whole pixels, is
  // taller than the viewport; the scrollbar stays even if the narrower
  // content would fit again.
  if (used(container).1 + line_descent + 2.0 * page.margin + 0.5).floor() >
    page.viewport_height {
    container -= page.scrollbar
  }
  let (physical_width, physical_height) = used(container)
  // The view box is read into single precision; the rest is Blink's
  // `SVGPreserveAspectRatio::ComputeTransform` in doubles.
  let logical_width = Float::from_double(width).to_double()
  let logical_height = Float::from_double(height).to_double()
  if logical_width / logical_height < physical_width / physical_height {
    let scale = physical_height / logical_height
    let shift = -(logical_width -
      physical_width * logical_height / physical_height) /
      2.0
    { scale, dx: shift * scale, dy: 0.0, left: page.margin, top: page.margin, }
  } else {
    let scale = physical_width / logical_width
    let shift = -(logical_height -
      physical_height * logical_width / physical_width) /
      2.0
    { scale, dx: 0.0, dy: shift * scale, left: page.margin, top: page.margin, }
  }
}
