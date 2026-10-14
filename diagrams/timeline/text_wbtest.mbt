// The numbers are what Chrome reports through `getComputedTextLength`
// and `getBBox` for the same spans, positioned as `drawNode` does.

///|
fn default_style(size : Double, bold~ : Bool = false) -> TextStyle {
  TextStyle::new(@font.Stack::default(bold~), size)
}

///|
fn box_of(spans : Array[String], style : TextStyle) -> Array[Double] {
  let box = text_box(spans, style)
  [box.x, box.y, box.width, box.height]
}

///|
test "words and separators" {
  json_inspect(split_words("a  b<br>c "), content=[
    "a", "  ", "b", "<br>", "c", " ", "",
  ])
  json_inspect(split_words(""), content=[""])
}

///|
test "wrapping" {
  let style = default_style(16.0)
  json_inspect(wrap("Machinery, Water power, Steam <br>power", 150.0, style), content=[
    "Machinery,   Water", "power,   Steam", "power",
  ])
  // A first word too long for the line leaves an empty span before it.
  json_inspect(wrap("Supercalifragilisticexpialidocious word", 150.0, style), content=[
    "", "Supercalifragilisticexpialidocious", "word",
  ])
  json_inspect(wrap("a<br>", 150.0, style), content=["a", ""])
  json_inspect(wrap("", 150.0, style), content=[""])
}

///|
test "the box of wrapped text" {
  let style = default_style(16.0)
  json_inspect(box_of(["2002"], style), content=[-16.78125, 5.1875, 33.5625, 19])
  json_inspect(box_of(["Machinery, Water", "power, Steam", "power"], style), content=[
    -61.875, 5.1875, 123.75, 54.19999694824219,
  ])
  // An empty span takes no line: the next one is 1.1em down from the top.
  json_inspect(
    box_of(["", "Supercalifragilisticexpialidocious", "word"], style),
    content=[-117.6640625, 6.787500381469727, 235.328125, 36.60000228881836],
  )
  json_inspect(box_of(["BoxT", " "], style), content=[
    -17.4765625, 5.1875, 34.953125, 19,
  ])
}

///|
test "the box in other sizes and faces" {
  json_inspect(
    box_of(["Thirteen and half", "jumping", "lines three"], default_style(13.5)),
    content=[-52.671875, 4.03125, 105.396240234375, 45.70000076293945],
  )
  json_inspect(
    box_of(["Bold jumping", "fjord Å"], default_style(16.0, bold=true)),
    content=[-49.0234375, 5.1875, 98.046875, 36.599998474121094],
  )
  // The middle baseline of a tall font lands between layout units, and
  // the two edges round apart.
  json_inspect(box_of(["xgÅ"], default_style(32.0)), content=[
    -25.484375, 10.359375, 50.96875, 37.015625,
  ])
  let arial = (bold : Bool, size : Double) => {
    TextStyle::new(@font.Stack::for_family("arial", bold~), size)
  }
  json_inspect(box_of(["Arial semi bold", "jumping"], arial(true, 14.0)), content=[
    -50.1796875, 4.625, 100.359375, 31.400001525878906,
  ])
  json_inspect(box_of(["Arial regular", "jumping"], arial(false, 14.0)), content=[
    -37.7626953125, 4.625, 75.6875, 31.400001525878906,
  ])
  let verdana = TextStyle::new(
    @font.Stack::for_family("verdana", bold=true),
    16.0,
  )
  json_inspect(box_of(["Verdana bold", "jumping"], verdana), content=[
    -59.53125, 4.390625, 119.0625, 36.904685974121094,
  ])
}

///|
test "ink above the ascent" {
  // An accented capital reaches above the line; where its top lands
  // depends on the order the browser adds the offsets up in.
  let style = (family : String, size : Double, bold : Bool) => {
    TextStyle::new(@font.Stack::for_family(family, bold~), size)
  }
  json_inspect(box_of(["Ĝi a\\b ¥7 (x)"], style("verdana", 13.067, false)), content=[
    -42.796875, 3.5631227493286133, 85.59375, 16.06637954711914,
  ])
  json_inspect(box_of(["Ĝ"], style("trebuchet ms", 13.067, false)), content=[
    -4.421875, 4.225994110107422, 8.84375, 15.262882232666016,
  ])
  json_inspect(box_of(["Ünïcödé"], style("Arial, verdana", 10.46, true)), content=[
    -20.6328125, 4.031357765197754, 41.265625, 11.147392272949219,
  ])
  json_inspect(box_of(["Ĉu"], style("Arial, verdana", 16.494, false)), content=[
    -10.546875, 5.775249481201172, 21.09375, 18,
  ])
  json_inspect(box_of(["Ĝ"], style("verdana", 13.0, false)), content=[
    -5.046875, 3.54052734375, 10.09375, 16.00634765625,
  ])
}

///|
test "ink below the descent, and lines off the pixel grid" {
  let style = (family : String, size : Double) => {
    TextStyle::new(@font.Stack::for_family(family), size)
  }
  json_inspect(box_of(["[object Object]"], style("Arial, verdana", 10.46)), content=[
    -33.4375, 4.178750038146973, 66.875, 11.201299667358398,
  ])
  json_inspect(box_of(["j"], style("Arial, verdana", 10.46)), content=[
    -1.6441601514816284, 4.178750038146973, 2.808222770690918, 11.201300621032715,
  ])
  json_inspect(box_of(["["], style("Arial, verdana", 10.46)), content=[
    -1.453125, 4.178750038146973, 2.90625, 11.078721046447754,
  ])
  json_inspect(box_of(["[object Object]"], style("Arial, verdana", 9.6)), content=[
    -30.6875, 3.0843753814697266, 61.375, 11.020313262939453,
  ])
  json_inspect(
    box_of(["† … Ñandú ¶ {z}"], style("Arial, verdana", 9.6)),
    content=[-35.1328125, 3.0843753814697266, 70.265625, 11.02031421661377],
  )
  // Nothing overhangs here, and still the height is a step over 15: the
  // bottom edge of the line rounds up.
  json_inspect(box_of(["gjpqy[]{}()|"], style("trebuchet ms", 13.067)), content=[
    -33.984375, 4.488875389099121, 67.96875, 15.000000953674316,
  ])
  json_inspect(box_of(["gjpqy[]{}()|Ĝ"], style("arial", 17.3)), content=[
    -45.9765625, 5.784374237060547, 91.953125, 20,
  ])
}
