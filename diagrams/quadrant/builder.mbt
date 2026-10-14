// A port of mermaid's QuadrantBuilder: from the chart's data, the
// configuration and the theme to positioned texts, rectangles, lines and
// circles. The arithmetic follows the TypeScript operation by operation.

///|
/// A text with its place; `x` and `y` are already formatted, since a
/// point off the scale has coordinates that are not numbers.
priv struct PlacedText {
  text : String
  fill : String
  x : String
  y : String
  font_size : Double
  /// `left` or `center`
  vertical_pos : String
  /// `top` or `middle`
  horizontal_pos : String
  rotation : Double
}

///|
priv struct PlacedPoint {
  /// Absent for a position that is not a number: the scale has no value
  /// for it, and the attribute is left out.
  x : Double?
  y : Double?
  fill : String
  radius : Double
  text : PlacedText
  stroke_color : String
  stroke_width : String
}

///|
priv struct PlacedQuadrant {
  text : PlacedText
  x : Double
  y : Double
  width : Double
  height : Double
  fill : String
}

///|
priv struct Line {
  stroke_width : Double
  stroke_fill : String
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
}

///|
/// Everything the renderer draws.
priv struct Build {
  points : Array[PlacedPoint]
  quadrants : Array[PlacedQuadrant]
  axis_labels : Array[PlacedText]
  border_lines : Array[Line]
  title : PlacedText?
}

///|
/// Where the parts of the chart go.
priv struct Space {
  title_top : Double
  quadrant_left : Double
  quadrant_top : Double
  quadrant_width : Double
  quadrant_half_width : Double
  quadrant_height : Double
  quadrant_half_height : Double
}

///|
/// The builder's inputs besides the chart: the `quadrantChart`
/// configuration and the theme's quadrant variables.
priv struct Builder {
  chart : Quadrant
  number : (String) -> Double
  text : (String) -> String
  theme : (String) -> String
}

///|
fn Builder::calculate_space(
  self : Builder,
  x_axis_position : String,
  show_x_axis : Bool,
  show_y_axis : Bool,
  show_title : Bool,
) -> Space {
  let n = self.number
  let x_axis_space_calculation = n("xAxisLabelPadding") * 2.0 +
    n("xAxisLabelFontSize")
  let x_axis_top = if x_axis_position == "top" && show_x_axis {
    x_axis_space_calculation
  } else {
    0.0
  }
  let x_axis_bottom = if x_axis_position == "bottom" && show_x_axis {
    x_axis_space_calculation
  } else {
    0.0
  }
  let y_axis_space_calculation = n("yAxisLabelPadding") * 2.0 +
    n("yAxisLabelFontSize")
  let y_axis_position = (self.text)("yAxisPosition")
  let y_axis_left = if y_axis_position == "left" && show_y_axis {
    y_axis_space_calculation
  } else {
    0.0
  }
  let y_axis_right = if y_axis_position == "right" && show_y_axis {
    y_axis_space_calculation
  } else {
    0.0
  }
  let title_space_calculation = n("titleFontSize") + n("titlePadding") * 2.0
  let title_top = if show_title { title_space_calculation } else { 0.0 }
  let quadrant_left = n("quadrantPadding") + y_axis_left
  let quadrant_top = n("quadrantPadding") + x_axis_top + title_top
  let quadrant_width = n("chartWidth") -
    n("quadrantPadding") * 2.0 -
    y_axis_left -
    y_axis_right
  let quadrant_height = n("chartHeight") -
    n("quadrantPadding") * 2.0 -
    x_axis_top -
    x_axis_bottom -
    title_top
  {
    title_top,
    quadrant_left,
    quadrant_top,
    quadrant_width,
    quadrant_half_width: quadrant_width / 2.0,
    quadrant_height,
    quadrant_half_height: quadrant_height / 2.0,
  }
}

