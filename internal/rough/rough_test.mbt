///|
fn exact(seed : Int32) -> @rough.Options {
  let options = @rough.Options::new()
  options.roughness = 0.0
  options.fill_style = "solid"
  options.fill = "#eee"
  options.stroke = "#333"
  options.stroke_width = "1.3"
  options.seed = seed
  options
}

///|
test "a seeded path is repeatable and exact at its corners" {
  let d = "M0,0 L100,0 L100,50 Z"
  let first = @rough.path(d, exact(1)).to_html()
  let second = @rough.path(d, exact(1)).to_html()
  inspect(first == second, content="true")
  // One fill and one stroke; every line is a curve along the line itself.
  inspect(
    first,
    content=(
      #|<g><path d="M0 0 C28.680931767448786 0, 57.36186353489757 0, 100 0 C100 18.18831339944154, 100 36.37662679888308, 100 50 C78.0015514884144 39.0007757442072, 56.003102976828814 28.001551488414407, 0 0" stroke="none" stroke-width="0" fill="#eee"></path><path d="M0 0 C20.000449558719993 0, 40.000899117439985 0, 100 0 M0 0 C22.135189184919003 0, 44.27037836983801 0, 100 0 M100 0 C100 10.875115315429868, 100 21.750230630859736, 100 50 M100 0 C100 13.419787739403546, 100 26.83957547880709, 100 50 M100 50 C78.43275235034525 39.21637617517263, 56.86550470069051 28.432752350345254, 0 0 M100 50 C62.408741703256965 31.204370851628482, 24.81748340651393 12.408741703256965, 0 0" stroke="#333" stroke-width="1.3" fill="none"></path></g>
    ),
  )
  // Another seed moves the control points, not the corners.
  inspect(@rough.path(d, exact(2)).to_html() == first, content="false")
}

///|
test "several subpaths are filled as polygons" {
  let html = @rough.path("M0,0 L10,0 L10,10 Z M20,0 L30,0 L30,10 Z", exact(3)).to_html()
  inspect(
    html.contains("d=\"M0 0 L10 0 L10 10 L0 0 M20 0 L30 0 L30 10 L20 0\""),
    content="true",
  )
}

///|
test "rectangle, line and circle" {
  let rectangle = @rough.rectangle(0.0, 0.0, 20.0, 10.0, exact(5)).to_html()
  inspect(
    rectangle.contains("<path d=\"M0 0 L20 0 L20 10 L0 10\" stroke=\"none\""),
    content="true",
  )
  let options = exact(5)
  options.fill = ""
  options.stroke_line_dash = Some([4.0, 2.0])
  inspect(
    @rough.line(0.0, 0.0, 10.0, 0.0, options).to_html(),
    content=(
      #|<g><path d="M0 0 C2.0002247793599963 0, 4.000449558719993 0, 10 0 M0 0 C3.0675945924595 0, 6.135189184919 0, 10 0" stroke="#333" stroke-width="1.3" fill="none" stroke-dasharray="4 2"></path></g>
    ),
  )
  let circle = @rough.circle(0.0, 0.0, 20.0, exact(5))
  inspect(circle.child_elements().length(), content="2")
}
