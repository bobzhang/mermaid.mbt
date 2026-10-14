///|
/// The font a node's text is set in, with what the browser derives from
/// it to place lines aligned on the `middle` baseline.
priv struct TextStyle {
  font : @font.Stack
  size : Double
  /// Ascent above the alphabetic baseline, a whole number of pixels.
  ascent : Float
  /// The extent of a line above and below the middle baseline — half the
  /// x-height up from the alphabetic one — each rounded to a layout unit.
  ascent_middle : Float
  descent_middle : Float
}

///|
/// Round to Blink's layout unit, 1/64 of a pixel, halves away from zero.
fn round_layout_unit(value : Float) -> Float {
  let scaled = value.to_double() * 64.0
  let rounded = if scaled < 0.0 {
    -(0.5 - scaled).floor()
  } else {
    (scaled + 0.5).floor()
  }
  Float::from_double(rounded / 64.0)
}

///|
fn TextStyle::new(font : @font.Stack, size : Double) -> TextStyle {
  let f = Float::from_double
  let (ascent, descent) = font.line_metrics(size)
  let half_x_height = f(font.x_height(size)) / 2
  {
    font,
    size,
    ascent: f(ascent),
    ascent_middle: round_layout_unit(f(ascent) - half_x_height),
    descent_middle: round_layout_unit(f(descent) + half_x_height),
  }
}

///|
/// Text as SVG lays it out with the default `white-space`: runs of
/// blanks, tabs and line breaks are one blank, and none at either end.
fn collapse_white_space(text : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for c in text {
    if c is (' ' | '\t' | '\n' | '\r' | '\u{0c}') {
      pending = !out.is_empty()
    } else {
      if pending {
        out.write_char(' ')
        pending = false
      }
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// What `getComputedTextLength()` reports for a `<tspan>` holding `text`.
fn TextStyle::text_length(self : TextStyle, text : String) -> Double {
  self.font.advance(collapse_white_space(text), self.size)
}

///|
/// `text.split(/(\s+|<br>)/)`: the words of a description, with the
/// separators between them kept as items of their own.
fn split_words(text : String) -> Array[String] {
  let separator = try! @jsregex.Regex::compile("\\s+|<br>")
  let parts = []
  let mut last = 0
  let mut position = 0
  while position <= text.length() {
    guard separator.exec(text, from=position) is Some(found) else { break }
    parts.push(text[last:found.start].to_owned())
    parts.push(found.text())
    last = found.end
    position = found.end
  }
  parts.push(text[last:].to_owned())
  parts
}

///|
/// svgDraw's `wrap`: break a description into lines no longer than
/// `width`, one `<tspan>` each. Words are added to the current line until
/// it measures too long; `<br>` forces a break.
///
/// The quirks are upstream's: the words of a line are joined with the
/// blanks between them and one more blank on each side of those, a first
/// word that is too long leaves an empty line before it, and a trailing
/// `<br>` stays as text.
fn wrap(text : String, width : Double, style : TextStyle) -> Array[String] {
  let spans = [""]
  let mut line : Array[String] = []
  for word in split_words(text) {
    let current = spans.length() - 1
    line.push(word)
    spans[current] = @journeycommon.js_trim(line.join(" "))
    if style.text_length(spans[current]) > width || word == "<br>" {
      line.pop() |> ignore
      spans[current] = @journeycommon.js_trim(line.join(" "))
      line = if word == "<br>" { [""] } else { [word] }
      spans.push(word)
    }
  }
  spans
}

///|
/// A box in single precision, united the way Blink's `gfx::RectF` is.
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
  let next = (size : Float) => {
    Float::reinterpret_from_int(size.reinterpret_as_int() + 1)
  }
  let mut width = right - left
  let mut height = bottom - top
  if left + width < right {
    width = next(width)
  }
  if top + height < bottom {
    height = next(height)
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
fn BoxF::to_rect(self : BoxF) -> @dom.Rect {
  {
    x: self.x.to_double(),
    y: self.y.to_double(),
    width: self.width.to_double(),
    height: self.height.to_double(),
  }
}

///|
/// The box `getBBox()` reports for a wrapped node text: lines centred on
/// x = 0 and aligned on their middle baselines, the first one `1em` down
/// and each further one `1.1em` below the last.
///
/// A span without characters takes no position: its `dy` is never
/// applied, and the next span starts from where the text stood.
fn text_box(spans : Array[String], style : TextStyle) -> @dom.Rect {
  let f = Float::from_double
  let mut box : BoxF = { x: 0, y: 0, width: 0, height: 0, }
  let mut baseline : Float = 0
  for index, span in spans {
    let text = collapse_white_space(span)
    if text == "" {
      continue
    }
    // `em` lengths are the number times the font size, in single
    // precision.
    let dy = if index == 0 { 1.0 } else { 1.1 }
    baseline = baseline + f(dy) * f(style.size)
    let width = style.font.advance(text, style.size)
    let x = -width / 2.0
    let top = baseline - style.ascent_middle
    let cell = BoxF::from_edges(
      f(x),
      top,
      f(x + width),
      baseline + style.descent_middle,
    )
    // Glyphs are drawn from the alphabetic baseline.
    let ink = style.font.ink(text, style.size)
    let ink_box : BoxF = {
      x: f(x) + f(ink.x),
      y: top + style.ascent + f(ink.y),
      width: f(ink.width),
      height: f(ink.height),
    }
    box = box.unite(ink_box.unite(cell))
  }
  box.to_rect()
}
