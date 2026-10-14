///|
fn parse(source : String) -> @er.ErDb raise {
  @er.parse(source + "\n", @config.Config::new(diagram_type="er"))
}

///|
test "entities, attributes and relationships" {
  let db = parse(
    (
      #|erDiagram
      #|    CUSTOMER ||--o{ ORDER : places
      #|    ORDER {
      #|        int id PK, FK "the key"
      #|        string? note
      #|    }
      #|    p[Person]:::big
      #|    p }|..|| CUSTOMER : "is a"
    ),
  )
  // Ids number the entities in the order they are first mentioned.
  json_inspect(db.entities.values().map(entity => entity.id).collect(), content=[
    "entity-CUSTOMER-0", "entity-ORDER-1", "entity-p-2",
  ])
  let order = db.entities["ORDER"]
  json_inspect(
    order.attributes.map(a => (a.type_, a.name, a.keys, a.comment)),
    content=[
      ["int", "id", ["PK", "FK"], "the key"],
      ["string?", "note", [], ""],
    ],
  )
  inspect(db.entities["p"].alias_name, content="Person")
  inspect(db.entities["p"].css_classes, content="default big")
  // The cardinality next to the first entity is `card_b`.
  json_inspect(
    db.relationships.map(r => {
      (r.entity_a, r.card_b, r.rel_type, r.card_a, r.entity_b, r.role_a)
    }),
    content=[
      [
        "entity-CUSTOMER-0", "ONLY_ONE", "IDENTIFYING", "ZERO_OR_MORE", "entity-ORDER-1",
        "places",
      ],
      [
        "entity-p-2", "ONE_OR_MORE", "NON_IDENTIFYING", "ONLY_ONE", "entity-CUSTOMER-0",
        "is a",
      ],
    ],
  )
}

///|
test "cardinality words" {
  let db = parse(
    (
      #|erDiagram
      #|    A one or zero to many(1) B : x
      #|    C 1+ optionally to 0+ D : y
      #|    E only one to zero or many F : z
      #|    G u--|| H : parent
    ),
  )
  json_inspect(db.relationships.map(r => (r.card_b, r.rel_type, r.card_a)), content=[
    ["ZERO_OR_ONE", "IDENTIFYING", "ONE_OR_MORE"],
    ["ONE_OR_MORE", "NON_IDENTIFYING", "ZERO_OR_MORE"],
    ["ONLY_ONE", "IDENTIFYING", "ZERO_OR_MORE"],
    ["MD_PARENT", "IDENTIFYING", "ONLY_ONE"],
  ])
}

///|
test "styles, classes, direction and subgraphs" {
  let db = parse(
    (
      #|erDiagram
      #|    direction LR
      #|    accTitle: A title
      #|    subgraph g1 [The group]
      #|        direction TB
      #|        A
      #|        B
      #|    end
      #|    subgraph g2
      #|        B
      #|        C
      #|    end
      #|    A ||--|| g2 : into
      #|    classDef hot fill:#f96,color:red
      #|    class A,g1 hot
      #|    style B stroke:#333,stroke-width:4px
    ),
  )
  inspect(db.direction(), content="LR")
  inspect(db.acc_title, content="A title")
  // An entity stays in the first subgraph that lists it.
  json_inspect(
    db.sub_graphs.map(g => (g.id, g.title, g.nodes, g.dir, g.classes)),
    content=[
      ["g1", "The group", ["A", "B"], ["TB"], ["hot"]],
      ["g2", "g2", ["C"], null, []],
    ],
  )
  // A relationship can end at a subgraph, by its own id.
  inspect(db.relationships[0].entity_b, content="g2")
  let hot = db.classes["hot"]
  json_inspect((hot.styles, hot.text_styles), content=[
    ["fill:#f96", "color:red"],
    ["color:red"],
  ])
  inspect(db.entities["A"].css_classes, content="default hot")
  json_inspect(db.entities["B"].css_styles, content=[
    "stroke:#333", "stroke-width:4px",
  ])
}

///|
test "characters no rule names are tokens of their own" {
  let message = try parse("erDiagram\n    A ||--o{ B : has }") catch {
    @jison.ParseError(message~, ..) => message
    _ => ""
  } noraise {
    _ => ""
  }
  inspect(message.has_suffix("got '}'"), content="true")
}
