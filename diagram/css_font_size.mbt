///|
/// The font size the browser computes for `value`, a theme variable a
/// stylesheet writes after `font-size:`. `parent` is the size inherited
/// when the declaration is invalid, as a bare number is, and the size
/// relative units refer to. `None` for a value the port does not
/// measure (other units, keywords, sizes not above zero).
pub fn css_font_size(value : Json, parent : Double) -> Double? {
  let text = match value {
    String(text) => text.trim(chars=" \t\n").to_owned().to_lower()
    // Written without a unit: not a length.
    _ => return Some(parent)
  }
  // An empty value (what theme sanitising leaves of one it rejects) is a
  // declaration the stylesheet compiler drops.
  if text == "" {
    return Some(parent)
  }
  let mut digits = 0
  for c in text {
    guard c is ('0'..<='9' | '.') else { break }
    digits += 1
  }
  let number = @string.parse_double(text[:digits]) catch { _ => return None }
  let size = match text[digits:] {
    "px" => number
    "em" => number * parent
    "rem" => number * 16.0
    "%" => number / 100.0 * parent
    "pt" => number * 4.0 / 3.0
    "" => return Some(parent)
    _ => return None
  }
  if size > 0.0 {
    Some(size)
  } else {
    None
  }
}
