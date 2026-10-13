///|
/// Parse the declarations of a `style` attribute.
fn parse_declarations(text : String) -> Array[(String, String)] {
  let declarations = []
  for part in text.split(";") {
    guard part.find(":") is Some(colon) else { continue }
    let name = part[:colon].trim().to_owned()
    let value = part[colon + 1:].trim().to_owned()
    if name != "" && value != "" {
      declarations.push((name, value))
    }
  }
  declarations
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
  let channel = (v : Double) => (v + 0.5).floor().to_int()
  let r = channel(channels.r())
  let g = channel(channels.g())
  let b = channel(channels.b())
  if channels.a() < 1.0 {
    "rgba(\{r}, \{g}, \{b}, \{number(channels.a())})"
  } else {
    "rgb(\{r}, \{g}, \{b})"
  }
}

///|
/// Set an inline style property, like d3's `selection.style`. The browser
/// re-serializes the whole `style` attribute from its parsed declarations,
/// so values come out normalized: `name: value;` pairs separated by spaces,
/// colors resolved.
pub fn Element::style(self : Element, name : String, value : String) -> Element {
  let declarations = match self.get_attr("style") {
    Some(text) => parse_declarations(text)
    None => []
  }
  let value = if is_color_property(name) {
    serialize_color(value)
  } else {
    value.trim().to_owned()
  }
  let mut found = false
  for i, declaration in declarations {
    if declaration.0 == name {
      declarations[i] = (name, value)
      found = true
      break
    }
  }
  if !found {
    declarations.push((name, value))
  }
  let text = declarations.map(d => "\{d.0}: \{d.1};").join(" ")
  self.attr("style", text)
}
