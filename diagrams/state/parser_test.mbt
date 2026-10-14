// The layout data is compared with mermaid's own on every state diagram in
// upstream's documentation by scripts/check_state_parse.py; these cases pin
// down a few representative ones.

///|
fn summary(source : String) -> String raise {
  let config = @config.Config::new(diagram_type="stateDiagram")
  guard @state.parse("stateDiagram-v2\n" + source + "\n", config).dump()
    is { "nodes": Array(nodes), "edges": Array(edges), .. } else {
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
  for node in nodes {
    lines.push(
      "\{text(node, "shape")} \{text(node, "id")} [\{text(node, "label")}] in \{text(node, "parentId")} \{text(node, "domId")}",
    )
  }
  for edge in edges {
    lines.push(
      "\{text(edge, "start")} --> \{text(edge, "end")} [\{text(edge, "label")}] \{text(edge, "id")}",
    )
  }
  lines.join("\n")
}

///|
test "start and end states are named after their document" {
  inspect(
    summary(
      (
        #|[*] --> Still
        #|Still --> [*] : done
        #|state Still {
        #|  [*] --> a
        #|}
      ),
    ),
    content=(
      #|stateStart root_start [root_start] in - state-root_start-0
      #|roundedWithTitle Still [Still] in - state-Still-2
      #|stateEnd root_end [root_end] in - state-root_end-1
      #|stateStart Still_start [Still_start] in Still state-Still_start-2
      #|rect a [a] in Still state-a-2
      #|root_start --> Still [-] edge0
      #|Still --> root_end [done] edge1
      #|Still_start --> a [-] edge2
    ),
  )
}

///|
test "descriptions add up to a titled state" {
  inspect(
    summary(
      (
        #|s : first
        #|s : second
        #|state "Long name" as t
        #|state "Name" as u: and more
      ),
    ),
    content=(
      #|rectWithTitle s [first] in - state-s-0
      #|rect t [Long name] in - state-t-0
      #|rectWithTitle u [Name] in - state-u-0
    ),
  )
}

///|
test "a composite split by -- becomes one region per part" {
  inspect(
    summary(
      (
        #|state Active {
        #|  a --> b
        #|  --
        #|  c --> d
        #|}
      ),
    ),
    content=(
      #|roundedWithTitle Active [Active] in - state-Active-0
      #|divider divider-id-1 [] in Active state-divider-id-1-0
      #|rect a [a] in divider-id-1 state-a-0
      #|rect b [b] in divider-id-1 state-b-0
      #|divider id-i-1 [] in Active state-id-i-1-1
      #|rect c [c] in id-i-1 state-c-1
      #|rect d [d] in id-i-1 state-d-1
      #|a --> b [-] edge0
      #|c --> d [-] edge1
    ),
  )
}

///|
test "a note stands in a group of its own, tied to its state" {
  inspect(
    summary(
      (
        #|A --> B
        #|note left of B : careful
      ),
    ),
    content=(
      #|rect A [A] in - state-A-0
      #|rect B [B] in - state-B-1
      #|noteGroup B----parent [careful] in - state-B----parent-1
      #|note B----note-1 [careful] in B----parent state-B----note-1
      #|A --> B [-] edge0
      #|B----note-1 --> B [-] B----note-1-B
    ),
  )
}

///|
test "forks, joins and choices keep their type as shape" {
  inspect(
    summary(
      (
        #|state f <<fork>>
        #|state j [[join]]
        #|state c <<choice>>
        #|f --> j
        #|j --> c : if x < 1
      ),
    ),
    content=(
      #|fork f [f] in - state-f-0
      #|join j [j] in - state-j-1
      #|choice c [c] in - state-c-1
      #|f --> j [-] edge0
      #|j --> c [if x &lt; 1] edge1
    ),
  )
}

///|
test "classes and styles reach the nodes" {
  let config = @config.Config::new(diagram_type="stateDiagram")
  let db = @state.parse(
    (
      #|stateDiagram-v2
      #|classDef hot fill:#f00,color:white;
      #|A --> B:::hot
      #|class A hot
      #|style A stroke:#000;
      #|
    ),
    config,
  )
  guard db.dump() is { "nodes": [a, b, ..], "classes": classes, .. } else {
    fail("unexpected dump")
  }
  json_inspect(classes, content=[
    {
      "id": "hot",
      "styles": ["fill:#f00", "color:white"],
      "textStyles": ["fill:white"],
    },
  ])
  guard a
    is {
      "cssClasses": a_classes,
      "cssStyles": a_styles,
      "cssCompiledStyles": a_compiled,
      ..
    } else {
    fail("unexpected node")
  }
  json_inspect([a_classes, a_styles, a_compiled], content=[
    "hot statediagram-state",
    ["stroke:#000"],
    ["fill:#f00", "color:white"],
  ])
  guard b is { "cssClasses": b_classes, .. } else { fail("unexpected node") }
  json_inspect(b_classes, content="hot statediagram-state")
}

///|
test "a state name is one word" {
  let config = @config.Config::new(diagram_type="stateDiagram")
  let message = try
    @state.parse("stateDiagram-v2\nstate a b c {\n}\n", config)
  catch {
    @jison.ParseError(message~, ..) => message
    _ => fail("expected a parse error")
  } noraise {
    _ => fail("expected a parse error")
  }
  inspect(
    message,
    content="Error: State name must be a single word. Found: \"a b c {\"",
  )
}