///|
fn Builder::axis_labels(
  self : Builder,
  x_axis_position : String,
  show_x_axis : Bool,
  show_y_axis : Bool,
  space : Space,
) -> Array[PlacedText] {
  let n = self.number
  let chart = self.chart
  let in_middle_x = chart.x_axis_right != ""
  let in_middle_y = chart.y_axis_top != ""
  let labels = []
  let x_label = (text : String, x : Double) => {
    let y = if x_axis_position == "top" {
      n("xAxisLabelPadding") + space.title_top
    } else {
      n("xAxisLabelPadding") +
      space.quadrant_top +
      space.quadrant_height +
      n("quadrantPadding")
    }
    labels.push({
      text,
      fill: (self.theme)("quadrantXAxisTextFill"),
      x: @dom.number(x),
      y: @dom.number(y),
      font_size: n("xAxisLabelFontSize"),
      vertical_pos: if in_middle_x {
        "center"
      } else {
        "left"
      },
      horizontal_pos: "top",
      rotation: 0.0,
    })
  }
  let middle_x = if in_middle_x { space.quadrant_half_width / 2.0 } else { 0.0 }
  if chart.x_axis_left != "" && show_x_axis {
    x_label(chart.x_axis_left, space.quadrant_left + middle_x)
  }
  if chart.x_axis_right != "" && show_x_axis {
    x_label(
      chart.x_axis_right,
      space.quadrant_left + space.quadrant_half_width + middle_x,
    )
  }
  let y_label = (text : String, y : Double) => {
    let x = if (self.text)("yAxisPosition") == "left" {
      n("yAxisLabelPadding")
    } else {
      n("yAxisLabelPadding") +
      space.quadrant_left +
      space.quadrant_width +
      n("quadrantPadding")
    }
    labels.push({
      text,
      fill: (self.theme)("quadrantYAxisTextFill"),
      x: @dom.number(x),
      y: @dom.number(y),
      font_size: n("yAxisLabelFontSize"),
      vertical_pos: if in_middle_y {
        "center"
      } else {
        "left"
      },
      horizontal_pos: "top",
      rotation: -90.0,
    })
  }
  let middle_y = if in_middle_y {
    space.quadrant_half_height / 2.0
  } else {
    0.0
  }
  if chart.y_axis_bottom != "" && show_y_axis {
    y_label(
      chart.y_axis_bottom,
      space.quadrant_top + space.quadrant_height - middle_y,
    )
  }
  if chart.y_axis_top != "" && show_y_axis {
    y_label(
      chart.y_axis_top,
      space.quadrant_top + space.quadrant_half_height - middle_y,
    )
  }
  labels
}

///|
fn Builder::quadrants(self : Builder, space : Space) -> Array[PlacedQuadrant] {
  let n = self.number
  let left = space.quadrant_left
  let top = space.quadrant_top
  let half_width = space.quadrant_half_width
  let half_height = space.quadrant_half_height
  // Top right, top left, bottom left, bottom right.
  let corners = [
    (left + half_width, top),
    (left, top),
    (left, top + half_height),
    (left + half_width, top + half_height),
  ]
  let quadrants = []
  for index, corner in corners {
    let (x, y) = corner
    let text_x = x + half_width / 2.0
    // Without points the text is in the middle of its quadrant; with
    // points it moves to the top, out of their way.
    let (text_y, horizontal_pos) = if self.chart.points.is_empty() {
      (y + half_height / 2.0, "middle")
    } else {
      (y + n("quadrantTextTopPadding"), "top")
    }
    quadrants.push({
      text: {
        text: self.chart.quadrant_texts[index],
        fill: (self.theme)("quadrant\{index + 1}TextFill"),
        x: @dom.number(text_x),
        y: @dom.number(text_y),
        font_size: n("quadrantLabelFontSize"),
        vertical_pos: "center",
        horizontal_pos,
        rotation: 0.0,
      },
      x,
      y,
      width: half_width,
      height: half_height,
      fill: (self.theme)("quadrant\{index + 1}Fill"),
    })
  }
  quadrants
}

///|
/// A d3 linear scale over the domain from zero to one: `range.0` at zero,
/// `range.1` at one. A position that is not a number has no value.
fn scale(range : (Double, Double), position : String) -> Double? {
  let t = @journeycommon.js_number(position)
  if t.is_nan() {
    return None
  }
  // The domain normalizes to `(x - 0) / 1`; the range is interpolated.
  let t = (t - 0.0) / 1.0
  Some(range.0 * (1.0 - t) + range.1 * t)
}

///|
/// A coordinate as JavaScript prints it in a template string.
fn coordinate(value : Double?) -> String {
  match value {
    Some(value) => @dom.number(value)
    None => "undefined"
  }
}

