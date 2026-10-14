// Fonts named by a CSS `font-family` list, resolved as the reference
// browser resolves them as far as that can be known here.

///|
/// Families whose metrics are embedded, as CSS names them. The generic
/// `sans-serif` is Helvetica in the reference environment and `serif` is
/// Times, but only as keywords: in quotes they would name a family.
let css_embedded_families : Array[String] = [
  "trebuchet ms", "verdana", "arial", "helvetica", "times",
]

///|
let generic_families : Array[String] = ["sans-serif", "serif"]

///|
/// Keywords that are no family names: alone they are another value of
/// the property, in a list they make it invalid.
let css_wide_keywords : Array[String] = [
  "inherit", "initial", "unset", "revert", "revert-layer", "default",
]

///|
/// The name an item of a `font-family` list stands for, in lower case,
/// and whether it was quoted. `None` when the item is not valid CSS: the
/// browser then ignores the whole list.
fn family_name(item : StringView) -> (String, Bool)? {
  let item = item.trim(chars=" ")
  if item is ['"' | '\'' as quote, .. rest] {
    guard rest is [.. name, last] &&
      last == quote &&
      !name.iter().any(c => c == quote) else {
      return None
    }
    return Some((name.to_owned().to_lower(), true))
  }
  // A run of identifiers, joined by one blank each.
  let words = []
  for word in item.split(" ") {
    if word.is_empty() {
      continue
    }
    let letters = match word {
      ['-', .. rest] => rest
      _ => word
    }
    guard letters is ['A'..<='Z' | 'a'..<='z' | '_', .. rest] &&
      rest
      .iter()
      .all(c => c is ('A'..<='Z' | 'a'..<='z' | '0'..<='9' | '_' | '-')) else {
      return None
    }
    words.push(word.to_owned().to_lower())
  }
  let name = words.join(" ")
  if words.is_empty() || css_wide_keywords.contains(name) {
    return None
  }
  Some((name, false))
}

///|
/// The font text set in the CSS `font-family` list `family` is measured
/// in: the families of the list that are embedded. The first one that is neither embedded nor known to be
/// absent ends the list: it may be installed in the reference
/// environment, with metrics unknown here, and a character the families
/// before it lack is refused rather than measured in another face.
pub fn family_font(
  family : String,
  bold~ : Bool = false,
) -> @font.Stack raise MeasureError {
  let names = []
  for item in family.split(",") {
    // A list the browser does not accept as a `font-family` attribute
    // leaves the text in a font that depends on what is around it.
    guard family_name(item) is Some(name) else {
      raise MeasureError("the font family \{family} is not a list of families")
    }
    names.push(name)
  }
  let usable = []
  for name in names {
    let (name, quoted) = name
    if absent_families.contains(name) {
      continue
    }
    let embedded = css_embedded_families.contains(name) ||
      (!quoted && generic_families.contains(name))
    if !embedded {
      if usable.is_empty() {
        raise MeasureError(
          "text cannot be measured in the font family \{family}",
        )
      }
      break
    }
    usable.push(name)
  }
  if usable.is_empty() {
    // No family of the list is installed: the browser's standard font.
    @font.Stack::page_default(bold~)
  } else {
    @font.Stack::for_family(usable.join(", "), bold~)
  }
}
