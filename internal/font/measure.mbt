///|
/// A rectangle in user units, relative to the start of the text baseline,
/// with y pointing down as in SVG.
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Blink shapes with HarfBuzz positions in 16.16 fixed point.
const HB_ONE : Float = 65536.0

///|
/// The advance Blink gets for a glyph: Skia's 32-bit float width, truncated
/// to 16.16 fixed point.
fn Face::advance_fixed(self : Face, units : Int32, size : Double) -> Int32 {
  let width = Float::from_double(
    units.to_double() * size / self.units_per_em.to_double(),
  )
  (width * HB_ONE).to_int()
}

///|
/// A design-space value scaled the way HarfBuzz scales kerning.
fn Face::scale_fixed(self : Face, units : Int32, size : Double) -> Int32 {
  let scale = (Float::from_double(size) * HB_ONE).to_int().to_int64()
  let mult = (scale << 16) / self.units_per_em.to_int64()
  ((units.to_int64() * mult + 32768L) >> 16).to_int()
}

///|
/// Round a length up to Blink's layout unit, 1/64 of a pixel.
fn ceil_layout_unit(value : Float) -> Double {
  (value.to_double() * 64.0).ceil() / 64.0
}

///|
/// Font ascent and descent in pixels. Blink rounds each to a whole pixel.
pub fn Face::ascent(self : Face, size : Double) -> Double {
  let ascent = round_half_up(
    self.ascent.to_double() * size / self.units_per_em.to_double(),
  )
  if self.legacy_mac_ascent {
    // SimpleFontData::PlatformInit, in single precision.
    let line = Float::from_double(ascent + self.descent(size))
    ascent + (line * 0.15 + 0.5).floor().to_double()
  } else {
    ascent
  }
}

///|
pub fn Face::descent(self : Face, size : Double) -> Double {
  round_half_up(self.descent.to_double() * size / self.units_per_em.to_double())
}

///|
/// The size glyphs are actually scaled to: the reference browser drops
/// everything past the second decimal of a font size.
fn effective_size(size : Double) -> Double {
  (size * 100.0).floor() / 100.0
}

