///|
fn parse(source : String) -> @classdiagram.ClassDb raise {
  @classdiagram.parse(
    source + "\n",
    @config.Config::new(diagram_type="classDiagram"),
  )
}

///|
test "members: visibility, classifiers and generic types" {
  let db = parse(
    (
      #|classDiagram
      #|    class Account~T~ {
      #|      +String owner
      #|      -List~int~ history$
      #|      +deposit(amount) bool
      #|      #audit(Map~K, V~ m) List~T~*
      #|      total()$
      #|    }
      #|    Account : +int id
    ),
  )
  let account = db.classes["Account"]
  inspect(account.type_, content="T")
  // The title carries the generic type as entities.
  inspect(account.text, content="Account&lt;T&gt;")
  inspect(account.dom_id, content="classId-Account-0")
  // A visibility marker is escaped for the markdown the box is drawn from.
  json_inspect(
    account.members.map(m => (m.visibility, m.id, m.classifier, m.text)),
    content=[
      ["+", "String owner", "", "\\+String owner"],
      ["-", "List~int~ history", "$", "\\-List&lt;int&gt; history"],
      ["+", "int id", "", "\\+int id"],
    ],
  )
  json_inspect(
    account.methods.map(m => {
      (m.visibility, m.id, m.parameters, m.return_type, m.classifier, m.text)
    }),
    content=[
      ["+", "deposit", "amount", "bool", "", "\\+deposit(amount) : bool"],
      [
        "#", "audit", "Map~K, V~ m", "List~T~", "*", "\\#audit(Map&lt;K, V&gt; m) : List&lt;T&gt;",
      ],
      ["", "total", "", "", "$", "total()"],
    ],
  )
  json_inspect(account.methods.map(m => m.css_style()), content=[
    "", "font-style:italic;", "text-decoration:underline;",
  ])
}

///|
test "relations: ends, line types and titles" {
  let db = parse(
    (
      #|classDiagram
      #|    A <|-- B : extends
      #|    C "1" *.. "many" D
      #|    E --() F
    ),
  )
  json_inspect(
    db.relations.map(r => {
      (r.id1, r.type1, r.dotted, r.type2, r.id2, r.title1, r.title2, r.title)
    }),
    content=[
      ["A", [1], false, null, "B", "none", "none", ["extends"]],
      ["C", [2], true, null, "D", "1", "many", null],
      ["E", null, false, [4], "interface0", "none", "none", null],
    ],
  )
  json_inspect(db.interfaces.map(i => (i.id, i.label, i.class_id)), content=[
    ["interface0", "F", "E"],
  ])
  inspect(db.classes.contains("F"), content="false")
}

///|
test "namespaces, notes and annotations" {
  let db = parse(
    (
      #|classDiagram
      #|    namespace Company.Engineering["Engineers"] {
      #|        class Developer
      #|        note "inside"
      #|    }
      #|    class Shape
      #|    <<interface>> Shape
      #|    note for Shape "about shapes"
    ),
  )
  // A dotted name declares its ancestors, which the source did not write.
  let namespaces : Array[@classdiagram.Namespace] = db.namespaces
    .values()
    .collect()
  json_inspect(namespaces.map(n => (n.id, n.label, n.parent, n.explicit)), content=[
    ["Company", "Company", null, false],
    ["Company.Engineering", "Engineers", ["Company"], true],
  ])
  json_inspect(db.classes["Developer"].parent, content=["Company.Engineering"])
  json_inspect(db.classes["Shape"].annotations, content=["interface"])
  let notes : Array[@classdiagram.ClassNote] = db.notes.values().collect()
  json_inspect(notes.map(n => (n.id, n.class_, n.text, n.parent)), content=[
    ["note0", null, "inside", ["Company.Engineering"]],
    ["note1", ["Shape"], "about shapes", null],
  ])
}

///|
test "styles reach the classes that carry the name when it is defined" {
  let db = parse(
    (
      #|classDiagram
      #|    class A:::warm
      #|    class B
      #|    classDef warm fill:#f96,color:red
      #|    cssClass "B" warm
      #|    style B stroke:#333,stroke-width:4px
    ),
  )
  inspect(db.classes["A"].css_classes, content="default warm")
  json_inspect(db.classes["A"].styles, content=["fill:#f96", "color:red"])
  // `B` took the name after the definition, and gets none of its styles.
  inspect(db.classes["B"].css_classes, content="default warm")
  json_inspect(db.classes["B"].styles, content=[
    "stroke:#333", "stroke-width:4px",
  ])
}
