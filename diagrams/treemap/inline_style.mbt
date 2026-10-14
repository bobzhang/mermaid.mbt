// The inline style of a text element, as the browser holds it. The
// renderer writes a `style` attribute as text and later changes single
// properties through the CSSOM (d3's `selection.style`). The first such
// change makes the browser write the attribute again from its parsed
// declarations, which normalizes it; an attribute that is never changed
// keeps its text.

///|
priv struct Declaration {
  name : String
  mut value : String
  mut important : Bool
  /// Whether `value` is known to be valid and is written the way the
  /// CSSOM serializes it.
  known : Bool
}

///|
priv struct InlineStyle {
  /// The attribute as written.
  raw : String
  declarations : Array[Declaration]
  /// Whether a property was changed since.
  mut changed : Bool
}

///|
/// A number as CSS serializes it.
fn css_number(text : String) -> String? {
  guard text != "" &&
    text.iter().all(c => c is ('0'..<='9' | '.')) &&
    text.iter().filter(c => c == '.').count() <= 1 &&
    !text.has_suffix(".") else {
    return None
  }
  Some(@dom.number(@diagram.parse_float(text)))
}

///|
/// The value of a declaration as the CSSOM serializes it; `None` for a
/// property the port does not know how the browser treats.
fn normalize(name : String, value : String) -> String? {
  let lower = value.to_lower()
  match name {
    "text-anchor" =>
      if lower is ("start" | "middle" | "end") {
        Some(lower)
      } else {
        None
      }
    "dominant-baseline" =>
      if lower is ("auto" | "middle" | "hanging" | "central") {
        Some(lower)
      } else {
        None
      }
    "display" =>
      if lower is ("none" | "inline" | "block") {
        Some(lower)
      } else {
        None
      }
    "font-size" =>
      match lower.strip_suffix("px") {
        Some(number) =>
          css_number(number.to_owned()).map(number => number + "px")
        None => None
      }
    "font-weight" =>
      if lower is ("normal" | "bold" | "bolder" | "lighter") {
        Some(lower)
      } else {
        match css_number(lower) {
          Some(number) => {
            let weight = @diagram.parse_float(number)
            if weight >= 1.0 && weight <= 1000.0 {
              Some(number)
            } else {
              None
            }
          }
          None => None
        }
      }
    "font-style" =>
      if lower is ("normal" | "italic") {
        Some(lower)
      } else {
        None
      }
    "fill" => {
      if lower is ("none" | "currentcolor" | "transparent") {
        return Some(lower)
      }
      // Anything the color parser does not know may be a keyword the
      // browser accepts, or an error it drops.
      (@color.Channels::parse(value) catch { _ => return None }) |> ignore
      let serialized = @dom.serialize_declarations("fill:" + value)
      match serialized.strip_prefix("fill: ") {
        Some(rest) => rest.strip_suffix(";").map(text => text.to_owned())
        None => None
      }
    }
    _ => None
  }
}

///|
/// Parse a `style` attribute the way the browser builds its declaration
/// block: of several declarations of a property the last one counts, an
/// `!important` one before any other, and the important ones are kept
/// after all the others.
fn InlineStyle::parse(raw : String) -> InlineStyle {
  let parsed : Array[Declaration] = []
  for part in raw.split(";") {
    guard part.find(":") is Some(colon) else { continue }
    let name = part[:colon].trim().to_owned().to_lower()
    let value = part[colon + 1:].trim().to_owned()
    let (value, important) = match value.to_lower().strip_suffix("!important") {
      Some(_) => (value[:value.length() - 10].trim().to_owned(), true)
      None => (value, false)
    }
    // A declaration without a name or a value is no declaration.
    guard name != "" && value != "" else { continue }
    match normalize(name, value) {
      Some(value) => parsed.push({ name, value, important, known: true, })
      None => parsed.push({ name, value, important, known: false, })
    }
  }
  let last = (important : Bool) => {
    let kept : Array[Declaration] = []
    for declaration in parsed.rev() {
      if declaration.important == important &&
        !kept.iter().any(other => other.name == declaration.name) {
        kept.push(declaration)
      }
    }
    kept.rev_in_place()
    kept
  }
  let important = last(true)
  let normal = last(false).filter(declaration => {
    !important.iter().any(other => other.name == declaration.name)
  })
  { raw, declarations: [..normal, ..important], changed: false, }
}

///|
/// `style.getPropertyValue(name)`.
fn InlineStyle::get(self : InlineStyle, name : String) -> String? {
  for declaration in self.declarations {
    if declaration.name == name {
      return Some(declaration.value)
    }
  }
  None
}

///|
/// `style.setProperty(name, value)`: the declaration is replaced where it
/// stands, or added at the end. Setting what is already there changes
/// nothing, and the attribute then keeps its text.
fn InlineStyle::set(self : InlineStyle, name : String, value : String) -> Unit {
  let value = normalize(name, value).unwrap_or(value)
  for declaration in self.declarations {
    if declaration.name == name {
      if declaration.value != value || declaration.important {
        declaration.value = value
        declaration.important = false
        self.changed = true
      }
      return
    }
  }
  self.declarations.push({ name, value, important: false, known: true, })
  self.changed = true
}

///|
/// The text of the `style` attribute as the document is serialized.
fn InlineStyle::text(self : InlineStyle) -> String raise TreemapError {
  if !self.changed {
    return self.raw
  }
  let parts = []
  for declaration in self.declarations {
    if !declaration.known {
      raise Unsupported(
        "the style \{declaration.name}:\{declaration.value} on a treemap label",
      )
    }
    parts.push(
      "\{declaration.name}: \{declaration.value}" +
      (if declaration.important { " !important;" } else { ";" }),
    )
  }
  parts.join(" ")
}

///|
/// Properties a class may set on a label that change how wide its text
/// is, in ways the port does not measure.
let unmeasured : Array[String] = [
  "font-family", "text-transform", "letter-spacing", "word-spacing", "white-space",
]

///|
/// The font a text with this inline style is drawn in, and its size.
/// `bold` and `italic` are what its presentation attributes ask for.
fn InlineStyle::font(
  self : InlineStyle,
  context : @diagram.Context,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> (@font.Stack, Double) raise TreemapError {
  for declaration in self.declarations {
    if declaration.name is ("font-size" | "font-weight" | "font-style") &&
      !declaration.known {
      raise Unsupported(
        "the style \{declaration.name}:\{declaration.value} on a treemap label",
      )
    }
  }
  let bold = match self.get("font-weight") {
    Some("bold" | "bolder") => true
    Some("normal" | "lighter") => false
    Some(weight) => @diagram.parse_float(weight) >= 600.0
    None => bold
  }
  let italic = match self.get("font-style") {
    Some(style) => style == "italic"
    None => italic
  }
  guard self.get("font-size") is Some(size) else {
    raise Unsupported("a treemap label without a font size")
  }
  (context.font(bold~, italic~), @diagram.parse_float(size))
}
