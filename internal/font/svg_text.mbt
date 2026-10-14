// SVG text as Blink lays it out when the `<svg>` is displayed at another
// size than its `viewBox`: the text is shaped in a font scaled by the
// same factor, so that glyphs are positioned for the pixels they are
// drawn in, and every length is divided by the factor again when it is
// reported. A label measured in a diagram drawn at 74% of its size is
// therefore not quite as wide as the same label at full size, and its box
// no longer falls on whole layout units.

///|
/// The distance from the top of a line to a baseline of the stack's first
/// face at `size`, as `FontMetrics::FloatAscent(baseline)` computes it.
fn Stack::float_ascent(
  self : Stack,
  dominant_baseline : String,
  size : Double,
) -> Float {
  let face = self.faces[0]
  let ascent = Float::from_double(face.ascent(size))
  let descent = Float::from_double(face.descent(size))
  match dominant_baseline {
    "middle" => {
      let x_height = Float::from_double(
        face.x_height().to_double() *
        effective_size(size) /
        face.units_per_em.to_double(),
      )
      ascent - x_height / 2
    }
    "central" => (ascent + descent) / 2
    "hanging" => ascent * 2 / 10
    "mathematical" => ascent / 2
    "text-before-edge" => 0
    "ideographic" | "text-after-edge" => ascent + descent
    _ => ascent
  }
}

///|
/// `getComputedTextLength()` of SVG text in a diagram displayed at `scale`
/// times the size of its user units.
pub fn Stack::svg_text_length(
  self : Stack,
  text : StringView,
  size : Double,
  scale~ : Double = 1.0,
) -> Double {
  let s = Float::from_double(scale)
  let scaled_size = (Float::from_double(size) * s).to_double()
  let length = Float::from_double(
    ceil_layout_unit(self.shape(text, scaled_size).pen),
  )
  (length / s).to_double()
}

///|
/// `getBBox()` of an SVG `<text>` holding the one run `text`, positioned
/// by `x` and `y`, a `text-anchor` and a `dominant-baseline`, in a diagram
/// displayed at `scale` times the size of its user units.
///
/// The fragment is placed in scaled coordinates, united there with the
/// ink of its glyphs, and the result is scaled back; all in single
/// precision, in the order Blink does it
/// (`SvgTextLayoutAlgorithm::WriteBackToFragmentItems`,
/// `FragmentItem::ObjectBoundingBox`).
///
/// Checked against 600 boxes measured in the reference browser at
/// scales from 0.25 to 1: the length, `x`, `y` and `width` always agree;
/// the height is one or two steps of single precision off in about one
/// box of 25 whose glyphs reach below the descent of the font, where
/// the ink the port computes is that much off.
pub fn Stack::svg_text_box(
  self : Stack,
  text : StringView,
  size : Double,
  x~ : Double,
  y~ : Double,
  anchor~ : String = "start",
  baseline~ : String = "auto",
  scale~ : Double = 1.0,
) -> Rect {
  let f = Float::from_double
  let s = f(scale)
  let scaled_size = (f(size) * s).to_double()
  let shaped = self.shape(text, scaled_size)
  let length = f(ceil_layout_unit(shaped.pen))
  let face = self.faces[0]
  let ascent = f(face.ascent(scaled_size))
  let descent = f(face.descent(scaled_size))
  let x = f(x) * s
  let y = f(y) * s
  let end = x + length
  let start = match anchor {
    "middle" => x + (x - (x + end) / 2)
    "end" => x + (x - end)
    _ => x
  }
  // The fragment hangs from its baseline by a whole number of layout
  // units.
  let to_baseline = self.float_ascent(baseline, scaled_size)
  let top = y - f(round_layout_unit(to_baseline))
  let cell : RectF = {
    x: start,
    y: top,
    width: length,
    height: ascent + descent,
  }
  // The ink lies around the alphabetic baseline of the fragment.
  let ink = if shaped.ink.is_empty() {
    shaped.ink
  } else {
    {
      ..shaped.ink,
      x: shaped.ink.x + cell.x,
      y: shaped.ink.y + ascent + cell.y,
    }
  }
  let box = ink.union(cell)
  let k = (1.0 : Float) / s
  {
    x: (box.x * k).to_double(),
    y: (box.y * k).to_double(),
    width: (box.width * k).to_double(),
    height: (box.height * k).to_double(),
  }
}
