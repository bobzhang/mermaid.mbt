///|
/// A theme variable, or `fallback` when the theme does not define it.
fn variable(theme : @theme.Theme, name : String, fallback : String) -> String {
  match theme.get(name) {
    Null => fallback
    _ => theme.text(name)
  }
}

///|
/// Set a color taken from the theme. The sanitizer the output goes
/// through removes a value that looks like an address it does not allow.
fn paint(element : @dom.Element, name : String, value : String) -> Unit {
  if @dom.is_allowed_uri(value) {
    element.attr(name, value) |> ignore
  }
}

///|
/// `renderD3Swimlane`: the background of a row and its label.
fn draw_swimlane(
  context : @diagram.Context,
  swimlane : Swimlane,
  max_r : Double,
) -> Unit raise Unsupported {
  let theme = context.theme()
  let group = context.svg.append("g").attr("class", "em-swimlane")
  let rect = group
    .append("rect")
    .attr_number("x", 0.0)
    .attr_number("y", swimlane.y)
    .attr("rx", "3")
    .attr_number("width", max_r + SWIMLANE_PADDING)
    .attr_number("height", swimlane.height)
  paint(
    rect,
    "fill",
    variable(theme, "emSwimlaneBackgroundOdd", "rgb(250,250,250)"),
  )
  paint(
    rect,
    "stroke",
    variable(theme, "emSwimlaneBackgroundStroke", "rgb(240,240,240)"),
  )
  let text = group
    .append("text")
    .attr("font-weight", "bold")
    .attr_number("x", 30.0)
    .attr_number("y", swimlane.y + 30.0)
    .text(swimlane.label)
  // The label is in the diagram's font, and counts for the size of the
  // diagram where it reaches out of its row.
  let label = @journeycommon.collapse_white_space(swimlane.label)
  if label != "" {
    if theme_css_restyles_text(context.config) {
      raise Unsupported("themeCSS that restyles the swimlane labels")
    }
    let family = theme.text("fontFamily")
    let font = if @journeycommon.js_trim(family) == "" {
      // `font-family:;` is no declaration: the page's font is inherited.
      @font.Stack::page_default(bold=true)
    } else {
      @journeycommon.family_font(family, bold=true) catch {
        @journeycommon.MeasureError(message) => raise Unsupported(message)
      }
    }
    let size = @journeycommon.theme_font_size(theme) catch {
      @journeycommon.MeasureError(message) => raise Unsupported(message)
    }
    @journeycommon.require_glyphs(font, label) catch {
      @journeycommon.MeasureError(message) => raise Unsupported(message)
    }
    let box = font.svg_text_box(label, size, x=30.0, y=swimlane.y + 30.0)
    text.set_text_box({
      x: box.x,
      y: box.y,
      width: box.width,
      height: box.height,
    })
  }
}

///|
/// `renderD3Box`: a frame's box, with its content as HTML centered in it.
fn draw_box(svg : @dom.Element, box : Box) -> Unit {
  let y = box.swimlane.y + SWIMLANE_PADDING
  let group = svg.append("g").attr("class", "em-box")
  let rect = group
    .append("rect")
    .attr_number("x", box.x)
    .attr_number("y", y)
    .attr("rx", "3")
    .attr_number("width", box.width)
    .attr_number("height", box.height)
  paint(rect, "stroke", box.stroke)
  paint(rect, "fill", box.fill)
  let div = group
    .append("foreignObject")
    .attr_number("x", box.x + BOX_PADDING)
    .attr_number("y", y + 10.0)
    .attr_number("width", box.width - 2.0 * BOX_PADDING)
    .attr_number("height", box.height - 2.0 * BOX_PADDING)
    .append("div")
    .style("display", "table")
    .style("height", "100%")
    .style("width", "100%")
  div
  .append("span")
  .style("display", "table-cell")
  .style("text-align", "center")
  .style("vertical-align", "middle")
  .set_inner_html(box.text)
  // mermaid stamps the namespace on what a `foreignObject` holds just
  // before it serializes the diagram.
  div.attr("xmlns", "http://www.w3.org/1999/xhtml") |> ignore
}

