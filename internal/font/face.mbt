///|
/// The metrics of one glyph, in font units with y pointing up.
priv struct Glyph {
  id : Int32
  advance : Int32
  x_min : Int32
  y_min : Int32
  x_max : Int32
  y_max : Int32
}

///|
/// The metrics of one font face: enough to measure text, nothing to draw it.
pub struct Face {
  priv units_per_em : Int32
  priv ascent : Int32
  priv descent : Int32
  /// Glyphs by code point.
  priv glyphs : Map[Int32, Glyph]
  /// Pair adjustments, keyed by `left_glyph * 65536 + right_glyph`.
  priv kerning : Map[Int32, Int32]
  /// Pairs of characters drawn as one glyph, keyed by
  /// `first * 65536 + second`, with the code point of that glyph.
  priv ligatures : Map[Int32, Int32]
  /// Whether Blink raises the ascent on macOS, as it does for Helvetica,
  /// Times and Courier.
  priv mac_ascent : Bool
  /// Whether a pair adjustment is shared between the two glyphs, as
  /// HarfBuzz does for a `kern` table, instead of going to the first one,
  /// as with GPOS.
  priv split_kerning : Bool
}

///|
/// Build a face from the flat tables written by
/// `scripts/gen_font_metrics.py`: seven numbers per glyph and three per
/// kerning pair and per ligature.
fn Face::new(
  units_per_em~ : Int32,
  ascent~ : Int32,
  descent~ : Int32,
  glyphs~ : FixedArray[Int32],
  kerning~ : FixedArray[Int32],
  ligatures~ : FixedArray[Int32] = [],
  mac_ascent~ : Bool = false,
  split_kerning~ : Bool = false,
) -> Face {
  let by_code : Map[Int32, Glyph] = Map([])
  for i = 0; i + 6 < glyphs.length(); i = i + 7 {
    by_code[glyphs[i]] = {
      id: glyphs[i + 1],
      advance: glyphs[i + 2],
      x_min: glyphs[i + 3],
      y_min: glyphs[i + 4],
      x_max: glyphs[i + 5],
      y_max: glyphs[i + 6],
    }
  }
  let pairs : Map[Int32, Int32] = Map([])
  for i = 0; i + 2 < kerning.length(); i = i + 3 {
    pairs[kerning[i] * 65536 + kerning[i + 1]] = kerning[i + 2]
  }
  let joined : Map[Int32, Int32] = Map([])
  for i = 0; i + 2 < ligatures.length(); i = i + 3 {
    joined[ligatures[i] * 65536 + ligatures[i + 1]] = ligatures[i + 2]
  }
  {
    units_per_em,
    ascent,
    descent,
    glyphs: by_code,
    kerning: pairs,
    ligatures: joined,
    mac_ascent,
    split_kerning,
  }
}

///|
/// Whether the face has a glyph for `code`.
pub fn Face::covers(self : Face, code : Char) -> Bool {
  self.glyphs.contains(code.to_int())
}
