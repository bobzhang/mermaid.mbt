///|
/// `text-anchor` for a horizontal position.
fn text_anchor(horizontal_pos : String) -> String {
  match horizontal_pos {
    "left" => "start"
    "right" => "end"
    _ => "middle"
  }
}

///|
/// A bar with the value written on it.
priv struct LabelItem {
  data : RectData
  label : String
}

///|
/// The size the labels of a group of bars are written at: the largest
/// at which each fits its bar, by an estimate of 0.7 of the size per
/// character, and of those the smallest.
fn uniform_font_size(
  items : Array[LabelItem],
  first : (LabelItem) -> Double,
  fits : (LabelItem, Double) -> Bool,
) -> Double {
  // `Math.min` of nothing is infinite.
  let mut smallest = @double.infinity
  for item in items {
    let mut font_size = first(item)
    while !fits(item, font_size) && font_size > 0.0 {
      font_size -= 1.0
    }
    smallest = js_min(smallest, font_size)
  }
  smallest.floor()
}

///|
/// Write the values of the first plot on the rectangles of `rects`, as
/// upstream does for every group of rectangles — the legend's markers
/// included — when data labels are on.
fn draw_data_labels(
  group : @dom.Element,
  rects : Array[RectData],
  label_data : Array[Double?],
  config : ChartConfig,
  theme : ChartTheme,
) -> Unit raise XYChartError {
  let n = @dom.number
  let outside = config.show_data_label_outside_bar
  let items : Array[LabelItem] = []
  for i, data in rects {
    guard label_data.get(i) is Some(Some(value)) else {
      raise XYChartError(
        "Cannot read properties of undefined (reading 'toString')",
      )
    }
    items.push({ data, label: n(value), })
  }
  let items = items.filter(item => {
    item.data.width > 0.0 && item.data.height > 0.0
  })
  let length = (item : LabelItem) => item.label.length().to_double()
  let y = (item : LabelItem) => or_nan(item.data.y)
  if config.horizontal {
    let char_width_factor = 0.7
    let right_margin = 10.0
    let font_size = uniform_font_size(items, item => item.data.height * 0.7, (
      item,
      font_size,
    ) => {
      let text_width = font_size * length(item) * char_width_factor
      text_width <= item.data.width - right_margin
    })
    for i in entering(group, "text")..<items.length() {
      let item = items[i]
      let x = if outside {
        item.data.x + item.data.width + right_margin
      } else {
        item.data.x + item.data.width - right_margin
      }
      group
      .append("text")
      .attr_number("x", x)
      .attr_number("y", y(item) + item.data.height / 2.0)
      .attr("text-anchor", if outside { "start" } else { "end" })
      .attr("dominant-baseline", "middle")
      .attr("fill", theme.data_label_color)
      .attr("font-size", "\{n(font_size)}px")
      .text(item.label)
      |> ignore
    }
  } else {
    let y_offset = 10.0
    let font_size = uniform_font_size(
      items,
      item => item.data.width / (length(item) * 0.7),
      (item, font_size) => {
        let data = item.data
        let char_width_factor = 0.7
        let text_width = font_size * length(item) * char_width_factor
        let center_x = data.x + data.width / 2.0
        let left_edge = center_x - text_width / 2.0
        let right_edge = center_x + text_width / 2.0
        let horizontal_fits = left_edge >= data.x &&
          right_edge <= data.x + data.width
        let vertical_fits = y(item) + y_offset + font_size <=
          y(item) + data.height
        horizontal_fits && vertical_fits
      },
    )
    for i in entering(group, "text")..<items.length() {
      let item = items[i]
      group
      .append("text")
      .attr_number("x", item.data.x + item.data.width / 2.0)
      .attr_number(
        "y",
        if outside {
          y(item) - y_offset
        } else {
          y(item) + y_offset
        },
      )
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", if outside { "auto" } else { "hanging" })
      .attr("fill", theme.data_label_color)
      .attr("font-size", "\{n(font_size)}px")
      .text(item.label)
      |> ignore
    }
  }
}

