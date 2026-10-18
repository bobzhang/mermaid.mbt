///|
/// How far a line of this stack's first face reaches above and below the
/// baseline its text sits on (`dominant-baseline`), in pixels: the cell
/// of an SVG text fragment. Off the alphabetic baseline each extent is
/// rounded to a layout unit on its own.
pub fn Stack::baseline_extents(
  self : Stack,
  size : Double,
  baseline : Baseline,
) -> (Float, Float) {
  self.faces[0].baseline_extents(baseline, size)
}
