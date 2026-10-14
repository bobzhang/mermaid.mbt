///|
/// A chart upstream fails on while it builds or draws it.
pub(all) suberror XYChartError {
  XYChartError(String)
} derive(Eq, Debug)

///|
/// A chart whose rendering depends on something that is not ported.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// What an axis shows: named categories in bands, or a range of numbers.
priv enum AxisData {
  Band(Array[String])
  Linear(Double, Double)
}

///|
priv enum PlotKind {
  Line
  Bar
}

///|
/// One `line` or `bar` statement.
priv struct Plot {
  kind : PlotKind
  title : String
  /// The plot's place among the plots, which picks its color.
  index : Int32
  /// Where along the horizontal axis each value belongs — a category, or
  /// a number as text — and the value, absent where the axis has more
  /// categories than the plot has values.
  data : Array[(String, Double?)]
  /// The texts written after the values of a line, when there are any.
  point_labels : Array[String]?
}

///|
/// A parsed XY chart.
pub struct XYChart {
  mut title : String
  mut acc_title : String
  mut acc_description : String
  /// The orientation written after the keyword, which goes before the
  /// configured one.
  priv mut orientation : String?
  priv mut x_axis_title : String
  priv mut x_axis : AxisData
  priv mut y_axis_title : String
  /// The vertical axis is always a range; empty until a plot or a
  /// `y-axis` statement gives it one.
  priv mut y_axis : (Double, Double)
  priv plots : Array[Plot]
  /// Whether the axes have been given their extent: by a statement, or
  /// for the horizontal axis by the first plot.
  priv mut has_set_x_axis : Bool
  priv mut has_set_y_axis : Bool
}

///|
fn XYChart::new() -> XYChart {
  {
    title: "",
    acc_title: "",
    acc_description: "",
    orientation: None,
    x_axis_title: "",
    x_axis: Band([]),
    y_axis_title: "",
    y_axis: (@double.infinity, @double.neg_infinity),
    plots: [],
    has_set_x_axis: false,
    has_set_y_axis: false,
  }
}

///|
/// The title of the frontmatter, which a `title` statement replaces.
pub fn XYChart::set_title(
  self : XYChart,
  title : String,
) -> Unit raise @journeycommon.SanitizeError {
  self.title = @journeycommon.sanitize_text(title)
}

///|
/// Text of the chart as the database stores it: trimmed and sanitized.
fn text_sanitizer(text : String) -> String raise @journeycommon.SanitizeError {
  @journeycommon.sanitize_text(@journeycommon.js_trim(text))
}

///|
/// `Math.min` of two numbers: not a number if either is not.
fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// `Math.max` of two numbers: not a number if either is not.
fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// The database's `transformDataWithoutCategory`: pair the values of a
/// plot with positions along the horizontal axis as it is at this point
/// of the chart, giving the axes their extent on the way.
fn XYChart::transform_data(
  self : XYChart,
  data : Array[Double],
) -> Array[(String, Double?)] {
  if data.is_empty() {
    return []
  }
  if !self.has_set_x_axis {
    // The first plot without an axis before it numbers its values from
    // one.
    let (min, max) = match self.x_axis {
      Linear(min, max) => (min, max)
      Band(_) => (@double.infinity, @double.neg_infinity)
    }
    self.x_axis = Linear(
      js_min(min, 1.0),
      js_max(max, data.length().to_double()),
    )
    self.has_set_x_axis = true
  }
  // Values beyond the last category are dropped.
  let data = match self.x_axis {
    Band(categories) if data.length() > categories.length() =>
      data[:categories.length()].to_owned()
    _ => data
  }
  if !self.has_set_y_axis {
    let mut min = self.y_axis.0
    let mut max = self.y_axis.1
    for value in data {
      min = js_min(min, value)
      max = js_max(max, value)
    }
    self.y_axis = (min, max)
  }
  match self.x_axis {
    Band(categories) =>
      categories.mapi((i, category) => (category, data.get(i)))
    Linear(min, max) =>
      if data.length() == 1 {
        [(@dom.number(min), Some(data[0]))]
      } else {
        let step = (max - min) / (data.length() - 1).to_double()
        data.mapi((index, datum) => {
          (@dom.number(min + index.to_double() * step), Some(datum))
        })
      }
  }
}

///|
fn XYChart::add_plot(
  self : XYChart,
  kind : PlotKind,
  title : String,
  points : Array[(Double, String)],
) -> Unit raise @journeycommon.SanitizeError {
  let labels = []
  for point in points {
    labels.push(if point.1 == "" { "" } else { text_sanitizer(point.1) })
  }
  let data = self.transform_data(points.map(point => point.0))
  // Only lines have labels at their points, and only when one is given.
  let point_labels = if kind is Line && labels.any(label => label != "") {
    Some(labels)
  } else {
    None
  }
  self.plots.push({
    kind,
    title: text_sanitizer(title),
    index: self.plots.length(),
    data,
    point_labels,
  })
}