///|
/// Where the data that enters a group starts: d3 joins data to the
/// elements of the tag already in the group by position, and only what
/// is left over gets new elements.
fn entering(group : @dom.Element, tag : String) -> Int32 {
  group.descendants([tag]).length()
}

///|
/// Draw the XY chart into the context's `<svg>` element.
pub fn draw(chart : XYChart, context : @diagram.Context) -> Unit raise {
  let n = @dom.number
  let svg = context.svg
  let config = ChartConfig::new(context.config, chart)
  let theme = ChartTheme::new(context.theme())
  // The labels on bars are the values of the first plot, whichever plot
  // the bars belong to.
  guard chart.plots.get(0) is Some(first_plot) else {
    raise XYChartError("Cannot read properties of undefined (reading 'data')")
  }
  let label_data = first_plot.data.map(d => d.1)
  let group = svg.append("g").attr("class", "main")
  let background = group
    .append("rect")
    .attr_number("width", config.width)
    .attr_number("height", config.height)
    .attr("class", "background")
  @diagram.configure_svg_size(svg, config.height, config.width, true)
  svg.attr("viewBox", "0 0 \{n(config.width)} \{n(config.height)}") |> ignore
  background.attr("fill", theme.background_color) |> ignore
  // The group the texts are measured in stays, empty.
  svg.append("g").attr("class", "mermaid-tmp-group") |> ignore
  let measure = Measurer::new(
    context.font(),
    context.placement(config.width, config.height, max_width=config.width),
  )
  let shapes = Orchestrator::new(chart, config, theme, measure).drawable_elements()
  // Groups by the classes leading to them, joined.
  let groups : Map[String, @dom.Element] = Map([])
  let get_group = (classes : Array[String]) => {
    let mut element = group
    let mut prefix = ""
    for i, class in classes {
      let parent = if i > 0 && groups.get(prefix) is Some(parent) {
        parent
      } else {
        group
      }
      prefix += class
      element = match groups.get(prefix) {
        Some(element) => element
        None => {
          let element = parent.append("g").attr("class", class)
          groups[prefix] = element
          element
        }
      }
    }
    element
  }
  for shape in shapes {
    match shape.shapes {
      Rects(rects) => {
        guard rects.length() > 0 else { continue }
        let shape_group = get_group(shape.groups)
        for i in entering(shape_group, "rect")..<rects.length() {
          let data = rects[i]
          let rect = shape_group.append("rect").attr_number("x", data.x)
          if data.y is Some(y) {
            rect.attr_number("y", y) |> ignore
          }
          rect
          .attr_number("width", data.width)
          .attr_number("height", data.height)
          .attr("fill", data.fill)
          .attr("stroke", data.stroke_fill)
          .attr_number("stroke-width", data.stroke_width)
          |> ignore
        }
        if config.show_data_label {
          draw_data_labels(shape_group, rects, label_data, config, theme)
        }
      }
      Texts(texts) => {
        guard texts.length() > 0 else { continue }
        let shape_group = get_group(shape.groups)
        for i in entering(shape_group, "text")..<texts.length() {
          let data = texts[i]
          shape_group
          .append("text")
          .attr("x", "0")
          .attr("y", "0")
          .attr("fill", data.fill)
          .attr("font-size", n(data.font_size))
          .attr(
            "dominant-baseline",
            if data.vertical_pos == "top" {
              "text-before-edge"
            } else {
              "middle"
            },
          )
          .attr("text-anchor", text_anchor(data.horizontal_pos))
          .attr(
            "transform",
            "translate(\{data.x}, \{data.y}) rotate(\{n(data.rotation)})",
          )
          .text(data.text)
          |> ignore
        }
      }
      Paths(paths) => {
        guard paths.length() > 0 else { continue }
        let shape_group = get_group(shape.groups)
        for i in entering(shape_group, "path")..<paths.length() {
          let data = paths[i]
          shape_group
          .append("path")
          .attr("d", data.path)
          .attr("fill", "none")
          .attr("stroke", data.stroke_fill)
          .attr_number("stroke-width", data.stroke_width)
          |> ignore
        }
      }
    }
  }
}
