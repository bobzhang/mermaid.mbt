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
/// Font ascent and descent in pixels. Blink rounds each to a whole pixel,
/// from the metric of the face at the size it is actually scaled to.
pub fn Face::ascent(self : Face, size : Double) -> Double {
  let ascent = self.rounded_metric(self.ascent, size)
  if self.mac_ascent_adjustment {
    // `ascent += floorf((ascent + descent) * 0.15f + 0.5f)`
    let line = Float::from_double(ascent + self.descent(size))
    ascent + (line * 0.15 + 0.5).to_double().floor()
  } else {
    ascent
  }
}

///|
pub fn Face::descent(self : Face, size : Double) -> Double {
  self.rounded_metric(self.descent, size)
}

///|
/// `SkScalarRoundToScalar` of a vertical metric: the float nearest the
/// scaled value, plus a half, floored.
fn Face::rounded_metric(self : Face, units : Int32, size : Double) -> Double {
  let scaled = Float::from_double(
    units.to_double() * effective_size(size) / self.units_per_em.to_double(),
  )
  (scaled + 0.5).to_double().floor()
}

///|
/// How far a line box of normal height reaches below its baseline, in
/// pixels. The line is as tall as the rounded ascent, descent and line gap
/// together, and the larger half of the gap goes below.
pub fn Face::line_descent(self : Face, size : Double) -> Double {
  let gap = round_half_up(
    self.line_gap.to_double() * size / self.units_per_em.to_double(),
  )
  self.descent(size) + (gap - (gap / 2.0).floor())
}

