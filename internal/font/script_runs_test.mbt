///|
test "the pieces of a line continue the script run before them" {
  // getBBox of <tspan>мир</tspan><tspan> Tools</tspan><tspan> Ideas</tspan>
  // in Chrome is 111.265625: the space after the Cyrillic word is in its
  // run, and does not kern with the T.
  let widths = @font.Stack::default().item_advances(
    ["мир", " Tools", " Ideas"],
    16.0,
  )
  inspect(widths.fold(init=0.0, (a, b) => a + b), content="111.265625")
}
