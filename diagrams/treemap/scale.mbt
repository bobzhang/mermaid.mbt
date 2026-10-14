// The treemap sets its `viewBox` before it measures any text, and a
// browser shapes SVG text for the size it is displayed at. So the widths
// that decide how labels are shortened and shrunk, and the boxes of the
// texts, depend on how wide the page shows the diagram: on the window of
// the reference browser. These are its measures (headless Chrome's
// default window, as `scripts/oracle.py` runs it).

///|
/// The width a diagram may take: the window less the margins of `<body>`.
const PAGE_WIDTH : Double = 740.0

///|
/// The same once the page is taller than the window and has a scrollbar.
const PAGE_WIDTH_WITH_SCROLLBAR : Double = 725.0

///|
/// The diagram's height from which the page scrolls: the window's 469
/// pixels less the margins and the room a line leaves under an image,
/// rounded to whole pixels.
const SCROLLING_HEIGHT : Double = 449.5

///|
/// A CSS length as layout holds it: whole 64ths of a pixel, cut off.
fn layout_unit(value : Double) -> Double {
  (value * 64.0).floor() / 64.0
}

///|
/// How much smaller than its user units the reference browser displays an
/// `<svg>` with `viewBox="0 0 width height"`: the factor SVG text is
/// scaled by while it is shaped (Blink's
/// `CalculateScreenFontSizeScalingFactor`).
///
/// With `use_max_width` the element is `width: 100%` up to `width`
/// pixels, and as tall as the ratio of the view box makes it; otherwise
/// it has the size of the view box.
fn display_scale(
  width : Double,
  height : Double,
  use_max_width : Bool,
) -> Double {
  let f = Float::from_double
  let fitted = (page_width : Double) => {
    let shown_width = if page_width < layout_unit(width) {
      page_width
    } else {
      layout_unit(width)
    }
    (shown_width, layout_unit(shown_width * height / width))
  }
  let (shown_width, shown_height) = if use_max_width {
    let (shown_width, shown_height) = fitted(PAGE_WIDTH)
    if shown_height >= SCROLLING_HEIGHT {
      fitted(PAGE_WIDTH_WITH_SCROLLBAR)
    } else {
      (shown_width, shown_height)
    }
  } else {
    (layout_unit(width), layout_unit(height))
  }
  // `preserveAspectRatio="xMidYMid meet"`: the smaller of the two
  // ratios, chosen as `SVGPreserveAspectRatio::ComputeTransform` does.
  let view_width = f(width).to_double()
  let view_height = f(height).to_double()
  let scale = if view_width / view_height < shown_width / shown_height {
    shown_height / view_height
  } else {
    shown_width / view_width
  }
  f(((scale * scale + scale * scale) / 2.0).sqrt()).to_double()
}