///|
fn round_half_up(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
/// The size glyphs are actually scaled to: the reference browser drops
/// everything past the second decimal of a font size. Its font cache keys
/// faces by the size times a hundred as an integer and hands that back
/// divided by a hundred, all in single precision — which keeps 18.4 from
/// becoming 18.39, and makes 33.46 the float nearest to it rather than
/// the double.
fn effective_size(size : Double) -> Double {
  let hundredths = Float::from_double(
    (Float::from_double(size) * 100).to_double().floor(),
  )
  (hundredths / 100).to_double()
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
/// `gfx::SkRectToRectF`: the box between two corners. Whenever origin
/// plus the rounded size is not the far edge again — short of it or past
/// it — the size grows by one step.
fn RectF::from_corners(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> RectF {
  let mut width = right - left
  let mut height = bottom - top
  if left + width != right {
    width = Float::reinterpret_from_uint(width.reinterpret_as_uint() + 1)
  }
  if top + height != bottom {
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
/// `text` with the ligatures its faces form: a pair of characters from one
/// face that has a ligature for them becomes the ligature's character.
fn Stack::ligated(self : Stack, text : StringView) -> Array[Char] {
  let chars = text.to_array()
  if self.faces.iter().all(face => face.ligatures.is_empty()) {
    return chars
  }
  let out = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if i + 1 < chars.length() {
      let face = self.face_for(c)
      if physical_equal(face, self.face_for(chars[i + 1])) &&
        face.ligatures.get(c.to_int() * 65536 + chars[i + 1].to_int())
        is Some(ligature) {
        out.push(ligature)
        i += 2
        continue
      }
    }
    out.push(c)
    i += 1
  }
  out
}

///|
/// The stack of the font a page falls back to when a style names no
/// family the browser accepts: Times on the reference system.
pub fn Stack::page_default() -> Stack {
  { faces: [times_regular], }
}

///|
/// The stack of the generic `sans-serif` family: Helvetica on the
/// reference system.
pub fn Stack::sans_serif() -> Stack {
  { faces: [helvetica_regular], }
}

///|
/// The advance in ems of a character no embedded face has. The reference
/// browser draws it from a system fallback font; the advances of a few
/// symbols were read off it, the rest is approximated with half an em, or
/// a full one for the wide scripts.
fn fallback_em(c : Char) -> Double {
  match c.to_int() {
    // BLACK HEART SUIT
    0x2665 => 0.59375
    // HEAVY BLACK HEART
    0x2764 => 0.91015625
    code => if code >= 0x1100 { 1.0 } else { 0.5 }
  }
}

///|
/// The result of shaping: the advance width before rounding, and the ink
/// bounds around the baseline origin, y down.
priv struct Shaped {
  mut pen : Float
  mut ink : RectF
}

///|
/// The extent of a run's glyphs as Blink's `GlyphBoundsAccumulator` keeps
/// it: four edges, each the least or greatest seen so far. Only at the
/// end do they become an origin and a size, by plain subtraction — unlike
/// a chain of `RectF` unions, which rounds at every step.
priv struct Edges {
  mut min_x : Float
  mut max_x : Float
  mut min_y : Float
  mut max_y : Float
}

///|
fn Edges::unite(self : Edges, box : RectF) -> Unit {
  if box.is_empty() {
    return
  }
  let right = box.x + box.width
  let bottom = box.y + box.height
  // Upstream takes two zero edges to mean that nothing was added yet.
  if self.min_x == 0.0 && self.max_x == 0.0 {
    self.min_x = box.x
    self.max_x = right
    self.min_y = box.y
    self.max_y = bottom
    return
  }
  if box.x < self.min_x {
    self.min_x = box.x
  }
  if right > self.max_x {
    self.max_x = right
  }
  if box.y < self.min_y {
    self.min_y = box.y
  }
  if bottom > self.max_y {
    self.max_y = bottom
  }
}

///|
fn Edges::bounds(self : Edges) -> RectF {
  {
    x: self.min_x,
    y: self.min_y,
    width: self.max_x - self.min_x,
    height: self.max_y - self.min_y,
  }
}

///|
/// A run being shaped: consecutive glyphs of one face. Advances add up
/// exactly, in 16.16 fixed point, from where the run starts.
priv struct Run {
  face : Face
  edges : Edges
  origin : Int64
  mut total : Int64
  mut previous : Glyph?
}

///|
/// A 16.16 fixed point length as a float: `FixedPoint::ToFloat`.
fn fixed_to_float(value : Int64) -> Float {
  Float::from_double(value.to_double()) / HB_ONE
}

///|
/// The advance of a character no embedded face has, as a float.
fn fallback_advance(c : Char, size : Double) -> Float {
  Float::from_double(size * fallback_em(c))
}

///|
/// The box of a glyph's outline at `size`: each edge scaled and rounded
/// to a float on its own, then turned from Skia's four edges into origin
/// and size. Nothing for a glyph without an outline.
fn Face::glyph_bounds(self : Face, glyph : Glyph, size : Double) -> RectF? {
  if glyph.x_min == glyph.x_max && glyph.y_min == glyph.y_max {
    return None
  }
  let scale = size / self.units_per_em.to_double()
  Some(
    RectF::from_corners(
      Float::from_double(glyph.x_min.to_double() * scale),
      Float::from_double(-glyph.y_max.to_double() * scale),
      Float::from_double(glyph.x_max.to_double() * scale),
      Float::from_double(-glyph.y_min.to_double() * scale),
    ),
  )
}

///|
/// Shape `text` at `size` pixels. Consecutive characters of the same face
/// form a run and kern against each other; a change of face starts a new
/// run, where the one before ends.
fn Stack::shape(self : Stack, text : StringView, size : Double) -> Shaped {
  let size = effective_size(size)
  let shaped = { pen: 0.0, ink: { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }, }
  // A finished run adds its width, as a float, and its box.
  let close = (run : Run?) => {
    guard run is Some(run) else { return }
    shaped.ink = shaped.ink.union(run.edges.bounds())
    let total = if run.total < 0L { 0L } else { run.total }
    shaped.pen = shaped.pen + fixed_to_float(total)
  }
  let mut current : Run? = None
  for c in self.ligated(text) {
    let face = self.face_for(c)
    guard face.glyphs.get(c.to_int()) is Some(glyph) else {
      close(current)
      current = None
      shaped.pen = shaped.pen + fallback_advance(c, size)
      continue
    }
    let run = match current {
      Some(run) if physical_equal(run.face, face) => run
      _ => {
        close(current)
        // The run starts at the width so far, rounded up to a fixed
        // point position.
        let run : Run = {
          face,
          edges: { min_x: 0.0, max_x: 0.0, min_y: 0.0, max_y: 0.0, },
          origin: (shaped.pen.to_double() * 65536.0).ceil().to_int64(),
          total: 0L,
          previous: None,
        }
        current = Some(run)
        run
      }
    }
    // Kerning is part of the advance of the glyph before.
    if run.previous is Some(left) &&
      face.kerning.get(left.id * 65536 + glyph.id) is Some(adjust) {
      run.total += face.scale_fixed(adjust, size).to_int64()
    }
    if face.glyph_bounds(glyph, size) is Some(bounds) {
      let origin = fixed_to_float(run.origin + run.total)
      run.edges.unite({ ..bounds, x: bounds.x + origin, })
    }
    run.total += face.advance_fixed(glyph.advance, size).to_int64()
    run.previous = Some(glyph)
  }
  close(current)
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
  // Exact sums in 16.16 fixed point, like the advances of a run.
  let sums : Array[Int64] = items.map(_ => 0L)
  let mut previous : (Face, Glyph, Int32)? = None
  for index, item in items {
    for c in item {
      let face = self.face_for(c)
      guard face.glyphs.get(c.to_int()) is Some(glyph) else {
        sums[index] += (fallback_advance(c, size) * HB_ONE).to_int().to_int64()
        previous = None
        continue
      }
      if previous is Some((left_face, left, left_index)) &&
        physical_equal(left_face, face) &&
        face.kerning.get(left.id * 65536 + glyph.id) is Some(adjust) {
        sums[left_index] += face.scale_fixed(adjust, size).to_int64()
      }
      sums[index] += face.advance_fixed(glyph.advance, size).to_int64()
      previous = Some((face, glyph, index))
    }
  }
  sums.map(sum => ceil_layout_unit(fixed_to_float(sum)))
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
/// How far a line of this stack's first face, at normal line height,
/// reaches below its baseline: the gap a browser leaves under an inline
/// image or `<svg>` standing on the baseline of an otherwise empty block.
pub fn Stack::line_descent(self : Stack, size : Double) -> Double {
  self.faces[0].line_descent(size)
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
/// installed ones, Trebuchet MS, Verdana and Arial are embedded. A list
/// naming none of them falls back to Arial, the closest embedded face to
/// the system sans-serif.
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
      "arial" | "helvetica" | "sans-serif" => Some(arial(bold, italic))
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
fn arial(bold : Bool, italic : Bool) -> Face {
  match (bold, italic) {
    (false, false) => arial_regular
    (true, false) => arial_bold
    (false, true) => arial_italic
    (true, true) => arial_bold_italic
  }
}

///|
/// Whether every character of `text` has a glyph in one of the stack's
/// faces. Any other character is drawn from a system fallback font in the
/// reference browser, and measured here only roughly; a caller that needs
/// exact measurements can refuse such text.
pub fn Stack::covers(self : Stack, text : StringView) -> Bool {
  for c in text {
    if !self.faces.iter().any(face => face.covers(c)) {
      return false
    }
  }
  true
}

///|
/// The x-height of the stack's first face at `size` pixels: what `1ex`
/// measures, and twice the distance from the alphabetic baseline to the
/// one `dominant-baseline: middle` aligns. The reference platform reports
/// the face's OS/2 x-height or, for a face without one, the height of its
/// `x`; in the embedded faces the two are the same number.
pub fn Stack::x_height(self : Stack, size : Double) -> Double {
  let face = self.faces[0]
  guard face.glyphs.get('x'.to_int()) is Some(glyph) else { return 0.0 }
  Float::from_double(
    effective_size(size) *
    glyph.y_max.to_double() /
    face.units_per_em.to_double(),
  ).to_double()
}
