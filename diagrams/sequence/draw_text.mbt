// Text and rectangles, as svgDraw.js and svgDrawCommon.ts draw them.

///|
/// What `drawText` is told about a text: where, how aligned, in which
/// font. Fields left out upstream are `None` here.
priv struct TextData {
  mut x : Double
  mut y : Double
  mut anchor : String?
  mut dominant_baseline : String?
  mut alignment_baseline : String?
  mut width : Double?
  mut height : Double
  mut text_margin : Double
  mut tspan : Bool
  mut valign : String?
  mut text : String
  mut class_name : String?
  font : TextFont
  mut dy : String?
}

///|
/// The text object of svgDrawCommon.ts (`width` 100) or of svgDraw.js (no
/// width at all), which decides whether the anchor is applied.
fn TextData::new(font : TextFont, width? : Double) -> TextData {
  {
    x: 0.0,
    y: 0.0,
    anchor: None,
    dominant_baseline: None,
    alignment_baseline: None,
    width,
    height: 100.0,
    text_margin: 0.0,
    tspan: true,
    valign: None,
    text: "",
    class_name: None,
    font,
    dy: None,
  }
}

///|
/// A `font-family` value as the CSSOM serializes it, or `None` when it
/// refuses the value: names separated by a comma and a space, names of
/// several words quoted.
fn serialize_font_family(value : String) -> String? {
  if value.contains(";") || value.contains("!") {
    return None
  }
  let names = []
  for part in value.split(",") {
    let name = part.trim(chars=" \t\n").to_owned()
    if name.length() >= 2 &&
      (
        (name.has_prefix("\"") && name.has_suffix("\"")) ||
        (name.has_prefix("'") && name.has_suffix("'"))
      ) {
      names.push("\"" + name[1:name.length() - 1].to_owned() + "\"")
      continue
    }
    let words = name
      .split(" ")
      .filter(word => !word.is_empty())
      .map(word => word.to_owned())
      .collect()
    // An unquoted name is a run of identifiers.
    for word in words {
      guard word
        .iter()
        .all(c => {
          c.is_ascii_alphabetic() ||
          c.is_ascii_digit() ||
          c == '-' ||
          c == '_' ||
          c.to_int() >= 0x80
        }) &&
        !(word[0:1] is ['0'..<='9', ..]) else {
        return None
      }
    }
    match words {
      [] => return None
      [word] =>
        names.push(
          if word.to_lower()
            is ("serif"
            | "sans-serif"
            | "monospace"
            | "cursive"
            | "fantasy"
            | "system-ui"
            | "inherit"
            | "initial"
            | "unset") {
            word.to_lower()
          } else {
            word
          },
        )
      _ => names.push("\"" + words.join(" ") + "\"")
    }
  }
  Some(names.join(", "))
}

///|
/// A `font-weight` value as the CSSOM keeps it, or `None` when it refuses
/// the value.
fn serialize_font_weight(weight : Json) -> String? {
  match weight {
    Number(n, ..) =>
      if n >= 1.0 && n <= 1000.0 {
        Some(@dom.number(n))
      } else {
        None
      }
    String(text) => {
      let lower = text.trim(chars=" \t\n").to_owned().to_lower()
      match lower {
        "normal"
        | "bold"
        | "bolder"
        | "lighter"
        | "inherit"
        | "initial"
        | "unset" => Some(lower)
        _ => {
          let n = @string.parse_double(lower) catch { _ => return None }
          if n >= 1.0 && n <= 1000.0 {
            Some(@dom.number(n))
          } else {
            None
          }
        }
      }
    }
    _ => None
  }
}

///|
/// A `font-size` in pixels as the CSSOM keeps it.
fn serialize_font_size(size : String) -> String? raise SequenceError {
  Some(@dom.number(css_pixels(Some(size))) + "px")
}

