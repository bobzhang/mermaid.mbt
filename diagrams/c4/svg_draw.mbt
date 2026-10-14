// What the diagram draws itself: boundaries, relationships and the
// definitions every C4 diagram carries. Upstream's `svgDraw`.

///|
/// One of the icons upstream defines for sprites.
fn insert_icon(
  svg : @dom.Element,
  id : String,
  attributes : Array[(String, String)],
  path : String,
) -> Unit {
  let symbol = svg.append("defs").append("symbol").attr("id", id)
  for attribute in attributes {
    symbol.attr(attribute.0, attribute.1) |> ignore
  }
  symbol.append("path").attr("transform", "scale(.5)").attr("d", path) |> ignore
}

///|
/// The computer, database and clock icons.
fn insert_icons(svg : @dom.Element, id : String) -> Unit {
  let sized = [("width", "24"), ("height", "24")]
  insert_icon(svg, "\{id}-computer", sized, icon_path(computer_icon))
  insert_icon(
    svg,
    "\{id}-database",
    [("fill-rule", "evenodd"), ("clip-rule", "evenodd")],
    icon_path(database_icon),
  )
  insert_icon(svg, "\{id}-clock", sized, icon_path(clock_icon))
}

///|
/// The markers relationships end in, and two more upstream defines.
fn insert_markers(svg : @dom.Element, id : String) -> Unit {
  let arrow = (name : String, ref_x : String, path : String) => {
    svg
    .append("defs")
    .append("marker")
    .attr("id", "\{id}-\{name}")
    .attr("refX", ref_x)
    .attr("refY", "5")
    .attr("markerUnits", "userSpaceOnUse")
    .attr("markerWidth", "12")
    .attr("markerHeight", "12")
    .attr("orient", "auto")
    .append("path")
    .attr("d", path)
    |> ignore
  }
  arrow("arrowhead", "9", "M 0 0 L 10 5 L 0 10 z")
  arrow("arrowend", "1", "M 10 0 L 0 5 L 10 10 z")
  let cross = svg
    .append("defs")
    .append("marker")
    .attr("id", "\{id}-crosshead")
    .attr("markerWidth", "15")
    .attr("markerHeight", "8")
    .attr("orient", "auto")
    .attr("refX", "16")
    .attr("refY", "4")
  // The arrow, then the cross.
  cross
  .append("path")
  .attr("fill", "black")
  .attr("stroke", "#000000")
  .style("stroke-dasharray", "0, 0")
  .attr("stroke-width", "1px")
  .attr("d", "M 9,2 V 6 L16,4 Z")
  |> ignore
  cross
  .append("path")
  .attr("fill", "none")
  .attr("stroke", "#000000")
  .style("stroke-dasharray", "0, 0")
  .attr("stroke-width", "1px")
  .attr("d", "M 0,1 L 6,7 M 6,1 L 0,7")
  |> ignore
  svg
  .append("defs")
  .append("marker")
  .attr("id", "\{id}-filled-head")
  .attr("refX", "18")
  .attr("refY", "7")
  .attr("markerWidth", "20")
  .attr("markerHeight", "28")
  .attr("orient", "auto")
  .append("path")
  .attr("d", "M 18,7 L9,13 L14,7 L9,1 Z")
  |> ignore
}

