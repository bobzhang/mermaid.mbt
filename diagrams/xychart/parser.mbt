///|
/// What the grammar's symbols carry.
priv enum Value {
  Text(String)
  Texts(Array[String])
  /// A value of a plot with the text written after it, if any.
  Point(Double, String)
  Points(Array[(Double, String)])
}

///|
fn Value::text(self : Value) -> String {
  match self {
    Text(text) => text
    _ => ""
  }
}

///|
fn Value::points(self : Value) -> Array[(Double, String)] {
  match self {
    Points(points) => points
    Point(value, label) => [(value, label)]
    _ => []
  }
}

///|
fn Value::texts(self : Value) -> Array[String] {
  match self {
    Texts(texts) => texts
    Text(text) => [text]
    _ => []
  }
}

///|
/// The semantic actions of `xychart.jison`, by production number.
/// `None` keeps the default value, that of the first symbol.
fn XYChart::reduce(
  self : XYChart,
  reduction : @jison.Reduction[Value],
) -> Value? raise {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let trim = @journeycommon.js_trim
  let number = (value : Value) => @journeycommon.js_number(value.text())
  match reduction.production {
    5 => {
      // Only the lowercase word turns the chart; the keyword itself is
      // matched in any case.
      self.orientation = Some(
        if v(0).text() == "horizontal" {
          "horizontal"
        } else {
          "vertical"
        },
      )
      None
    }
    9 => {
      self.title = @journeycommon.sanitize_text(trim(v(0).text()))
      None
    }
    12 => {
      self.add_plot(Line, "", v(0).points())
      None
    }
    13 => {
      self.add_plot(Line, v(1).text(), v(0).points())
      None
    }
    14 => {
      self.add_plot(Bar, "", v(0).points())
      None
    }
    15 => {
      self.add_plot(Bar, v(1).text(), v(0).points())
      None
    }
    16 => {
      self.acc_title = @journeycommon.acc_title(trim(v(0).text()))
      None
    }
    17 | 18 => {
      self.acc_description = @journeycommon.acc_description(trim(v(0).text()))
      None
    }
    // The contents of a pair of brackets.
    19 | 29 => Some(v(1))
    20 => Some(Points([..v(2).points(), ..v(0).points()]))
    21 => Some(Points(v(0).points()))
    22 => Some(Point(number(v(1)), v(0).text()))
    23 => Some(Point(number(v(0)), ""))
    24 => {
      self.x_axis_title = text_sanitizer(v(0).text())
      None
    }
    25 => {
      self.x_axis_title = text_sanitizer(v(1).text())
      None
    }
    26 => {
      self.x_axis_title = ""
      None
    }
    27 => {
      let categories = []
      for category in v(0).texts() {
        categories.push(text_sanitizer(category))
      }
      self.x_axis = Band(categories)
      self.has_set_x_axis = true
      None
    }
    28 => {
      self.x_axis = Linear(number(v(2)), number(v(0)))
      self.has_set_x_axis = true
      None
    }
    30 => Some(Texts([..v(2).texts(), ..v(0).texts()]))
    31 => Some(Texts(v(0).texts()))
    32 => {
      self.y_axis_title = text_sanitizer(v(0).text())
      None
    }
    33 => {
      self.y_axis_title = text_sanitizer(v(1).text())
      None
    }
    34 => {
      self.y_axis_title = ""
      None
    }
    35 => {
      self.y_axis = (number(v(2)), number(v(0)))
      self.has_set_y_axis = true
      None
    }
    43 => Some(Text(v(1).text() + v(0).text()))
    _ => None
  }
}

///|
/// Parse the text of an XY chart. `title` is the title given in the
/// frontmatter, which a `title` statement in the chart replaces.
pub fn parse(source : String, title? : String) -> XYChart raise {
  let chart = XYChart::new()
  if title is Some(title) {
    chart.set_title(title)
  }
  xychart_grammar.parse(source, empty=Text(""), token=text => Text(text), reduce=reduction => {
    chart.reduce(reduction)
  })
  |> ignore
  chart
}