///|
/// Set the three font properties on a text element, in the given order,
/// each only when the browser would accept it.
fn style_font(
  element : @dom.Element,
  font : TextFont,
  order : Array[String],
) -> Unit raise SequenceError {
  let (_, size) = parse_font_size(font.size)
  for property in order {
    let value = match property {
      "font-family" => font.family.bind(serialize_font_family)
      "font-size" =>
        match size {
          Some(size) => serialize_font_size(size)
          None => None
        }
      _ => serialize_font_weight(font.weight)
    }
    if value is Some(value) {
      element.style(property, value) |> ignore
    }
  }
}

///|
/// The font a drawn text ends up in, and its size in pixels: its own
/// family when the browser accepts it, else the family the diagram's
/// stylesheet sets on the root element.
fn Renderer::drawn_font(
  self : Renderer,
  font : TextFont,
) -> (@font.Stack, Double) raise SequenceError {
  let bold = is_bold(font.weight)
  let (_, size) = parse_font_size(font.size)
  let size = match size {
    Some(size) => css_pixels(Some(size))
    // The size of the root rule.
    None => css_pixels(Some(self.theme.text("fontSize")))
  }
  let stack = match font.family {
    Some(family) if is_valid_font_family(family) => font_stack(family, bold)
    _ => font_stack(self.theme.text("fontFamily"), bold)
  }
  (stack, size)
}

///|
/// svgDraw.js's `drawText`: one `<text>` element per line. Returns the
/// elements with the height the browser reports for each.
fn Renderer::draw_text(
  self : Renderer,
  parent : @dom.Element,
  data : TextData,
) -> Array[(@dom.Element, Double)] raise SequenceError {
  let mut prev_text_height = 0.0
  let mut text_height = 0.0
  let lines = split_breaks(data.text)
  let font_size = parse_font_size(data.font.size).0
  let measures = data.valign is Some(_) && data.text_margin > 0.0
  let y = data.y
  let text_margin = data.text_margin
  let yfunc = () => {
    guard measures else { return y }
    match data.valign {
      Some("top" | "start") => js_round(y + text_margin)
      Some("middle" | "center") =>
        js_round(y + (prev_text_height + text_height + text_margin) / 2.0)
      Some("bottom" | "end") =>
        js_round(
          y + (prev_text_height + text_height + 2.0 * text_margin) - text_margin,
        )
      _ => y
    }
  }
  if data.anchor is Some(anchor) && data.width is Some(width) {
    let aligned = match anchor {
      "left" | "start" => Some((js_round(data.x + text_margin), "start"))
      "middle" | "center" => Some((js_round(data.x + width / 2.0), "middle"))
      "right" | "end" => Some((js_round(data.x + width - text_margin), "end"))
      _ => None
    }
    if aligned is Some((x, anchor)) {
      data.x = x
      data.anchor = Some(anchor)
      data.dominant_baseline = Some("middle")
      data.alignment_baseline = Some("middle")
    }
  }
  let drawn = self.drawn_font(data.font)
  let elements = []
  let mut dy = 0.0
  for i, line in lines {
    if text_margin == 0.0 && font_size is Some(size) {
      dy = i.to_double() * size
    }
    let element = parent.append("text")
    element.attr_number("x", data.x).attr_number("y", yfunc()) |> ignore
    if data.anchor is Some(anchor) {
      element.attr("text-anchor", anchor) |> ignore
      if data.dominant_baseline is Some(baseline) {
        element.attr("dominant-baseline", baseline) |> ignore
      }
      if data.alignment_baseline is Some(baseline) {
        element.attr("alignment-baseline", baseline) |> ignore
      }
    }
    style_font(element, data.font, ["font-family", "font-size", "font-weight"])
    if data.class_name is Some(class_name) {
      element.attr("class", class_name) |> ignore
    }
    if data.dy is Some(offset) {
      element.attr("dy", offset) |> ignore
    } else if dy != 0.0 {
      element.attr_number("dy", dy) |> ignore
    }
    let text = if line == "" { ZERO_WIDTH_SPACE } else { line }
    if data.tspan {
      element.append("tspan").attr_number("x", data.x).text(text) |> ignore
    } else {
      element.text(text) |> ignore
    }
    // Half the x-height of a shift can make the box 1/64 pixel taller.
    let baseline : @font.Baseline = if data.anchor is Some(_) &&
      data.dominant_baseline == Some("middle") {
      Middle
    } else {
      Alphabetic
    }
    let (_, height) = line_box(drawn.0, text, drawn.1, baseline~)
    if measures {
      text_height += height
      prev_text_height = text_height
    }
    elements.push((element, height))
  }
  elements
}

