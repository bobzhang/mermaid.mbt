///|
fn parsed(source : String) -> BlockDb raise {
  parse(source + "\n", @config.Config::new(diagram_type="block"))
}

///|
/// The blocks of a level as `id:type:label`, composites with what is
/// inside them.
fn outline(blocks : Array[Block]) -> Array[String] {
  blocks.map(block => {
    let text = "\{block.id_text()}:\{block.type_.unwrap_or("undefined")}:\{block.label.unwrap_or("undefined")}"
    if block.children.is_empty() {
      text
    } else {
      "\{text}[\{outline(block.children).join(" ")}]"
    }
  })
}

///|
test "blocks, shapes and composites" {
  let db = parsed(
    (
      #|block-beta
      #|  columns 3
      #|  a["A label"] b("round"):2 c{{"hex"}}
      #|  block:group:2
      #|    columns 1
      #|    d e<["arrow"]>(right, x)
      #|  end
      #|  block
      #|    f
      #|  end
    ),
  )
  json_inspect(outline(db.root.children), content=[
    "a:square:A label", "b:round:round", "c:hexagon:hex", "group:composite:[d:na:d e:block_arrow:arrow]",
    "id-i-2:composite:[f:na:f]",
  ])
  inspect(db.root.columns.unwrap_or(0.0), content="3")
  inspect(db.blocks[Some("b")].width_in_columns.unwrap_or(0.0), content="2")
  inspect(db.blocks[Some("group")].columns.unwrap_or(0.0), content="1")
  json_inspect(db.blocks[Some("e")].directions.unwrap_or([]), content=[
    "right", "x",
  ])
  // Composites take palette slots in the order they are declared.
  inspect(db.blocks[Some("group")].color_index.unwrap_or(-1), content="0")
  inspect(db.blocks[Some("id-i-2")].color_index.unwrap_or(-1), content="1")
}

///|
test "spaces are one block per column, named after a generated id" {
  let db = parsed(
    (
      #|block-beta
      #|  a space:2 b space
    ),
  )
  json_inspect(db.root.children.map(block => block.id_text()), content=[
    "a", "id-i-1-0", "id-i-1-1", "b", "id-i-2-0",
  ])
}

///|
test "edges" {
  let db = parsed(
    (
      #|block-beta
      #|  a b c
      #|  a --> b
      #|  a --> b
      #|  b -- "label" --x c
      #|  c <-.-> a
      #|  a ==o c
    ),
  )
  json_inspect(
    db.edges.map(edge => {
      [
        edge.id_text(),
        edge.label.unwrap_or(""),
        edge.arrow_type_start,
        edge.arrow_type_end,
        edge.thickness,
        edge.pattern,
      ]
    }),
    content=[
      ["1-a-b", "", "arrow_open", "arrow_point", "normal", "solid"],
      ["2-a-b", "", "arrow_open", "arrow_point", "normal", "solid"],
      ["1-b-c", "label", "arrow_open", "arrow_cross", "normal", "solid"],
      ["1-c-a", "", "arrow_point", "arrow_point", "normal", "dotted"],
      ["1-a-c", "", "arrow_open", "arrow_circle", "thick", "solid"],
    ],
  )
}

///|
test "a chain of links keeps its last block only" {
  // The left side of the second link is the three statements of the
  // first, an array without an id.
  let db = parsed(
    (
      #|block-beta
      #|  a --> b --> c
    ),
  )
  json_inspect(outline(db.root.children), content=[
    "undefined:undefined:undefined", "c:na:c",
  ])
  json_inspect(
    db.edges.map(edge => {
      [
        edge.id_text(),
        edge.start.unwrap_or("undefined"),
        edge.end.unwrap_or("undefined"),
      ]
    }),
    content=[["1-undefined-c", "undefined", "c"]],
  )
}

///|
test "classes and styles" {
  let db = parsed(
    (
      #|block-beta
      #|  a b c
      #|  classDef hot fill:#f96,color:#fff;
      #|  class a, c hot
      #|  style b fill:#eee,stroke-width:2px
    ),
  )
  json_inspect(db.classes["hot"].styles, content=["fill:#f96", "color:#fff"])
  json_inspect(db.classes["hot"].text_styles, content=["fill:#fff"])
  json_inspect(db.blocks[Some("a")].classes, content=["hot"])
  // A name after a space is not found as written, and becomes a block of
  // its own in the database: the one that is drawn stays without class.
  json_inspect(db.root.children[2].classes, content=[])
  json_inspect(db.blocks[Some("c")].classes, content=["hot"])
  json_inspect(db.blocks[Some("b")].styles, content=[
    "fill:#eee", "stroke-width:2px",
  ])
}

///|
test "styling a block that is not there fails" {
  let source =
    #|block-beta
    #|  a
    #|  style b fill:#eee
  try parsed(source) catch {
    BlockError(message) =>
      inspect(
        message,
        content="Cannot set properties of undefined (setting 'styles')",
      )
    _ => fail("expected a BlockError")
  } noraise {
    _ => fail("expected the style statement to fail")
  }
}

///|
test "positions in the grid" {
  let at = (columns : Double, position : Double) => {
    let (px, py) = try! block_position(columns, position)
    [px, py]
  }
  json_inspect(at(2.0, 0.0), content=[0, 0])
  json_inspect(at(2.0, 1.0), content=[1, 0])
  json_inspect(at(2.0, 2.0), content=[0, 1])
  json_inspect(at(2.0, 3.0), content=[1, 1])
  json_inspect(at(2.0, 4.0), content=[0, 2])
  json_inspect(at(1.0, 3.0), content=[0, 3])
  // Without columns everything is in one row.
  json_inspect(at(-1.0, 3.0), content=[3, 0])
  try block_position(0.0, 1.0) catch {
    BlockError(message) =>
      inspect(message, content="Columns must be an integer !== 0.")
  } noraise {
    _ => fail("expected no position without columns")
  }
}

///|
test "layout of a grid with a span" {
  let db = parsed(
    (
      #|block-beta
      #|  columns 2
      #|  a:2
      #|  b c
    ),
  )
  // As measured: `a` is the widest per column.
  let sizes = [(100.0, 40.0), (30.0, 20.0), (50.0, 30.0)]
  for i, block in db.root.children {
    block.size = Some({ width: sizes[i].0, height: sizes[i].1, x: 0.0, y: 0.0, })
  }
  let bounds = db.layout()
  json_inspect(
    db.root.children.map(block => {
      guard block.size is Some(size) else { return [] }
      [size.x, size.y, size.width, size.height]
    }),
    content=[[54, -24, 108, 40], [25, 24, 50, 40], [83, 24, 50, 40]],
  )
  json_inspect([bounds.x, bounds.y, bounds.width, bounds.height], content=[
    0, -44, 108, 88,
  ])
}

///|
test "JSON text" {
  inspect(
    json_string("a\"b\\c\n\u{1}é"),
    content="\"a\\\"b\\\\c\\n\\u0001é\"",
  )
  inspect(json_number(@double.not_a_number), content="null")
  inspect(point_json({ x: 1.5, y: -0.0, }), content="{\"x\":1.5,\"y\":0}")
}
