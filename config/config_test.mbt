///|
test "defaults" {
  let config = @config.Config::new()
  json_inspect(config.get("pie"), content={
    "useMaxWidth": true,
    "textPosition": 0.75,
    "donutHole": 0,
    "legendPosition": "right",
    "highlightSlice": "",
    "useWidth": 984,
  })
  debug_inspect(
    config.text("theme"),
    content=(
      #|Some("default")
    ),
  )
  debug_inspect(
    config.text("layout"),
    content=(
      #|Some("elk")
    ),
  )
  debug_inspect(
    config.number("pie.textPosition"),
    content=(
      #|Some(0.75)
    ),
  )
  inspect(
    config.flag("pie.useMaxWidth"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    config.get("no.such.key"),
    content=(
      #|Null
    ),
  )
  inspect(
    config.theme().text("pie3"),
    content=(
      #|hsl(80, 100%, 56.2745098039%)
    ),
  )
}

///|
test "a diagram section scopes theme and look to that diagram type" {
  let pie = @config.Config::new(diagram_type="pie")
  debug_inspect(
    (pie.text("theme"), pie.text("look")),
    content=(
      #|(Some("default"), Some("classic"))
    ),
  )
  let flowchart = @config.Config::new(diagram_type="flowchart-v2")
  debug_inspect(
    (flowchart.text("theme"), flowchart.text("look")),
    content=(
      #|(Some("redux-color"), Some("neo"))
    ),
  )
  inspect(
    flowchart.theme().text("primaryColor"),
    content=(
      #|#cccccc
    ),
  )
  // An explicit top-level theme in the diagram wins over the section default.
  let dark = @config.Config::new(diagram_type="flowchart-v2", directive={
    "theme": "dark",
  })
  debug_inspect(
    (dark.text("theme"), dark.theme().text("primaryColor")),
    content=(
      #|(Some("dark"), "#1f2020")
    ),
  )
}

///|
test "site configuration and directives layer over the defaults" {
  let config = @config.Config::new(
    site={ "theme": "forest", "pie": { "textPosition": 0.5 } },
    directive={
      "pie": { "donutHole": 0.3 },
      "themeVariables": { "pie1": "#ff0000" },
      "securityLevel": "loose",
      "notAKey": 1,
    },
  )
  json_inspect(config.get("pie"), content={
    "useMaxWidth": true,
    "textPosition": 0.5,
    "donutHole": 0.3,
    "legendPosition": "right",
    "highlightSlice": "",
    "useWidth": 984,
  })
  // Secure keys cannot be changed by a diagram; unknown keys are dropped.
  debug_inspect(
    config.text("securityLevel"),
    content=(
      #|Some("strict")
    ),
  )
  debug_inspect(
    config.get("notAKey"),
    content=(
      #|Null
    ),
  )
  inspect(
    config.theme().text("pie1"),
    content=(
      #|#ff0000
    ),
  )
  inspect(
    config.theme().text("pie2"),
    content=(
      #|#cdffb2
    ),
  )
}

///|
test "assign_with_depth" {
  let merged = @config.assign_with_depth(
    { "a": 1, "b": { "c": 2, "d": { "e": 3 } }, "list": [1, 2] },
    { "a": 5, "b": { "d": { "f": 4 } }, "list": [2, 3], "new": { "x": true } },
  )
  json_inspect(merged, content={
    "a": 5,
    "b": { "c": 2, "d": { "e": 3, "f": 4 } },
    "list": [1, 2, 3],
    "new": { "x": true },
  })
}

///|
test "directives are sanitized" {
  json_inspect(
    @config.sanitize_directive({
      "theme": "dark",
      "__proto__": { "x": 1 },
      "constructor": 1,
      "fontFamily": "a { b } }",
      "themeVariables": { "primaryColor": "#fff", "lineColor": "url(evil)<x>" },
      "sankey": { "nodeColors": { "a": "#ff0000", "b": "javascript:1" } },
    }),
    content={
      "theme": "dark",
      "fontFamily": "{ /* ERROR: Unbalanced CSS */ }",
      "themeVariables": { "primaryColor": "#fff", "lineColor": "" },
      "sankey": { "nodeColors": { "a": "#ff0000" } },
    },
  )
  inspect(
    @config.sanitize_css("a { b }"),
    content=(
      #|a { b }
    ),
  )
}
