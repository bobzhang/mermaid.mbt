///|
/// The font size the browser computes for `value`, a theme variable a
/// stylesheet writes after `font-size:`. `parent` is the size inherited
/// when the declaration is invalid, as a bare number is, and the size
/// relative units refer to. `None` for a value the port does not
/// measure (other units, keywords, sizes not above zero).
pub fn css_font_size(value : Json, parent : Double) -> Double? {
  let text = match value {
    String(text) => text.trim(chars=" \t\n").to_owned().to_lower()
    // A number is written without a unit: no length, but for zero.
    Number(number, ..) if number == 0.0 => return Some(0.0)
    _ => return Some(parent)
  }
  // An empty value (what theme sanitising leaves of one it rejects) is a
  // declaration the stylesheet compiler drops.
  if text == "" {
    return Some(parent)
  }
  guard @dom.css_dimension(text) is Some((number, unit)) else { return None }
  // A negative size is invalid, whatever its unit.
  if number < 0.0 {
    return Some(parent)
  }
  let size = match unit {
    "px" => number
    "em" => number * parent
    "rem" => number * 16.0
    "%" => number / 100.0 * parent
    "pt" => number * 4.0 / 3.0
    // A number without a unit is no length, but for zero.
    "" if number == 0.0 => 0.0
    "" => return Some(parent)
    _ => return None
  }
  // Zero is a size: text set in it takes no room.
  Some(size)
}
