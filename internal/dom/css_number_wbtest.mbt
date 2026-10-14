///|
test "css numbers as the reference browser serializes them" {
  // Read back from `element.style.maxWidth` after assigning each length.
  let cases : Array[(Double, String)] = [
    (100.0625, "100.062"),
    (100.0635, "100.064"),
    (100.0645, "100.064"),
    (372.015625, "372.016"),
    (0.0001234565, "0.000123457"),
    (1234567.5, "1.23457e+06"),
    (99999.95, "99999.9"),
    (100.5, "100.5"),
    (16384.0, "16384"),
    (0.5, "0.5"),
    (123456.5, "123456"),
    (123457.5, "123458"),
    (2.5e-07, "2.5e-07"),
    (1000000.0, "1e+06"),
    (1.0e21, "1e+21"),
    (12.3456789, "12.3457"),
    (999999.5, "1e+06"),
    (0.015625, "0.015625"),
    (10.03125, "10.0312"),
    (1000.03125, "1000.03"),
    (10000.03125, "10000"),
    (100000.03125, "100000"),
    (1000.015625, "1000.02"),
    (100.046875, "100.047"),
  ]
  for item in cases {
    assert_eq(css_number(item.0), item.1)
  }
  assert_eq(css_length("414.203125px"), Some("414.203px"))
  assert_eq(css_length("table-cell"), None)
}

///|
test "repeated and important declarations" {
  // What the reference browser makes of each style attribute once a
  // declaration is added through the CSSOM.
  let serialized = (style : String) => {
    Element::new("div")
    .attr("style", style)
    .style("display", "table-cell")
    .to_html()
  }
  inspect(
    serialized(
      "color:red !important; font-weight: bold; fill: blue; color: green",
    ),
    content=(
      #|<div style="font-weight: bold; fill: blue; color: red !important; display: table-cell;"></div>
    ),
  )
  inspect(
    serialized("font-weight:bold !important; font-weight: bold;"),
    content=(
      #|<div style="font-weight: bold !important; display: table-cell;"></div>
    ),
  )
  // Two declarations of different properties stay as written.
  inspect(
    serialized("color:green !important; font-weight: bold;"),
    content=(
      #|<div style="color: green !important; font-weight: bold; display: table-cell;"></div>
    ),
  )
  inspect(
    serialized("color:red !important; font-weight: bold; fill: blue"),
    content=(
      #|<div style="font-weight: bold; fill: blue; color: red !important; display: table-cell;"></div>
    ),
  )
  inspect(
    serialized("fill: blue; color: red; fill: green"),
    content=(
      #|<div style="color: red; fill: green; display: table-cell;"></div>
    ),
  )
  inspect(
    serialized(
      "font-size: 12px !important; font-size: 14px !important; font-size: 16px",
    ),
    content=(
      #|<div style="font-size: 14px !important; display: table-cell;"></div>
    ),
  )
}
