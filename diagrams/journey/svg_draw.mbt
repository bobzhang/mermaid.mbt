///|
/// The namespace mermaid stamps on the children of `foreignObject`
/// elements just before it serializes the diagram.
const XHTML : String = "http://www.w3.org/1999/xhtml"

///|
/// Set `name` to a configuration value the way d3's `attr` does: `null`
/// leaves the attribute out, anything else is converted to a string.
fn attr_json(element : @dom.Element, name : String, value : Json) -> Unit {
  match value {
    Null => ()
    String(text) => element.attr(name, text) |> ignore
    Number(n, ..) => element.attr_number(name, n) |> ignore
    True => element.attr(name, "true") |> ignore
    False => element.attr(name, "false") |> ignore
    other => element.attr(name, other.stringify()) |> ignore
  }
}

///|
/// Set an attribute unless the value is `undefined`.
fn attr_optional(
  element : @dom.Element,
  name : String,
  value : String?,
) -> Unit {
  if value is Some(value) {
    element.attr(name, value) |> ignore
  }
}

///|
/// svgDrawCommon's `drawRect` on a note rectangle with rounded corners.
fn draw_rect(
  parent : @dom.Element,
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
  fill~ : String?,
  class~ : String,
) -> Unit {
  let rect = parent.append("rect").attr_number("x", x).attr_number("y", y)
  attr_optional(rect, "fill", fill)
  rect
  .attr("stroke", "#666")
  .attr_number("width", width)
  .attr_number("height", height)
  .attr_number("rx", 3.0)
  .attr_number("ry", 3.0)
  .attr("class", class)
  |> ignore
}

///|
/// The dot standing for an actor: in the legend, and on each task the
/// actor takes part in, where it carries the name as a tooltip.
fn draw_circle(
  parent : @dom.Element,
  cx~ : Double,
  cy~ : Double,
  fill~ : String?,
  position~ : Int32,
  title? : String,
) -> Unit {
  let circle = parent
    .append("circle")
    .attr_number("cx", cx)
    .attr_number("cy", cy)
    .attr("class", "actor-\{position}")
  attr_optional(circle, "fill", fill)
  circle.attr("stroke", "#000").attr_number("r", 7.0) |> ignore
  if title is Some(title) {
    circle.append("title").text(title) |> ignore
  }
}

///|
/// svgDrawCommon's `drawText` as the legend uses it: the text starts two
/// margins right of `x`, line breaks flattened to blanks.
fn draw_text(
  parent : @dom.Element,
  x~ : Double,
  y~ : Double,
  text~ : String,
  text_margin~ : Double,
) -> @dom.Element {
  let line_break = try! @jsregex.Regex::compile("<br\\s*/?>", flags="gi")
  let element = parent
    .append("text")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("class", "legend")
  element
  .append("tspan")
  .attr_number("x", x + text_margin * 2.0)
  .text(line_break.replace_all(text, _ => " "))
  |> ignore
  element
}

///|
/// The face showing how a task scored: smiling above three, sad below,
/// indifferent at three — or when the score is not a number.
fn draw_face(
  parent : @dom.Element,
  cx~ : Double,
  cy~ : Double,
  score~ : Double,
) -> Unit {
  let n = @dom.number
  let radius = 15.0
  parent
  .append("circle")
  .attr_number("cx", cx)
  .attr_number("cy", cy)
  .attr("class", "face")
  .attr_number("r", radius)
  .attr_number("stroke-width", 2.0)
  .attr("overflow", "visible")
  |> ignore
  let face = parent.append("g")
  for eye_x in [cx - radius / 3.0, cx + radius / 3.0] {
    face
    .append("circle")
    .attr_number("cx", eye_x)
    .attr_number("cy", cy - radius / 3.0)
    .attr_number("r", 1.5)
    .attr_number("stroke-width", 2.0)
    .attr("fill", "#666")
    .attr("stroke", "#666")
    |> ignore
  }
  let pi = @math.PI
  // The mouth is half a ring; upstream gives it an inner radius larger
  // than the outer one, which d3 swaps.
  let mouth = (start_angle : Double, end_angle : Double, drop : Double) => {
    face
    .append("path")
    .attr("class", "mouth")
    .attr(
      "d",
      @d3.arc_path(
        inner_radius=radius / 2.0,
        outer_radius=radius / 2.2,
        start_angle~,
        end_angle~,
      ),
    )
    .attr("transform", "translate(\{n(cx)},\{n(cy + drop)})")
    |> ignore
  }
  if score > 3.0 {
    mouth(pi / 2.0, 3.0 * (pi / 2.0), 2.0)
  } else if score < 3.0 {
    mouth(3.0 * pi / 2.0, 5.0 * (pi / 2.0), 7.0)
  } else {
    face
    .append("line")
    .attr("class", "mouth")
    .attr("stroke", "#666")
    .attr_number("x1", cx - 5.0)
    .attr_number("y1", cy + 7.0)
    .attr_number("x2", cx + 5.0)
    .attr_number("y2", cy + 7.0)
    .attr("stroke-width", "1px")
    |> ignore
  }
}

