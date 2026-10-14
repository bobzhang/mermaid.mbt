///|
/// A CSS font size in pixels. The stylesheet takes the theme's sizes as
/// they are written; only pixel lengths can be measured here.
fn css_pixels(name : String, value : Json) -> Double raise Unsupported {
  let unsupported = () => {
    Unsupported("\{name} is not a length in pixels: \{value.stringify()}")
  }
  guard value is String(text) else { raise unsupported() }
  guard text.trim().strip_suffix("px") is Some(digits) else {
    raise unsupported()
  }
  let size = @string.parse_double(digits) catch { _ => raise unsupported() }
  if size > 0.0 {
    size
  } else {
    raise unsupported()
  }
}

///|
/// Whether a CSS `font-weight` selects the bold face of a family that has
/// a regular and a bold one: weights above 500 do.
fn is_bold_weight(weight : Json) -> Bool {
  match weight {
    Number(weight, ..) => weight > 500.0
    String("bold" | "bolder") => true
    String(text) => (@string.parse_double(text) catch { _ => 400.0 }) > 500.0
    _ => false
  }
}

///|
/// Text as SVG lays it out without `xml:space="preserve"`: line breaks
/// and tabs are spaces, runs of spaces collapse, and the spaces at both
/// ends go.
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
/// The size `getBBox()` reports for a `<text>` holding `text`, wherever it
/// is: nothing when no glyph is laid out.
fn text_size(
  font : @font.Stack,
  text : String,
  size : Double,
) -> (Double, Double) {
  let text = collapse_spaces(text)
  if text == "" {
    return (0.0, 0.0)
  }
  let box = font.bbox(text, size)
  (box.width, box.height)
}

///|
/// Record the box the browser reports for `element`, a `<text>`, where
/// its `x` and `y` attributes put it. `middle` centres it on `x`.
///
/// Positions are single precision in the browser: the attributes are read
/// into floats, and the shift of `text-anchor: middle` is computed from
/// the two ends of the text rather than from half its advance.
fn place_text(
  element : @dom.Element,
  font : @font.Stack,
  size : Double,
  middle~ : Bool = false,
) -> Unit {
  let text = collapse_spaces(element.text_content())
  if text == "" {
    return
  }
  let f = Float::from_double
  let x = f(element.length_attr("x").unwrap_or(0.0))
  let y = f(element.length_attr("y").unwrap_or(0.0))
  let start = if middle {
    let end = x + f(font.advance(text, size))
    let shift = x - (x + end) / 2
    x + shift
  } else {
    x
  }
  let box = font.bbox(text, size)
  element.set_text_box({
    x: (start + f(box.x)).to_double(),
    y: (y + f(box.y)).to_double(),
    width: box.width,
    height: box.height,
  })
}
