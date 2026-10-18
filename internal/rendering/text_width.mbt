// Measuring text before it is laid out: mermaid's `calculateTextWidth`,
// which the entity and requirement boxes size their labels' wrapping width
// from.

///|
/// The size in pixels of the text `calculateTextWidth` measures, from the
/// `fontSize` setting: mermaid's `parseFontSize` followed by what the
/// browser makes of the style. A number, or a string of digits, counts
/// pixels; other strings are CSS lengths, relative to the page's 16px; a
/// string that does not start with a number sets nothing.
fn text_measure_size(setting : Json) -> Double {
  let page = 16.0
  match setting {
    Number(size, ..) => size
    String(text) => {
      // The number as CSS writes one: `+12px` and `1.2e1px` are 12.
      guard @dom.css_dimension(text.trim().to_owned()) is Some((value, unit)) else {
        return page
      }
      match unit.trim() {
        "" | "px" => value
        "em" | "rem" => value * page
        "%" => value * page / 100.0
        "pt" => value * 4.0 / 3.0
        // An unknown unit leaves the page's size in place.
        _ => page
      }
    }
    _ => 12.0
  }
}

///|
/// mermaid's `calculateTextWidth` with the diagram's configuration: the
/// text is drawn as SVG text in `sans-serif` and in the configured font,
/// line by line, and the rounded width of its widest line in the
/// configured font is the answer, unless the text comes out larger in
/// every dimension in `sans-serif`.
///
/// The default `fontFamily` ends in a semicolon, which the browser rejects
/// as a style value, so that measurement is in the page's own font.
fn calculate_text_width(text : String, config : @config.Config) -> Double {
  if text == "" {
    return 0.0
  }
  let size = text_measure_size(config.get("fontSize"))
  let configured = match config.text("fontFamily") {
    Some(family) if !family.contains(";") => @font.Stack::for_family(family)
    _ => @font.Stack::page_default()
  }
  // `Math.round`
  let round = (value : Double) => (value + 0.5).floor()
  // Width, height and line height of the text in one font.
  let dimensions = (stack : @font.Stack) => {
    let mut width = 0.0
    let mut height = 0.0
    let mut line_height = 0.0
    for line in normalize_breaks(text).split("\n") {
      // White space collapses as in any SVG text, and soft hyphens do not
      // show.
      let words = []
      for word in line.split(" ") {
        let word = word.to_owned().replace_all(old="\u{ad}", new="")
        if word != "" {
          words.push(word)
        }
      }
      let box = stack.bbox(words.join(" "), size)
      width = round(width.max(box.width))
      let rounded = round(box.height)
      height += rounded
      line_height = round(line_height.max(rounded))
    }
    (width, height, line_height)
  }
  let sans = dimensions(@font.Stack::sans_serif())
  let own = dimensions(configured)
  if sans.1 > own.1 && sans.0 > own.0 && sans.2 > own.2 {
    sans.0
  } else {
    own.0
  }
}
