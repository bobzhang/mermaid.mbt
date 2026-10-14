///|
fn dump(source : String) -> Json raise {
  @c4.parse(source + "\n", @config.Config::new(diagram_type="c4")).dump()
}

///|
test "elements, boundaries and relationships" {
  let db = dump(
    (
      #|C4Context
      #|title A title
      #|Enterprise_Boundary(b0, "Bank") {
      #|  Person(a, "A", "does things")
      #|  System_Ext(s, "S", $tags="queue")
      #|}
      #|BiRel(a, s, "uses", "HTTP")
    ),
  )
  json_inspect(db, content={
    "shapes": [
      {
        "alias": "a",
        "label": { "text": "A" },
        "descr": { "text": "does things" },
        "typeC4Shape": { "text": "person" },
        "parentBoundary": "b0",
      },
      {
        "alias": "s",
        "label": { "text": "S" },
        "tags": "queue",
        "typeC4Shape": { "text": "external_system" },
        "parentBoundary": "b0",
      },
    ],
    "boundaries": [
      {
        "alias": "global",
        "label": { "text": "global" },
        "type": { "text": "global" },
        "tags": null,
        "link": null,
        "parentBoundary": "",
      },
      {
        "alias": "b0",
        "label": { "text": "Bank" },
        "type": { "text": "ENTERPRISE" },
        "parentBoundary": "global",
      },
    ],
    "rels": [
      {
        "type": "birel",
        "from": "a",
        "to": "s",
        "label": { "text": "uses" },
        "techn": { "text": "HTTP" },
        "descr": { "text": "" },
      },
    ],
    "title": "A title",
    "c4Type": "C4Context",
    "c4ShapeInRow": 4,
    "c4BoundaryInRow": 2,
    "accDescription": "",
  })
}

///|
test "a named attribute sets the field it names, whatever slot it is in" {
  let db = dump(
    (
      #|C4Container
      #|Container(c, "C", $descr="a description")
      #|Rel(c, c, "uses")
      #|UpdateRelStyle(c, c, $offsetY="-40", $lineColor="red")
      #|UpdateElementStyle(c, $fontColor="red")
      #|UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
    ),
  )
  guard db
    is {
      "shapes": [shape],
      "rels": [rel],
      "c4ShapeInRow": Number(shapes, ..),
      "c4BoundaryInRow": Number(boundaries, ..),
      ..
    } else {
    fail("unexpected database")
  }
  json_inspect(shape, content={
    "alias": "c",
    "label": { "text": "C" },
    "descr": { "text": "a description" },
    "typeC4Shape": { "text": "container" },
    "parentBoundary": "global",
    "fontColor": "red",
  })
  json_inspect(rel, content={
    "type": "rel",
    "from": "c",
    "to": "c",
    "label": { "text": "uses" },
    "techn": { "text": "" },
    "descr": { "text": "" },
    // Only the offset slots convert their value; the renderer reads both.
    "offsetY": "-40",
    "lineColor": "red",
  })
  debug_inspect((shapes, boundaries), content="(3, 1)")
}

///|
test "upstream's missing setDirection" {
  // A whole diagram matching the grammar's `direction` rule.
  try dump("C4Context direction TB") catch {
    @c4.C4Error(message) =>
      inspect(message, content="yy.setDirection is not a function")
    _ => fail("expected a C4Error")
  } noraise {
    _ => fail("expected the diagram to be refused")
  }
}
