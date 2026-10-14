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
