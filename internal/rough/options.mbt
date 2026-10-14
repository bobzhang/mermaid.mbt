// A port of the parts of rough.js 4.6.6 that mermaid draws shapes with.
// Mermaid sends many shapes through rough.js even outside the hand-drawn
// look, with roughness 0: the outline is then exact, but every straight
// line still becomes a Bezier curve whose control points sit at a random
// place along it.

///|
/// How a shape is drawn: rough.js's `ResolvedOptions`.
pub(all) struct Options {
  mut max_randomness_offset : Double
  mut roughness : Double
  mut bowing : Double
  mut stroke : String
  /// Kept as text: mermaid passes a number or the text of a style.
  mut stroke_width : String
  mut curve_tightness : Double
  mut curve_fitting : Double
  mut curve_step_count : Double
  mut fill_style : String
  /// No fill when empty.
  mut fill : String
  mut seed : Int32
  mut disable_multi_stroke : Bool
  mut preserve_vertices : Bool
  mut fill_shape_roughness_gain : Double
  mut stroke_line_dash : Array[Double]?
  /// The width of the lines of a sketched fill; half the stroke width
  /// when negative.
  mut fill_weight : Double
  /// The direction of the lines of a hachure fill, in degrees.
  mut hachure_angle : Double
  /// The distance between them; four stroke widths when negative.
  mut hachure_gap : Double
  priv mut randomizer : Randomizer?
}

///|
/// rough.js's defaults.
pub fn Options::new() -> Options {
  {
    max_randomness_offset: 2.0,
    roughness: 1.0,
    bowing: 1.0,
    stroke: "#000",
    stroke_width: "1",
    curve_tightness: 0.0,
    curve_fitting: 0.95,
    curve_step_count: 9.0,
    fill_style: "hachure",
    fill: "",
    seed: 0,
    disable_multi_stroke: false,
    preserve_vertices: false,
    fill_shape_roughness_gain: 0.8,
    stroke_line_dash: None,
    fill_weight: -1.0,
    hachure_angle: -41.0,
    hachure_gap: -1.0,
    randomizer: None,
  }
}

///|
/// The generator behind rough.js's randomness: a Lehmer generator when
/// seeded.
priv struct Randomizer {
  mut seed : Int32
}

///|
/// Stands in for `Math.random()` when no seed is configured. Upstream's
/// output is different on every render then; here it is repeatable.
let unseeded : Randomizer = { seed: 0x2f6e2b1, }

///|
fn Randomizer::next(self : Randomizer) -> Double {
  let source = if self.seed != 0 { self } else { unseeded }
  source.seed = 48271 * source.seed
  (source.seed & 0x7fffffff).to_double() / 2147483648.0
}

///|
/// A copy for one call: the random sequence starts over from the seed.
fn Options::fresh(self : Options) -> Options {
  { ..self, randomizer: None, }
}

///|
fn Options::random(self : Options) -> Double {
  let randomizer = match self.randomizer {
    Some(randomizer) => randomizer
    None => {
      let randomizer = { seed: self.seed, }
      self.randomizer = Some(randomizer)
      randomizer
    }
  }
  randomizer.next()
}

///|
/// A random value between `min` and `max`, scaled by the roughness.
fn Options::offset(
  self : Options,
  min : Double,
  max : Double,
  gain~ : Double = 1.0,
) -> Double {
  self.roughness * gain * (self.random() * (max - min) + min)
}

///|
/// A random value within `x` of zero, scaled by the roughness.
fn Options::offset_opt(
  self : Options,
  x : Double,
  gain~ : Double = 1.0,
) -> Double {
  self.offset(-x, x, gain~)
}
