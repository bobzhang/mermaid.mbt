///|
test "sankey: columns, values and link ends of a small graph" {
  // a -> b -> d, a -> c -> d
  let graph = @d3.sankey(
    4,
    [(0, 1, 10.0), (0, 2, 5.0), (1, 3, 7.0), (2, 3, 5.0)],
    node_width=10.0,
    node_padding=27.0,
    extent=(0.0, 0.0, 600.0, 400.0),
  )
  json_inspect(
    graph.nodes.map(node => (node.layer, node.value, node.x0, node.y0, node.y1)),
    content=[
      [0, 15, 0, 8.543975101516265, 381.54397510151625],
      [1, 10, 295, 0, 248.66666666666669],
      [1, 5, 295, 275.6666666666667, 400],
      [2, 12, 590, 42.17159366662946, 340.57159366662944],
    ],
  )
  inspect(
    graph.link_horizontal(graph.links[2]),
    content="M305,87.03333333333333C447.5,87.03333333333333,447.5,129.2049269999628,590,129.2049269999628",
  )
}

///|
test "sankey: alignments choose the column of loose ends" {
  // a -> b -> c, d -> c: where does d go, and e, which ends early?
  let links = [(0, 1, 1.0), (1, 2, 1.0), (3, 2, 1.0), (0, 4, 1.0)]
  let layers = (align : @d3.SankeyAlign) => {
    @d3.sankey(5, links, align~).nodes.map(node => node.layer)
  }
  json_inspect(layers(Justify), content=[0, 1, 2, 0, 2])
  json_inspect(layers(Left), content=[0, 1, 2, 0, 1])
  json_inspect(layers(Right), content=[0, 1, 2, 1, 2])
  json_inspect(layers(Center), content=[0, 1, 2, 1, 1])
}

///|
test "sankey: a cycle is refused" {
  let refused = try {
    @d3.sankey(2, [(0, 1, 1.0), (1, 0, 1.0)]) |> ignore
    false
  } catch {
    @d3.CircularLink => true
  }
  inspect(refused, content="true")
}

///|
test "js_sort is stable and treats NaN as equal" {
  let items = [(3.0, "a"), (1.0, "b"), (3.0, "c"), (2.0, "d"), (1.0, "e")]
  @d3.js_sort(items, (a, b) => a.0 - b.0)
  json_inspect(items.map(item => item.1), content=["b", "e", "d", "a", "c"])
  let descending = [5.0, 4.0, 3.0, 9.0, 1.0]
  @d3.js_sort(descending, (a, b) => a - b)
  json_inspect(descending, content=[1, 3, 4, 5, 9])
  let unordered = [2.0, 1.0, 3.0]
  @d3.js_sort(unordered, (_, _) => 0.0 / 0.0)
  json_inspect(unordered, content=[2, 1, 3])
}

///|
test "ordinal scale: keys take the range in order of first use, cycling" {
  let scale = @d3.Ordinal::new(["x", "y", "z"])
  json_inspect(["a", "b", "a", "c", "d", "b"].map(key => scale.get(key)), content=[
    "x", "y", "x", "z", "x", "y",
  ])
  let fixed = @d3.Ordinal::with_domain(["b", "a", "b"], [1, 2])
  json_inspect(["a", "b", "c"].map(key => fixed.get(key)), content=[2, 1, 1])
}