///|
fn round_half_up(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
/// An ordered list of faces, as a CSS `font-family` resolves to: each
/// character is drawn from the first face that covers it.
pub struct Stack {
  priv faces : Array[Face]
}

///|
/// The default mermaid font stack,
/// `"trebuchet ms", verdana, arial, sans-serif`, as resolved on macOS.
pub fn Stack::default(bold~ : Bool = false, italic~ : Bool = false) -> Stack {
  let trebuchet = match (bold, italic) {
    (false, false) => trebuchet_regular
    (true, false) => trebuchet_bold
    (false, true) => trebuchet_italic
    (true, true) => trebuchet_bold_italic
  }
  // Verdana and Arial italics are not embedded; their upright faces stand in.
  if bold {
    { faces: [trebuchet, verdana_bold, arial_bold], }
  } else {
    { faces: [trebuchet, verdana_regular, arial_regular], }
  }
}

///|
/// The face that draws `code`: the first one covering it, else the primary.
fn Stack::face_for(self : Stack, code : Char) -> Face {
  for face in self.faces {
    if face.covers(code) {
      return face
    }
  }
  self.faces[0]
}

///|
/// A rectangle in 32-bit floats, stored as origin and size like Blink's
/// `gfx::RectF`. Its edges are recomputed from origin plus size on every
/// union, and that rounding is part of what the browser reports.
priv struct RectF {
  x : Float
  y : Float
  width : Float
  height : Float
}

///|
/// `RectF::SetByBounds`: where origin plus the rounded size falls short
/// of the far edge, the size grows by one step.
fn RectF::from_edges(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> RectF {
  let mut width = right - left
  let mut height = bottom - top
  if left + width < right {
    width = Float::reinterpret_from_uint(width.reinterpret_as_uint() + 1)
  }
  if top + height < bottom {
    height = Float::reinterpret_from_uint(height.reinterpret_as_uint() + 1)
  }
  { x: left, y: top, width, height, }
}

///|
fn RectF::is_empty(self : RectF) -> Bool {
  self.width <= 0.0 || self.height <= 0.0
}

///|
fn RectF::union(self : RectF, other : RectF) -> RectF {
  if self.is_empty() {
    return other
  }
  if other.is_empty() {
    return self
  }
  let min = (a : Float, b : Float) => if a < b { a } else { b }
  let max = (a : Float, b : Float) => if a > b { a } else { b }
  RectF::from_edges(
    min(self.x, other.x),
    min(self.y, other.y),
    max(self.x + self.width, other.x + other.width),
    max(self.y + self.height, other.y + other.height),
  )
}

///|
/// The result of shaping: the advance width before rounding, and the ink
/// bounds around the baseline origin, y down.
priv struct Shaped {
  mut pen : Float
  mut ink : RectF
}

///|
/// What draws one character, or one ligature of two.
priv enum Drawn {
  /// A glyph of an embedded face.
  Glyph(Face, Glyph)
  /// A character no embedded face has.
  Missing(Char)
  /// A default-ignorable character such as a zero-width space: shaped to
  /// an invisible glyph without advance.
  Ignorable
}

///|
fn is_default_ignorable(c : Char) -> Bool {
  c is ('\u{200B}'..<='\u{200F}' | '\u{2060}' | '\u{FEFF}')
}

///|
/// The glyphs `text` is drawn with. Two characters of one face that it
/// has a ligature for (`fi` and `fl` in Times and Helvetica) become one
/// glyph.
fn Stack::glyphs(self : Stack, text : StringView) -> Array[Drawn] {
  let drawn : Array[Drawn] = []
  for c in text {
    if is_default_ignorable(c) {
      drawn.push(Ignorable)
      continue
    }
    let face = self.face_for(c)
    guard face.glyphs.get(c.to_int()) is Some(glyph) else {
      drawn.push(Missing(c))
      continue
    }
    if drawn.last() is Some(Glyph(left_face, left)) &&
      physical_equal(left_face, face) &&
      face.ligatures.get(left.id * 65536 + glyph.id) is Some(code) &&
      face.glyphs.get(code) is Some(ligature) {
      drawn[drawn.length() - 1] = Glyph(face, ligature)
      continue
    }
    drawn.push(Glyph(face, glyph))
  }
  drawn
}

///|
/// Shape `text` at `size` pixels. Consecutive characters of the same face
/// kern against each other; a change of face starts a new run.
fn Stack::shape(self : Stack, text : StringView, size : Double) -> Shaped {
  let size = effective_size(size)
  let shaped = { pen: 0.0, ink: { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }, }
  let mut previous : (Face, Glyph)? = None
  for drawn in self.glyphs(text) {
    let (face, glyph) = match drawn {
      Glyph(face, glyph) => (face, glyph)
      Missing(c) => {
        // No embedded face has this character. The reference browser would
        // use a system fallback font; approximate with half or a full em.
        let em = if c.to_int() >= 0x1100 { 1.0 } else { 0.5 }
        shaped.pen = shaped.pen + Float::from_double(size * em)
        previous = None
        continue
      }
      Ignorable => {
        previous = None
        continue
      }
    }
    if previous is Some((left_face, left)) &&
      physical_equal(left_face, face) &&
      face.kerning.get(left.id * 65536 + glyph.id) is Some(adjust) {
      shaped.pen = shaped.pen +
        Float::from_int(face.scale_fixed(adjust, size)) / HB_ONE
    }
    if glyph.x_min != glyph.x_max || glyph.y_min != glyph.y_max {
      // Skia receives the box from CoreText as origin and size in
      // doubles, converts each to a float and adds them up again.
      let scale = size / face.units_per_em.to_double()
      let x = Float::from_double(glyph.x_min.to_double() * scale)
      let y = Float::from_double(-glyph.y_max.to_double() * scale)
      let width = Float::from_double(
        (glyph.x_max - glyph.x_min).to_double() * scale,
      )
      let height = Float::from_double(
        (glyph.y_max - glyph.y_min).to_double() * scale,
      )
      let bounds = RectF::from_edges(x, y, x + width, y + height)
      shaped.ink = shaped.ink.union({ ..bounds, x: bounds.x + shaped.pen, })
    }
    shaped.pen = shaped.pen +
      Float::from_int(face.advance_fixed(glyph.advance, size)) / HB_ONE
    previous = Some((face, glyph))
  }
  shaped
}

///|
/// The advance width of `text` at `size` pixels: what
/// `getComputedTextLength()` reports for an SVG text element.
pub fn Stack::advance(self : Stack, text : StringView, size : Double) -> Double {
  ceil_layout_unit(self.shape(text, size).pen)
}

///|
/// The widths of consecutive pieces of text shaped as one run, as SVG
/// text lays out the `<tspan>`s of a line: kerning reaches across the
/// pieces (the adjustment belongs to the earlier glyph), and every piece
/// takes whole layout units.
pub fn Stack::item_advances(
  self : Stack,
  items : Array[String],
  size : Double,
) -> Array[Double] {
  let size = effective_size(size)
  let sums : Array[Float] = items.map(_ => 0.0)
  let mut previous : (Face, Glyph, Int32)? = None
  for index, item in items {
    for c in item {
      let face = self.face_for(c)
      guard face.glyphs.get(c.to_int()) is Some(glyph) else {
        let em = if c.to_int() >= 0x1100 { 1.0 } else { 0.5 }
        sums[index] = sums[index] + Float::from_double(size * em)
        previous = None
        continue
      }
      if previous is Some((left_face, left, left_index)) &&
        physical_equal(left_face, face) &&
        face.kerning.get(left.id * 65536 + glyph.id) is Some(adjust) {
        sums[left_index] = sums[left_index] +
          Float::from_int(face.scale_fixed(adjust, size)) / HB_ONE
      }
      sums[index] = sums[index] +
        Float::from_int(face.advance_fixed(glyph.advance, size)) / HB_ONE
      previous = Some((face, glyph, index))
    }
  }
  sums.map(sum => ceil_layout_unit(sum))
}

///|
/// The ink of `text` at `size` pixels around its origin on the baseline,
/// y down; an empty box when nothing is drawn.
pub fn Stack::ink(self : Stack, text : StringView, size : Double) -> Rect {
  let ink = self.shape(text, size).ink
  {
    x: ink.x.to_double(),
    y: ink.y.to_double(),
    width: ink.width.to_double(),
    height: ink.height.to_double(),
  }
}

///|
/// The ascent and descent of the stack's first face at `size` pixels,
/// which is what lines of text are as tall as.
pub fn Stack::line_metrics(self : Stack, size : Double) -> (Double, Double) {
  (self.faces[0].ascent(size), self.faces[0].descent(size))
}

///|
/// The bounding box of `text` at `size` pixels: what `getBBox()` reports
/// for an SVG text element positioned at the origin. It is the cell
/// (advance by ascent plus descent) united with the ink of the glyphs,
/// which can overhang the cell.
pub fn Stack::bbox(self : Stack, text : StringView, size : Double) -> Rect {
  let shaped = self.shape(text, size)
  let primary = self.faces[0]
  let ascent = Float::from_double(primary.ascent(size))
  let descent = Float::from_double(primary.descent(size))
  let cell : RectF = {
    x: 0.0,
    y: -ascent,
    width: Float::from_double(ceil_layout_unit(shaped.pen)),
    height: ascent + descent,
  }
  let box = shaped.ink.union(cell)
  {
    x: box.x.to_double(),
    y: box.y.to_double(),
    width: box.width.to_double(),
    height: box.height.to_double(),
  }
}

///|
/// The stack a CSS `font-family` list resolves to in the reference
/// environment. Families that are not installed there are skipped; of the
/// installed ones, Trebuchet MS, Verdana, Arial, Helvetica and Times are
/// embedded. The generic `sans-serif` is Helvetica there and `serif` is
/// Times. A list naming none of them falls back to Arial, the closest
/// embedded face to the system sans-serif.
pub fn Stack::for_family(
  family : String,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> Stack {
  let faces = []
  for name in family.split(",") {
    let name = name.trim(chars=" \t\n\"';").to_owned().to_lower()
    let face = match name {
      "trebuchet ms" =>
        Some(
          match (bold, italic) {
            (false, false) => trebuchet_regular
            (true, false) => trebuchet_bold
            (false, true) => trebuchet_italic
            (true, true) => trebuchet_bold_italic
          },
        )
      "verdana" => Some(if bold { verdana_bold } else { verdana_regular })
      "arial" => Some(arial(bold, italic))
      // The obliques are not embedded; the upright faces stand in.
      "helvetica" | "sans-serif" =>
        Some(if bold { helvetica_bold } else { helvetica_regular })
      "times" | "serif" => Some(if bold { times_bold } else { times_regular })
      _ => None
    }
    if face is Some(face) && !faces.iter().any(f => physical_equal(f, face)) {
      faces.push(face)
    }
  }
  if faces.is_empty() {
    faces.push(arial(bold, italic))
  }
  { faces, }
}

///|
/// The browser's standard font, which text falls back to when no
/// `font-family` applies: Times in the reference environment.
pub fn Stack::standard(bold~ : Bool = false) -> Stack {
  { faces: [if bold { times_bold } else { times_regular }], }
}

///|
fn arial(bold : Bool, italic : Bool) -> Face {
  match (bold, italic) {
    (false, false) => arial_regular
    (true, false) => arial_bold
    (false, true) => arial_italic
    (true, true) => arial_bold_italic
  }
}
