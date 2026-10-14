///|
/// The parsed diagram as JSON, or the error.
fn dump(source : String) -> Json {
  let venn = @venn.parse(source) catch {
    @jison.ParseError(..) => return Json::string("syntax error")
    @venn.Invalid(message) => return Json::string("invalid: " + message)
    _ => return Json::string("error")
  }
  let label = (label : String?) => {
    match label {
      Some(label) => "[\{label}]"
      None => ""
    }
  }
  {
    "subsets": venn.subsets.map(subset => {
      "\{subset.sets.join(",")}\{label(subset.label)}:\{subset.size}"
    }),
    "texts": venn.text_nodes.map(node => {
      "\{node.sets.join(",")} \{node.id}\{label(node.label)}"
    }),
    "styles": venn.style_entries.map(entry => {
      let styles = entry.styles
        .iter()
        .map(style => "\{style.0}=\{style.1}")
        .collect()
      "\{entry.targets.join(",")} \{styles.join(";")}"
    }),
    "title": venn.title,
  }
}

///|
test "sets and unions: sorted identifiers, labels and default sizes" {
  json_inspect(
    dump(
      (
        #|venn-beta
        #|  title "Team overlap"
        #|  set Zed["Last one"]:20
        #|  set "A B"
        #|  set c[ plain ]
        #|  union Zed,"A B"["both"]
        #|  union c,Zed,"A B":.5
      ),
    ),
    content={
      "subsets": [
        "Zed[Last one]:20", "A B:10", "c[plain]:10", "A B,Zed[both]:2.5", "A B,Zed,c:0.5",
      ],
      "texts": [],
      "styles": [],
      "title": "\"Team overlap\"",
    },
  )
}

///|
test "an indented text line belongs to the statement before it" {
  json_inspect(
    dump(
      (
        #|venn-beta
        #|  set A
        #|    text a1["React"]
        #|    text "two words"
        #|  set B
        #|  union B,A
        #|    text 42
        #|text A,B explicit["E"]
      ),
    ),
    content={
      "subsets": ["A:10", "B:10", "A,B:2.5"],
      "texts": ["A a1[React]", "A two words", "A,B 42", "A,B explicit[E]"],
      "styles": [],
      "title": "",
    },
  )
}

///|
test "style values: tokens joined by spaces, quotes dropped" {
  json_inspect(
    dump(
      (
        #|venn-beta
        #|  set A
        #|  set B
        #|  style B,A fill:#ff6b6b, stroke: rgb(1, 2, 3), stroke-width: 2.5 px, color: "dark red"
      ),
    ),
    content={
      "subsets": ["A:10", "B:10"],
      "texts": [],
      "styles": [
        "A,B fill=#ff6b6b;stroke=rgb(1, 2, 3);stroke-width=2.5 px;color=dark red",
      ],
      "title": "",
    },
  )
}

///|
test "unions are of declared sets, and of two at least" {
  json_inspect(
    dump("venn-beta\n  set A\n  union A,B,C"),
    content="invalid: unknown set identifier: B, C",
  )
  json_inspect(
    dump("venn-beta\n  set A\n  union A"),
    content="invalid: union requires multiple identifiers",
  )
  json_inspect(dump("venn-beta\n  set A\n    text"), content="syntax error")
}
