///|
test "a long markdown label renders on every target" {
  // marked's rules are matched with backtracking that once went one call
  // deeper per character, which the stack of wasm-gc did not hold for a
  // paragraph of a thousand. The default `maxTextSize` is 50000.
  let label = "word ".repeat(4000)
  let svg = @mermaid.render("flowchart TD\nA[\"`\{label}`\"]\n")
  assert_true(svg.contains("<p>" + label.trim_end().to_owned()))
}
