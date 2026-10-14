// The expected paths are those mermaid drew through these points, in the
// block diagram fixtures.

///|
test "a basis curve through three points" {
  inspect(
    @d3.line_basis([
      (49.96354166666667, -4.0),
      (45.8125, 0.0),
      (41.66145833333333, 4.0),
    ]).unwrap_or(""),
    content="M49.964,-4L49.272,-3.333C48.58,-2.667,47.196,-1.333,45.813,0C44.429,1.333,43.045,2.667,42.353,3.333L41.661,4",
  )
}

///|
test "basis curves of fewer points" {
  inspect(@d3.line_basis([]) is None, content="true")
  inspect(@d3.line_basis([(1.0, 2.0)]).unwrap_or(""), content="M1,2Z")
  inspect(
    @d3.line_basis([(1.0, 2.0), (3.0005, 4.0)]).unwrap_or(""),
    content="M1,2L3.001,4",
  )
}

///|
test "a polyline" {
  inspect(
    @d3.line_linear([(0.0, 0.0), (10.0, 5.25), (20.0, -5.0)]).unwrap_or(""),
    content="M0,0L10,5.25L20,-5",
  )
  inspect(@d3.line_linear([(1.0, 2.0)]).unwrap_or(""), content="M1,2Z")
}

///|
test "the other curves" {
  // As mermaid drew an edge of a block diagram through these points with
  // `flowchart.curve` set to each name (`testdata/block/curve_*.mmd`).
  let points = [
    (46.774628957112625, 68.12955474853516),
    (92.19433212280273, 0.0),
    (140.7563491782771, -72.84302558321157),
  ]
  let drawn = (curve : String) => @d3.line(curve, points).unwrap_or("")
  inspect(drawn("linear"), content="M46.775,68.13L92.194,0L140.756,-72.843")
  inspect(
    drawn("step"),
    content="M46.775,68.13L69.484,68.13L69.484,0L116.475,0L116.475,-72.843L140.756,-72.843",
  )
  inspect(
    drawn("stepBefore"),
    content="M46.775,68.13L46.775,0L92.194,0L92.194,-72.843L140.756,-72.843",
  )
  inspect(
    drawn("stepAfter"),
    content="M46.775,68.13L92.194,68.13L92.194,0L140.756,0L140.756,-72.843",
  )
  inspect(
    drawn("bumpX"),
    content="M46.775,68.13C69.484,68.13,69.484,0,92.194,0C116.475,0,116.475,-72.843,140.756,-72.843",
  )
  inspect(
    drawn("bumpY"),
    content="M46.775,68.13C46.775,34.065,92.194,34.065,92.194,0C92.194,-36.422,140.756,-36.422,140.756,-72.843",
  )
  inspect(
    drawn("cardinal"),
    content="M46.775,68.13C46.775,68.13,76.531,23.495,92.194,0C107.858,-23.495,140.756,-72.843,140.756,-72.843",
  )
  inspect(
    drawn("catmullRom"),
    content="M46.775,68.13C46.775,68.13,76.801,23.09,92.194,0C108.111,-23.875,140.756,-72.843,140.756,-72.843",
  )
  inspect(
    drawn("monotoneX"),
    content="M46.775,68.13C61.915,45.42,77.054,22.71,92.194,0C108.382,-24.281,124.569,-48.562,140.756,-72.843",
  )
  inspect(
    drawn("monotoneY"),
    content="M46.775,68.13C61.915,45.42,77.054,22.71,92.194,0C108.382,-24.281,124.569,-48.562,140.756,-72.843",
  )
  inspect(
    drawn("natural"),
    content="M46.775,68.13C61.653,45.812,76.531,23.495,92.194,0C107.858,-23.495,124.307,-48.169,140.756,-72.843",
  )
  inspect(@d3.line("spiral", points) is None, content="true")
}
