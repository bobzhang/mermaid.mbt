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
  /// The extra space the font asks for between lines.
  priv line_gap : Int32
  /// Glyphs by code point.
  priv glyphs : Map[Int32, Glyph]
  /// Pair adjustments, keyed by `left_glyph * 65536 + right_glyph`.
  priv kerning : Map[Int32, Int32]
  /// Code points of the ligatures two glyphs join into, keyed like
  /// `kerning`.
  priv ligatures : Map[Int32, Int32]
  /// Characters the face has no glyph for but draws all the same, as a
  /// base letter and a combining mark it does have. No other face gets to
  /// draw them, and where the mark lands is not known here.
  priv composed : Map[Int32, Unit]
  /// Whether Blink raises the ascent by 15% of the line: its hack for
  /// Times, Helvetica and Courier on macOS.
  priv mac_ascent_adjustment : Bool
  /// Whether a pair adjustment is shared between the two glyphs, as
  /// HarfBuzz does for a `kern` table: the earlier glyph's advance takes
  /// the half rounded down, the later glyph's advance takes the rest and
  /// the glyph is drawn that much earlier. An adjustment from GPOS belongs
  /// to the earlier glyph alone.
  priv split_kerning : Bool
}

///|
/// Build a face from the flat tables written by
/// `scripts/gen_font_metrics.py`: seven numbers per glyph, three per
/// kerning pair and per ligature, and one per composed character.
fn Face::new(
  units_per_em~ : Int32,
  ascent~ : Int32,
  descent~ : Int32,
  line_gap~ : Int32,
  glyphs~ : FixedArray[Int32],
  kerning~ : FixedArray[Int32],
  ligatures~ : FixedArray[Int32] = [],
  composed~ : FixedArray[Int32] = [],
  mac_ascent_adjustment~ : Bool = false,
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
  let pieces : Map[Int32, Unit] = Map([])
  for code in composed {
    pieces[code] = ()
  }
  {
    units_per_em,
    ascent,
    descent,
    line_gap,
    glyphs: by_code,
    kerning: pairs,
    ligatures: joined,
    composed: pieces,
    mac_ascent_adjustment,
    split_kerning,
  }
}

///|
/// Whether the face has a glyph for `code`.
pub fn Face::covers(self : Face, code : Char) -> Bool {
  self.glyphs.contains(code.to_int())
}
