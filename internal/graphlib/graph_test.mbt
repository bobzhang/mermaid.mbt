///|
fn new_graph(
  directed~ : Bool = true,
  compound~ : Bool = false,
  multigraph~ : Bool = false,
) -> @graphlib.Graph[Unit, Int32, String] {
  @graphlib.Graph::new(
    (),
    default_node=_ => 0,
    directed~,
    compound~,
    multigraph~,
  )
}

///|
test "nodes are listed as the keys of a JavaScript object" {
  let g = new_graph()
  for v in ["b", "10", "a", "2", "01", "4294967295", "4294967294", "-1"] {
    g.set_node(v, 1)
  }
  json_inspect(g.nodes(), content=[
    "2", "10", "4294967294", "b", "a", "01", "4294967295", "-1",
  ])
  // A node that is removed and added again is the last of its kind.
  g.remove_node("b")
  g.remove_node("2")
  g.set_node("b", 2)
  g.set_node("2", 2)
  json_inspect(g.nodes(), content=[
    "2", "10", "4294967294", "a", "01", "4294967295", "-1", "b",
  ])
}

///|
test "edges keep the order they were added in" {
  let g = new_graph(multigraph=true)
  g.set_edge("a", "b", "first", name="x")
  g.set_edge("c", "b", "second")
  g.set_edge("a", "b", "third", name="y")
  json_inspect(g.predecessors("b"), content=["a", "c"])
  g.remove_edge_between("a", "b", name="x")
  // Another edge from `a` is left, so it keeps its place.
  json_inspect(g.predecessors("b"), content=["a", "c"])
  g.remove_edge_between("a", "b", name="y")
  g.set_edge("a", "b", "again", name="x")
  json_inspect(g.predecessors("b"), content=["c", "a"])
  json_inspect(g.edges().map(e => g.edge(e)), content=[["second"], ["again"]])
  json_inspect(g.in_edges("b", u="c").length(), content=1)
  json_inspect(g.sources(), content=["a", "c"])
  json_inspect(g.sinks(), content=["b"])
}

///|
test "an undirected graph orders the ends of an edge as JavaScript does" {
  let g = new_graph(directed=false)
  // `_d10` is before `_d9` for JavaScript, after it for MoonBit.
  g.set_edge("_d9", "_d10", "e")
  debug_inspect(
    g.edges(),
    content=(
      #|[{ v: "_d10", w: "_d9", name: None }]
    ),
  )
  json_inspect(g.edge_between("_d10", "_d9"), content=["e"])
  g.set_edge("_d9", "a", "f")
  json_inspect(g.neighbors("_d9"), content=["_d10", "a"])
}

///|
test "children of a removed node move to the top" {
  let g = new_graph(compound=true)
  g.set_node("a", 1)
  g.set_parent("b", parent="p")
  g.set_parent("c", parent="p")
  json_inspect(g.nodes(), content=["a", "p", "b", "c"])
  json_inspect(g.top_children(), content=["a", "p"])
  json_inspect(g.children("p"), content=["b", "c"])
  g.remove_node("p")
  json_inspect(g.top_children(), content=["a", "b", "c"])
  assert_true(g.parent("b") is None)
  try g.set_parent("a", parent="a") catch {
    @graphlib.GraphError(message) =>
      inspect(message, content="Setting a as parent of a would create a cycle")
  } noraise {
    _ => fail("expected a cycle")
  }
}
