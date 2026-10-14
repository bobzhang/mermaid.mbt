// SVG text as Blink lays it out when the `<svg>` is displayed at another
// size than its `viewBox`: the text is shaped in a font scaled by the
// same factor, so that glyphs are positioned for the pixels they are
// drawn in, and every length is divided by the factor again when it is
// reported. A label measured in a diagram drawn at 74% of its size is
// therefore not quite as wide as the same label at full size, and its box
// no longer falls on whole layout units.

///|
/// Blink's scaling factor for the text of an `<svg>` drawn at `scale`
/// times the size of its user units, uniformly
/// (`CalculateScreenFontSizeScalingFactor`): the font is laid out at the
/// size it has on screen.
fn scaling_factor(scale : Double) -> Float {
  Float::from_double(((scale * scale + scale * scale) / 2.0).sqrt())
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
  let s = scaling_factor(scale)
  let scaled_size = (Float::from_double(size) * s).to_double()
  let length = Float::from_double(
    ceil_layout_unit(self.shape(text, scaled_size).pen),
  )
  (length / s).to_double()
}

///|
/// The box of one fragment of SVG text — a run in this stack at
/// `scaled_size`, anchored at `x` on a baseline at `y` — in the scaled
/// coordinates Blink lays text out in, and the fragment's length there.
///
/// The fragment's cell hangs from its baseline by a whole number of
/// layout units and is united with the ink of its glyphs, which lies
/// around the alphabetic baseline; all in single precision, in the order
/// Blink does it (`SvgTextLayoutAlgorithm::WriteBackToFragmentItems`,
/// `FragmentItem::ObjectBoundingBox`). The anchor shifts the fragment by
/// the positions of its ends, not by its length: the sums round on the
/// way.
fn Stack::fragment_box(
  self : Stack,
  text : StringView,
  scaled_size : Double,
  x : Float,
  y : Float,
  anchor : String,
  baseline : Baseline,
) -> (RectF, Float) {
  let f = Float::from_double
  let shaped = self.shape(text, scaled_size)
  let length = f(ceil_layout_unit(shaped.pen))
  let face = self.faces[0]
  let ascent = f(face.ascent(scaled_size))
  let (to_baseline, below_baseline) = face.baseline_extents(
    baseline, scaled_size,
  )
  let end = x + length
  let start = match anchor {
    "middle" => x + (x - (x + end) / 2)
    "end" => x + (x - end)
    _ => x
  }
  let cell : RectF = {
    x: start,
    y: y - to_baseline,
    width: length,
    height: to_baseline + below_baseline,
  }
  let ink = if shaped.ink.is_empty() {
    shaped.ink
  } else {
    {
      ..shaped.ink,
      x: shaped.ink.x + cell.x,
      y: shaped.ink.y + ascent + cell.y,
    }
  }
  (ink.union(cell), length)
}

///|
/// A box in scaled coordinates as `getBBox()` reports it: every number
/// times the inverse of the scaling factor, in single precision.
fn RectF::scaled_back(self : RectF, factor : Float) -> Rect {
  let k = (1.0 : Float) / factor
  {
    x: (self.x * k).to_double(),
    y: (self.y * k).to_double(),
    width: (self.width * k).to_double(),
    height: (self.height * k).to_double(),
  }
}

///|
/// `getBBox()` of an SVG `<text>` holding the one run `text`, positioned
/// by `x` and `y`, a `text-anchor` and a `dominant-baseline`, in a diagram
/// displayed at `scale` times the size of its user units.
///
/// The fragment is placed in scaled coordinates, united there with the
/// ink of its glyphs, and the result is scaled back (see `fragment_box`).
///
/// Checked against 4000 boxes measured in the reference browser at
/// scales from 0.25 to 1, on three baselines and three anchors: the
/// length and all four numbers of the box agree in every one.
pub fn Stack::svg_text_box(
  self : Stack,
  text : StringView,
  size : Double,
  x~ : Double,
  y~ : Double,
  anchor~ : String = "start",
  baseline~ : Baseline = Alphabetic,
  scale~ : Double = 1.0,
) -> Rect {
  let f = Float::from_double
  let s = scaling_factor(scale)
  let scaled_size = (f(size) * s).to_double()
  let (box, _) = self.fragment_box(
    text,
    scaled_size,
    f(x) * s,
    f(y) * s,
    anchor,
    baseline,
  )
  box.scaled_back(s)
}