///|
/// Text centred in the box `x, y, width, height`, placed as
/// `journey.textPlacement` says: `fo` for HTML in a `foreignObject` with
/// SVG text as the fallback, `old` for one plain `<text>`, anything else
/// for one `<text>` per line.
fn draw_boxed_text(
  conf : Conf,
  content : String,
  parent : @dom.Element,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  class~ : String,
  colour~ : String?,
) -> Unit {
  match conf.text_placement {
    "fo" => {
      let body = parent.append("switch")
      // The `position` attribute upstream sets does not survive
      // sanitizing.
      let outer = body
        .append("foreignObject")
        .attr_number("x", x)
        .attr_number("y", y)
        .attr_number("width", width)
        .attr_number("height", height)
        .append("div")
        .style("display", "table")
        .style("height", "100%")
        .style("width", "100%")
      outer
      .append("div")
      .attr("class", "label")
      .style("display", "table-cell")
      .style("text-align", "center")
      .style("vertical-align", "middle")
      .text(content)
      |> ignore
      // Upstream passes no colour on to the fallback text.
      text_by_tspan(
        conf,
        content,
        body,
        x,
        y,
        width,
        height,
        class~,
        colour=None,
      )
      outer.attr("class", class).attr("xmlns", XHTML) |> ignore
    }
    "old" =>
      // `font-color` is not a CSS property, so the colour is dropped.
      parent
      .append("text")
      .attr_number("x", x + width / 2.0)
      .attr_number("y", y + height / 2.0 + 5.0)
      .style("text-anchor", "middle")
      .text(content)
      .attr("class", class)
      |> ignore
    _ =>
      text_by_tspan(conf, content, parent, x, y, width, height, class~, colour~)
  }
}

///|
/// One `<text>` per line of `content`, the lines spread around the middle
/// of the box.
fn text_by_tspan(
  conf : Conf,
  content : String,
  parent : @dom.Element,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  class~ : String,
  colour~ : String?,
) -> Unit {
  let line_break = try! @jsregex.Regex::compile("<br\\s*/?>", flags="gi")
  let lines = line_break.split(content)
  let size = conf.task_font_size
  let count = lines.length().to_double()
  for i, line in lines {
    let dy = i.to_double() * size - size * (count - 1.0) / 2.0
    let text = parent
      .append("text")
      .attr_number("x", x + width / 2.0)
      .attr_number("y", y)
    attr_optional(text, "fill", colour)
    text.style("text-anchor", "middle") |> ignore
    if conf.task_font_size_css is Some(size) {
      text.style("font-size", size) |> ignore
    }
    text.style("font-family", conf.task_font_family) |> ignore
    text
    .append("tspan")
    .attr_number("x", x + width / 2.0)
    .attr_number("dy", dy)
    .text(line)
    |> ignore
    text
    .attr_number("y", y + height / 2.0)
    .attr("dominant-baseline", "central")
    .attr("alignment-baseline", "central")
    .attr("class", class)
    |> ignore
  }
}
