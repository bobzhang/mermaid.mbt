// Fonts of the `c4` configuration, as the stylesheet and the inline styles
// of the diagram write them and as the browser resolves them.

///|
/// The font of one kind of text: upstream's `C4Font`.
priv struct Font {
  /// A CSS `font-family` list, as the CSSOM serializes it.
  family : String
  /// The size in pixels.
  size : Double
  /// A CSS `font-weight`: a keyword or a number.
  weight : String
}

///|
/// Whether a weight selects the bold face of a family that has a regular
/// and a bold one: weights above 500 do.
fn is_bold(weight : String) -> Bool {
  match weight {
    "bold" | "bolder" => true
    "normal" | "lighter" => false
    _ => (@string.parse_double(weight) catch { _ => 400.0 }) > 500.0
  }
}

///|
/// A `font-family` value as the CSSOM serializes it: quoted names in
/// double quotes, the words of unquoted names a space apart, a comma and a
/// space between names. `None` for anything else, which the port does not
/// try to parse as CSS.
fn serialize_font_family(value : String) -> String? {
  let names = []
  for part in value.split(",") {
    let part = part.trim(chars=" \t\n").to_owned()
    if part == "" {
      return None
    }
    let chars = part.to_array()
    if chars[0] is ('"' | '\'') {
      let quote = chars[0]
      guard chars.length() >= 2 && chars[chars.length() - 1] == quote else {
        return None
      }
      let inner = chars[1:chars.length() - 1]
      guard !inner.iter().any(c => c is ('"' | '\'' | '\\' | '\n')) else {
        return None
      }
      names.push("\"" + String::from_array(inner) + "\"")
    } else {
      // A sequence of identifiers.
      let words = []
      for word in part.split(" ") {
        guard !word.is_empty() else { continue }
        let word = word.to_owned()
        let letters = word.to_array()
        guard letters
          .iter()
          .all(c => {
            c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-' | '_') ||
            c.to_int() >= 0x80
          }) &&
          !(letters[0] is ('0'..<='9')) else {
          return None
        }
        words.push(word)
      }
      names.push(words.join(" "))
    }
  }
  if names.is_empty() {
    None
  } else {
    Some(names.join(", "))
  }
}

///|
/// A `font-weight` value as the CSSOM keeps it, `None` when it is not one.
fn serialize_font_weight(value : Json) -> String? {
  match value {
    String("normal" | "bold" | "bolder" | "lighter" as keyword) => Some(keyword)
    String(text) =>
      match js_parse_int(text) {
        Some(number) if number >= 1.0 &&
          number <= 1000.0 &&
          number.to_int().to_string() == text => Some(text)
        _ => None
      }
    Number(number, ..) if number >= 1.0 && number <= 1000.0 =>
      Some(@dom.number(number))
    _ => None
  }
}

///|
/// A font size of the configuration in pixels: a number, or a string in
/// pixels.
fn font_size_px(value : Json) -> Double? {
  match value {
    Number(number, ..) if number > 0.0 => Some(number)
    String(text) => {
      let text = text.trim(chars=" \t\n").to_owned().to_lower()
      guard text.has_suffix("px") else { return None }
      let number = @string.parse_double(text[:text.length() - 2].to_owned()) catch {
        _ => return None
      }
      if number > 0.0 {
        Some(number)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// The font configured for `kind` (`person`, `boundary`, `message`, ...):
/// upstream's `conf.<kind>Font()`.
fn configured_font(
  config : @config.Config,
  kind : String,
) -> Font raise Unsupported {
  let family = config.get("c4.\{kind}FontFamily")
  let size = config.get("c4.\{kind}FontSize")
  let weight = config.get("c4.\{kind}FontWeight")
  let unsupported = (what : String, value : Json) => {
    Unsupported("C4: c4.\{kind}Font\{what} \{value.stringify()}")
  }
  guard family is String(family_text) &&
    serialize_font_family(family_text) is Some(family_text) else {
    raise unsupported("Family", family)
  }
  guard font_size_px(size) is Some(size) else {
    raise unsupported("Size", size)
  }
  guard serialize_font_weight(weight) is Some(weight) else {
    raise unsupported("Weight", weight)
  }
  { family: family_text, size, weight, }
}
