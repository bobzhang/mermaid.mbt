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

///|
test "sans-serif is Helvetica, with the ascent Blink raises on macOS" {
  let font = @font.Stack::for_family("\"Open Sans\", sans-serif")
  debug_inspect(
    font.bbox("x x", 14.0),
    content="{ x: 0, y: -13, width: 17.890625, height: 16 }",
  )
  debug_inspect(
    font.bbox("x x", 11.48),
    content="{ x: 0, y: -11, width: 14.671875, height: 14 }",
  )
  debug_inspect(
    font.bbox("x x", 10.5),
    content="{ x: 0, y: -10, width: 13.421875, height: 12 }",
  )
}

///|
test "Helvetica joins fi into one glyph" {
  let font = @font.Stack::for_family("Helvetica")
  inspect(font.advance("fi", 100.0), content="50")
  // The ligature's ink ends where the dot of a separate `i` would not.
  debug_inspect(
    font.ink("fi", 100.0),
    content=(
      #|{
      #|  x: 1.3671875,
      #|  y: -72.75390625,
      #|  width: 41.9921875,
      #|  height: 72.75390625,
      #|}
    ),
  )
  inspect(font.advance("ffi", 14.0), content="10.890625")
}

///|
test "kerning from a kern table is shared between the two glyphs" {
  // `A` and the space after it kern; each word takes half.
  let helvetica = @font.Stack::for_family("sans-serif")
  debug_inspect(
    helvetica.item_advances(["A", " cat"], 14.0),
    content="[8.96875, 22.1875]",
  )
  debug_inspect(
    helvetica.item_advances(["xA", " Ax"], 11.48),
    content="[13.09375, 15.65625]",
  )
  let trebuchet = @font.Stack::default()
  debug_inspect(
    trebuchet.item_advances(["A", " cat"], 14.0),
    content="[7.875, 23.671875]",
  )
  debug_inspect(
    trebuchet.item_advances(["L", " x"], 16.0),
    content="[7.8125, 12.546875]",
  )
}

///|
test "ink at a size that is not a float" {
  // 9.6px: the tail of `j` ends 2.02500008 below the baseline, and its
  // box, grown to hold that, ends at 2.0250015. `p` ends on a float.
  let font = @font.Stack::for_family("Helvetica")
  debug_inspect(
    font.bbox("j", 9.6),
    content=(
      #|{
      #|  x: -0.17812500894069672,
      #|  y: -8,
      #|  width: 2.3187499046325684,
      #|  height: 10.025001525878906,
      #|}
    ),
  )
  debug_inspect(
    font.bbox("p", 9.6),
    content="{ x: 0, y: -8, width: 5.34375, height: 10.00156307220459 }",
  )
  // Anchor points, contours of one point, are not ink: `g` is not as
  // tall as its header box says.
  debug_inspect(
    font.ink("g", 2048.0),
    content="{ x: 61, y: -1090, width: 939, height: 1543 }",
  )
}
