///|
test "a long markdown label renders on every target" {
  // marked's rules are matched with backtracking that once went one call
  // deeper per character, which the stack of wasm-gc did not hold for a
  // paragraph of a thousand. The default `maxTextSize` is 50000.
  let label = "word ".repeat(4000)
  let svg = @mermaid.render("flowchart TD\nA[\"`\{label}`\"]\n")
  assert_true(svg.contains("<p>" + label.trim_end().to_owned()))
}

///|
test "deeply nested block quotes are refused, not overflowed" {
  // marked lexes each level of a block quote by recursion; the port takes
  // 250 levels and refuses more, well below what any backend's stack
  // holds.
  let render = (depth : Int32) => {
    let label = ">".repeat(depth) + " a"
    try {
      ignore(
        @mermaid.render(
          "flowchart TD\nA[\"`\{label}`\"] -- \"`\{label}`\" --> B\n",
        ),
      )
      "rendered"
    } catch {
      Unsupported(_) => "unsupported"
      error => "other: " + Repr(error).to_string()
    }
  }
  inspect(render(250), content="rendered")
  inspect(render(251), content="unsupported")
  inspect(render(3000), content="unsupported")
  // Emphasis nests by recursion too.
  let emphasis = (depth : Int32) => {
    let label = "*_".repeat(depth) + "a" + "_*".repeat(depth)
    try {
      ignore(@mermaid.render("flowchart TD\nA[\"`\{label}`\"]\n"))
      "rendered"
    } catch {
      Unsupported(_) => "unsupported"
      error => "other: " + Repr(error).to_string()
    }
  }
  inspect(emphasis(250), content="rendered")
  inspect(emphasis(3000), content="unsupported")
}
