///|
/// Parse the declarations of a `style` attribute, normalizing values as
/// the CSSOM would.
fn parse_declarations(text : String) -> Array[(String, String)] {
  let declarations = []
  for part in text.split(";") {
    guard part.find(":") is Some(colon) else { continue }
    let name = part[:colon].trim().to_owned()
    let value = part[colon + 1:].trim().to_owned()
    if name != "" && value != "" {
      declarations.push((name, normalize_value(name, value)))
    }
  }
  declarations
}

///|
/// A declaration value as the CSSOM serializes it.
fn normalize_value(name : String, value : String) -> String {
  if is_color_property(name) {
    serialize_color(value)
  } else {
    value.trim().to_owned()
  }
}

///|
/// Properties whose value is a color, which the browser stores resolved.
fn is_color_property(name : String) -> Bool {
  name
  is ("fill"
  | "stroke"
  | "color"
  | "background-color"
  | "stop-color"
  | "flood-color"
  | "lighting-color"
  | "border-color"
  | "outline-color")
}

///|
/// A color as the browser serializes it in a declaration: keywords stay,
/// everything else becomes `rgb()` or `rgba()` with whole channels.
fn serialize_color(value : String) -> String {
  let trimmed = value.trim().to_owned()
  let lower = trimmed.to_lower()
  if !(lower.has_prefix("#") ||
    lower.has_prefix("rgb") ||
    lower.has_prefix("hsl")) {
    return lower
  }
  let channels = @color.Channels::parse(trimmed) catch { _ => return trimmed }
  let (r, g, b) = channels.to_css_rgb()
  if channels.a() < 1.0 {
    "rgba(\{r}, \{g}, \{b}, \{number(channels.a())})"
  } else {
    "rgb(\{r}, \{g}, \{b})"
  }
}

///|
/// Set an inline style property, like d3's `selection.style`.
///
/// The browser keeps the declarations in the CSSOM and only writes the
/// `style` attribute back when something reads it — in practice when the
/// document is serialized. The attribute therefore appears after
/// attributes that were set later, and its text is re-serialized from the
/// parsed declarations: `name: value;` pairs, colors resolved.
pub fn Element::style(self : Element, name : String, value : String) -> Element {
  let value = normalize_value(name, value)
  let mut found = false
  for i, declaration in self.declarations {
    if declaration.0 == name {
      self.declarations[i] = (name, value)
      found = true
      break
    }
  }
  if !found {
    self.declarations.push((name, value))
  }
  self.style_dirty = true
  self
}

///|
/// Write pending declarations to the `style` attribute.
fn Element::sync_style(self : Element) -> Unit {
  if !self.style_dirty {
    return
  }
  self.style_dirty = false
  let text = self.declarations.map(d => "\{d.0}: \{d.1};").join(" ")
  for i, attribute in self.attributes {
    if attribute.0 == "style" {
      self.attributes[i] = ("style", text)
      return
    }
  }
  self.attributes.push(("style", text))
}
