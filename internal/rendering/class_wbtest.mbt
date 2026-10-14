///|
test "addresses the sanitizer keeps on a link" {
  inspect(allowed_uri("https://example.com/a?b=1"), content="true")
  inspect(allowed_uri("mailto:someone@example.com"), content="true")
  // Relative addresses have no scheme.
  inspect(allowed_uri("/docs/page.html"), content="true")
  inspect(allowed_uri("page.html#top"), content="true")
  inspect(allowed_uri("#anchor"), content="true")
  // Any other scheme goes, however it is spaced or cased.
  inspect(allowed_uri("about:blank"), content="false")
  inspect(allowed_uri("JavaScript:alert(1)"), content="false")
  inspect(allowed_uri("java\tscript:alert(1)"), content="false")
  inspect(allowed_uri("data:text/html,x"), content="false")
  inspect(allowed_uri(""), content="false")
}

///|
test "the text colour of a class style, as a fill" {
  inspect(
    style_color("fill:#f9f;color:#00f;stroke:#333").unwrap_or("none"),
    content="fill:#00f",
  )
  // The first `color` followed by a colon counts, wherever it stands.
  inspect(
    style_color("background-color : red;color:blue").unwrap_or("none"),
    content="fill : red",
  )
  inspect(
    style_color("fill:#f9f;stroke:#333").unwrap_or("none"),
    content="none",
  )
}

///|
test "markers of a class relation" {
  let defs = @dom.Element::new("g")
  inspect(
    insert_class_marker(defs, "extension", "classDiagram", "id"),
    content="true",
  )
  inspect(
    insert_class_marker(defs, "point", "classDiagram", "id"),
    content="false",
  )
  // The start marker of the neo look is the one upstream leaves outside
  // a `<defs>`, and its styles, set through the CSSOM, come last.
  inspect(
    defs.child_elements()[2].to_html(),
    content=(
      #|<marker id="id_classDiagram-extensionStart-margin" class="marker extension classDiagram" refX="18" refY="7" markerWidth="20" markerHeight="28" orient="auto" markerUnits="userSpaceOnUse" viewBox="0 0 20 14"><polygon points="10,7 18,13 18,1" style="stroke-width: 2; stroke-dasharray: 0;"></polygon></marker>
    ),
  )
}

///|
/// An edge along `points` with one placed terminal label.
fn edge_with_terminal(
  id : String,
  points : Array[Point],
  key : String,
  centre : Point,
) -> Edge {
  let edge = Edge::new(id~, start="a", end="b", look="neo")
  edge.points = points
  edge.terminals.push({
    key,
    text: "1",
    element: @dom.Element::new("g"),
    width: 10.0,
    height: 10.0,
    centre: Some(centre),
    port: None,
  })
  edge
}

///|
test "a terminal label goes to its own side of the edge" {
  // The edge runs down; its right, seen along the direction of travel, is
  // the side of smaller x.
  let down = [{ x: 100.0, y: 0.0, }, { x: 100.0, y: 80.0, }]
  let right = edge_with_terminal("e1", down, "startRight", {
    x: 110.0,
    y: 10.0,
  })
  put_terminal_labels_on_their_side([right], [])
  debug_inspect(right.terminals[0].centre, content="Some({ x: 90, y: 10 })")
  // A label already on its side stays.
  let left = edge_with_terminal("e2", down, "endLeft", { x: 110.0, y: 70.0, })
  put_terminal_labels_on_their_side([left], [])
  debug_inspect(left.terminals[0].centre, content="Some({ x: 110, y: 70 })")
  // The mirrored spot must be free: here another edge runs through it.
  let blocked = edge_with_terminal("e3", down, "startRight", {
    x: 110.0,
    y: 10.0,
  })
  let other = Edge::new(id="e4", start="c", end="d", look="neo")
  other.points = [{ x: 90.0, y: 0.0, }, { x: 90.0, y: 80.0, }]
  put_terminal_labels_on_their_side([blocked, other], [])
  debug_inspect(blocked.terminals[0].centre, content="Some({ x: 110, y: 10 })")
}

///|
test "a terminal label across the frame of a group slides along its edge" {
  let frame = Node::new(
    id="group",
    label="",
    padding=0.0,
    look="neo",
    shape="rect",
    is_group=true,
  )
  frame.x = 100.0
  frame.y = 150.0
  frame.width = Some(200.0)
  frame.height = Some(100.0)
  // The edge enters the group from above; its end label straddles the top
  // of the frame at y = 100.
  let edge = edge_with_terminal(
    "e1",
    [{ x: 100.0, y: 0.0, }, { x: 100.0, y: 140.0, }],
    "endLeft",
    { x: 110.0, y: 100.0, },
  )
  slide_terminal_labels_off_frames([edge], [frame])
  // The nearest spot that clears the frame by two pixels, towards the end.
  debug_inspect(edge.terminals[0].centre, content="Some({ x: 110, y: 108 })")
}
