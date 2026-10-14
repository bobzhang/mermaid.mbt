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
  /// `first * 65536 + second` and giving the character of the ligature.
  priv ligatures : Map[Int32, Char]
}

///|
/// Build a face from the flat tables written by
/// `scripts/gen_font_metrics.py`: seven numbers per glyph, three per
/// kerning pair and three per ligature.
fn Face::new(
  units_per_em~ : Int32,
  ascent~ : Int32,
  descent~ : Int32,
  glyphs~ : FixedArray[Int32],
  kerning~ : FixedArray[Int32],
  ligatures~ : FixedArray[Int32] = [],
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
  let joined : Map[Int32, Char] = Map([])
  for i = 0; i + 2 < ligatures.length(); i = i + 3 {
    joined[ligatures[i] * 65536 + ligatures[i + 1]] = Int32::unsafe_to_char(
      ligatures[i + 2],
    )
  }
  {
    units_per_em,
    ascent,
    descent,
    glyphs: by_code,
    kerning: pairs,
    ligatures: joined,
  }
}

///|
/// Whether the face has a glyph for `code`.
pub fn Face::covers(self : Face, code : Char) -> Bool {
  self.glyphs.contains(code.to_int())
}
