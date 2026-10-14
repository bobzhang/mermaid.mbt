///|
/// Whether text can be measured in `family`, or why not.
fn measurable(family : String) -> String {
  try measuring_font(family) catch {
    Unsupported(message) => message
  } noraise {
    _ => "yes"
  }
}

///|
test "fonts: the embedded families up to the first unknown one" {
  inspect(
    measurable("\"trebuchet ms\", verdana, arial, sans-serif"),
    content="yes",
  )
  inspect(measurable("Times, serif"), content="yes")
  inspect(measurable("arial, Menlo"), content="yes")
  // Not installed where the references are made: passed over.
  inspect(measurable("Open Sans"), content="yes")
  inspect(
    measurable("monospace"),
    content="text cannot be measured in the font family monospace",
  )
  // In quotes a generic family is a family of that name.
  inspect(
    measurable("\"serif\""),
    content="text cannot be measured in the font family \"serif\"",
  )
}

///|
test "fonts: a list the browser rejects is refused" {
  for family in ["arial,", "arial, 3d", "'arial", "inherit", "a.b", "a\"b"] {
    inspect(
      measurable(family),
      content="the font family \{family} is not a list of families",
    )
  }
}

///|
test "options: what does not pass for a value gives way to the theme" {
  let config = @config.Config::new(site={
    "railroad": {
      "padding": "7px",
      "arcRadius": -1,
      "strokeWidth": "wide",
      "fontSize": 0,
      "fontFamily": "ari;al",
      "lineColor": "url(#x)",
      "terminalFill": " Red ",
      "markerFill": "rgb(1, 2, 3)",
    },
  })
  let options = Options::new(config)
  inspect(options.padding, content="7")
  inspect(options.arc_radius, content="10")
  inspect(options.stroke_width, content="2")
  inspect(options.font_size, content="0")
  inspect(
    options.font_family,
    content="\"trebuchet ms\", verdana, arial, sans-serif",
  )
  inspect(options.line_color, content="#333333")
  inspect(options.terminal_fill, content="Red")
  inspect(options.marker_fill, content="rgb(1, 2, 3)")
}
