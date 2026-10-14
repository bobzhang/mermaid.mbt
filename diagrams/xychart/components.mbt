// Ports of the chart builder's title, legend and plot components.

///|
priv struct ChartTitle {
  measure : Measurer
  config : ChartConfig
  title : String
  color : String
  bounding_rect : Rect
  mut title_width : Double
  mut show : Bool
}

///|
/// Take the room the title needs of what is on offer; returns the height
/// it took.
fn ChartTitle::calculate_space(
  self : ChartTitle,
  available_width : Double,
  available_height : Double,
) -> Double raise Unsupported {
  let (width, height) = self.measure.max_dimension(
    [self.title],
    self.config.title_font_size,
  )
  let width_required = width.max(available_width)
  let height_required = height + 2.0 * self.config.title_padding
  if height_required <= available_height &&
    self.config.show_title &&
    self.title != "" {
    self.bounding_rect.width = width_required
    self.bounding_rect.height = height_required
    self.title_width = width
    self.show = true
  }
  self.bounding_rect.height
}

///|
/// Centre the title over the stretch from `start` to `end`, moved as far
/// as it takes to keep it inside the chart.
fn ChartTitle::align_to(
  self : ChartTitle,
  start : Double,
  end : Double,
) -> Unit {
  let half_width = self.title_width.min(self.config.width) / 2.0
  let center = ((start + end) / 2.0)
    .max(half_width)
    .min(self.config.width - half_width)
  self.bounding_rect.x = center - half_width
  self.bounding_rect.width = half_width * 2.0
}

///|
fn ChartTitle::drawable_elements(self : ChartTitle) -> Array[Drawable] {
  if !self.show {
    return []
  }
  let rect = self.bounding_rect
  [
    {
      groups: ["chart-title"],
      shapes: Texts([
        {
          font_size: self.config.title_font_size,
          text: self.title,
          vertical_pos: "middle",
          horizontal_pos: "center",
          x: @dom.number(rect.x + rect.width / 2.0),
          y: @dom.number(rect.y + rect.height / 2.0),
          fill: self.color,
          rotation: 0.0,
        },
      ]),
    },
  ]
}

///|
const LEGEND_MARKER_TO_FONT_RATIO : Double = 0.75

///|
const LEGEND_ITEM_SPACING_TO_FONT_RATIO : Double = 0.5

///|
const LEGEND_MARKER_SPACING_TO_FONT_RATIO : Double = 0.35

///|
priv struct ChartLegend {
  measure : Measurer
  config : ChartConfig
  theme : ChartTheme
  plots : Array[Plot]
  bounding_rect : Rect
  /// The plots with a title, while the legend has room.
  mut visible_plots : Array[Plot]
}

///|
/// Take the room the legend needs of what is on offer; returns the size
/// it took.
fn ChartLegend::calculate_space(
  self : ChartLegend,
  available_width : Double,
  available_height : Double,
) -> (Double, Double) raise Unsupported {
  self.visible_plots = if self.config.show_legend {
    self.plots.filter(plot => plot.title != "")
  } else {
    []
  }
  self.bounding_rect.width = 0.0
  self.bounding_rect.height = 0.0
  if self.visible_plots.is_empty() {
    return (0.0, 0.0)
  }
  let font_size = self.config.legend_font_size
  let marker_size = font_size * LEGEND_MARKER_TO_FONT_RATIO
  let marker_spacing = font_size * LEGEND_MARKER_SPACING_TO_FONT_RATIO
  let item_spacing = font_size * LEGEND_ITEM_SPACING_TO_FONT_RATIO
  let (text_width, _) = self.measure.max_dimension(
    self.visible_plots.map(plot => plot.title),
    font_size,
  )
  let count = self.visible_plots.length().to_double()
  let width_required = self.config.legend_padding * 2.0 +
    marker_size +
    marker_spacing +
    text_width
  let height_required = self.config.legend_padding * 2.0 +
    count * font_size +
    (count - 1.0) * item_spacing
  if width_required <= available_width && height_required <= available_height {
    self.bounding_rect.width = width_required
    self.bounding_rect.height = height_required
  } else {
    self.visible_plots = []
  }
  (self.bounding_rect.width, self.bounding_rect.height)
}

