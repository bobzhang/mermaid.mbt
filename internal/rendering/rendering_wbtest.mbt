///|
test "rounded corners" {
  let points = [
    { x: 114.0, y: 57.0, },
    { x: 114.0, y: 77.0, },
    { x: 88.0, y: 77.0, },
    { x: 88.0, y: 97.0, },
  ]
  inspect(
    rounded_path(points, 5.0),
    content="M114,57L114,69.92893218813452Q114,77 106.92893218813452,77L95.07106781186548,77Q88,77 88,84.07106781186548L88,97",
  )
  // Straight runs and repeated points get no curve.
  inspect(
    rounded_path(
      [{ x: 0.0, y: 0.0, }, { x: 10.0, y: 0.0, }, { x: 20.0, y: 0.0, }],
      5.0,
    ),
    content="M0,0L10,0L20,0",
  )
}

///|
test "route attribute" {
  let points = [{ x: 88.0, y: 57.0, }, { x: 88.0, y: 97.0, }]
  inspect(
    points_json(points),
    content="[{\"x\":88,\"y\":57},{\"x\":88,\"y\":97}]",
  )
  inspect(
    base64(points_json(points)),
    content="W3sieCI6ODgsInkiOjU3fSx7IngiOjg4LCJ5Ijo5N31d",
  )
  inspect(base64("a"), content="YQ==")
  inspect(base64("ab"), content="YWI=")
}

///|
test "dash pattern of dotted edges" {
  inspect(dash_array(22.0, 0.0, 4.0), content="0 0 2 2 2 2 2 2 2 2 4")
  inspect(dash_array(3.0, 0.0, 4.0), content="0 0  4")
}

///|
test "clipping against a rectangle" {
  let bounds : Bounds = { x: 100.0, y: 50.0, width: 40.0, height: 20.0, }
  debug_inspect(
    intersect_rect(100.0, 50.0, 40.0, 20.0, { x: 100.0, y: 200.0, }),
    content="{ x: 100, y: 60 }",
  )
  debug_inspect(
    box_intersection(bounds, { x: 200.0, y: 50.0, }, { x: 100.0, y: 50.0, }),
    content="{ x: 120, y: 50 }",
  )
  inspect(on_border(bounds, { x: 120.0, y: 55.0, }), content="true")
  inspect(outside_node(bounds, { x: 119.0, y: 55.0, }), content="false")
}

///|
test "terminal jogs are straightened" {
  let points = [
    { x: 0.0, y: 0.0, },
    { x: 0.0, y: 10.0, },
    { x: 6.0, y: 10.0, },
    { x: 6.0, y: 60.0, },
    { x: 80.0, y: 60.0, },
    { x: 80.0, y: 100.0, },
  ]
  guard straighten_terminal_jogs(points) is Some((moved, runs)) else {
    fail("expected the jog to be straightened")
  }
  debug_inspect(
    moved,
    content="[{ x: 0, y: 0 }, { x: 0, y: 60 }, { x: 80, y: 60 }, { x: 80, y: 100 }]",
  )
  inspect(runs.length(), content="1")
}

///|
test "line breaks in edge labels" {
  inspect(normalize_breaks("a<br>b<BR/>c<br />d"), content="a\nb\nc\nd")
  inspect(non_markdown_to_html("a\nb"), content="<p>a<br />b</p>")
  inspect(non_markdown_to_html(""), content="")
}

///|
test "icons in labels" {
  inspect(
    replace_icons("<p>fa:fa-car Car and fab:fa-github</p>"),
    content="<p><i class='fa fa-car'></i> Car and <i class='fab fa-github'></i></p>",
  )
  inspect(replace_icons("sofa: fa-x"), content="sofa: fa-x")
  inspect(collapse_spaces("  a   b \n"), content="a b")
}
