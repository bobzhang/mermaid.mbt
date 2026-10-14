// The inline styles of a label that change how its text measures: weight,
// slant, size and family. They are written on the label's element, so the
// browser lays the text out with them.

///|
/// The number at the start of a CSS length and the unit after it.
fn css_length(value : String) -> (Double, String)? {
  let mut end = 0
  for c in value {
    guard c is ('0'..<='9' | '.' | '-' | '+') else { break }
    end += 1
  }
  guard end > 0 else { return None }
  let number = @string.parse_double(value[:end].to_owned()) catch {
    _ => return None
  }
  Some((number, value[end:].trim().to_owned()))
}

///|
/// The environment text is measured in under the declarations of `style`,
/// such as `color:#fff !important;font-weight:bold !important`. SVG text
/// names weight and slant on every `<tspan>`, so there only size and
/// family reach the text: `faces` is false.
fn Env::styled(self : Env, style : String, faces~ : Bool = true) -> Env {
  if !style.contains("font") {
    return self
  }
  let mut env = self
  for declaration in style.split(";") {
    guard declaration.find(":") is Some(colon) else { continue }
    let name = declaration[:colon].trim().to_owned().to_lower()
    let value = declaration[colon + 1:]
      .to_owned()
      .replace_all(old="!important", new="")
      .trim()
      .to_owned()
    match name {
      "font-weight" if faces => {
        let bold = match value.to_lower() {
          "bold" | "bolder" => true
          "normal" | "lighter" => false
          other =>
            match css_length(other) {
              // With a regular and a bold face to choose from, font
              // matching takes the bold one for any weight above 500.
              Some((weight, "")) => weight > 500.0
              _ => env.bold
            }
        }
        env = { ..env, bold, }
      }
      "font-style" if faces => {
        let italic = match value.to_lower() {
          "italic" => true
          "normal" => false
          other => other.has_prefix("oblique")
        }
        env = { ..env, italic, }
      }
      "font-size" =>
        match css_length(value) {
          Some((size, "px")) => env = { ..env, font_size: size, }
          // Relative sizes compound over the elements the style is
          // written on, which differ from label to label; not modelled.
          _ => ()
        }
      "font-family" => env = { ..env, font_family: value, }
      _ => ()
    }
  }
  env
}

///|
/// The size edge labels are set in: some diagrams' stylesheets fix it,
/// whatever the theme's font size.
fn edge_label_font_size(diagram_type : String, font_size : Double) -> Double {
  match diagram_type {
    // `.edgeLabel .label { font-size: 14px }`
    "er" => 14.0
    // `.relationship-label, .edgeLabel { font-size: 10px }`
    "usecase" => 10.0
    _ => font_size
  }
}

///|
/// The horizontal padding the diagram's stylesheet gives the background
/// of HTML edge labels, on both sides together.
fn label_background_padding(diagram_type : String) -> Double {
  match diagram_type {
    // `.labelBkg { padding: 0 2px }`
    "usecase" => 4.0
    _ => 0.0
  }
}

///|
/// Whether the label of an edge takes the edge's own styles besides
/// those of its classes. Use case edges keep their own in `style`, which
/// upstream's label code does not read.
fn edge_label_uses_own_styles(diagram_type : String) -> Bool {
  diagram_type != "usecase"
}

///|
/// Whether the diagram's stylesheet centres the SVG text of node labels
/// on its position (`.node .label text { text-anchor: middle }`).
fn node_text_centred(diagram_type : String) -> Bool {
  !(diagram_type
  is ("er"
  | "requirement"
  | "stateDiagram"
  | "classDiagram"
  | "kanban"
  | "usecase"))
}

///|
/// The face and size an inline label style asks for.
priv struct LabelFont {
  bold : Bool
  italic : Bool
  size : Double?
}

///|
/// Read `font-weight`, `font-style` and a `font-size` in pixels out of a
/// style text such as `color:red !important;font-weight:bold !important`.
fn label_font(style : String) -> LabelFont {
  let mut bold = false
  let mut italic = false
  let mut size : Double? = None
  for declaration in style.split(";") {
    guard declaration.find(":") is Some(colon) else { continue }
    let name = declaration[:colon].trim().to_owned().to_lower()
    let value = declaration[colon + 1:]
      .to_owned()
      .replace(old="!important", new="")
      .trim()
      .to_owned()
      .to_lower()
    match name {
      "font-weight" =>
        bold = match value {
          "bold" | "bolder" => true
          _ =>
            match (@string.parse_double(value) catch { _ => 0.0 }) {
              // With a regular and a bold face to choose from, font matching
              // takes the bold one for any weight above 500.
              weight => weight > 500.0
            }
        }
      "font-style" => italic = value is ("italic" | "oblique")
      "font-size" =>
        if value.has_suffix("px") {
          size = Some(
            @string.parse_double(value[:value.length() - 2].to_owned()) catch {
              _ => continue
            },
          )
        }
      _ => ()
    }
  }
  { bold, italic, size, }
}

///|
/// Whether an inline label style has `white-space: nowrap`.
fn keeps_on_one_line(style : String) -> Bool {
  for declaration in style.split(";") {
    guard declaration.find(":") is Some(colon) else { continue }
    let name = declaration[:colon].trim().to_owned().to_lower()
    let value = declaration[colon + 1:]
      .to_owned()
      .replace(old="!important", new="")
      .trim()
      .to_owned()
      .to_lower()
    if name == "white-space" && value == "nowrap" {
      return true
    }
  }
  false
}
