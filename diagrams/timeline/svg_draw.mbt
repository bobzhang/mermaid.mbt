///|
/// What drawing nodes needs to know of the configuration and the fonts.
priv struct Env {
  /// The id ids inside the diagram are prefixed with. The vertical
  /// renderer passes none upstream, which spells `undefined`.
  id_prefix : String
  svg : @dom.Element
  theme_name : String
  look : String
  is_redux : Bool
  /// The top level `fontSize`, as a number: `NaN` when it is not one.
  font_size : Double
  /// How many section colours there are before they repeat.
  max_sections : Double
  /// Text as the diagram inherits it, and as the stylesheet sets it
  /// inside a node: the redux themes make that bold.
  plain : TextStyle
  node : TextStyle
  /// The bold face of the inherited font, for the title.
  title_font : @font.Stack
  /// Nodes drawn so far, which numbers their ids.
  mut node_count : Int32
}

///|
/// Whether a CSS `font-weight` selects the bold face of a family that
/// has a regular and a bold one.
fn is_bold(weight : Json) -> Bool raise @journeycommon.MeasureError {
  match weight {
    Number(n, ..) => n > 500.0
    String("bold" | "bolder") => true
    String("normal" | "lighter") => false
    String(text) => {
      let value = @journeycommon.js_number(text)
      if value != value {
        raise @journeycommon.MeasureError("font weight \{text} is not known")
      }
      value > 500.0
    }
    _ => false
  }
}

///|
fn Env::new(
  context : @diagram.Context,
  id_prefix : String,
) -> Env raise @journeycommon.MeasureError {
  let config = context.config
  let theme = context.theme()
  let theme_name = config.text("theme").unwrap_or("")
  let is_redux = theme_name.contains("redux")
  let size = @journeycommon.theme_font_size(theme)
  let plain = @journeycommon.theme_font(theme)
  // `.section-N text { font-weight }` is only part of the redux rules.
  let node = if is_redux && is_bold(theme.get("fontWeight")) {
    @journeycommon.theme_font(theme, bold=true)
  } else {
    plain
  }
  let font_size = match config.get("fontSize") {
    Number(n, ..) => n
    // Only the first `px` is removed before the string is used as a
    // number.
    String(text) =>
      @journeycommon.js_number(
        match text.find("px") {
          Some(at) => text[:at].to_owned() + text[at + 2:].to_owned()
          None => text
        },
      )
    _ => @journeycommon.js_number("NaN")
  }
  let max_sections = match theme.get("THEME_COLOR_LIMIT") {
    Number(n, ..) => n
    Null => 12.0
    _ => raise @journeycommon.MeasureError("THEME_COLOR_LIMIT must be a number")
  }
  {
    id_prefix,
    svg: context.svg,
    theme_name,
    look: config.text("look").unwrap_or(""),
    is_redux,
    font_size,
    max_sections,
    plain: TextStyle::new(plain, size),
    node: TextStyle::new(node, size),
    title_font: @journeycommon.theme_font(theme, bold=true),
    node_count: 0,
  }
}

///|
/// The arrow head that ends the timeline's axis and the lines down to
/// the events.
fn Env::init_graphics(self : Env) -> Unit {
  self.svg
  .append("defs")
  .append("marker")
  .attr("id", "\{self.id_prefix}-arrowhead")
  .attr_number("refX", 5.0)
  .attr_number("refY", 2.0)
  .attr_number("markerWidth", 6.0)
  .attr_number("markerHeight", 4.0)
  .attr("orient", "auto")
  .append("path")
  .attr("d", "M 0,0 V 4 L6,2 Z")
  |> ignore
}

///|
/// The text of a node: a `<text>` centred on x = 0 with its wrapped
/// lines, and the box the browser would report for it.
fn Env::append_text(
  self : Env,
  parent : @dom.Element,
  description : String,
  width : Double,
  style : TextStyle,
) -> @dom.Rect raise @journeycommon.MeasureError {
  @journeycommon.require_glyphs(style.font, description)
  ignore(self)
  let text = parent
    .append("text")
    .attr("dy", "1em")
    .attr("alignment-baseline", "middle")
    .attr("dominant-baseline", "middle")
    .attr("text-anchor", "middle")
  let spans = wrap(description, width, style)
  for index, span in spans {
    text
    .append("tspan")
    .attr("x", "0")
    .attr("dy", if index == 0 { "1em" } else { "1.1em" })
    .text(span)
    |> ignore
  }
  let box = text_box(spans, style)
  text.set_text_box(box)
  box
}

///|
/// svgDraw's `getVirtualNodeHeight`: how tall a node with this text would
/// be, measured on text that is not kept.
fn Env::virtual_node_height(
  self : Env,
  description : String,
  width~ : Double,
  padding~ : Double,
) -> Double raise @journeycommon.MeasureError {
  let scratch = @dom.Element::new("g")
  let box = self.append_text(scratch, description, width, self.plain)
  box.height + self.font_size * 1.1 * 0.5 + padding
}

///|
/// A drawn node's outer size.
priv struct NodeSize {
  width : Double
  height : Double
}

///|
/// JavaScript's `%` on numbers.
fn js_remainder(a : Double, b : Double) -> Double {
  if b == 0.0 || a != a || b != b {
    return @journeycommon.js_number("NaN")
  }
  let quotient = (a / b).to_int().to_double()
  a - quotient * b
}

