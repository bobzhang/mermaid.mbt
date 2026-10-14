// The page the reference output is rendered in. mermaid draws into an
// `<svg width="100%">` inside a block in the page's `<body>`, and a
// diagram that sets its `viewBox` before it measures text has that text
// measured under the scale the `viewBox` is shown at — which depends on
// how wide the page is. Byte-identical output therefore includes the
// reference browser's window: headless Chrome's default one.

///|
/// The width of the window's viewport, in CSS pixels.
const VIEWPORT_WIDTH : Double = 756.0

///|
const VIEWPORT_HEIGHT : Double = 469.0

///|
/// The margin of `<body>` on each side.
const BODY_MARGIN : Double = 8.0

///|
/// What a vertical scrollbar takes from the width once the page is
/// taller than the viewport.
const SCROLLBAR_WIDTH : Double = 15.0

///|
/// The room below the baseline of the line the inline `<svg>` sits on:
/// the descent of the page's default font.
const LINE_DESCENT : Double = 4.0

///|
/// The height of a replaced element `width` wide with the aspect ratio
/// `ratio_width : ratio_height`: all in layout units of 1/64 px, the
/// division rounding down.
fn height_for_ratio(
  width : Double,
  ratio_width : Double,
  ratio_height : Double,
) -> Double {
  (width * 64.0 * (ratio_height * 64.0) / (ratio_width * 64.0)).floor() / 64.0
}

///|
/// The factor by which the reference browser draws the content of an
/// `<svg width="100%">` whose `viewBox` is `view_width` by `view_height`
/// user units: what Blink calls the screen font size scaling factor of
/// text inside it, in single precision. It is 1 when the element is given
/// the size of its `viewBox` (`use_max_width` off) or is narrower than
/// the page; otherwise the `viewBox` is fitted to the width of the page,
/// and the height that follows from the aspect ratio — rounded down to a
/// layout unit — usually is what decides the scale.
///
/// Returns `None` for a `viewBox` that is not a whole number of layout
/// units, where the rounding of the browser's conversions is not known.
pub fn text_scale(
  view_width : Double,
  view_height : Double,
  use_max_width : Bool,
) -> Double? {
  if !use_max_width {
    return Some(1.0)
  }
  let whole = (value : Double) => (value * 64.0).floor() == value * 64.0
  if !(view_width > 0.0 && view_height > 0.0) {
    return Some(1.0)
  }
  let page = VIEWPORT_WIDTH - 2.0 * BODY_MARGIN
  if view_width <= page - SCROLLBAR_WIDTH {
    // Narrower than the page with or without a scrollbar: shown at its
    // own size, `max-width` being the width of the `viewBox`.
    return Some(1.0)
  }
  guard whole(view_width) && whole(view_height) else { return None }
  let fit = (available : Double) => {
    if view_width < available {
      view_width
    } else {
      available
    }
  }
  // Without a scrollbar first; the page gets one when its content, snapped
  // to whole pixels, is taller than the viewport.
  let mut width = fit(page)
  let mut height = height_for_ratio(width, view_width, view_height)
  let content = 2.0 * BODY_MARGIN + height + LINE_DESCENT
  if (content + 0.5).floor() > VIEWPORT_HEIGHT {
    width = fit(page - SCROLLBAR_WIDTH)
    height = height_for_ratio(width, view_width, view_height)
  }
  // `preserveAspectRatio="xMidYMid meet"`: the smaller of the two ratios
  // scales both axes.
  let scale = if view_width / view_height < width / height {
    height / view_height
  } else {
    width / view_width
  }
  Some(
    Float::from_double(((scale * scale + scale * scale) / 2.0).sqrt()).to_double(),
  )
}
