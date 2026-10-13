///|
const MARGIN : Double = 40.0

///|
const LEGEND_RECT_SIZE : Double = 18.0

///|
const LEGEND_SPACING : Double = 4.0

///|
const HEIGHT : Double = 450.0

///|
/// Draw the pie chart into the context's `<svg>` element.
pub fn draw(pie : Pie, context : @diagram.Context) -> Unit {
  let n = @dom.number
  let config = context.config
  let theme = context.theme()
  let svg = context.svg
  let pie_width = HEIGHT
  let group = svg.append("g")
  group.attr("transform", "translate(\{n(pie_width / 2.0)},\{n(HEIGHT / 2.0)})")
  |> ignore
  let outer_stroke_width = @diagram.parse_font_size(
    theme.text("pieOuterStrokeWidth"),
  ).unwrap_or(2.0)
  let legend_position = config.text("pie.legendPosition").unwrap_or("right")
  let text_position = config.number("pie.textPosition").unwrap_or(0.75)
  let donut_hole = config.number("pie.donutHole").unwrap_or(0.0)
  let inner_hole = if donut_hole > 0.0 && donut_hole <= 0.9 {
    donut_hole
  } else {
    0.0
  }
  let highlight = config.text("pie.highlightSlice").unwrap_or("")
  let radius = pie_width.min(HEIGHT) / 2.0 - MARGIN
  let slices = group.append("g")
  slices
  .append("circle")
  .attr_number("cx", 0.0)
  .attr_number("cy", 0.0)
  .attr_number("r", radius + outer_stroke_width / 2.0)
  .attr("class", "pieOuterCircle")
  |> ignore
  let labels = pie.sections.keys().collect()
  let mut sum = 0.0
  for _, value in pie.sections {
    sum += value
  }
  // Slices under one percent are left out of the pie, though not of the
  // legend.
  let shown = labels.filter(label => pie.sections[label] / sum * 100.0 >= 1.0)
  let arcs = @d3.pie(shown.map(label => pie.sections[label])).filter(arc => {
    @diagram.to_fixed0(arc.value / sum * 100.0) != "0"
  })
  let palette = [
    "pie1", "pie2", "pie3", "pie4", "pie5", "pie6", "pie7", "pie8", "pie9", "pie10",
    "pie11", "pie12",
  ].map(name => theme.text(name))
  // An ordinal scale: each label takes the next color, cycling.
  let color = (label : String) => {
    let index = labels.search(label).unwrap_or(0)
    palette[index % palette.length()]
  }
  for arc in arcs {
    let label = shown[arc.index]
    let class_name = if highlight == "hover" {
      "pieCircle highlightedOnHover"
    } else if highlight == label {
      "pieCircle highlighted"
    } else {
      "pieCircle"
    }
    slices
    .append("path")
    .attr(
      "d",
      @d3.arc_path(
        inner_radius=inner_hole * radius,
        outer_radius=radius,
        start_angle=arc.start_angle,
        end_angle=arc.end_angle,
      ),
    )
    .attr("fill", color(label))
    .attr("class", class_name)
    |> ignore
  }
  for arc in arcs {
    let (x, y) = @d3.arc_centroid(
      inner_radius=radius * text_position,
      outer_radius=radius * text_position,
      start_angle=arc.start_angle,
      end_angle=arc.end_angle,
    )
    slices
    .append("text")
    .text(@diagram.to_fixed0(arc.value / sum * 100.0) + "%")
    .attr("transform", "translate(\{n(x)},\{n(y)})")
    .style("text-anchor", "middle")
    .attr("class", "slice")
    |> ignore
  }
  let title = group
    .append("text")
    .text(pie.title)
    .attr_number("x", 0.0)
    .attr_number("y", -(HEIGHT - 50.0) / 2.0)
    .attr("class", "pieTitleText")
  // The legend lists every section, shown or not.
  let legend_size = @diagram.parse_font_size(theme.text("pieLegendTextSize")).unwrap_or(
    17.0,
  )
  let legends = []
  let mut longest_text_width = 0.0
  for label in labels {
    let legend = group.append("g").attr("class", "legend")
    legend
    .append("rect")
    .attr_number("width", LEGEND_RECT_SIZE)
    .attr_number("height", LEGEND_RECT_SIZE)
    .style("fill", color(label))
    .style("stroke", color(label))
    |> ignore
    let text = if pie.show_data {
      "\{label} [\{n(pie.sections[label])}]"
    } else {
      label
    }
    legend
    .append("text")
    .attr_number("x", LEGEND_RECT_SIZE + LEGEND_SPACING)
    .attr_number("y", LEGEND_RECT_SIZE - LEGEND_SPACING)
    .text(text)
    |> ignore
    longest_text_width = longest_text_width.max(
      context.font().bbox(text, legend_size).width,
    )
    legends.push(legend)
  }
  let count = labels.length().to_double()
  let legend_height = LEGEND_RECT_SIZE + LEGEND_SPACING
  let total_legend_height = count * legend_height
  let mut chart_height = HEIGHT
  let mut chart_width = pie_width + MARGIN
  let centered = -longest_text_width / 2.0 - (LEGEND_RECT_SIZE + LEGEND_SPACING)
  for index, legend in legends {
    let index = index.to_double()
    let transform = match legend_position {
      "center" => {
        let offset = legend_height * count / 2.0
        "translate(\{n(centered)},\{n(index * legend_height - offset)})"
      }
      "top" => "translate(\{n(centered)}, \{n(index * legend_height - radius)})"
      "bottom" => {
        let offset = -radius - legend_height
        "translate(\{n(centered)},\{n(index * legend_height - offset)})"
      }
      "left" => {
        let offset = legend_height * count / 2.0
        let horizontal = -radius - (LEGEND_RECT_SIZE + LEGEND_SPACING)
        "translate(\{n(horizontal)},\{n(index * legend_height - offset)})"
      }
      _ => {
        let offset = legend_height * count / 2.0
        let horizontal = 12.0 * LEGEND_RECT_SIZE
        "translate(\{n(horizontal)},\{n(index * legend_height - offset)})"
      }
    }
    legend.attr("transform", transform) |> ignore
  }
  match legend_position {
    "center" => ()
    "top" => {
      chart_height += total_legend_height
      slices.attr(
        "transform",
        "translate(0, \{n(total_legend_height + legend_height)})",
      )
      |> ignore
    }
    "bottom" => chart_height += total_legend_height
    "left" => {
      chart_width += LEGEND_RECT_SIZE + LEGEND_SPACING + longest_text_width
      slices.attr(
        "transform",
        "translate(\{n(longest_text_width + LEGEND_RECT_SIZE + LEGEND_SPACING)}, 0)",
      )
      |> ignore
    }
    _ => chart_width += LEGEND_RECT_SIZE + LEGEND_SPACING + longest_text_width
  }
  // Widen the view box when the centered title is wider than the chart.
  let title_size = @diagram.parse_font_size(theme.text("pieTitleTextSize")).unwrap_or(
    25.0,
  )
  let title_width = if pie.title == "" {
    0.0
  } else {
    context.font().bbox(pie.title, title_size).width
  }
  ignore(title)
  let title_left = pie_width / 2.0 - title_width / 2.0
  let title_right = pie_width / 2.0 + title_width / 2.0
  let view_box_x = title_left.min(0.0)
  let total_width = chart_width.max(title_right) - view_box_x
  svg.attr("viewBox", "\{n(view_box_x)} 0 \{n(total_width)} \{n(chart_height)}")
  |> ignore
  @diagram.configure_svg_size(
    svg,
    chart_height,
    total_width,
    config.flag("pie.useMaxWidth"),
  )
}
