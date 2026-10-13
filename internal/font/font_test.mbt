// Expected values are what Chrome reports for SVG text in the reference
// environment; see scripts/check_metrics.py for the full comparison.

///|
test "advance width snaps up to 1/64 pixel" {
  let font = @font.Stack::default()
  inspect(font.advance("Dogs", 17.0), content="34.96875")
  inspect(font.advance("D", 17.0), content="10.4375")
  inspect(font.advance("Pets adopted by volunteers", 17.0), content="207.09375")
  inspect(font.advance("79%", 17.0), content="28.046875")
  inspect(font.advance("Dogs", 16.0), content="32.90625")
  inspect(font.advance("", 16.0), content="0")
}

///|
test "kerning pairs tighten the advance" {
  let font = @font.Stack::default()
  inspect(font.advance("A", 17.0), content="10.03125")
  inspect(font.advance("V", 17.0), content="10")
  inspect(font.advance("AV", 17.0), content="18.53125")
}

///|
test "bounding box unites the cell with overhanging ink" {
  let font = @font.Stack::default()
  debug_inspect(
    font.bbox("Dogs", 17.0),
    content="{ x: 0, y: -16, width: 34.96875, height: 20 }",
  )
  // The hook of `f` reaches past its advance.
  debug_inspect(
    font.bbox("f", 17.0),
    content="{ x: 0, y: -16, width: 6.36669921875, height: 20 }",
  )
  // The tail of `g` reaches below the rounded descent at small sizes.
  debug_inspect(
    font.bbox("Dogs", 10.0),
    content="{ x: 0, y: -9, width: 20.578125, height: 11.05078125 }",
  )
}

///|
test "font size is truncated to two decimals" {
  let font = @font.Stack::default()
  inspect(font.advance("DDDD", 13.3333), content="32.703125")
  inspect(font.advance("DDDD", 13.33), content="32.703125")
  inspect(font.advance("DDDD", 13.34), content="32.734375")
}

///|
test "bold and italic faces" {
  inspect(
    @font.Stack::default(bold=true).advance("Dogs", 16.0),
    content=(
      #|34.265625
    ),
  )
  inspect(
    @font.Stack::default(italic=true).advance("Dogs", 16.0),
    content=(
      #|32.90625
    ),
  )
  inspect(
    @font.Stack::default(bold=true, italic=true).advance("Dogs", 16.0),
    content=(
      #|35.140625
    ),
  )
}
