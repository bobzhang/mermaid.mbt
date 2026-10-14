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
test "Times and Helvetica join fi and fl, and stand taller on macOS" {
  let times = @font.Stack::standard()
  inspect(times.advance("f", 16.0), content="5.328125")
  inspect(times.advance("i", 16.0), content="4.453125")
  inspect(times.advance("fi", 16.0), content="8.90625")
  // The pair `ff` is kerned; before a ligature it is not.
  inspect(times.advance("ff", 16.0), content="10.375")
  inspect(times.advance("ffi", 16.0), content="14.234375")
  debug_inspect(
    times.bbox("Hello John, how are you?", 16.0),
    content="{ x: 0, y: -14, width: 163.96875, height: 18 }",
  )
  let helvetica = @font.Stack::for_family("sans-serif")
  inspect(helvetica.advance("fl", 16.0), content="8")
  debug_inspect(
    helvetica.bbox("Hello John, how are you?", 16.0),
    content="{ x: 0, y: -14, width: 180.5625, height: 18 }",
  )
  // A zero-width space takes no room but still makes a line.
  debug_inspect(
    times.bbox("\u{200B}", 16.0),
    content="{ x: 0, y: -14, width: 0, height: 18 }",
  )
}

///|
test "the middle baseline shifts glyphs and can stretch the cell" {
  let arial = @font.Stack::for_family("arial")
  // At 16px half of Arial's x-height is 265.5 layout units: the ascent
  // above the middle line rounds up, and so does the descent below it.
  debug_inspect(
    arial.bbox("Features:", 16.0, baseline=Middle),
    content="{ x: 0, y: -9.859375, width: 67.59375, height: 17.015625 }",
  )
  // Ink below the descent moves down with the glyphs.
  debug_inspect(
    arial.bbox("- createCssStyles()", 16.0, baseline=Middle),
    content="{ x: 0, y: -9.859375, width: 136.03125, height: 17.3671875 }",
  )
  // No tie at other sizes: the cell keeps its height.
  debug_inspect(
    arial.bbox("H", 10.0, baseline=Middle),
    content="{ x: 0, y: -6.40625, width: 7.234375, height: 11 }",
  )
  let times = @font.Stack::standard()
  debug_inspect(
    times.bbox("H", 32.0, baseline=Middle),
    content=(
      #|{ x: 0, y: -21.828125, width: 23.109375, height: 37.015625 }
    ),
  )
}
