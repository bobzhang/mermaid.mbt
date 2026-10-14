// Cases follow upstream's pie.spec.ts.

///|
fn summary(source : String) -> String raise {
  let pie = @pie.parse(source)
  let sections = pie.sections
    .iter()
    .map(entry => "\{entry.0}=\{entry.1}")
    .collect()
    .join(", ")
  let parts = ["sections: \{sections}"]
  if pie.show_data {
    parts.push("showData")
  }
  if pie.title != "" {
    parts.push("title: \{pie.title}")
  }
  if pie.acc_title != "" {
    parts.push("accTitle: \{pie.acc_title}")
  }
  if pie.acc_description != "" {
    parts.push("accDescr: \{pie.acc_description}")
  }
  parts.join("; ")
}

///|
test "simple pies" {
  inspect(
    summary("pie\n      \"ash\": 100\n      "),
    content="sections: ash=100",
  )
  inspect(
    summary("pie\n      \"ash\" : 60\n      \"bat\" : 40\n      "),
    content="sections: ash=60, bat=40",
  )
  inspect(
    summary("pie showData\n      \"ash\" : 60\n      \"bat\" : 40\n      "),
    content="sections: ash=60, bat=40; showData",
  )
  inspect(
    summary(
      "pie\n      %% comments\n      \"ash\" : 60\n      \"bat\" : 40\n      ",
    ),
    content="sections: ash=60, bat=40",
  )
  inspect(
    summary("\n\n  pie\n\n\n      \"ash\" : 60.67\n\n      \"bat\" : 40\n"),
    content="sections: ash=60.67, bat=40",
  )
}

///|
test "titles and accessibility" {
  inspect(
    summary(
      "pie title a 60/40 pie\n      \"ash\" : 60\n      \"bat\" : 40\n      ",
    ),
    content="sections: ash=60, bat=40; title: a 60/40 pie",
  )
  inspect(
    summary(
      "pie title a neat chart\n      accTitle: a neat acc title\n      \"ash\" : 60\n      \"bat\" : 40\n      ",
    ),
    content="sections: ash=60, bat=40; title: a neat chart; accTitle: a neat acc title",
  )
  inspect(
    summary(
      "pie title a neat chart\n      accDescr: a neat description\n      \"ash\" : 60\n      \"bat\" : 40\n      ",
    ),
    content="sections: ash=60, bat=40; title: a neat chart; accDescr: a neat description",
  )
  inspect(
    summary(
      "pie title a neat chart\n      accDescr {\n        a neat description\n        on multiple lines\n      }\n      \"ash\" : 60\n      \"bat\" : 40\n    ",
    ),
    content=(
      #|sections: ash=60, bat=40; title: a neat chart; accDescr: a neat description
      #|on multiple lines
    ),
  )
  // The title may come on its own line, and blanks in it collapse.
  inspect(
    summary("pie showData\n  title   Key   elements\n  \"a\" : 1"),
    content="sections: a=1; showData; title: Key elements",
  )
}

///|
test "labels" {
  // Single quotes, escapes, and a repeated label keeps its first value.
  inspect(
    summary(
      "pie\n 'single' : 1\n \"say \\\"hi\\\"\" : 2\n \"dup\" : 3\n \"dup\" : 4",
    ),
    content="sections: single=1, say \"hi\"=2, dup=3",
  )
}

///|
test "invalid pies are rejected" {
  let rejected = (source : String) => {
    try @pie.parse(source) catch {
      error => Some(Repr(error).to_string())
    } noraise {
      _ => None
    }
  }
  debug_inspect(
    rejected("pie\n        \"ash\" : -60.67\n        \"bat\" : 40.12\n        "),
    content=(
      #|Some("ParseError(\n  message=\"\\\"ash\\\" has invalid value: -60.67. Negative values are not allowed in pie charts. All slice values must be >= 0.\",\n  offset=26,\n)")
    ),
  )
  debug_inspect(
    rejected("pie\n \"ash\" 60"),
    content=(
      #|Some("ParseError(message=\"Expecting token of type ':'\", offset=11)")
    ),
  )
  debug_inspect(
    rejected("pie\n \"ash\" : sixty"),
    content=(
      #|Some("ParseError(message=\"Expecting a number\", offset=13)")
    ),
  )
  debug_inspect(
    rejected("pie \"ash\" : 60 \"bat\" : 40"),
    content=(
      #|Some("ParseError(message=\"Expecting end of line\", offset=15)")
    ),
  )
  debug_inspect(
    rejected("pies\n \"ash\" : 60"),
    content=(
      #|Some("ParseError(message=\"Expecting keyword 'pie'\", offset=0)")
    ),
  )
  debug_inspect(
    rejected("pie\n \"ash\" : 1.2.3"),
    content=(
      #|Some("ParseError(message=\"Expecting a number\", offset=13)")
    ),
  )
}

///|
test "labels keep characters outside the basic plane" {
  inspect(
    summary("pie title Pets 🐶\n \"Dogs 🐕\" : 3\n \"Cats\" : 1"),
    content=(
      #|sections: Dogs 🐕=3, Cats=1; title: Pets 🐶
    ),
  )
}
