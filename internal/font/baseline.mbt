///|
/// The x-height of an embedded face in font units, as the reference
/// browser reports it (measured there at a font size of one em in units).
fn Face::x_height(self : Face) -> Int32 {
  if physical_equal(self, verdana_bold) {
    1123
  } else if physical_equal(self, verdana_regular) {
    1117
  } else if self.ascent == 1923 {
    // Trebuchet MS, every style.
    1071
  } else {
    // Arial, every style.
    1062
  }
}

///|
/// Blink's `LayoutUnit::FromFloatRound`: to the nearest 1/64 of a pixel.
fn round_layout_unit(value : Float) -> Double {
  (value.to_double() * 64.0 + 0.5).floor() / 64.0
}

///|
/// How far the CSS `dominant-baseline` of SVG text moves the text down
/// from where its alphabetic baseline would sit on `y`, in pixels: the
/// box `Stack::bbox` reports is to be shifted by this much.
///
/// Blink places the text by the distance from the top of the line to the
/// chosen baseline of the stack's first face, rounded to a layout unit:
/// `middle` is half the x-height above the alphabetic baseline, `central`
/// the middle of ascent and descent, `hanging` 80% of the ascent,
/// `mathematical` half of it. Unknown values count as `auto`.
pub fn Stack::baseline_shift(
  self : Stack,
  dominant_baseline : String,
  size : Double,
) -> Double {
  let face = self.faces[0]
  let ascent = Float::from_double(face.ascent(size))
  if !(dominant_baseline
    is ("middle"
    | "central"
    | "hanging"
    | "mathematical"
    | "text-before-edge"
    | "ideographic"
    | "text-after-edge")) {
    return 0.0
  }
  ascent.to_double() -
  round_layout_unit(self.float_ascent(dominant_baseline, size))
}