///|
fn Builder::points(self : Builder, space : Space) -> Array[PlacedPoint] {
  let n = self.number
  let x_range = (
    space.quadrant_left,
    space.quadrant_width + space.quadrant_left,
  )
  let y_range = (space.quadrant_height + space.quadrant_top, space.quadrant_top)
  let point_fill = (self.theme)("quadrantPointFill")
  self.chart.points.map(point => {
    // What the point says of itself comes before its class.
    let styles = match self.chart.classes.get(point.class_name) {
      Some(of_class) => point.styles.or(of_class)
      None => point.styles
    }
    let x = scale(x_range, point.x)
    let y = scale(y_range, point.y)
    let text_y = match y {
      Some(y) => @dom.number(y + n("pointTextPadding"))
      None => "NaN"
    }
    {
      x,
      y,
      fill: styles.color.unwrap_or(point_fill),
      radius: styles.radius.unwrap_or(n("pointRadius")),
      text: {
        text: point.text,
        fill: (self.theme)("quadrantPointTextFill"),
        x: coordinate(x),
        y: text_y,
        vertical_pos: "center",
        horizontal_pos: "top",
        font_size: n("pointLabelFontSize"),
        rotation: 0.0,
      },
      stroke_color: styles.stroke_color.unwrap_or(point_fill),
      stroke_width: styles.stroke_width.unwrap_or("0px"),
    }
  })
}

///|
fn Builder::borders(self : Builder, space : Space) -> Array[Line] {
  let n = self.number
  let external_width = n("quadrantExternalBorderStrokeWidth")
  let internal_width = n("quadrantInternalBorderStrokeWidth")
  let half_external = external_width / 2.0
  let external = (self.theme)("quadrantExternalBorderStrokeFill")
  let internal = (self.theme)("quadrantInternalBorderStrokeFill")
  let left = space.quadrant_left
  let top = space.quadrant_top
  let width = space.quadrant_width
  let height = space.quadrant_height
  [
    // top
    {
      stroke_fill: external,
      stroke_width: external_width,
      x1: left - half_external,
      y1: top,
      x2: left + width + half_external,
      y2: top,
    },
    // right
    {
      stroke_fill: external,
      stroke_width: external_width,
      x1: left + width,
      y1: top + half_external,
      x2: left + width,
      y2: top + height - half_external,
    },
    // bottom
    {
      stroke_fill: external,
      stroke_width: external_width,
      x1: left - half_external,
      y1: top + height,
      x2: left + width + half_external,
      y2: top + height,
    },
    // left
    {
      stroke_fill: external,
      stroke_width: external_width,
      x1: left,
      y1: top + half_external,
      x2: left,
      y2: top + height - half_external,
    },
    // the vertical line inside
    {
      stroke_fill: internal,
      stroke_width: internal_width,
      x1: left + space.quadrant_half_width,
      y1: top + half_external,
      x2: left + space.quadrant_half_width,
      y2: top + height - half_external,
    },
    // the horizontal line inside
    {
      stroke_fill: internal,
      stroke_width: internal_width,
      x1: left + half_external,
      y1: top + space.quadrant_half_height,
      x2: left + width - half_external,
      y2: top + space.quadrant_half_height,
    },
  ]
}

///|
fn Builder::build(self : Builder) -> Build {
  let n = self.number
  let chart = self.chart
  let show_x_axis = chart.x_axis_left != "" || chart.x_axis_right != ""
  let show_y_axis = chart.y_axis_top != "" || chart.y_axis_bottom != ""
  let show_title = chart.title != ""
  // Points push the labels of the horizontal axis below the chart.
  let x_axis_position = if chart.points.is_empty() {
    (self.text)("xAxisPosition")
  } else {
    "bottom"
  }
  let space = self.calculate_space(
    x_axis_position, show_x_axis, show_y_axis, show_title,
  )
  let title = if show_title {
    Some({
      text: chart.title,
      fill: (self.theme)("quadrantTitleFill"),
      font_size: n("titleFontSize"),
      horizontal_pos: "top",
      vertical_pos: "center",
      rotation: 0.0,
      y: @dom.number(n("titlePadding")),
      x: @dom.number(n("chartWidth") / 2.0),
    })
  } else {
    None
  }
  {
    points: self.points(space),
    quadrants: self.quadrants(space),
    axis_labels: self.axis_labels(
      x_axis_position, show_x_axis, show_y_axis, space,
    ),
    border_lines: self.borders(space),
    title,
  }
}
