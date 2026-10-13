///|
/// Whether a CSS property styles the label rather than the shape.
fn is_label_style(key : String) -> Bool {
  key
  is ("color"
  | "font-size"
  | "font-family"
  | "font-weight"
  | "font-style"
  | "text-decoration"
  | "text-align"
  | "text-transform"
  | "line-height"
  | "letter-spacing"
  | "word-spacing"
  | "text-shadow"
  | "text-overflow"
  | "white-space"
  | "word-wrap"
  | "word-break"
  | "overflow-wrap"
  | "hyphens")
}

///|
/// The declarations of several style lists merged by property, later ones
/// winning: mermaid's `styles2Map`.
fn styles_map(styles : Array[String]) -> Map[String, String] {
  let map : Map[String, String] = Map([])
  for style in styles {
    let parts = style.split(":").map(part => part.to_owned()).collect()
    let key = parts[0].trim().to_owned()
    let value = if parts.length() > 1 { parts[1].trim().to_owned() } else { "" }
    map[key] = value
  }
  map
}

///|
/// The inline styles of a node or edge, split into those for its label and
/// those for its shape: mermaid's `styles2String`.
priv struct SplitStyles {
  label_styles : String
  node_styles : String
}

///|
fn split_styles(styles : Array[String]) -> SplitStyles {
  let map = styles_map(styles)
  let label_styles = []
  let node_styles = []
  for key, value in map {
    let declaration = "\{key}:\{value} !important"
    if is_label_style(key) {
      label_styles.push(declaration)
    } else {
      node_styles.push(declaration)
    }
  }
  { label_styles: label_styles.join(";"), node_styles: node_styles.join(";"), }
}

///|
/// `styles2String` of a node; also records the label styles on it.
fn node_styles(node : Node) -> SplitStyles {
  let styles = [..node.css_compiled_styles, ..node.css_styles]
  for style in node.label_style.split(";") {
    let style = style.trim().to_owned()
    if style != "" {
      styles.push(style)
    }
  }
  let split = split_styles(styles)
  node.label_style = split.label_styles
  split
}
