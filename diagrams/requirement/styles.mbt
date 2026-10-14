///|
/// `look`, if it is safe to put in a selector.
fn safe_look(look : String) -> String {
  if look != "" &&
    look
    .iter()
    .all(c => c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_' | '-')) {
    look
  } else {
    "classic"
  }
}

///|
fn palette_color(palette : Array[Json], index : Int32) -> String {
  match palette[index % palette.length()] {
    String(color) => color
    other => other.stringify()
  }
}

///|
/// Cycling per-node colors: one pair of rules per palette slot.
fn color_sections(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  guard theme_name is ("redux-color" | "redux-dark-color") &&
    theme.get("borderColorArray") is Array(borders) &&
    !borders.is_empty() else {
    return ""
  }
  let look = safe_look(look)
  let fills = match theme.get("bkgColorArray") {
    Array(fills) if !fills.is_empty() => Some(fills)
    _ => None
  }
  let out = StringBuilder()
  for i in 0..<borders.length() {
    let border = palette_color(borders, i)
    let fill = match fills {
      Some(fills) => "fill: \{palette_color(fills, i)};"
      None => ""
    }
    let slot = "[data-look=\"\{look}\"][data-color-id=\"color-\{i}\"]"
    out.write_string(
      (
        $|
        $|
        $|    \{slot}.node path {
        $|    stroke: \{border};
        $|    \{fill}
        $|    }
        $|
        $|    \{slot}.node  rect {
        $|    stroke: \{border};
        $|    \{fill}
        $|     }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// The requirement diagram's stylesheet, before it is scoped to the
/// diagram.
pub fn styles(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  let v = (name : String) => theme.text(name)
  let text_color = if theme.flag("nodeTextColor") {
    v("nodeTextColor")
  } else {
    v("textColor")
  }
  let stroke_width = if look == "neo" { v("strokeWidth") } else { "1px" }
  let label_background = match theme.get("requirementEdgeLabelBackground") {
    Null => v("edgeLabelBackground")
    _ => v("requirementEdgeLabelBackground")
  }
  (
    $|
    $|  \{color_sections(theme, theme_name, look)}
    $|  marker {
    $|    fill: \{v("relationColor")};
    $|    stroke: \{v("relationColor")};
    $|  }
    $|
    $|  marker.cross {
    $|    stroke: \{v("lineColor")};
    $|  }
    $|
    $|  svg {
    $|    font-family: \{v("fontFamily")};
    $|    font-size: \{v("fontSize")};
    $|  }
    $|
    $|  .reqBox {
    $|    fill: \{v("requirementBackground")};
    $|    fill-opacity: 1.0;
    $|    stroke: \{v("requirementBorderColor")};
    $|    stroke-width: \{v("requirementBorderSize")};
    $|  }
    $|  
    $|  .reqTitle, .reqLabel{
    $|    fill:  \{v("requirementTextColor")};
    $|  }
    $|  .reqLabelBox {
    $|    fill: \{v("relationLabelBackground")};
    $|    fill-opacity: 1.0;
    $|  }
    $|
    $|  .req-title-line {
    $|    stroke: \{v("requirementBorderColor")};
    $|    stroke-width: \{v("requirementBorderSize")};
    $|  }
    $|  .relationshipLine {
    $|    stroke: \{v("relationColor")};
    $|    stroke-width: \{stroke_width};
    $|  }
    $|  .relationshipLabel {
    $|    fill: \{v("relationLabelColor")};
    $|  }
    $|    .edgeLabel {
    $|    background-color: \{v("edgeLabelBackground")};
    $|  }
    $|  .edgeLabel .label rect {
    $|    fill: \{v("edgeLabelBackground")};
    $|  }
    $|  .edgeLabel .label text {
    $|    fill: \{v("relationLabelColor")};
    $|  }
    $|  .divider {
    $|    stroke: \{v("nodeBorder")};
    $|    stroke-width: 1;
    $|  }
    $|  .label {
    $|    font-family: \{v("fontFamily")};
    $|    color: \{text_color};
    $|  }
    $|  .label text,span {
    $|    fill: \{text_color};
    $|    color: \{text_color};
    $|  }
    $|  .labelBkg {
    $|    background-color: \{label_background};
    $|  }
    $|
    $|
  )
}
