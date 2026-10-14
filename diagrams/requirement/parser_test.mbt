///|
fn parse(source : String) -> @requirement.RequirementDb raise {
  @requirement.parse(
    source + "\n",
    @config.Config::new(diagram_type="requirement"),
  )
}

///|
test "requirements, elements and relationships" {
  let db = parse(
    (
      #|requirementDiagram
      #|    functionalRequirement test_req {
      #|    id: 1.1
      #|    text: "the test text."
      #|    risk: high
      #|    verifyMethod: demonstration
      #|    }
      #|    element "test entity" {
      #|    type: word doc
      #|    docRef: reqs/test_entity
      #|    }
      #|    "test entity" - satisfies -> test_req
      #|    test_req <- copies - "test entity"
    ),
  )
  let requirement = db.requirements["test_req"]
  json_inspect(
    (
      requirement.type_,
      requirement.requirement_id,
      requirement.text,
      requirement.risk,
      requirement.verify_method,
    ),
    content=[
      "Functional Requirement", "1.1", "the test text.", "High", "Demonstration",
    ],
  )
  let element = db.elements["test entity"]
  json_inspect((element.type_, element.doc_ref), content=[
    "word doc", "reqs/test_entity",
  ])
  // An arrow pointing left names its source last.
  json_inspect(db.relations.map(r => (r.type_, r.src, r.dst)), content=[
    ["satisfies", "test entity", "test_req"],
    ["copies", "test entity", "test_req"],
  ])
}

///|
test "the first definition and the first field stand" {
  let db = parse(
    (
      #|requirementDiagram
      #|    requirement a {
      #|    id: 1
      #|    id: 2
      #|    }
      #|    requirement a {
      #|    id: 3
      #|    }
    ),
  )
  inspect(db.requirements["a"].requirement_id, content="1")
}

///|
test "classes and styles" {
  let db = parse(
    (
      #|requirementDiagram
      #|    direction LR
      #|    requirement a:::hot {
      #|    id: 1
      #|    }
      #|    element b {
      #|    }
      #|    classDef hot fill:#f96,color:red
      #|    classDef cold stroke:#00f
      #|    class b cold,hot
      #|    style a stroke-width:4px,fill:#fff
    ),
  )
  inspect(db.direction(), content="LR")
  // A class defined after its use still reaches the node, and so do the
  // classes given later, in the order they are given.
  json_inspect(db.requirements["a"].classes, content=["default", "hot"])
  json_inspect(db.requirements["a"].css_styles, content=[
    "fill:#f96", "color:red", "stroke-width:4px", "fill:#fff",
  ])
  json_inspect(db.elements["b"].classes, content=["default", "cold", "hot"])
  json_inspect(db.elements["b"].css_styles, content=[
    "stroke:#00f", "fill:#f96", "color:red",
  ])
  let hot = db.classes["hot"]
  json_inspect((hot.styles, hot.text_styles), content=[
    ["fill:#f96", "color:red"],
    ["color:red"],
  ])
}

///|
test "a body left open is an error" {
  let failed = try
    parse("requirementDiagram\n    requirement a {\n    id: 1")
  catch {
    @jison.ParseError(..) => true
    _ => false
  } noraise {
    _ => false
  }
  inspect(failed, content="true")
}
