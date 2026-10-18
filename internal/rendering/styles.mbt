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
/// `styles2String` of a node.
fn node_styles(node : Node) -> SplitStyles {
  let styles = [..node.css_compiled_styles, ..node.css_styles]
  for style in node.label_style.split(";") {
    let style = style.trim().to_owned()
    if style != "" {
      styles.push(style)
    }
  }
  split_styles(styles)
}

///|
/// `styles2String` of a node as shapes use it: the label styles are
/// recorded on the node for its label.
fn shape_styles(node : Node) -> SplitStyles {
  let split = node_styles(node)
  node.label_style = split.label_styles
  split
}

///|
/// The dash pattern of a `stroke-dasharray` style for rough.js.
fn stroke_dash_array(style : String?) -> Array[Double] {
  guard style is Some(style) && style != "" else { return [0.0, 0.0] }
  let numbers = []
  for part in style.trim().split(" ") {
    if !part.is_empty() {
      numbers.push(@string.parse_double(part.to_owned()) catch { _ => 0.0 })
    }
  }
  match numbers {
    [] => [0.0, 0.0]
    [value] => [value, value]
    [first, second, ..] => [first, second]
  }
}

///|
/// How rough.js draws a node's outline outside the hand-drawn look: the
/// node's own colours over the theme's, exact lines, plain fill. Mermaid's
/// `userNodeOverrides` with `roughness: 0` and `fillStyle: 'solid'`.
fn rough_options(node : Node, env : Env) -> @rough.Options {
  let theme = env.config.theme()
  let styles = [..node.css_compiled_styles, ..node.css_styles]
  for style in node.label_style.split(";") {
    let style = style.trim().to_owned()
    if style != "" {
      styles.push(style)
    }
  }
  let map = styles_map(styles)
  let pick = (name : String, fallback : String) => {
    match map.get(name) {
      Some(value) if value != "" => value
      _ => fallback
    }
  }
  let options = @rough.Options::new()
  if hand_drawn(node) {
    sketch_fill(options)
  } else {
    options.roughness = 0.0
    options.fill_style = "solid"
  }
  options.fill = pick("fill", theme.text("mainBkg"))
  options.stroke = pick("stroke", theme.text("nodeBorder"))
  options.stroke_width = match map.get("stroke-width") {
    Some(width) if width.replace(old="px", new="") != "" =>
      width.replace(old="px", new="")
    _ => "1.3"
  }
  options.stroke_line_dash = Some(
    stroke_dash_array(map.get("stroke-dasharray")),
  )
  options.seed = env.config.number("handDrawnSeed").unwrap_or(0.0).to_int()
  options
}
