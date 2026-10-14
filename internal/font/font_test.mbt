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
test "the truncation is done in single precision" {
  // 18.4 and 19.99 times a hundred fall just short of a whole number in
  // double precision, but not in the browser's floats. Values measured in
  // Chrome.
  let font = @font.Stack::for_family("trebuchet ms")
  let text = "A reasonably long actor name, Tj fi WAVE. Another actor that is long enough to wrap"
  inspect(font.advance(text, 18.4), content="697.21875")
  inspect(font.advance(text, 18.39), content="696.828125")
  inspect(font.advance(text, 18.39996), content="696.828125")
  inspect(font.advance(text, 19.99), content="757.453125")
  inspect(font.advance(text, 19.999), content="757.453125")
  inspect(font.advance(text, 4.35), content="164.828125")
  inspect(font.advance(text, 16.4), content="621.421875")
  // The truncated size is a float as well: 33.46 as a double would put
  // the top of this ink one step higher.
  let bold = @font.Stack::default(bold=true)
  inspect(
    bold.bbox(
      "Sym ĀāĂăĄą Čč Ďď Ēē Ğğ Łł Ńń Őő Řř Śś Šš Ťť Űű Žž here",
      33.46875,
    ).y,
    content="-31.20536994934082",
  )
}

///|
test "x-height and glyph coverage" {
  // Four x-heights of Trebuchet at 16px is what `font-size: 4ex` computes
  // to there: 33.4688px.
  inspect(@font.Stack::default().x_height(16.0) * 4.0, content="33.46875")
  inspect(
    @font.Stack::for_family("verdana", bold=true).x_height(32.0),
    content="17.546875",
  )
  inspect(@font.Stack::default().covers("naïve — text"), content="true")
  inspect(@font.Stack::default().covers("日本"), content="false")
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
  let times = @font.Stack::page_default()
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
test "a kerning pair the shaper cannot find does not kern" {
  // Trebuchet MS Bold lists `v.` out of order; HarfBuzz looks pairs up by
  // binary search and misses it. Chrome: 12.203125.
  inspect(
    @font.Stack::default(bold=true).advance("v.", 16.0),
    content="12.203125",
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
  let times = @font.Stack::page_default()
  debug_inspect(
    times.bbox("H", 32.0, baseline=Middle),
    content=(
      #|{ x: 0, y: -21.828125, width: 23.109375, height: 37.015625 }
    ),
  )
}

///|
test "ink at sizes that do not scale to whole floats" {
  // Values are `getBBox()` of plain SVG text in Chrome. The ink of each
  // glyph is the box of its outline; a run keeps the extreme edges and
  // subtracts them once.
  let box = (family : String, text : String, size : Double) => {
    let b = @font.Stack::for_family(family).bbox(text, size)
    [b.x, b.y, b.width, b.height]
  }
  json_inspect(box("arial", "[object Object]", 10.46), content=[
    0, -9, 66.875, 11.201299667358398,
  ])
  json_inspect(box("arial", "j", 10.46), content=[
    -0.4800976514816284, -9, 2.808222770690918, 11.201300621032715,
  ])
  json_inspect(box("arial", "[object Object]", 9.6), content=[
    0, -9, 61.375, 11.02031421661377,
  ])
  json_inspect(box("verdana", "Ĝi a\\b ¥7 (x)", 13.067), content=[
    0, -13.066377639770508, 85.59375, 16.066377639770508,
  ])
}

///|
test "kerning from a kern table is shared between the two glyphs" {
  // What `getComputedTextLength()` reports for `<tspan>A</tspan>` and the
  // `<tspan>` after it: `A` and the space kern, and each word takes half.
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
test "the ink of a piece follows the kerning it shares with the piece before" {
  // The space of ` A` gives up its half of the adjustment, so the `A`
  // after it starts that much earlier than in a piece shaped alone.
  let helvetica = @font.Stack::for_family("sans-serif")
  let alone = helvetica.ink(" A", 14.0)
  let after = helvetica.item_inks(["A", " A"], 14.0)[1]
  debug_inspect(alone.x - after.x, content="0.3828125")
  debug_inspect(alone.width == after.width, content="true")
}

///|
test "Helvetica has oblique faces" {
  let oblique = @font.Stack::for_family("Helvetica", italic=true)
  let upright = @font.Stack::for_family("Helvetica")
  // The advances are the same; the slanted `J` leans out of its cell.
  debug_inspect(
    (oblique.advance("J", 11.48), upright.advance("J", 11.48)),
    content="(5.75, 5.75)",
  )
  debug_inspect(oblique.bbox("J", 11.48).width, content="6.664902210235596")
}
