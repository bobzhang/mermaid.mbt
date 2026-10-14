///|
/// Round to Blink's layout unit, 1/64 of a pixel, halves away from zero.
fn round_layout_unit(value : Float) -> Float {
  let scaled = value.to_double() * 64.0
  let rounded = if scaled < 0.0 {
    -(0.5 - scaled).floor()
  } else {
    (scaled + 0.5).floor()
  }
  Float::from_double(rounded / 64.0)
}

///|
/// The bounding box of `text` at `size` pixels set with
/// `dominant-baseline: middle`: what `getBBox()` reports for such an SVG
/// text element whose `x` and `y` attributes are as given.
///
/// The middle baseline lies half the x-height above the alphabetic one.
/// The line's extents above and below it are each rounded to a layout
/// unit, so the box can be 1/64 px taller or shorter than ascent plus
/// descent. The glyphs' ink, which can overhang the line, is placed from
/// the top of the line.
///
/// Positions are single precision, and the far edges of the boxes united
/// are sums that round: the size reported depends on where the text is.
pub fn Stack::bbox_middle(
  self : Stack,
  text : StringView,
  size : Double,
  x~ : Double = 0.0,
  y~ : Double = 0.0,
) -> Rect {
  let shaped = self.shape(text, size)
  let primary = self.faces[0]
  let ascent = Float::from_double(primary.ascent(size))
  let descent = Float::from_double(primary.descent(size))
  let half_x_height = Float::from_double(self.x_height(size)) / 2
  let above = round_layout_unit(ascent - half_x_height)
  let below = round_layout_unit(descent + half_x_height)
  let left = Float::from_double(x)
  let top = Float::from_double(y) - above
  let cell : RectF = {
    x: left,
    y: top,
    width: Float::from_double(ceil_layout_unit(shaped.pen)),
    height: above + below,
  }
  let ink : RectF = {
    x: left + shaped.ink.x,
    y: top + (ascent + shaped.ink.y),
    width: shaped.ink.width,
    height: shaped.ink.height,
  }
  let box = ink.union(cell)
  {
    x: box.x.to_double(),
    y: box.y.to_double(),
    width: box.width.to_double(),
    height: box.height.to_double(),
  }
}