///|
/// `renderD3Relation`: a line from two thirds along the source to one
/// third along the target, between the sides that face each other.
fn draw_relation(
  context : @diagram.Context,
  source : Box,
  target : Box,
) -> Unit {
  let n = @dom.number
  let source_box_y = source.swimlane.y + SWIMLANE_PADDING
  let target_box_y = target.swimlane.y + SWIMLANE_PADDING
  let source_x = source.x + source.width * 2.0 / 3.0
  let target_x = target.x + target.width / 3.0
  let (source_y, target_y) = if source_box_y > target_box_y {
    (source_box_y, target_box_y + target.height)
  } else {
    (source_box_y + source.height, target_box_y)
  }
  let path = context.svg
    .append("path")
    .attr("class", "em-relation")
    .attr("fill", "none")
  paint(path, "stroke", variable(context.theme(), "emRelationStroke", "#000"))
  path
  .attr("stroke-width", "1")
  .attr("marker-end", "url(#em-arrowhead-\{context.id})")
  .attr("d", "M\{n(source_x)} \{n(source_y)} L\{n(target_x)} \{n(target_y)}")
  |> ignore
}

///|
/// Draw the event model into the context's `<svg>` element.
pub fn draw(model : EventModel, context : @diagram.Context) -> Unit raise {
  let config = context.config
  let svg = context.svg
  let state = layout(model, context.theme())
  match config.text("securityLevel") {
    None | Some("strict" | "antiscript") => ()
    // The output is then not sanitized, which is where entity codes are
    // resolved and line breaks rewritten.
    Some("loose") =>
      if model.entities ||
        state.boxes.iter().any(box => box.text.contains("<br")) {
        raise Unsupported("data and entity codes under securityLevel loose")
      }
    // The diagram is then in a frame of its own, where upstream looks
    // for it in vain.
    Some("sandbox") =>
      raise Invalid("Cannot read properties of null (reading 'getBBox')")
    // Text is sanitized otherwise.
    Some(level) => raise Unsupported("securityLevel \{level}")
  }
  for swimlane in state.sorted_swimlanes() {
    draw_swimlane(context, swimlane, state.max_r)
  }
  for box in state.boxes {
    draw_box(svg, box)
  }
  for relation in state.relations {
    draw_relation(context, relation.0, relation.1)
  }
  let marker = svg
    .append("defs")
    .append("marker")
    .attr("id", "em-arrowhead-\{context.id}")
    .attr("markerWidth", "10")
    .attr("markerHeight", "7")
    .attr("refX", "10")
    .attr("refY", "3.5")
    .attr("orient", "auto")
  paint(
    marker.append("polygon").attr("points", "0 0, 10 3.5, 0 7"),
    "fill",
    variable(context.theme(), "emArrowhead", "#000000"),
  )
  // `setupGraphViewbox`
  let padding = match config.get("eventmodeling.padding") {
    Null => 30.0
    Number(padding, ..) => padding
    other => raise Unsupported("eventmodeling.padding \{other.stringify()}")
  }
  let n = @dom.number
  let bounds = svg.bbox()
  @diagram.configure_svg_size(
    svg,
    bounds.height + padding * 2.0,
    bounds.width + padding * 2.0,
    config.flag("eventmodeling.useMaxWidth"),
  )
  svg.attr(
    "viewBox",
    "\{n(bounds.x - padding)} \{n(bounds.y - padding)} \{n(bounds.width + 2.0 * padding)} \{n(bounds.height + 2.0 * padding)}",
  )
  |> ignore
}

///|
/// Whether the user's `themeCSS` could change how text the renderer
/// measures is laid out: a rule of it beats what the renderer sets.
fn theme_css_restyles_text(config : @config.Config) -> Bool {
  guard config.text("themeCSS") is Some(css) else { return false }
  let css = css.to_lower()
  ["font", "spacing", "text-transform", "white-space", "writing-mode"]
  .iter()
  .any(property => css.contains(property))
}
