///|
/// Text the port cannot measure exactly as the reference browser does.
pub(all) suberror MeasureError {
  MeasureError(String)
} derive(Eq, Debug)

///|
/// The families whose metrics are embedded, as CSS names them.
let embedded_families : Array[String] = ["trebuchet ms", "verdana", "arial"]

///|
/// Families mermaid's themes and defaults name that are not installed in
/// the reference environment (checked there: text set in them measures as
/// in the next family of the list).
let absent_families : Array[String] = ["open sans", "recursive variable"]

///|
/// The font a diagram's text is measured in: the theme's `fontFamily`.
///
/// Only a list whose first installed family is an embedded one is
/// accepted. Any other choice is either installed in the reference
/// environment, with metrics unknown here, or the browser's default font.
pub fn theme_font(
  theme : @theme.Theme,
  bold~ : Bool = false,
) -> @font.Stack raise MeasureError {
  let family = theme.text("fontFamily")
  for name in family.split(",") {
    let name = name.trim(chars=" \t\n\"';").to_owned().to_lower()
    if absent_families.contains(name) {
      continue
    }
    if embedded_families.contains(name) {
      return @font.Stack::for_family(family, bold~)
    }
    break
  }
  raise MeasureError("text cannot be measured in the font family \{family}")
}

///|
/// The size the diagram's text inherits from the root rule
/// `font-size: <theme fontSize>`: a length in pixels. A bare number is
/// not a valid length in a stylesheet, which leaves the page's default of
/// 16px in force. Relative sizes depend on the page around the diagram.
pub fn theme_font_size(theme : @theme.Theme) -> Double raise MeasureError {
  let text = match theme.get("fontSize") {
    Number(n, ..) => @dom.number(n)
    String(text) => text.trim(chars=" \t\n").to_owned()
    _ => raise MeasureError("the theme has no font size")
  }
  let (number, unit) = match text.strip_suffix("px") {
    Some(number) => (number.to_owned(), true)
    None => (text, false)
  }
  let plain = number != "" &&
    number.iter().all(c => c is ('0'..<='9' | '.')) &&
    number.iter().filter(c => c == '.').count() <= 1 &&
    !number.has_suffix(".") &&
    !number.has_prefix(".")
  guard plain else { raise MeasureError("font size \{text} is not in pixels") }
  let value = @string.parse_double(number) catch {
    _ => raise MeasureError("font size \{text} is not in pixels")
  }
  if unit || value == 0.0 {
    value
  } else {
    16.0
  }
}

///|
/// Refuse text needing a glyph none of the embedded faces has: the
/// browser takes it from a fallback font. White space is exempt, since
/// SVG text lays every kind of it out as a blank.
pub fn require_glyphs(
  font : @font.Stack,
  text : String,
) -> Unit raise MeasureError {
  let blank = (c : Char) => {
    c is (' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}')
  }
  let drawn = String::from_array(text.iter().filter(c => !blank(c)).collect())
  if !font.covers(drawn) {
    raise MeasureError("text needs a fallback font to be measured: \{text}")
  }
}

///|
/// Text as SVG lays it out with the default `white-space`: runs of
/// blanks, tabs and line breaks are one blank, and none at either end.
pub fn collapse_white_space(text : String) -> String {
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
