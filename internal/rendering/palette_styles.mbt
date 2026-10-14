///|
/// `look`, if it is safe to put in a selector: mermaid's `safeLook`.
pub fn safe_look(look : String) -> String {
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
/// The stylesheet rules that colour nodes by their slot in the palette of
/// the colour themes, as the ER and requirement stylesheets write them:
/// one pair of rules per slot, nothing for other themes.
pub fn node_palette_rules(config : @config.Config) -> String {
  let theme = config.theme()
  guard config.text("theme") is Some("redux-color" | "redux-dark-color") &&
    theme.get("borderColorArray") is Array(borders) &&
    !borders.is_empty() else {
    return ""
  }
  let look = safe_look(config.text("look").unwrap_or(""))
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