///|
fn ChartLegend::drawable_elements(self : ChartLegend) -> Array[Drawable] {
  if self.visible_plots.is_empty() {
    return []
  }
  let n = @dom.number
  let font_size = self.config.legend_font_size
  let marker_size = font_size * LEGEND_MARKER_TO_FONT_RATIO
  let marker_spacing = font_size * LEGEND_MARKER_SPACING_TO_FONT_RATIO
  let item_spacing = font_size * LEGEND_ITEM_SPACING_TO_FONT_RATIO
  let row_height = font_size + item_spacing
  let start_x = self.bounding_rect.x + self.config.legend_padding
  let start_y = self.bounding_rect.y + self.config.legend_padding
  let bar_markers = []
  let line_markers = []
  let labels = []
  for index, plot in self.visible_plots {
    let index = index.to_double()
    let color = self.theme.plot_color(plot.index)
    match plot.kind {
      Bar =>
        bar_markers.push({
          x: start_x,
          y: Some(start_y + index * row_height),
          width: marker_size,
          height: marker_size,
          fill: color,
          stroke_fill: color,
          stroke_width: 0.0,
        })
      Line => {
        let marker_y = n(start_y + index * row_height + marker_size / 2.0)
        line_markers.push({
          path: "M \{n(start_x)},\{marker_y} L \{n(start_x + marker_size)},\{marker_y}",
          stroke_fill: color,
          stroke_width: LINE_STROKE_WIDTH,
        })
      }
    }
    labels.push({
      text: plot.title,
      x: n(start_x + marker_size + marker_spacing),
      y: n(start_y + index * row_height + marker_size / 2.0),
      fill: self.theme.legend_text_color,
      font_size,
      rotation: 0.0,
      vertical_pos: "middle",
      horizontal_pos: "left",
    })
  }
  [
    { groups: ["legend", "markers"], shapes: Rects(bar_markers), },
    { groups: ["legend", "markers"], shapes: Paths(line_markers), },
    { groups: ["legend", "label"], shapes: Texts(labels), },
  ]
}

///|
/// The width every line is drawn with.
const LINE_STROKE_WIDTH : Double = 2.0

///|
/// The drawables of a line plot: the line, and the labels of its points.
fn line_plot(
  plot : Plot,
  color : String,
  x_axis : Axis,
  y_axis : Axis,
  horizontal : Bool,
) -> Array[Drawable] {
  let final_data = plot.data.map(d => {
    (x_axis.scale_value(d.0), y_axis.scale_number(d.1))
  })
  // The line generator turns what is not a number into one that prints
  // as `NaN`.
  let points = final_data.map(d => {
    if horizontal {
      (or_nan(d.1), or_nan(d.0))
    } else {
      (or_nan(d.0), or_nan(d.1))
    }
  })
  guard @d3.line(points) is Some(path) else { return [] }
  let group = "line-plot-\{plot.index}"
  let elements = [
    {
      groups: ["plot", group],
      shapes: Paths([
        { path, stroke_fill: color, stroke_width: LINE_STROKE_WIDTH, },
      ]),
    },
  ]
  if plot.point_labels is Some(labels) && labels.length() > 0 {
    let label_offset = 10.0
    let font_size = 12.0
    let texts = []
    for i, point in final_data {
      let (px, py) = point
      guard labels.get(i) is Some(label) && label != "" else { continue }
      texts.push(
        if horizontal {
          {
            x: @dom.number(or_nan(py) + label_offset),
            y: printed(px),
            text: label,
            fill: color,
            vertical_pos: "middle",
            horizontal_pos: "left",
            font_size,
            rotation: 0.0,
          }
        } else {
          {
            x: printed(px),
            y: @dom.number(or_nan(py) - label_offset),
            text: label,
            fill: color,
            vertical_pos: "middle",
            horizontal_pos: "center",
            font_size,
            rotation: 0.0,
          }
        },
      )
    }
    if texts.length() > 0 {
      elements.push({ groups: ["plot", group, "labels"], shapes: Texts(texts), })
    }
  }
  elements
}

///|
/// The drawable of a bar plot: one rectangle per value, from the axis
/// the bars stand on to the value.
fn bar_plot(
  plot : Plot,
  color : String,
  bounding_rect : Rect,
  x_axis : Axis,
  y_axis : Axis,
  horizontal : Bool,
) -> Array[Drawable] {
  let final_data = plot.data.map(d => {
    (x_axis.scale_value(d.0), y_axis.scale_number(d.1))
  })
  let bar_padding_percent = 0.05
  let bar_width = (x_axis.outer_padding * 2.0).min(x_axis.tick_distance()) *
    (1.0 - bar_padding_percent)
  let bar_width_half = bar_width / 2.0
  let rects = final_data.map(data => {
    let rect : RectData = if horizontal {
      {
        x: bounding_rect.x,
        y: Some(or_nan(data.0) - bar_width_half),
        height: bar_width,
        width: or_nan(data.1) - bounding_rect.x,
        fill: color,
        stroke_width: 0.0,
        stroke_fill: color,
      }
    } else {
      {
        x: or_nan(data.0) - bar_width_half,
        y: data.1,
        width: bar_width,
        height: bounding_rect.y + bounding_rect.height - or_nan(data.1),
        fill: color,
        stroke_width: 0.0,
        stroke_fill: color,
      }
    }
    rect
  })
  [{ groups: ["plot", "bar-plot-\{plot.index}"], shapes: Rects(rects), }]
}
