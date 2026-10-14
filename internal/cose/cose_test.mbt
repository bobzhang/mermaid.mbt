///|
/// The centres as nested arrays, to be shown in full precision.
fn centres(
  sizes : Array[(Double, Double)],
  edges : Array[(Int32, Int32)],
) -> Array[Array[Double]] raise {
  @cose.layout(sizes, edges).map(centre => [centre.0, centre.1])
}

///|
test "a node alone goes to the margin" {
  json_inspect(centres([(100.0, 34.0)], []), content=[[65, 32]])
}

///|
test "the mindmap of mermaid's documentation, as Chrome lays it out" {
  // Sizes and positions captured from mermaid in Chrome
  // (scripts/cose_corpus.py).
  let sizes = [
    (90.33100128173828, 90.33100128173828),
    (89.375, 34.0),
    (127.109375, 34.0),
    (141.4375, 34.0),
    (240.0, 58.0),
    (103.890625, 34.0),
    (159.4375, 58.0),
    (201.421875, 34.0),
    (72.0625, 34.0),
    (183.109375, 34.0),
    (169.9375, 34.0),
    (175.203125, 34.0),
    (75.671875, 34.0),
    (142.53125, 34.0),
    (101.46875, 34.0),
  ]
  let edges = [
    (0, 1),
    (1, 2),
    (1, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (5, 7),
    (7, 8),
    (8, 9),
    (8, 10),
    (8, 11),
    (0, 12),
    (12, 13),
    (12, 14),
  ]
  json_inspect(centres(sizes, edges), content=[
    [434.1111966295256, 396.38156788722836],
    [436.4941812815458, 512.4266187214738],
    [582.915018315541, 564.1667713354715],
    [381.5602598550232, 593.367738748033],
    [407.9041414764539, 691.2159385026742],
    [367.05603035046204, 283.22229630374113],
    [182.96072881076543, 313.1089467447921],
    [333.4828530079957, 198.31293963808537],
    [290.02781496262503, 112.99912684696073],
    [106.5546875, 94.51650763422924],
    [240.55515099468857, 32.0],
    [462.7269991455861, 77.96920980383072],
    [571.3769451839938, 412.0403345711526],
    [682.5407176512873, 352.2836256947978],
    [676.8147357926485, 473.85697144725714],
  ])
}

///|
test "a graph with a cycle is not covered" {
  let sizes = [(10.0, 10.0), (10.0, 10.0), (10.0, 10.0)]
  try @cose.layout(sizes, [(0, 1), (1, 2), (2, 0)]) catch {
    Unsupported(message) =>
      inspect(message, content="cose-bilkent: a graph with a cycle")
  } noraise {
    _ => fail("expected the layout to refuse")
  }
}

///|
test "cytoscape's straight edge between two default nodes" {
  let points = @cose.straight_edge(
    (434.1111966295256, 396.38156788722836),
    (436.4941812815458, 512.4266187214738),
  )
  json_inspect(points.unwrap().map(point => [point.0, point.1]), content=[
    [434.41915664480007, 411.3784062416613],
    [435.3026889555357, 454.4040933043511],
    [436.18622126627133, 497.42978036704085],
  ])
  // Nodes closer than their radii have no edge points.
  inspect(@cose.straight_edge((0.0, 0.0), (3.0, 4.0)) is None, content="true")
}
