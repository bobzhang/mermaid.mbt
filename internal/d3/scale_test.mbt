// The expected values are what the d3 bundled with mermaid returns for
// the same calls, run in Node.

///|
test "linear scale" {
  let scale = @d3.LinearScale::new(
    domain=(4000.0, 11000.0),
    range=(459.0, 51.0),
  )
  debug_inspect(scale.apply(7500.0), content="Some(255)")
  debug_inspect(scale.apply(8200.0), content="Some(214.20000000000002)")
  // Outside the domain the scale carries on.
  debug_inspect(scale.apply(12000.0), content="Some(-7.285714285714256)")
  // What is not a number is unknown.
  debug_inspect(scale.apply(@double.not_a_number), content="None")
  json_inspect(scale.ticks(), content=[
    4000, 4500, 5000, 5500, 6000, 6500, 7000, 7500, 8000, 8500, 9000, 9500, 10000,
    10500, 11000,
  ])
}

///|
test "linear scale over a descending or empty domain" {
  let descending = @d3.LinearScale::new(domain=(100.0, 0.0), range=(0.0, 50.0))
  debug_inspect(descending.apply(25.0), content="Some(37.5)")
  json_inspect(descending.ticks(), content=[
    100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0,
  ])
  // A domain of one value maps everything to the middle of the range.
  let empty = @d3.LinearScale::new(domain=(5.0, 5.0), range=(0.0, 50.0))
  debug_inspect(empty.apply(123.0), content="Some(25)")
  json_inspect(empty.ticks(), content=[5])
}

///|
test "band scale" {
  let bands = @d3.BandScale::new(domain=["a", "b", "c"], range=(0.0, 120.0))
  debug_inspect(bands.apply("b"), content="Some(40)")
  debug_inspect(bands.apply("z"), content="None")
  inspect(bands.step(), content="40")
  inspect(bands.bandwidth(), content="40")
  // Points: bands of no width, the outer ones on the ends of the range.
  let points = @d3.BandScale::new(
    domain=["a", "b", "a", "c"],
    range=(10.0, 110.0),
    padding_inner=1.0,
  )
  debug_inspect(points.apply("a"), content="Some(10)")
  debug_inspect(points.apply("b"), content="Some(60)")
  debug_inspect(points.apply("c"), content="Some(110)")
  inspect(points.bandwidth(), content="0")
  // A single value sits in the middle; a descending range turns around.
  let single = @d3.BandScale::new(
    domain=["only"],
    range=(0.0, 100.0),
    padding_inner=1.0,
  )
  debug_inspect(single.apply("only"), content="Some(50)")
  let reversed = @d3.BandScale::new(domain=["a", "b"], range=(100.0, 0.0))
  debug_inspect(reversed.apply("a"), content="Some(50)")
  debug_inspect(reversed.apply("b"), content="Some(0)")
}

///|
test "line generator" {
  debug_inspect(@d3.line([]), content="None")
  debug_inspect(@d3.line([(1.0, 2.0)]), content="Some(\"M1,2Z\")")
  debug_inspect(
    @d3.line([(99.71875190734863, 400.7142857142857), (152.7443, 342.4286)]),
    content="Some(\"M99.719,400.714L152.744,342.429\")",
  )
  debug_inspect(
    @d3.line([(1.0, @double.not_a_number), (2.0, 3.0)]),
    content="Some(\"M1,NaNL2,3\")",
  )
}
