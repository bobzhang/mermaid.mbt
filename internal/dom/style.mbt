///|
/// Parse the declarations of a `style` attribute, normalizing values as
/// the CSSOM would. Of several declarations of one property the last
/// stands, unless an earlier one is important and it is not; important
/// declarations come after the others.
fn parse_declarations(text : String) -> Array[(String, String)] {
  // Name, serialized value, importance.
  let parsed : Array[(String, String, Bool)] = []
  for part in text.split(";") {
    guard part.find(":") is Some(colon) else { continue }
    let name = part[:colon].trim().to_owned()
    let value = part[colon + 1:].trim().to_owned()
    if name != "" && value != "" {
      // Priority is kept apart from the value while it is normalized.
      let lower = value.to_lower()
      if lower.has_suffix("!important") {
        let base = value[:value.length() - 10].trim().to_owned()
        // A `!` left in the value, as in `left !important !important`,
        // makes the declaration invalid, and it is dropped.
        if base.contains("!") && !name.has_prefix("--") {
          continue
        }
        parsed.push((name, normalize_value(name, base) + " !important", true))
      } else {
        parsed.push((name, normalize_value(name, value), false))
      }
    }
  }
  let declarations = []
  // One declaration, or two of different longhand properties, are kept
  // as they are: Blink only sorts out what could collide.
  let plain = match parsed {
    [] | [_] => true
    [first, second] =>
      first.0 != second.0 && !is_shorthand(first.0) && !is_shorthand(second.0)
    _ => false
  }
  if plain {
    return parsed.map(declaration => (declaration.0, declaration.1))
  }
  for important in [false, true] {
    for index, declaration in parsed {
      let (name, value, is_important) = declaration
      if is_important != important {
        continue
      }
      // Overridden by a later declaration of the same importance, or by
      // an important one anywhere.
      let mut overridden = false
      for other, later in parsed {
        if later.0 == name &&
          ((later.2 == important && other > index) || (later.2 && !important)) {
          overridden = true
          break
        }
      }
      if !overridden {
        declarations.push((name, value))
      }
    }
  }
  declarations
}

///|
/// Whether a property stands for several, which the parser expands
/// before it counts declarations.
fn is_shorthand(name : String) -> Bool {
  name
  is ("animation"
  | "background"
  | "border"
  | "border-bottom"
  | "border-color"
  | "border-left"
  | "border-radius"
  | "border-right"
  | "border-style"
  | "border-top"
  | "border-width"
  | "columns"
  | "flex"
  | "flex-flow"
  | "font"
  | "gap"
  | "grid"
  | "grid-area"
  | "grid-column"
  | "grid-row"
  | "grid-template"
  | "inset"
  | "list-style"
  | "margin"
  | "marker"
  | "outline"
  | "overflow"
  | "padding"
  | "place-content"
  | "place-items"
  | "place-self"
  | "text-decoration"
  | "text-emphasis"
  | "text-wrap"
  | "transition"
  | "white-space")
}

///|
/// A declaration value as the CSSOM serializes it.
fn normalize_value(name : String, value : String) -> String {
  if is_color_property(name) {
    serialize_color(value)
  } else if name == "animation" {
    serialize_animation(value)
  } else if name == "stroke-dasharray" {
    // A list: commas between the lengths.
    let parts = []
    for part in value.replace_all(old=",", new=" ").split(" ") {
      if !part.is_empty() {
        parts.push(part.to_owned())
      }
    }
    parts.join(", ")
  } else {
    let value = value.trim().to_owned()
    css_length(value).unwrap_or(value)
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
  match serialize_alpha(channels.a()) {
    Some(alpha) => "rgba(\{r}, \{g}, \{b}, \{alpha})"
    None => "rgb(\{r}, \{g}, \{b})"
  }
}

///|
/// The alpha of a color as the CSSOM writes it, or `None` for a color
/// that is opaque once its alpha is an 8-bit value. Two decimals are
/// written when they give that 8-bit value back, three otherwise.
fn serialize_alpha(alpha : Double) -> String? {
  // Blink keeps alpha as a float and scales it as one.
  let scaled : Float = Float::from_double(alpha) * 255.0
  let byte = (scaled.to_double() + 0.5).floor().max(0.0).min(255.0)
  if byte == 255.0 {
    return None
  }
  let two_decimals = (byte * 100.0 / 255.0 + 0.5).floor() / 100.0
  if (two_decimals * 255.0 + 0.5).floor() == byte {
    Some(number(two_decimals))
  } else {
    Some(number((byte * 1000.0 / 255.0 + 0.5).floor() / 1000.0))
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

///|
/// The declarations of a rule as the CSSOM serializes them: `name: value;`
/// pairs with colors resolved, later duplicates replacing earlier ones.
pub fn serialize_declarations(text : String) -> String {
  let merged : Array[(String, String)] = []
  for declaration in parse_declarations(text) {
    match merged.search_by(existing => existing.0 == declaration.0) {
      Some(index) => {
        merged.remove(index) |> ignore
        merged.push(declaration)
      }
      None => merged.push(declaration)
    }
  }
  merged.map(d => "\{d.0}: \{d.1};").join(" ")
}

///|
/// The `animation` shorthand as the CSSOM serializes it: every longhand
/// spelled out in canonical order, the name last.
fn serialize_animation(value : String) -> String {
  // Only a single animation of plain keywords and times is understood;
  // anything else is kept as written.
  if value.contains(",") || value.contains("(") {
    return value.trim().to_owned()
  }
  let mut duration = "0s"
  let mut delay = "0s"
  let mut timing = "ease"
  let mut iterations = "1"
  let mut direction = "normal"
  let mut fill_mode = "none"
  let mut play_state = "running"
  let mut name = "none"
  let mut times = 0
  // A keyword that could be a longhand value is one only the first time.
  let mut has_direction = false
  let mut has_fill_mode = false
  let mut has_play_state = false
  let mut has_timing = false
  let mut has_iterations = false
  let is_time = (token : String) => {
    let number = match token.strip_suffix("ms") {
      Some(number) => number
      None =>
        match token.strip_suffix("s") {
          Some(number) => number
          None => return false
        }
    }
    number.length() > 0 &&
    number.iter().all(c => c is ('0'..<='9' | '.' | '-' | '+'))
  }
  let is_number = (token : String) => {
    token != "" && token.iter().all(c => c is ('0'..<='9' | '.'))
  }
  for part in value.split(" ") {
    let token = part.trim().to_owned()
    if token == "" {
      continue
    }
    let lower = token.to_lower()
    if is_time(lower) {
      if times == 0 {
        duration = lower
      } else {
        delay = lower
      }
      times += 1
    } else if !has_timing &&
      lower
      is ("linear"
      | "ease"
      | "ease-in"
      | "ease-out"
      | "ease-in-out"
      | "step-start"
      | "step-end") {
      timing = lower
      has_timing = true
    } else if !has_iterations && (lower == "infinite" || is_number(lower)) {
      iterations = lower
      has_iterations = true
    } else if !has_direction &&
      lower is ("normal" | "reverse" | "alternate" | "alternate-reverse") {
      direction = lower
      has_direction = true
    } else if !has_fill_mode &&
      lower is ("none" | "forwards" | "backwards" | "both") {
      fill_mode = lower
      has_fill_mode = true
    } else if !has_play_state && lower is ("running" | "paused") {
      play_state = lower
      has_play_state = true
    } else {
      name = token
    }
  }
  "\{duration} \{timing} \{delay} \{iterations} \{direction} \{fill_mode} \{play_state} \{name}"
}
