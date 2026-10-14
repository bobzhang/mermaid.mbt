// The boxes `getBBox()` reports for SVG text that is anchored and aligned
// on a baseline other than the alphabetic one, line by line.

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
/// The baseline a line of text is aligned on at its `y`: the used value of
/// `dominant-baseline`.
pub(all) enum Baseline {
  /// `auto` and `alphabetic`, and what an invalid value leaves in effect.
  Alphabetic
  /// `middle`: half the x-height above the alphabetic baseline.
  Middle
  /// `central`: halfway between the top and the bottom of the line.
  Central
  /// `hanging`: eight tenths of the ascent above the alphabetic baseline,
  /// in faces that do not say where theirs is.
  Hanging
} derive(Eq, Debug)

///|
/// Which point of a line its `x` gives: the used value of `text-anchor`.
pub(all) enum Anchor {
  Start
  Middle
  End
} derive(Eq, Debug)

///|
/// How far a line extends above and below the baseline it is aligned on.
/// Blink keeps both as layout units, so the two can add up to 1/64 px
/// more or less than ascent plus descent.
fn Stack::extents(
  self : Stack,
  size : Double,
  baseline : Baseline,
) -> (Float, Float) {
  let primary = self.faces[0]
  let ascent = Float::from_double(primary.ascent(size))
  let descent = Float::from_double(primary.descent(size))
  match baseline {
    Alphabetic => (ascent, descent)
    Middle => {
      let half_x_height = Float::from_double(self.x_height(size)) / 2
      (
        round_layout_unit(ascent - half_x_height),
        round_layout_unit(descent + half_x_height),
      )
    }
    Central => {
      let half = (ascent + descent) / 2
      (round_layout_unit(half), round_layout_unit(half))
    }
    Hanging => {
      let hanging = ascent * 8 / 10
      (
        round_layout_unit(ascent - hanging),
        round_layout_unit(descent + hanging),
      )
    }
  }
}

///|
/// A `<tspan>` with an `x` of its own, which makes it a chunk that is
/// anchored by itself: a line, in text broken by hand.
pub(all) struct Chunk {
  /// What is laid out, white space already collapsed; not empty.
  text : String
  /// The `x` attribute as the browser holds it (see `Element::length_attr`).
  x : Double
  /// Where the baseline is: the `y` in effect plus the `dy` so far.
  y : Double
}

///|
/// The box `getBBox()` reports for an SVG `<text>` element made of
/// `chunks`, all in this face at `size` pixels: the union of their boxes.
///
/// A chunk contributes its cell — the advance wide, as tall as the
/// extents of the face around the baseline — and the ink of its glyphs,
/// which can overhang the cell and is placed from the top of the line.
///
/// The browser first lays all chunks out on one line — each shaped by
/// itself, a positioned character being where text is cut for shaping —
/// and then moves each one to its `x` by the difference to where it
/// stood. Positions are single precision, and both
/// that move and the far edges of the boxes united are sums that round:
/// the box depends on where the text is.
pub fn Stack::chunks_box(
  self : Stack,
  chunks : Array[Chunk],
  size : Double,
  anchor~ : Anchor = Start,
  baseline~ : Baseline = Alphabetic,
) -> Rect {
  let ascent = Float::from_double(self.faces[0].ascent(size))
  let (above, below) = self.extents(size, baseline)
  let mut box : RectF = { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
  // Where the chunk stood on the one line of the inline layout.
  let mut inline : Float = 0.0
  for chunk in chunks {
    let shaped = self.shape(chunk.text, size)
    let width = Float::from_double(ceil_layout_unit(shaped.pen))
    let x = inline + (Float::from_double(chunk.x) - inline)
    inline = inline + width
    // The anchor shifts the chunk by the position of its ends, not by
    // its advance: the sums round on the way.
    let end = x + width
    let left = match anchor {
      Start => x
      Middle => x + (x - (x + end) / 2)
      End => x + (x - end)
    }
    let top = Float::from_double(chunk.y) - above
    let cell : RectF = { x: left, y: top, width, height: above + below, }
    let ink : RectF = {
      x: left + shaped.ink.x,
      y: top + (ascent + shaped.ink.y),
      width: shaped.ink.width,
      height: shaped.ink.height,
    }
    box = box.union(ink.union(cell))
  }
  {
    x: box.x.to_double(),
    y: box.y.to_double(),
    width: box.width.to_double(),
    height: box.height.to_double(),
  }
}

///|
/// The bounding box of `text` at `size` pixels set with
/// `dominant-baseline: middle`: what `getBBox()` reports for such an SVG
/// text element whose `x` and `y` attributes are as given.
pub fn Stack::bbox_middle(
  self : Stack,
  text : StringView,
  size : Double,
  x~ : Double = 0.0,
  y~ : Double = 0.0,
) -> Rect {
  if text.is_empty() {
    return { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
  }
  self.chunks_box([{ text: text.to_owned(), x, y, }], size, baseline=Middle)
}