///|
/// svgDraw's `drawNode`: a box with a coloured line under it and the
/// wrapped text. `section` picks the colours; `width` is that of the
/// text, to which the padding is added on both sides.
fn Env::draw_node(
  self : Env,
  parent : @dom.Element,
  description : String,
  section~ : Int32,
  width~ : Double,
  padding~ : Double,
  max_height~ : Double,
  is_event~ : Bool = false,
) -> NodeSize raise @journeycommon.MeasureError {
  let n = @dom.number
  let section = n(js_remainder(section.to_double(), self.max_sections) - 1.0)
  let node = parent
    .append("g")
    .attr("class", "timeline-node section-\{section}")
  let background = node.append("g")
  let text_group = node.append("g")
  let box = self.append_text(text_group, description, width, self.node)
  let height = box.height + self.font_size * 1.1 * 0.5 + padding
  let height = if height != height || max_height != max_height {
    @journeycommon.js_number("NaN")
  } else if height > max_height {
    height
  } else {
    max_height
  }
  let width = width + 2.0 * padding
  text_group.attr(
    "transform",
    if self.is_redux {
      let y = if is_event { padding / 2.0 + 3.0 } else { padding }
      "translate(\{n(width / 2.0)}, \{n(y)})"
    } else {
      "translate(\{n(width / 2.0)}, \{n(padding / 2.0)})"
    },
  )
  |> ignore
  // The background: square under the redux themes, with rounded upper
  // corners and a line along the bottom otherwise.
  let d = if self.is_redux {
    "M0 \{n(height - 5.0)} v\{n(-(height - 5.0))} h\{n(width)} v\{n(height)} H0 Z"
  } else {
    "M0 \{n(height - 5.0)} v\{n(-height + 2.0 * 5.0)} q0,-5,5,-5 h\{n(width - 2.0 * 5.0)} q5,0,5,5 v\{n(height - 5.0)} H0 Z"
  }
  background
  .append("path")
  .attr("id", "\{self.id_prefix}-node-\{self.node_count}")
  .attr("class", "node-bkg node-undefined")
  .attr("d", d)
  |> ignore
  self.node_count += 1
  if !self.is_redux {
    background
    .append("line")
    .attr("class", "node-line-\{section}")
    .attr_number("x1", 0.0)
    .attr_number("y1", height)
    .attr_number("x2", width)
    .attr_number("y2", height)
    |> ignore
  }
  if self.look == "neo" {
    node.attr("data-look", "neo") |> ignore
    if self.is_redux {
      self.ensure_drop_shadow()
    }
  }
  { width, height, }
}

///|
/// The filter the redux themes' node rules refer to, defined once.
fn Env::ensure_drop_shadow(self : Env) -> Unit {
  let svg = self.svg
  let svg_id = svg.get_attr("id").unwrap_or("")
  let id = if svg_id != "" { "\{svg_id}-drop-shadow" } else { "drop-shadow" }
  if svg.find_by_id(id) is Some(_) {
    return
  }
  let is_dark = self.theme_name.contains("dark")
  let defs = match svg.descendants(["defs"]) {
    [defs, ..] => defs
    [] => svg.append("defs")
  }
  defs
  .append("filter")
  .attr("id", id)
  .attr("height", "130%")
  .attr("width", "130%")
  .append("feDropShadow")
  .attr("dx", "4")
  .attr("dy", "4")
  .attr("stdDeviation", "0")
  .attr("flood-opacity", if is_dark { "0.2" } else { "0.06" })
  .attr("flood-color", if is_dark { "#FFFFFF" } else { "#000000" })
  |> ignore
}

///|
/// mermaid's `setupGraphViewbox`: size the `<svg>` to what was drawn,
/// with `padding` around it.
fn setup_graph_viewbox(
  svg : @dom.Element,
  padding : Double,
  use_max_width : Bool,
) -> Unit {
  let n = @dom.number
  let bounds = svg.bbox()
  let width = bounds.width + padding * 2.0
  let height = bounds.height + padding * 2.0
  @diagram.configure_svg_size(svg, height, width, use_max_width)
  svg.attr(
    "viewBox",
    "\{n(bounds.x - padding)} \{n(bounds.y - padding)} \{n(bounds.width + 2.0 * padding)} \{n(bounds.height + 2.0 * padding)}",
  )
  |> ignore
}

///|
/// A length attribute as the browser reads it back, in single precision.
/// The DOM emulation knows the rules; a rectangle's box reports its `x`.
fn length_attribute(value : Double) -> Float {
  Float::from_double(
    @dom.Element::new("rect")
    .attr_number("x", value)
    .attr("width", "1")
    .attr("height", "1")
    .bbox().x,
  )
}

///|
/// The title above the timeline: bold, four x-heights of the inherited
/// font tall. Its box is what the browser measures for it, which the view
/// box depends on.
fn Env::append_title(
  self : Env,
  title : String,
  x : Double,
) -> Unit raise @journeycommon.MeasureError {
  let f = Float::from_double
  let text = self.svg
    .append("text")
    .text(title)
    .attr_number("x", x)
    .attr("font-size", "4ex")
    .attr("font-weight", "bold")
    .attr_number("y", 20.0)
  let content = collapse_white_space(title)
  @journeycommon.require_glyphs(self.title_font, content)
  if content == "" {
    return
  }
  let size = (f(4.0) * f(self.plain.font.x_height(self.plain.size))).to_double()
  let font = self.title_font
  let (ascent, descent) = font.line_metrics(size)
  let left = length_attribute(x)
  let cell : BoxF = {
    x: left,
    y: f(20.0) - f(ascent),
    width: f(font.advance(content, size)),
    height: f(ascent) + f(descent),
  }
  let ink = font.ink(content, size)
  let ink_box : BoxF = {
    x: left + f(ink.x),
    y: f(20.0) + f(ink.y),
    width: f(ink.width),
    height: f(ink.height),
  }
  text.set_text_box(ink_box.unite(cell).to_rect())
}
