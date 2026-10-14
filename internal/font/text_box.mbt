// SVG text broken into lines by hand: a `<text>` whose `<tspan>`s each
// have an `x` of their own.

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
/// `chunks`, all in this stack at `size` pixels, under one `text-anchor`
/// and one `dominant-baseline`, in a diagram displayed at `scale` times
/// the size of its user units: the union of the boxes of the chunks, each
/// a fragment as in `svg_text_box`.
///
/// The browser first lays all chunks out on one line — each shaped by
/// itself, a positioned character being where text is cut for shaping —
/// and then moves each one to its `x` by the difference to where it
/// stood. Positions are single precision, and both that move and the far
/// edges of the boxes united are sums that round: the box depends on
/// where the text is.
///
/// Checked against 6300 boxes of one to three chunks measured in the
/// reference browser, on three anchors and four baselines at scale 1,
/// and through the Cynefin fixtures at other scales.
pub fn Stack::chunks_box(
  self : Stack,
  chunks : Array[Chunk],
  size : Double,
  anchor~ : String = "start",
  baseline~ : Baseline = Alphabetic,
  scale~ : Double = 1.0,
) -> Rect {
  let f = Float::from_double
  let s = scaling_factor(scale)
  let scaled_size = (f(size) * s).to_double()
  let mut box : RectF = { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
  // Where the chunk stood on the one line of the inline layout.
  let mut inline : Float = 0.0
  for chunk in chunks {
    let x = inline + (f(chunk.x) * s - inline)
    let (fragment, length) = self.fragment_box(
      chunk.text,
      scaled_size,
      x,
      f(chunk.y) * s,
      anchor,
      baseline,
    )
    inline = inline + length
    box = box.union(fragment)
  }
  box.scaled_back(s)
}
