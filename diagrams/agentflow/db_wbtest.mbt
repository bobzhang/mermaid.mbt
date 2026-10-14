///|
test "the three edge operators" {
  json_inspect(destruct_link("-->"), content={
    "type": "arrow_point",
    "stroke": "normal",
    "length": 1,
  })
  json_inspect(destruct_link("--x"), content={
    "type": "arrow_cross",
    "stroke": "normal",
    "length": 1,
  })
  json_inspect(destruct_link("-.-"), content={
    "type": "arrow_open",
    "stroke": "dotted",
    "length": 1,
  })
  json_inspect(destruct_link("-->", start="--"), content={
    "type": "arrow_point",
    "stroke": "normal",
    "length": 1,
  })
}

///|
test "node kinds and container slots" {
  inspect(vertex_kind(Some("subroutine")), content="tool")
  inspect(vertex_kind(Some("lean_right")), content="input")
  inspect(vertex_kind(Some("lin-doc")), content="refdoc")
  inspect(vertex_kind(Some("fr-rect")), content="task")
  inspect(vertex_kind(None), content="task")
  inspect(normalise_shape("cylinder"), content="roundedRect")
  inspect(normalise_shape("hex"), content="hex")
  // Twelve colours: containers cycle the five above the kinds.
  json_inspect([0, 4, 5].map(n => container_slot(n, 12)), content=[7, 11, 7])
  // A palette shorter than the kinds still paints containers.
  json_inspect([0, 1].map(n => container_slot(n, 3)), content=[1, 1])
}
