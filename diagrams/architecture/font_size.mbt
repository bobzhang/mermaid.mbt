// The font size of icon text as upstream reads it back from the browser:
// `parseInt(getComputedStyle(div).fontSize.replace(/\D/g, ""))`.

///|
/// The size in pixels the browser computes for the theme's `fontSize`,
/// which the stylesheet sets on the diagram's `<svg>` and the page around
/// it leaves at 16px. An invalid declaration (a bare number, an unknown
/// unit, a negative size, a word) inherits the 16px. `None` for what the port does
/// not resolve: keywords, `calc()`, and sizes Chrome clamps (below its
/// minimum font size, above 10000px).
fn css_font_size(theme_size : Json) -> Double? {
  let page = 16.0
  let text = match theme_size {
    String(text) => text.trim(chars=" \t\n\r\u{c}").to_owned().to_lower()
    // A number is no CSS length; the page keeps 16px.
    _ => return Some(page)
  }
  let mut digits = 0
  for c in text {
    guard c is ('0'..<='9' | '.') else { break }
    digits += 1
  }
  if digits == 0 {
    return match text {
      // Size keywords and functions compute to sizes the port does not
      // derive; `medium` and the global keywords leave the page's.
      "xx-small"
      | "x-small"
      | "small"
      | "large"
      | "x-large"
      | "xx-large"
      | "xxx-large"
      | "larger"
      | "smaller"
      | "math" => None
      _ if text.contains("(") => None
      _ => Some(page)
    }
  }
  let number = @string.parse_double(text[:digits]) catch { _ => return None }
  let size = match text[digits:] {
    "px" => number
    "em" | "rem" => number * page
    "%" => number / 100.0 * page
    "pt" => number * 4.0 / 3.0
    "pc" => number * 16.0
    "in" => number * 96.0
    "cm" => number * 96.0 / 2.54
    "mm" => number * 96.0 / 25.4
    _ => return Some(page)
  }
  if size < 9.0 || size > 10000.0 {
    None
  } else {
    Some(size)
  }
}

///|
/// `parseInt(size.replace(/\D/g, ""))` of a computed font size: Blink keeps
/// it in single precision and prints six significant digits, and every
/// character that is not a digit goes, the point of `17.6px` too.
fn computed_font_size(theme_size : Json) -> Double? {
  guard css_font_size(theme_size) is Some(size) else { return None }
  let size = Float::from_double(size).to_double()
  let whole = size.floor()
  let integer_digits = whole.to_int64().to_string().length()
  let decimals = (6 - integer_digits).max(0)
  let mut scale = 1.0
  for _ in 0..<decimals {
    scale = scale * 10.0
  }
  // The digits, with the trailing zeros of the fraction dropped.
  let mut scaled = (size * scale).round()
  let mut kept = decimals
  while kept > 0 && scaled % 10.0 == 0.0 {
    scaled = scaled / 10.0
    kept -= 1
  }
  Some(scaled)
}

///|
test "computed font sizes as Chrome reports them" {
  let sizes = [
    "16px", "1em", "1.1em", "10pt", "15.123456px", "15.5px", "016px", "20", "1rem",
    "120%", "x", "2.5em", "12.34567px", "-1px", "medium", "larger",
  ].map(size => {
    match computed_font_size(Json::string(size)) {
      Some(value) => @dom.number(value)
      None => "-"
    }
  })
  // Chrome: 16px 16px 17.6px 13.3333px 15.1235px 15.5px 16px 16px 16px
  // 19.2px 16px 40px 12.3457px 16px 16px 19.2px (not derived).
  inspect(
    sizes.join(" "),
    content="16 16 176 133333 151235 155 16 16 16 192 16 40 123457 16 16 -",
  )
}
