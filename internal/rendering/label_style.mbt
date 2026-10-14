// What a label's own inline styles change about how its text is measured.

///|
/// The size edge labels are set in: some diagrams' stylesheets fix it,
/// whatever the theme's font size.
fn edge_label_font_size(diagram_type : String, font_size : Double) -> Double {
  match diagram_type {
    // `.edgeLabel .label { font-size: 14px }`
    "er" => 14.0
    _ => font_size
  }
}

///|
/// Whether the diagram's stylesheet centres the SVG text of node labels
/// on its position (`.node .label text { text-anchor: middle }`).
fn node_text_centred(diagram_type : String) -> Bool {
  !(diagram_type is ("er" | "requirement" | "classDiagram"))
}

///|
/// The environment inside a label group that carries `style`: a font
/// size there is the size of everything in the group.
fn Env::styled(self : Env, style : String) -> Env {
  match label_font(style).size {
    Some(size) => { ..self, font_size: size, }
    None => self
  }
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
              weight => weight >= 600.0
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
