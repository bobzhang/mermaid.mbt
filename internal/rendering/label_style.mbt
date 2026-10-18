// The inline styles of a label that change how its text measures: weight,
// slant, size and family. They are written on the label's element, so the
// browser lays the text out with them.

///|
/// The number at the start of a CSS length, as CSS writes one (`+12`,
/// `1e1`), and the unit right after it.
fn css_length(value : String) -> (Double, String)? {
  @dom.css_dimension(value)
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
          // A negative size is invalid, and refused before this.
          Some((size, "px")) if size >= 0.0 => env = { ..env, font_size: size, }
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
/// Whether the label measurement models a label style declaration. The
/// style is written on the label before the browser measures it, so a
/// declaration that changes how its text lays out (spacing, case, line
/// height, a relative size, other wrapping rules) changes the size of the
/// node; those are refused rather than measured wrong.
fn label_declaration_measured(key : String, value : String) -> Bool {
  let value = value
    .replace_all(old="!important", new="")
    .trim()
    .to_lower()
    .to_owned()
  match key {
    "color"
    | "text-decoration"
    | "text-align"
    | "text-shadow"
    | "text-overflow"
    | "font-family"
    | "font-weight"
    | "font-style" => true
    "font-size" => css_length(value) is Some((size, "px")) && size >= 0.0
    "text-transform" => value == "none"
    "letter-spacing" | "word-spacing" => value is ("normal" | "0" | "0px" | "")
    "white-space" => value is ("normal" | "nowrap")
    "word-wrap" | "overflow-wrap" | "word-break" => value == "normal"
    "hyphens" => value == "manual"
    // `line-height` and anything not a label style upstream.
    _ => !is_label_style(key)
  }
}

///|
/// Refuse a diagram whose node or edge labels carry a style the label
/// measurement does not model (see `label_declaration_measured`), whose
/// image or icon sizes are not numbers, or whose markers would be
/// absolute references.
fn check_label_styles(data : LayoutData) -> Unit raise LayoutError {
  let check = (styles : Array[String]) => {
    for key, value in styles_map(styles) {
      if !label_declaration_measured(key, value) {
        raise LayoutError(
          "the label style `\{key}:\{value}` changes the label's size, which is not ported",
        )
      }
    }
  }
  for node in data.nodes {
    // `Number("abc")`: a size that is not a number makes upstream's
    // geometry `NaN`, which the port does not follow.
    if node.data is Asset(asset_width~, asset_height~, ..) &&
      [asset_width, asset_height].any(size => {
        size is Some(size) && size.is_nan()
      }) {
      raise LayoutError(
        "the image or icon size of \{node.id} is not a number, which is not ported",
      )
    }
    let styles = [..node.css_compiled_styles, ..node.css_styles]
    for style in node.label_style.split(";") {
      let style = style.trim().to_owned()
      if style != "" {
        styles.push(style)
      }
    }
    check(styles)
  }
  // Marker references then start with the address of the page, which
  // a renderer without a page does not have.
  if !data.edges.is_empty() && marker_references_absolute(data) {
    raise LayoutError(
      "arrowMarkerAbsolute puts the page's address in the marker references, which is not ported",
    )
  }
  let own_styles = edge_label_uses_own_styles(data.diagram_type)
  for edge in data.edges {
    check(
      [..edge.css_compiled_styles, ..if own_styles { edge.style } else { [] }],
    )
  }
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
  | "usecase"
  | "mindmap"))
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

///|
/// Whether `insertEdge` writes marker references with the page's address:
/// `flowchart.arrowMarkerAbsolute || state.arrowMarkerAbsolute` as the
/// configuration reads when the diagram is drawn. The flowchart's diagrams
/// (flowcharts, swimlanes) and agentflow `setConfig` the root option over
/// `flowchart.arrowMarkerAbsolute` when they are set up, so there the root
/// one counts and the section's own is lost; the other diagrams' `init`
/// only change a copy of the configuration.
fn marker_references_absolute(data : LayoutData) -> Bool {
  let flowchart = match data.diagram_type {
    "flowchart-v2" | "flowchart-elk" | "swimlane" | "agentflow" =>
      data.config.flag("arrowMarkerAbsolute")
    _ => data.config.flag("flowchart.arrowMarkerAbsolute")
  }
  flowchart || data.config.flag("state.arrowMarkerAbsolute")
}
