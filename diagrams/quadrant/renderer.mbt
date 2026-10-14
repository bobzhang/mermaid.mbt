///|
/// The builder's defaults, for what the configuration leaves out.
fn default_number(name : String) -> Double {
  match name {
    "chartWidth" | "chartHeight" => 500.0
    "titlePadding" => 10.0
    "titleFontSize" => 20.0
    "xAxisLabelFontSize" | "yAxisLabelFontSize" | "quadrantLabelFontSize" =>
      16.0
    "pointLabelFontSize" => 12.0
    "quadrantInternalBorderStrokeWidth" => 1.0
    "quadrantExternalBorderStrokeWidth" => 2.0
    _ => 5.0
  }
}

///|
/// Place a text: at the origin, moved and turned by its transform.
fn place(text : @dom.Element, data : PlacedText) -> Unit {
  let n = @dom.number
  text
  .attr("fill", data.fill)
  .attr("font-size", n(data.font_size))
  .attr(
    "dominant-baseline",
    if data.horizontal_pos == "top" {
      "hanging"
    } else {
      "middle"
    },
  )
  .attr(
    "text-anchor",
    if data.vertical_pos == "left" {
      "start"
    } else {
      "middle"
    },
  )
  .attr(
    "transform",
    "translate(\{data.x}, \{data.y}) rotate(\{n(data.rotation)})",
  )
  |> ignore
}

///|
/// Draw the quadrant chart into the context's `<svg>` element.
pub fn draw(chart : Quadrant, context : @diagram.Context) -> Unit {
  let n = @dom.number
  let config = context.config
  let theme = context.theme()
  let svg = context.svg
  let number = (name : String) => {
    config.number("quadrantChart." + name).unwrap_or(default_number(name))
  }
  let group = svg.append("g").attr("class", "main")
  let width = number("chartWidth")
  let height = number("chartHeight")
  @diagram.configure_svg_size(
    svg,
    height,
    width,
    config.get("quadrantChart.useMaxWidth") != Json::boolean(false),
  )
  svg.attr("viewBox", "0 0 \{n(width)} \{n(height)}") |> ignore
  let builder : Builder = {
    chart,
    number,
    text: name => {
      config
      .text("quadrantChart." + name)
      .unwrap_or(if name == "xAxisPosition" { "top" } else { "left" })
    },
    theme: name => theme.text(name),
  }
  let data = builder.build()
  let quadrants_group = group.append("g").attr("class", "quadrants")
  let border_group = group.append("g").attr("class", "border")
  let data_point_group = group.append("g").attr("class", "data-points")
  let label_group = group.append("g").attr("class", "labels")
  let title_group = group.append("g").attr("class", "title")
  if data.title is Some(title) {
    let text = title_group.append("text").attr("x", "0").attr("y", "0")
    place(text, title)
    text.text(title.text) |> ignore
  }
  for line in data.border_lines {
    border_group
    .append("line")
    .attr_number("x1", line.x1)
    .attr_number("y1", line.y1)
    .attr_number("x2", line.x2)
    .attr_number("y2", line.y2)
    .style("stroke", line.stroke_fill)
    .style("stroke-width", n(line.stroke_width))
    |> ignore
  }
  for quadrant in data.quadrants {
    let element = quadrants_group.append("g").attr("class", "quadrant")
    element
    .append("rect")
    .attr_number("x", quadrant.x)
    .attr_number("y", quadrant.y)
    .attr_number("width", quadrant.width)
    .attr_number("height", quadrant.height)
    .attr("fill", quadrant.fill)
    |> ignore
    let text = element.append("text").attr("x", "0").attr("y", "0")
    place(text, quadrant.text)
    text.text(quadrant.text.text) |> ignore
  }
  for label in data.axis_labels {
    let text = label_group
      .append("g")
      .attr("class", "label")
      .append("text")
      .attr("x", "0")
      .attr("y", "0")
      .text(label.text)
    place(text, label)
  }
  for point in data.points {
    let element = data_point_group.append("g").attr("class", "data-point")
    let circle = element.append("circle")
    // A coordinate the scale has no value for is not written at all.
    if point.x is Some(x) {
      circle.attr_number("cx", x) |> ignore
    }
    if point.y is Some(y) {
      circle.attr_number("cy", y) |> ignore
    }
    circle
    .attr_number("r", point.radius)
    .attr("fill", point.fill)
    .attr("stroke", point.stroke_color)
    .attr("stroke-width", point.stroke_width)
    |> ignore
    let text = element
      .append("text")
      .attr("x", "0")
      .attr("y", "0")
      .text(point.text.text)
    place(text, point.text)
  }
}
