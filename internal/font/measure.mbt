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
  round_half_up(self.ascent.to_double() * size / self.units_per_em.to_double())
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
fn RectF::from_edges(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> RectF {
  { x: left, y: top, width: right - left, height: bottom - top, }
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
/// Shape `text` at `size` pixels. Consecutive characters of the same face
/// kern against each other; a change of face starts a new run.
fn Stack::shape(self : Stack, text : StringView, size : Double) -> Shaped {
  let size = effective_size(size)
  let shaped = { pen: 0.0, ink: { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }, }
  let mut previous : (Face, Glyph)? = None
  for c in text {
    let face = self.face_for(c)
    guard face.glyphs.get(c.to_int()) is Some(glyph) else {
      // No embedded face has this character. The reference browser would
      // use a system fallback font; approximate with half or a full em.
      let em = if c.to_int() >= 0x1100 { 1.0 } else { 0.5 }
      shaped.pen = shaped.pen + Float::from_double(size * em)
      previous = None
      continue
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
