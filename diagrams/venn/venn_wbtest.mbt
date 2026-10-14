///|
test "the keys of an object: array indices first, in numeric order" {
  let dict : Dict[Int32] = Dict::new()
  for key in ["b", "10", "a", "9", "01", "4294967295", "0", "b"] {
    dict.set(key, 0)
  }
  json_inspect(dict.keys(), content=[
    "0", "9", "10", "b", "a", "01", "4294967295",
  ])
}

///|
test "Math.max and Math.min tell the zeros apart" {
  inspect(1.0 / js_max(0.0, -0.0), content="Infinity")
  inspect(1.0 / js_max(-0.0, -0.0), content="-Infinity")
  inspect(1.0 / js_min(0.0, -0.0), content="-Infinity")
  inspect(js_max(1.0, @double.not_a_number).is_nan(), content="true")
}

///|
test "the random numbers of the reference page" {
  // mulberry32 from seed 0, as `testdata/venn/oracle-prelude.js` installs
  // it for `Math.random()`.
  let random = Random::new()
  json_inspect([random.next(), random.next(), random.next()], content=[
    0.26642920868471265, 0.0003297457005828619, 0.2232720274478197,
  ])
}

///|
test "two equal sets sharing a quarter: the layout of the documentation" {
  let areas : Array[Area] = [
    { sets: ["A"], size: 10.0, label: None, },
    { sets: ["B"], size: 10.0, label: None, },
    { sets: ["A", "B"], size: 2.5, label: Some("AB"), },
  ]
  let solution = solve(areas, 800.0, 426.0, 15.0, Random::new())
  let a = circle_of(solution.circles, "A")
  let b = circle_of(solution.circles, "B")
  // What the reference browser draws: `M 274.32849039325265 213 m -198 0`.
  json_inspect([a.x, a.y, a.radius, b.x, b.y, b.radius], content=[
    274.32849039325265, 213, 198, 525.6715096067473, 213, 198,
  ])
  inspect(
    intersection_area_path([a, b]),
    content=(
      #|
      #|M 400 366.0054628866604 
      #|A 198 198 0 0 1 400 59.99453711333962 
      #|A 198 198 0 0 1 400 366.0054628866604
    ),
  )
}
