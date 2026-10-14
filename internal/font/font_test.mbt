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
