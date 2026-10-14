///|
/// Text as SVG lays it out without `xml:space="preserve"`: line breaks
/// and tabs are spaces, runs of spaces collapse, and the spaces at both
/// ends go.
fn collapse_spaces(text : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for c in text {
    if c is (' ' | '\t' | '\n' | '\r') {
      pending = true
      continue
    }
    if pending && !out.is_empty() {
      out.write_char(' ')
    }
    pending = false
    out.write_char(c)
  }
  out.to_string()
}

///|
/// `getComputedTextLength()` of a text element holding `text`, in a
/// diagram displayed at `scale` times its size.
fn text_length(
  font : @font.Stack,
  text : String,
  size : Double,
  scale : Double,
) -> Double {
  let text = collapse_spaces(text)
  if text == "" {
    0.0
  } else {
    font.svg_text_length(text, size, scale~)
  }
}

///|
/// Record the box the browser reports for `element`, a `<text>` with `x`
/// and `y` attributes: where its anchor and its dominant baseline put it.
fn place_text(
  element : @dom.Element,
  font : @font.Stack,
  size : Double,
  anchor~ : String,
  baseline~ : String,
  scale~ : Double,
) -> Unit {
  let text = collapse_spaces(element.text_content())
  if text == "" {
    return
  }
  let box = font.svg_text_box(
    text,
    size,
    x=element.length_attr("x").unwrap_or(0.0),
    y=element.length_attr("y").unwrap_or(0.0),
    anchor~,
    baseline~,
    scale~,
  )
  element.set_text_box({
    x: box.x,
    y: box.y,
    width: box.width,
    height: box.height,
  })
}

///|
/// `String.prototype.trim`.
fn js_trim(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && @diagram.is_js_space(chars[start]) {
    start += 1
  }
  while end > start && @diagram.is_js_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// The declarations of a node's class, sorted by what they style:
/// mermaid's `styles2String`.
priv struct SplitStyles {
  /// Those for text, joined; `color` still under its own name.
  label_styles : String
  /// The names of the properties in `label_styles`.
  label_keys : Array[String]
  /// Those for shapes, joined.
  node_styles : String
  /// The shape declarations that mention a stroke.
  border_styles : Array[String]
}

///|
fn split_styles(styles : Array[String]) -> SplitStyles {
  // `styles2Map`: a later declaration of a property replaces the value
  // of an earlier one, in its place.
  let map : Map[String, String] = Map([])
  for style in styles {
    let parts = style.split(":").map(part => part.to_owned()).collect()
    let key = js_trim(parts[0])
    // A declaration without a colon has no value, which joins as nothing.
    map[key] = if parts.length() > 1 { js_trim(parts[1]) } else { "" }
  }
  let label = []
  let label_keys = []
  let node = []
  let border = []
  for key, value in map {
    let declaration = "\{key}:\{value} !important"
    if is_label_style(key) {
      label.push(declaration)
      label_keys.push(key)
    } else {
      node.push(declaration)
      if key.contains("stroke") {
        border.push(declaration)
      }
    }
  }
  {
    label_styles: label.join(";"),
    label_keys,
    node_styles: node.join(";"),
    border_styles: border,
  }
}
