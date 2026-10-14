// The chart builder sizes its parts by the text they hold, measured in
// the browser: each text is put in a hidden `<text>` holding one
// `<tspan x="0" y="0.9em" dy="1em">`, whose `getBoundingClientRect()` is
// divided by the scale the `<svg>` is drawn at.

///|
/// A box in single precision, united the way `gfx::RectF` does.
priv struct BoxF {
  x : Float
  y : Float
  width : Float
  height : Float
}

///|
/// A box from its edges: where origin plus the rounded size falls short
/// of the far edge, the size grows by one step.
fn BoxF::from_edges(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> BoxF {
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
fn BoxF::is_empty(self : BoxF) -> Bool {
  self.width <= 0 || self.height <= 0
}

///|
fn BoxF::unite(self : BoxF, other : BoxF) -> BoxF {
  if self.is_empty() {
    return other
  }
  if other.is_empty() {
    return self
  }
  let min = (a : Float, b : Float) => if b < a { b } else { a }
  let max = (a : Float, b : Float) => if a < b { b } else { a }
  BoxF::from_edges(
    min(self.x, other.x),
    min(self.y, other.y),
    max(self.x + self.width, other.x + other.width),
    max(self.y + self.height, other.y + other.height),
  )
}

///|
/// Measures text the way the chart builder's
/// `TextDimensionCalculatorWithFont` does.
priv struct Measurer {
  font : @font.Stack
  /// Where the chart's user space is on the page.
  placement : @diagram.Placement
  /// The font size of the diagram, which text is measured at when the
  /// size asked for is not one: the theme's `fontSize`, if in pixels.
  inherited_size : Double?
  /// The font sizes text has been laid out at so far, by the key the
  /// browser's font cache files them under.
  sizes : Map[Int32, Double]
}

///|
fn Measurer::new(
  font : @font.Stack,
  placement : @diagram.Placement,
  font_size~ : String = "16px",
) -> Measurer {
  let inherited_size = match font_size.strip_suffix("px") {
    Some(number) if number.iter().all(c => c is ('0'..<='9' | '.')) => {
      let size = @string.parse_double(number.to_owned()) catch { _ => 0.0 }
      if size > 0.0 {
        Some(size)
      } else {
        None
      }
    }
    _ => None
  }
  { font, placement, inherited_size, sizes: Map([]), }
}

///|
/// The size the browser's font cache has a face at for text asked for at
/// `size`.
///
/// Blink keeps two decimals of a font size and files the face under that
/// size times a hundred, truncated — in single precision, where 4.93
/// times a hundred falls just short of 493 and lands on the key of 4.92.
/// Whichever of two such sizes is asked for first is the size of the
/// face both get. (The cache lives as long as the page, so in a browser
/// earlier diagrams count too; here every chart starts afresh.)
fn Measurer::cached_size(self : Measurer, size : Double) -> Double {
  let f = Float::from_double
  let hundredths = f((f(size) * 100).to_double().floor())
  let effective : Float = hundredths / 100
  let key = (effective * 100).to_double().to_int()
  match self.sizes.get(key) {
    Some(first) => first
    None => {
      self.sizes[key] = size
      size
    }
  }
}

///|
/// Text as SVG lays it out: white space collapses to single spaces and
/// goes from both ends.
fn collapse_spaces(text : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for c in text {
    if c is (' ' | '\t' | '\n' | '\r') {
      pending = true
      continue
    }
    if pending && !out.is_empty() {
      out.write_char(' ')
    }
    pending = false
    out.write_char(c)
  }
  out.to_string()
}

///|
/// The width and height the chart builder takes `text` at `size` to
/// have.
///
/// The text's box is its cell — its advance wide, from the font's ascent
/// above the baseline to its descent below — united with its ink. Blink
/// lays the text out with the font scaled to the screen and scales the
/// box back to user units; `getBoundingClientRect()` then maps it to the
/// viewport, and the builder divides by the scale again. Every step but
/// the last is rounded to single precision, which is where the odd last
/// digits of the chart's coordinates come from. The mapping was checked
/// against 7140 measurements in the reference browser.
fn Measurer::dimension(
  self : Measurer,
  text : String,
  size : Double,
) -> (Double, Double) raise Unsupported {
  // What the sanitizer escaped is measured as the characters it stands
  // for.
  let text = collapse_spaces(
    text
    .replace_all(old="&lt;", new="<")
    .replace_all(old="&gt;", new=">")
    .replace_all(old="&amp;", new="&"),
  )
  // Text of no size has an empty box.
  if text == "" || size == 0.0 {
    return (0.0, 0.0)
  }
  // A negative `font-size` attribute is not valid, which leaves the
  // text at the size of the diagram.
  let size = if size > 0.0 {
    size
  } else {
    guard self.inherited_size is Some(inherited) else {
      raise Unsupported("text at the font size \{@dom.number(size)}")
    }
    inherited
  }
  if !self.font.covers(text) {
    raise Unsupported("measuring text outside the embedded fonts: \{text}")
  }
  let f = Float::from_double
  let placement = self.placement
  // The factor text is laid out at: the scale it has on screen.
  let scale = placement.scale
  let factor = f(((scale * scale + scale * scale) / 2.0).sqrt())
  let scaled_size = self.cached_size((f(size) * factor).to_double())
  // `y="0.9em"` and `dy="1em"`, each resolved and scaled in single
  // precision.
  let baseline = f(0.9) * f(size) * factor + f(1.0) * f(size) * factor
  let (ascent, descent) = self.font.line_metrics(scaled_size)
  let cell = BoxF::from_edges(
    0,
    baseline - f(ascent),
    f(self.font.advance(text, scaled_size)),
    baseline + f(descent),
  )
  let ink = self.font.ink(text, scaled_size)
  let ink_box : BoxF = {
    x: f(ink.x),
    y: baseline + f(ink.y),
    width: f(ink.width),
    height: f(ink.height),
  }
  let box = ink_box.unite(cell)
  // Back to user units.
  let inverse : Float = 1 / factor
  let left = box.x * inverse
  let top = box.y * inverse
  let right = left + box.width * inverse
  let bottom = top + box.height * inverse
  // To the viewport, corner by corner: first to the corner's place in
  // the `<svg>` element, then by where that element is, rounded to
  // single precision each time.
  let to_client = (user : Float, shift : Double, origin : Double) => {
    f(f(user.to_double() * scale + shift).to_double() + origin)
  }
  let client_left = to_client(left, placement.dx, placement.left)
  let client_right = to_client(right, placement.dx, placement.left)
  let client_top = to_client(top, placement.dy, placement.top)
  let client_bottom = to_client(bottom, placement.dy, placement.top)
  (
    (client_right - client_left).to_double() / scale,
    (client_bottom - client_top).to_double() / scale,
  )
}

///|
/// The largest width and the largest height among `texts` at `size`.
fn Measurer::max_dimension(
  self : Measurer,
  texts : Array[String],
  size : Double,
) -> (Double, Double) raise Unsupported {
  let mut width = 0.0
  let mut height = 0.0
  for text in texts {
    let (w, h) = self.dimension(text, size)
    width = width.max(w)
    height = height.max(h)
  }
  (width, height)
}