///|
/// upstream's `byTspan`: a text element per line, centred on `x` plus half
/// of `width`, the lines spread around `y`.
fn draw_text(
  parent : @dom.Element,
  content : String,
  x : Double,
  y : Double,
  width : Double,
  font : Font,
  attributes : Array[(String, String)],
) -> Unit {
  let lines = split_breaks(content)
  let count = lines.length().to_double()
  for index, line in lines {
    let dy = index.to_double() * font.size - font.size * (count - 1.0) / 2.0
    let text = parent
      .append("text")
      .attr_number("x", x + width / 2.0)
      .attr_number("y", y)
      .style("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      // Inline styles of SVG elements are parsed leniently: a bare number
      // is a length in pixels.
      .style("font-size", @dom.number(font.size) + "px")
      .style("font-weight", font.weight)
      .style("font-family", font.family)
    text
    .append("tspan")
    .attr_number("dy", dy)
    .text(line)
    .attr("alignment-baseline", "mathematical")
    |> ignore
    for attribute in attributes {
      text.attr(attribute.0, attribute.1) |> ignore
    }
  }
}

///|
/// The texts of a boundary once measured.
priv struct BoundaryTexts {
  label : Measured
  kind : Measured?
  description : Measured?
}

///|
/// A boundary: a frame, dashed unless it is a deployment node, with its
/// label, type and description at the top.
fn draw_boundary_frame(
  svg : @dom.Element,
  boundary : Element,
  texts : BoundaryTexts,
  conf : Conf,
) -> Unit {
  let group = svg.append("g")
  let colour = (field : String, fallback : String) => {
    if truthy(boundary.props, field) {
      string_of_prop(boundary.props, field).unwrap_or(fallback)
    } else {
      fallback
    }
  }
  let rect = group
    .append("rect")
    .attr_number("x", boundary.x)
    .attr_number("y", boundary.y)
    .attr("fill", colour("bgColor", "none"))
    .attr("stroke", colour("borderColor", "#444444"))
    .attr_number("width", boundary.width)
    .attr_number("height", boundary.height)
    .attr("rx", "2.5")
    .attr("ry", "2.5")
    .attr("stroke-width", "1")
  if !truthy(boundary.props, "nodeType") {
    rect.attr("stroke-dasharray", "7.0,7.0") |> ignore
  }
  let fill = [("fill", "#444444")]
  let font = conf.boundary_font
  draw_text(
    group,
    texts.label.text,
    boundary.x,
    boundary.y + texts.label.y,
    boundary.width,
    { ..font, size: font.size + 2.0, weight: "bold", },
    fill,
  )
  if texts.kind is Some(kind) {
    draw_text(
      group,
      kind.text,
      boundary.x,
      boundary.y + kind.y,
      boundary.width,
      font,
      fill,
    )
  }
  if texts.description is Some(description) {
    draw_text(
      group,
      description.text,
      boundary.x,
      boundary.y + description.y,
      boundary.width,
      { ..font, size: font.size - 2.0, },
      fill,
    )
  }
}

///|
/// A relationship ready to be drawn.
priv struct RelLine {
  rel : Rel
  start : @rendering.Point
  end : @rendering.Point
  label : Measured
  technology : Measured?
}

///|
/// JavaScript's `parseInt(String(value))` of an offset that is truthy,
/// zero otherwise. `NaN` stays `NaN`.
fn offset(props : Map[String, Json], field : String) -> Double {
  guard truthy(props, field) else { return 0.0 }
  let nan = 0x7ff8000000000000L.reinterpret_as_double()
  match props.get(field) {
    Some(Number(number, ..)) =>
      if number < 0.0 {
        number.ceil()
      } else {
        number.floor()
      }
    Some(String(text)) => js_parse_int(text).unwrap_or(nan)
    _ => nan
  }
}

///|
/// The relationships: the first as a straight line, the others as curves,
/// each with its label and technology at its middle.
fn draw_rel_lines(
  svg : @dom.Element,
  rels : Array[RelLine],
  conf : Conf,
  diagram_id : String,
) -> Unit {
  let group = svg.append("g")
  let n = @dom.number
  for index, line in rels {
    let props = line.rel.props
    let colour = (field : String) => {
      if truthy(props, field) {
        string_of_prop(props, field).unwrap_or("#444444")
      } else {
        "#444444"
      }
    }
    let text_colour = colour("textColor")
    let stroke = colour("lineColor")
    let offset_x = offset(props, "offsetX")
    let offset_y = offset(props, "offsetY")
    let kind = string_of_prop(props, "type").unwrap_or("")
    let { start, end, .. } = line
    let element = if index == 0 {
      group
      .append("line")
      .attr_number("x1", start.x)
      .attr_number("y1", start.y)
      .attr_number("x2", end.x)
      .attr_number("y2", end.y)
      .attr("stroke-width", "1")
      .attr("stroke", stroke)
      .style("fill", "none")
    } else {
      let control_x = start.x +
        (end.x - start.x) / 2.0 -
        (end.x - start.x) / 4.0
      let control_y = start.y + (end.y - start.y) / 2.0
      group
      .append("path")
      .attr("fill", "none")
      .attr("stroke-width", "1")
      .attr("stroke", stroke)
      .attr(
        "d",
        "M\{n(start.x)},\{n(start.y)} Q\{n(control_x)},\{n(control_y)} \{n(end.x)},\{n(end.y)} ",
      )
    }
    if kind != "rel_b" {
      element.attr("marker-end", "url(#\{diagram_id}-arrowhead)") |> ignore
    }
    if kind is ("birel" | "rel_b") {
      element.attr("marker-start", "url(#\{diagram_id}-arrowend)") |> ignore
    }
    let font = conf.message_font
    let middle_x = start.x.min(end.x) + (end.x - start.x).abs() / 2.0 + offset_x
    let middle_y = start.y.min(end.y) + (end.y - start.y).abs() / 2.0
    draw_text(
      group,
      line.label.text,
      middle_x,
      middle_y + offset_y,
      line.label.width,
      font,
      [("fill", text_colour)],
    )
    if line.technology is Some(technology) {
      draw_text(
        group,
        "[" + technology.text + "]",
        middle_x,
        middle_y + font.size + 5.0 + offset_y,
        line.label.width.max(technology.width),
        font,
        [("fill", text_colour), ("font-style", "italic")],
      )
    }
  }
}