///|
/// The rectangle upstream passes to `drawRect`.
priv struct RectSpec {
  mut x : Double
  mut y : Double
  mut fill : String?
  mut stroke : String?
  mut width : Double
  mut height : Double
  mut name : String?
  mut rx : Double
  mut ry : Double
  mut class_name : String?
}

///|
/// `getNoteRect`.
fn RectSpec::new() -> RectSpec {
  {
    x: 0.0,
    y: 0.0,
    fill: Some("#EDF2AE"),
    stroke: Some("#666"),
    width: 100.0,
    height: 100.0,
    name: None,
    rx: 0.0,
    ry: 0.0,
    class_name: None,
  }
}

///|
/// What the popup menu later needs of a participant's rectangle.
fn RectSpec::data(self : RectSpec) -> RectData {
  {
    x: self.x,
    fill: self.fill.unwrap_or(""),
    stroke: self.stroke.unwrap_or(""),
    width: self.width,
    height: self.height,
    rx: self.rx,
    ry: self.ry,
    class_name: self.class_name,
  }
}

///|
/// svgDraw.js's `drawRect`: the shared one, plus the look marker.
fn Renderer::draw_rect(
  self : Renderer,
  parent : @dom.Element,
  rect : RectSpec,
) -> @dom.Element {
  let element = draw_plain_rect(parent, rect)
  if self.conf.is_neo() {
    element.attr("data-look", "neo") |> ignore
  }
  element
}

///|
/// svgDrawCommon.ts's `drawRect`.
fn draw_plain_rect(parent : @dom.Element, rect : RectSpec) -> @dom.Element {
  let element = parent.append("rect")
  element.attr_number("x", rect.x).attr_number("y", rect.y) |> ignore
  if rect.fill is Some(fill) && @dom.is_allowed_uri(fill) {
    element.attr("fill", fill) |> ignore
  }
  if rect.stroke is Some(stroke) {
    element.attr("stroke", stroke) |> ignore
  }
  element.attr_number("width", rect.width).attr_number("height", rect.height)
  |> ignore
  if rect.name is Some(name) && name != "" {
    set_name(element, name)
  }
  if rect.rx != 0.0 {
    element.attr_number("rx", rect.rx) |> ignore
  }
  if rect.ry != 0.0 {
    element.attr_number("ry", rect.ry) |> ignore
  }
  if rect.class_name is Some(class_name) && class_name != "" {
    element.attr("class", class_name) |> ignore
  }
  element
}

///|
/// Move an element in front of its siblings, like d3's `lower`.
fn lower(element : @dom.Element) -> Unit {
  guard element.parent() is Some(parent) else { return }
  match parent.child_elements() {
    [first, ..] if !physical_equal(first, element) =>
      parent.insert_before(element, first)
    _ => ()
  }
}

///|
/// A filled rectangle behind everything else in its parent
/// (`drawBackgroundRect`).
fn draw_background_rect(
  parent : @dom.Element,
  startx : Double,
  starty : Double,
  stopx : Double,
  stopy : Double,
  fill : String?,
  stroke : String?,
) -> Unit {
  let rect = RectSpec::new()
  rect.x = startx
  rect.y = starty
  rect.width = stopx - startx
  rect.height = stopy - starty
  rect.fill = fill
  rect.stroke = stroke
  rect.class_name = Some("rect")
  lower(draw_plain_rect(parent, rect))
}

///|
/// Name an element after its participant. The output sanitizer removes
/// names that shadow a property of the document, such as `title`.
fn set_name(element : @dom.Element, name : String) -> Unit {
  if !@dom.is_clobbering_name(name) {
    element.attr("name", name) |> ignore
  }
}
