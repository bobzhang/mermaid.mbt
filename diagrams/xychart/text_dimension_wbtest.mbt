// What the chart builder's text dimension calculator returned in the
// reference browser — the tspan's `getBoundingClientRect()` divided by
// the scale of `getScreenCTM()` — for charts of several sizes.

///|
fn measured(
  width : Double,
  height : Double,
  font_size : Double,
  text : String,
) -> String raise {
  let context = @diagram.Context::new(
    "id",
    @config.Config::new(),
    @dom.Element::new("svg"),
    now=0.0,
    page=@diagram.Page::new(),
  )
  let measure = Measurer::new(
    context.font(),
    context.placement(width, height, max_width=width),
  )
  let (w, h) = measure.dimension(text, font_size)
  "\{w} \{h}"
}

///|
test "text in a chart drawn at its own size" {
  inspect(measured(700.0, 500.0, 14.0, "jan"), content="20.140625 16")
  inspect(
    measured(700.0, 500.0, 16.0, "Revenue (in $)"),
    content="103.25 19.000001907348633",
  )
  inspect(
    measured(700.0, 500.0, 20.0, "Sales Revenue"),
    content="126.265625 23",
  )
  inspect(measured(700.0, 500.0, 20.0, ""), content="0 0")
}

///|
test "text in a chart wider than the page is measured scaled down" {
  inspect(
    measured(900.0, 600.0, 12.0, "Revenue (in $)"),
    content="77.39307535641548 13.67864681832509",
  )
  inspect(
    measured(900.0, 600.0, 14.0, "feb"),
    content="20.599362274664195 17.37949762389681",
  )
  inspect(
    measured(900.0, 600.0, 20.0, "Sales Revenue"),
    content="126.2535156628843 23.586456325465523",
  )
  inspect(
    measured(1500.0, 900.0, 10.0, "jan"),
    content="14.379222972972972 12.184532268627269",
  )
  inspect(
    measured(5000.0, 5000.0, 31.0, "AVATAR"),
    content="97.09051724137932 34.48275862068966",
  )
}

///|
test "a size that is not whole layout units leaves a scale just short of one" {
  inspect(
    measured(720.0, 500.3, 13.3, "(parens)"),
    content="49.203431136514524 15.000093328375339",
  )
  inspect(
    measured(733.7, 211.9, 17.5, "fj"),
    content="12.891194968261898 20.00088431439422",
  )
}

///|
test "two sizes under one key of the font cache share the first one's face" {
  let context = @diagram.Context::new(
    "id",
    @config.Config::new(),
    @dom.Element::new("svg"),
    now=0.0,
    page=@diagram.Page::new(),
  )
  let text = "The quick brown fox jumps"
  let width = (sizes : Array[Double]) => {
    let measure = Measurer::new(
      context.font(),
      context.placement(700.0, 500.0, max_width=700.0),
    )
    sizes.map(size => measure.dimension(text, size).0)
  }
  // 4.9333 is kept as 4.93, which is filed with 4.92.
  json_inspect(width([4.92]), content=[59.796875])
  json_inspect(width([4.9333]), content=[59.90625])
  json_inspect(width([4.9333, 4.92]), content=[59.90625, 59.90625])
  json_inspect(width([4.92, 4.9333]), content=[59.796875, 59.796875])
  json_inspect(width([4.92, 4.94]), content=[59.796875, 60.03125])
  // 7.45 times a hundred is 745 in single precision: a key of its own.
  json_inspect(width([7.45, 7.44, 7.46]), content=[90.53125, 90.40625, 90.65625])
}
