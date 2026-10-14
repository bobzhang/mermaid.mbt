///|
/// What the grammar's symbols carry: text, or the styles of a point or
/// class.
priv enum Value {
  Text(String)
  Styles(Array[String])
}

///|
fn Value::text(self : Value) -> String {
  match self {
    Text(text) => text
    Styles(styles) => styles.join(",")
  }
}

///|
fn Value::styles(self : Value) -> Array[String] {
  match self {
    Styles(styles) => styles
    Text(_) => []
  }
}

///|
/// The semantic actions of `quadrant.jison`, by production number.
/// `None` keeps the default value, that of the first symbol.
fn Quadrant::reduce(
  self : Quadrant,
  reduction : @jison.Reduction[Value],
) -> Value? raise {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let trim = @journeycommon.js_trim
  match reduction.production {
    // Identifiers, styles and text are put together token by token.
    24 | 26 | 65 | 69 => Some(Text(v(1).text() + v(0).text()))
    27 => Some(Styles([trim(v(0).text())]))
    28 => {
      let styles = v(2).styles()
      styles.push(trim(v(0).text()))
      Some(Styles(styles))
    }
    29 => {
      self.classes[v(2).text()] = parse_styles(v(0).styles())
      None
    }
    42 => {
      self.title = @journeycommon.sanitize_text(trim(v(0).text()))
      None
    }
    43 => {
      self.acc_title = @journeycommon.acc_title(trim(v(0).text()))
      None
    }
    44 | 45 => {
      self.acc_description = @journeycommon.acc_description(trim(v(0).text()))
      None
    }
    // `section` is in the grammar, but nothing in the lexer produces it.
    46 => raise QuadrantError("yy.addSection is not a function")
    47 => {
      self.add_point(v(3).text(), "", v(1).text(), v(0).text(), [])
      None
    }
    48 => {
      self.add_point(v(4).text(), v(3).text(), v(1).text(), v(0).text(), [])
      None
    }
    49 => {
      self.add_point(v(4).text(), "", v(2).text(), v(1).text(), v(0).styles())
      None
    }
    50 => {
      self.add_point(
        v(5).text(),
        v(4).text(),
        v(2).text(),
        v(1).text(),
        v(0).styles(),
      )
      None
    }
    51 => {
      self.x_axis_left = text_sanitizer(v(2).text())
      self.x_axis_right = text_sanitizer(v(0).text())
      None
    }
    // An axis with an arrow and nothing after it keeps the arrow.
    52 => {
      self.x_axis_left = text_sanitizer(v(1).text() + " \u{27F6} ")
      None
    }
    53 => {
      self.x_axis_left = text_sanitizer(v(0).text())
      None
    }
    54 => {
      self.y_axis_bottom = text_sanitizer(v(2).text())
      self.y_axis_top = text_sanitizer(v(0).text())
      None
    }
    55 => {
      self.y_axis_bottom = text_sanitizer(v(1).text() + " \u{27F6} ")
      None
    }
    56 => {
      self.y_axis_bottom = text_sanitizer(v(0).text())
      None
    }
    57 | 58 | 59 | 60 => {
      self.quadrant_texts[reduction.production - 57] = text_sanitizer(
        v(0).text(),
      )
      None
    }
    _ => None
  }
}

///|
/// Parse the text of a quadrant chart. `title` is the title given in the
/// frontmatter, which a `title` statement in the chart replaces.
pub fn parse(source : String, title? : String) -> Quadrant raise {
  let chart = Quadrant::new()
  if title is Some(title) {
    chart.set_title(title)
  }
  quadrant_grammar.parse(source, empty=Text(""), token=text => Text(text), reduce=reduction => {
    chart.reduce(reduction)
  })
  |> ignore
  chart
}
