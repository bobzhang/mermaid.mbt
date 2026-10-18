// The `width` and `height` of an SVG root as lengths: CSS lengths, with a
// bare number taken as pixels, as Blink parses SVG presentation
// attributes.

///|
/// What a length attribute comes to.
priv enum SvgLength {
  /// A length in pixels, never negative.
  Pixels(Float)
  /// No length: a percentage, or a value that does not parse.
  Open
  /// A length the port does not evaluate, and which.
  Unevaluated(String)
}

///|
/// Pixels per unit: of the absolute units, and of the font-relative units
/// when the font size is known.
fn unit_scale(unit : String, font_size : Float?) -> Result[Double, String]? {
  let scale = match unit {
    "" | "px" => 1.0
    "in" => 96.0
    "cm" => 96.0 / 2.54
    "mm" => 96.0 / 25.4
    "q" => 96.0 / 101.6
    "pt" => 96.0 / 72.0
    "pc" => 16.0
    "em" | "rem" if font_size is Some(size) => size.to_double()
    "em" | "rem" => return Some(Err("length in \{unit} has a font size set"))
    // The metrics of the default font, which the port does not have.
    "ex"
    | "ch"
    | "ic"
    | "cap"
    | "lh"
    | "rex"
    | "rch"
    | "ric"
    | "rcap"
    | "rlh" => return Some(Err("length in \{unit} depends on the default font"))
    // The viewport of an image's document has no size yet.
    "vw" | "vh" | "vi" | "vb" | "vmin" | "vmax" => 0.0
    "svw" | "svh" | "svi" | "svb" | "svmin" | "svmax" => 0.0
    "lvw" | "lvh" | "lvi" | "lvb" | "lvmin" | "lvmax" => 0.0
    "dvw" | "dvh" | "dvi" | "dvb" | "dvmin" | "dvmax" => 0.0
    "cqw" | "cqh" | "cqi" | "cqb" | "cqmin" | "cqmax" => 0.0
    _ => return None
  }
  Some(Ok(scale))
}

///|
/// A length attribute's value.
fn svg_length(text : String, font_size : Float?) -> SvgLength {
  let text = text.trim(chars=" \t\n\r\u{0c}").to_owned()
  let chars = text.to_array()
  guard svg_number(chars, 0) is Some((value, end)) else {
    // A function (`calc(...)` and its kin) the port does not evaluate.
    if text.find("(") is Some(_) {
      return Unevaluated("length is a CSS function")
    }
    return Open
  }
  let unit = String::from_array(chars[end:])
  if unit == "%" {
    return Open
  }
  guard unit.iter().all(c => c is ('a'..<='z' | 'A'..<='Z')) else {
    return Open
  }
  match unit_scale(unit.to_lower(), font_size) {
    Some(Ok(scale)) => {
      let pixels = Float::from_double(value * scale)
      Pixels(if pixels < 0.0 { 0.0 } else { pixels })
    }
    Some(Err(reason)) => Unevaluated(reason)
    None => Open
  }
}
