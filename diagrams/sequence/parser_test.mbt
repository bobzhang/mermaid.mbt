// Cases follow upstream's sequenceDiagram.spec.js.

///|
fn parsed(source : String) -> Json raise {
  let config = @config.Config::new(diagram_type="sequence")
  @sequence.parse(source + "\n", config).dump()
}

///|
/// The entries of a diagram as `from to type: text`.
fn entries(source : String) -> Array[String] raise {
  guard parsed(source) is { "messages": Array(messages), .. } else { return [] }
  messages.map(message => {
    let text = (key : String) => {
      match message {
        Object(fields) =>
          match fields.get(key) {
            Some(String(text)) => text
            Some(Number(n, ..)) => n.to_int().to_string()
            _ => "-"
          }
        _ => "-"
      }
    }
    "\{text("from")} \{text("to")} \{text("type")}: \{text("message")}"
  })
}

///|
test "messages, notes and activations in order" {
  debug_inspect(
    entries(
      (
        #|sequenceDiagram
        #|Alice->>+Bob: Hello Bob, how are you?
        #|Note right of Bob: Bob thinks
        #|Bob-->>-Alice: I am good thanks!
        #|Note over Alice,Bob: both
      ),
    ),
    content=(
      #|[
      #|  "Alice Bob 0: Hello Bob, how are you?",
      #|  "Bob - 17: ",
      #|  "Bob Bob 2: Bob thinks",
      #|  "Bob Alice 1: I am good thanks!",
      #|  "Bob - 18: ",
      #|  "Alice Bob 2: both",
      #|]
    ),
  )
}

///|
test "blocks open and close around their content" {
  debug_inspect(
    entries(
      (
        #|sequenceDiagram
        #|alt is sick
        #|Bob->>Alice: Not so good :(
        #|else is well
        #|Bob->>Alice: Feeling fresh like a daisy
        #|end
        #|rect rgb(0, 255, 0)
        #|Bob-xAlice: bye
        #|end
      ),
    ),
    content=(
      #|[
      #|  "- - 12: is sick",
      #|  "Bob Alice 0: Not so good :(",
      #|  "- - 13: is well",
      #|  "Bob Alice 0: Feeling fresh like a daisy",
      #|  "- - 14: ",
      #|  "- - 22: rgb(0, 255, 0)",
      #|  "Bob Alice 3: bye",
      #|  "- - 23: ",
      #|]
    ),
  )
}

///|
test "participants keep their declaration order, aliases and kinds" {
  let db = parsed(
    (
      #|sequenceDiagram
      #|participant B as Bob
      #|actor A as wrap:Alice in Wonderland
      #|participant D@{ "type": "database", "alias": "Store" }
      #|A->>C: implicit
    ),
  )
  guard db is { "actors": Array(actors), .. } else { fail("no actors") }
  let summary = actors.map(actor => {
    match actor {
      {
        "id": String(id),
        "description": String(description),
        "type": String(kind),
        "wrap": wrap,
        ..
      } =>
        "\{id}=\{description} (\{kind}\{if wrap is True { ", wrap" } else { "" }})"
      _ => "?"
    }
  })
  debug_inspect(
    summary,
    content=(
      #|[
      #|  "B=Bob (participant)",
      #|  "A=Alice in Wonderland (actor, wrap)",
      #|  "D=Store (database)",
      #|  "C=C (participant)",
      #|]
    ),
  )
}

///|
test "what upstream rejects is rejected" {
  let fails = (source : String) => {
    try parsed(source) catch {
      _ => true
    } noraise {
      _ => false
    }
  }
  // Deactivating a participant that is not active.
  inspect(
    fails("sequenceDiagram\nAlice->>Bob: Hi\ndeactivate Bob"),
    content="true",
  )
  // A created participant must receive the next message.
  inspect(
    fails(
      "sequenceDiagram\nAlice->>Bob: Hi\ncreate participant Carl\nAlice->>Bob: x",
    ),
    content="true",
  )
  // One participant in two boxes.
  inspect(
    fails(
      "sequenceDiagram\nbox One\nparticipant A\nend\nbox Two\nparticipant A\nend",
    ),
    content="true",
  )
  inspect(fails("sequenceDiagram\nAlice->>: nobody"), content="true")
}
