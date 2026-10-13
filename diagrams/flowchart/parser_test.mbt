// The parser is compared with mermaid's own on every flowchart in upstream's
// documentation by scripts/check_flow_parse.py; these cases pin down a few
// representative databases.

///|
fn parsed(source : String) -> Json raise {
  let config = @config.Config::new(diagram_type="flowchart-v2")
  @flowchart.parse(source + "\n", config).dump()
}

///|
fn summary(source : String) -> String raise {
  guard parsed(source)
    is {
      "vertices": Array(vertices),
      "edges": Array(edges),
      "subGraphs": Array(sub_graphs),
      ..
    } else {
    fail("unexpected dump")
  }
  let text = (value : Json, key : String) => {
    match value {
      Object(fields) =>
        match fields.get(key) {
          Some(String(s)) => s
          Some(Number(n, ..)) => n.to_int().to_string()
          Some(Array(items)) => items.map(item => item.stringify()).join(",")
          _ => "-"
        }
      _ => "-"
    }
  }
  let lines = []
  for vertex in vertices {
    lines.push(
      "node \{text(vertex, "id")} [\{text(vertex, "text")}] \{text(vertex, "type")} \{text(vertex, "domId")}",
    )
  }
  for edge in edges {
    lines.push(
      "edge \{text(edge, "id")} \{text(edge, "type")} \{text(edge, "stroke")} len=\{text(edge, "length")} [\{text(edge, "text")}]",
    )
  }
  for sub_graph in sub_graphs {
    lines.push(
      "subgraph \{text(sub_graph, "id")} [\{text(sub_graph, "title")}] nodes=\{text(sub_graph, "nodes")} dir=\{text(sub_graph, "dir")}",
    )
  }
  lines.join("\n")
}

///|
test "nodes, shapes and labelled links" {
  inspect(
    summary(
      (
        #|flowchart TD
        #|    A[Start] --> B{Is it?}
        #|    B -->|Yes| C(OK)
        #|    B -- No --> D([End])
      ),
    ),
    content=(
      #|node A [Start] square flowchart-A-0
      #|node B [Is it?] diamond flowchart-B-1
      #|node C [OK] round flowchart-C-3
      #|node D [End] stadium flowchart-D-5
      #|edge L_A_B_0 arrow_point normal len=1 []
      #|edge L_B_C_0 arrow_point normal len=1 [Yes]
      #|edge L_B_D_0 arrow_point normal len=1 [No]
    ),
  )
}

///|
test "link kinds and lengths" {
  inspect(
    summary(
      (
        #|flowchart LR
        #|    A --- B
        #|    B --o C
        #|    C x--x D
        #|    D <-.-> E
        #|    E ===> F
        #|    F ~~~ G
        #|    G -..-> H
      ),
    ),
    content=(
      #|node A [A] - flowchart-A-0
      #|node B [B] - flowchart-B-1
      #|node C [C] - flowchart-C-3
      #|node D [D] - flowchart-D-5
      #|node E [E] - flowchart-E-7
      #|node F [F] - flowchart-F-9
      #|node G [G] - flowchart-G-11
      #|node H [H] - flowchart-H-13
      #|edge L_A_B_0 arrow_open normal len=1 []
      #|edge L_B_C_0 arrow_circle normal len=1 []
      #|edge L_C_D_0 double_arrow_cross normal len=1 []
      #|edge L_D_E_0 double_arrow_point dotted len=1 []
      #|edge L_E_F_0 arrow_point thick len=2 []
      #|edge L_F_G_0 arrow_open invisible len=1 []
      #|edge L_G_H_0 arrow_point dotted len=2 []
    ),
  )
}

///|
test "chains, ampersands and repeated links" {
  inspect(
    summary(
      (
        #|flowchart TD
        #|    A & B --> C & D
        #|    C --> D --> E
        #|    A --> C
      ),
    ),
    content=(
      #|node A [A] - flowchart-A-0
      #|node B [B] - flowchart-B-1
      #|node C [C] - flowchart-C-2
      #|node D [D] - flowchart-D-3
      #|node E [E] - flowchart-E-6
      #|edge L_A_C_0 arrow_point normal len=1 []
      #|edge L_A_D_0 arrow_point normal len=1 []
      #|edge L_B_C_0 arrow_point normal len=1 []
      #|edge L_B_D_0 arrow_point normal len=1 []
      #|edge L_C_D_0 arrow_point normal len=1 []
      #|edge L_D_E_0 arrow_point normal len=1 []
      #|edge L_A_C_2 arrow_point normal len=1 []
    ),
  )
}

///|
test "subgraphs" {
  inspect(
    summary(
      (
        #|flowchart LR
        #|    subgraph outer [Outer title]
        #|        direction TB
        #|        subgraph inner
        #|            a --> b
        #|        end
        #|        c
        #|    end
        #|    x --> outer
      ),
    ),
    content=(
      #|node a [a] - flowchart-a-0
      #|node b [b] - flowchart-b-1
      #|node c [c] - flowchart-c-2
      #|node x [x] - flowchart-x-3
      #|node outer [outer] - flowchart-outer-4
      #|edge L_a_b_0 arrow_point normal len=1 []
      #|edge L_x_outer_0 arrow_point normal len=1 []
      #|subgraph inner [inner] nodes="b","a" dir=-
      #|subgraph outer [Outer title] nodes="inner","c" dir=TB
    ),
  )
}

///|
test "styles, classes and shape data" {
  json_inspect(
    parsed(
      (
        #|flowchart TD
        #|    A:::warn --> B@{ shape: diam, label: "Decide" }
        #|    classDef warn fill:#f96,color:#000
        #|    style B stroke:#333,stroke-width:4px
        #|    linkStyle 0 stroke:red
        #|    click A href "https://example.com" _blank
      ),
    ),
    content={
      "vertices": [
        {
          "id": "A",
          "labelType": "text",
          "domId": "flowchart-A-0",
          "styles": [],
          "classes": ["warn", "clickable"],
          "text": "A",
          "link": "https://example.com/",
          "linkTarget": "_blank",
        },
        {
          "id": "B",
          "labelType": "markdown",
          "domId": "flowchart-B-1",
          "styles": ["stroke:#333", "stroke-width:4px"],
          "classes": [],
          "text": "Decide",
          "type": "diam",
        },
      ],
      "edges": [
        {
          "start": "A",
          "end": "B",
          "text": "",
          "labelType": "text",
          "classes": [],
          "isUserDefinedId": false,
          "id": "L_A_B_0",
          "type": "arrow_point",
          "stroke": "normal",
          "length": 1,
          "style": ["stroke:red", "fill:none"],
        },
      ],
      "subGraphs": [],
      "classes": [
        {
          "id": "warn",
          "styles": ["fill:#f96", "color:#000"],
          "textStyles": ["color:#000"],
        },
      ],
      "tooltips": {},
      "accTitle": "",
      "accDescription": "",
      "direction": "TB",
    },
  )
}

///|
test "syntax errors are reported the way jison words them" {
  try parsed("flowchart TD\n    A --> ") catch {
    @jison.ParseError(message~, ..) =>
      inspect(
        message,
        content=(
          #|Parse error on line 3:
          #|...chart TD    A --> 
          #|---------------------^
          #|Expecting 'AMP', 'COLON', 'PIPE', 'TESTSTR', 'DOWN', 'DEFAULT', 'NUM', 'COMMA', 'NODE_STRING', 'BRKT', 'MINUS', 'MULT', 'UNICODE_TEXT', got 'EOF'
        ),
      )
    error => fail("unexpected error \{error}")
  } noraise {
    _ => fail("expected a syntax error")
  }
}
