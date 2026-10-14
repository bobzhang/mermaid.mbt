///|
/// The configuration of one axis.
priv struct AxisConfig {
  show_label : Bool
  label_font_size : Double
  label_padding : Double
  show_title : Bool
  title_font_size : Double
  title_padding : Double
  show_tick : Bool
  tick_length : Double
  tick_width : Double
  show_axis_line : Bool
  axis_line_width : Double
  label_rotation : Double
}

///|
/// The `xyChart` configuration.
priv struct ChartConfig {
  width : Double
  height : Double
  title_font_size : Double
  title_padding : Double
  show_data_label : Bool
  show_data_label_outside_bar : Bool
  show_title : Bool
  show_legend : Bool
  legend_font_size : Double
  legend_padding : Double
  x_axis : AxisConfig
  y_axis : AxisConfig
  horizontal : Bool
  plot_reserved_space_percent : Double
}

///|
/// A number of the configuration. Upstream computes with whatever the
/// configuration holds, and JavaScript's arithmetic on anything but
/// numbers is not reproduced.
fn config_number(
  config : @config.Config,
  path : String,
) -> Double raise Unsupported {
  guard config.number(path) is Some(value) else {
    raise Unsupported("\{path} is not a number")
  }
  value
}

///|
fn AxisConfig::new(
  config : @config.Config,
  axis : String,
) -> AxisConfig raise Unsupported {
  let number = (name : String) => {
    config_number(config, "xyChart.\{axis}.\{name}")
  }
  let flag = (name : String) => config.flag("xyChart.\{axis}.\{name}")
  {
    show_label: flag("showLabel"),
    label_font_size: number("labelFontSize"),
    label_padding: number("labelPadding"),
    show_title: flag("showTitle"),
    title_font_size: number("titleFontSize"),
    title_padding: number("titlePadding"),
    show_tick: flag("showTick"),
    tick_length: number("tickLength"),
    tick_width: number("tickWidth"),
    show_axis_line: flag("showAxisLine"),
    axis_line_width: number("axisLineWidth"),
    label_rotation: number("labelRotation"),
  }
}

///|
/// The configuration in effect for `chart`, whose own orientation goes
/// before the configured one.
fn ChartConfig::new(
  config : @config.Config,
  chart : XYChart,
) -> ChartConfig raise Unsupported {
  let number = (name : String) => config_number(config, "xyChart." + name)
  let flag = (name : String) => config.flag("xyChart." + name)
  let orientation = match chart.orientation {
    Some(orientation) => orientation
    None => config.text("xyChart.chartOrientation").unwrap_or("")
  }
  {
    width: number("width"),
    height: number("height"),
    title_font_size: number("titleFontSize"),
    title_padding: number("titlePadding"),
    show_data_label: flag("showDataLabel"),
    show_data_label_outside_bar: flag("showDataLabelOutsideBar"),
    show_title: flag("showTitle"),
    show_legend: flag("showLegend"),
    legend_font_size: number("legendFontSize"),
    legend_padding: number("legendPadding"),
    x_axis: AxisConfig::new(config, "xAxis"),
    y_axis: AxisConfig::new(config, "yAxis"),
    horizontal: orientation == "horizontal",
    plot_reserved_space_percent: number("plotReservedSpacePercent"),
  }
}

///|
/// The colors of one axis.
priv struct AxisTheme {
  title_color : String
  label_color : String
  tick_color : String
  axis_line_color : String
}

///|
/// The `xyChart` theme variables, as the chart's database merges them:
/// those of the theme in effect over those of the default theme.
priv struct ChartTheme {
  background_color : String
  title_color : String
  data_label_color : String
  legend_text_color : String
  x_axis : AxisTheme
  y_axis : AxisTheme
  /// The colors plots take in turn.
  palette : Array[String]
}

///|
fn ChartTheme::new(theme : @theme.Theme) -> ChartTheme raise Unsupported {
  // What the theme in effect leaves out — the redux themes have no color
  // for data labels — is taken from the default theme.
  let default = (@theme.Theme::new("default") catch { _ => None }).unwrap_or(
    theme,
  )
  let color = (name : String) => {
    match (theme.nested("xyChart", name), default.nested("xyChart", name)) {
      (String(color), _) | (Null, String(color)) => color
      _ => raise Unsupported("themeVariables.xyChart.\{name} is not text")
    }
  }
  let axis = (prefix : String) => {
    let axis : AxisTheme = {
      title_color: color(prefix + "TitleColor"),
      label_color: color(prefix + "LabelColor"),
      tick_color: color(prefix + "TickColor"),
      axis_line_color: color(prefix + "LineColor"),
    }
    axis
  }
  // `"".split(",")` is one empty text.
  let palette = color("plotColorPalette")
    .split(",")
    .map(color => @journeycommon.js_trim(color.to_owned()))
    .collect()
  if palette.is_empty() {
    palette.push("")
  }
  {
    background_color: color("backgroundColor"),
    title_color: color("titleColor"),
    data_label_color: color("dataLabelColor"),
    legend_text_color: color("legendTextColor"),
    x_axis: axis("xAxis"),
    y_axis: axis("yAxis"),
    palette,
  }
}

///|
/// The color of the plot at `index`: the palette's colors in turn.
fn ChartTheme::plot_color(self : ChartTheme, index : Int32) -> String {
  self.palette[index % self.palette.length()]
}
