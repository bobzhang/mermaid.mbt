// A port of the chart builder's Orchestrator: it shares the chart's
// space out among title, axes, legend and plot, then collects what each
// of them draws.

///|
priv struct Orchestrator {
  config : ChartConfig
  theme : ChartTheme
  plots : Array[Plot]
  /// The space of the plot itself.
  plot_rect : Rect
  title : ChartTitle
  legend : ChartLegend
  x_axis : Axis
  y_axis : Axis
}

///|
fn Orchestrator::new(
  chart : XYChart,
  config : ChartConfig,
  theme : ChartTheme,
  measure : Measurer,
) -> Orchestrator {
  {
    config,
    theme,
    plots: chart.plots,
    plot_rect: Rect::new(),
    title: {
      measure,
      config,
      title: chart.title,
      color: theme.title_color,
      bounding_rect: Rect::new(),
      title_width: 0.0,
      show: false,
    },
    legend: {
      measure,
      config,
      theme,
      plots: chart.plots,
      bounding_rect: Rect::new(),
      visible_plots: [],
    },
    x_axis: Axis::new(
      chart.x_axis,
      config.x_axis,
      theme.x_axis,
      chart.x_axis_title,
      measure,
    ),
    y_axis: Axis::new(
      Linear(chart.y_axis.0, chart.y_axis.1),
      config.y_axis,
      theme.y_axis,
      chart.y_axis_title,
      measure,
    ),
  }
}

///|
fn Orchestrator::has_bar_plot(self : Orchestrator) -> Bool {
  self.plots.any(plot => plot.kind is Bar)
}

///|
fn Orchestrator::calculate_vertical_space(
  self : Orchestrator,
) -> Unit raise Unsupported {
  let config = self.config
  let mut available_width = config.width
  let mut available_height = config.height
  let mut chart_width = (available_width *
  config.plot_reserved_space_percent /
  100.0).floor()
  let mut chart_height = (available_height *
  config.plot_reserved_space_percent /
  100.0).floor()
  available_width -= chart_width
  available_height -= chart_height
  let title_height = self.title.calculate_space(config.width, available_height)
  let plot_y = title_height
  available_height -= title_height
  self.x_axis.set_position("bottom")
  let (_, x_axis_height) = self.x_axis.calculate_space(
    available_width, available_height,
  )
  available_height -= x_axis_height
  self.y_axis.set_position("left")
  let (y_axis_width, _) = self.y_axis.calculate_space(
    available_width, available_height,
  )
  let plot_x = y_axis_width
  available_width -= y_axis_width
  let (legend_width, legend_height) = self.legend.calculate_space(
    available_width, chart_height,
  )
  available_width -= legend_width
  if available_width > 0.0 {
    chart_width += available_width
  }
  if available_height > 0.0 {
    chart_height += available_height
  }
  self.plot_rect.width = chart_width
  self.plot_rect.height = chart_height
  self.plot_rect.x = plot_x
  self.plot_rect.y = plot_y
  self.title.align_to(plot_x, plot_x + chart_width)
  self.legend.bounding_rect.x = plot_x + chart_width
  self.legend.bounding_rect.y = plot_y +
    ((chart_height - legend_height) / 2.0).max(0.0)
  self.x_axis.set_range((plot_x, plot_x + chart_width))
  self.x_axis.set_bounding_box_xy(plot_x, plot_y + chart_height)
  self.y_axis.set_range((plot_y, plot_y + chart_height))
  self.y_axis.set_bounding_box_xy(0.0, plot_y)
  if self.has_bar_plot() {
    self.x_axis.recalculate_outer_padding_to_draw_bar()
  }
}

///|
fn Orchestrator::calculate_horizontal_space(
  self : Orchestrator,
) -> Unit raise Unsupported {
  let config = self.config
  let mut available_width = config.width
  let mut available_height = config.height
  let mut chart_width = (available_width *
  config.plot_reserved_space_percent /
  100.0).floor()
  let mut chart_height = (available_height *
  config.plot_reserved_space_percent /
  100.0).floor()
  available_width -= chart_width
  available_height -= chart_height
  let title_y_end = self.title.calculate_space(config.width, available_height)
  available_height -= title_y_end
  self.x_axis.set_position("left")
  let (x_axis_width, _) = self.x_axis.calculate_space(
    available_width, available_height,
  )
  available_width -= x_axis_width
  let plot_x = x_axis_width
  self.y_axis.set_position("top")
  let (_, y_axis_height) = self.y_axis.calculate_space(
    available_width, available_height,
  )
  available_height -= y_axis_height
  let plot_y = title_y_end + y_axis_height
  let (legend_width, legend_height) = self.legend.calculate_space(
    available_width, chart_height,
  )
  available_width -= legend_width
  if available_width > 0.0 {
    chart_width += available_width
  }
  if available_height > 0.0 {
    chart_height += available_height
  }
  self.plot_rect.width = chart_width
  self.plot_rect.height = chart_height
  self.plot_rect.x = plot_x
  self.plot_rect.y = plot_y
  self.title.align_to(plot_x, plot_x + chart_width)
  self.legend.bounding_rect.x = plot_x + chart_width
  self.legend.bounding_rect.y = plot_y +
    ((chart_height - legend_height) / 2.0).max(0.0)
  self.y_axis.set_range((plot_x, plot_x + chart_width))
  self.y_axis.set_bounding_box_xy(plot_x, title_y_end)
  self.x_axis.set_range((plot_y, plot_y + chart_height))
  self.x_axis.set_bounding_box_xy(0.0, plot_y)
  if self.has_bar_plot() {
    self.x_axis.recalculate_outer_padding_to_draw_bar()
  }
}

///|
/// Everything the chart draws, in drawing order: title, plots, legend,
/// then the axes.
fn Orchestrator::drawable_elements(
  self : Orchestrator,
) -> Array[Drawable] raise Unsupported {
  let horizontal = self.config.horizontal
  if horizontal {
    self.calculate_horizontal_space()
  } else {
    self.calculate_vertical_space()
  }
  let elements = self.title.drawable_elements()
  for plot in self.plots {
    let color = self.theme.plot_color(plot.index)
    match plot.kind {
      Line =>
        elements.append(
          line_plot(plot, color, self.x_axis, self.y_axis, horizontal),
        )
      Bar =>
        elements.append(
          bar_plot(
            plot,
            color,
            self.plot_rect,
            self.x_axis,
            self.y_axis,
            horizontal,
          ),
        )
    }
  }
  elements.append(self.legend.drawable_elements())
  elements.append(self.x_axis.drawable_elements())
  elements.append(self.y_axis.drawable_elements())
  elements
}
