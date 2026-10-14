///|
/// Boxes read off the reference browser's `getBBox()` for text elements
/// with `dominant-baseline: middle`.
test "text aligned on its middle baseline" {
  let box = (
    stack : @font.Stack,
    text : String,
    size : Double,
    x : Double,
    y : Double,
  ) => stack.svg_text_box(text, size, x~, y~, baseline=Middle)
  let arial = @font.Stack::for_family("arial")
  // Half of Arial's x-height is not a whole layout unit at this size: the
  // line comes out 1/64 px taller than ascent plus descent.
  debug_inspect(
    box(arial, "Dockerfile", 16.0, 0.0, 0.0),
    content=(
      #|{ x: 0, y: -9.859375, width: 71.140625, height: 17.015625 }
    ),
  )
  // Brackets reach below the line.
  debug_inspect(
    box(arial, "[brackets]", 16.0, 0.0, 0.0),
    content=(
      #|{ x: 0, y: -9.859375, width: 69.359375, height: 17.1796875 }
    ),
  )
  // The width is a difference of edges in single precision, so it depends
  // on where the text stands.
  debug_inspect(
    box(
      @font.Stack::for_family("arial", italic=true),
      "1 < 2",
      19.2,
      152.234375,
      108.5,
    ),
    content=(
      #|{ x: 152.234375, y: 96.484375, width: 43.34996032714844, height: 21 }
    ),
  )
  debug_inspect(
    box(@font.Stack::default(), "index.js", 16.0, 0.0, 0.0),
    content=(
      #|{ x: 0, y: -10.8125, width: 57.1875, height: 19 }
    ),
  )
  debug_inspect(
    box(
      @font.Stack::for_family("verdana", italic=true),
      "start here",
      24.0,
      238.78125,
      116.0,
    ),
    content=(
      #|{ x: 238.78125, y: 98.546875, width: 118.546875, height: 29 }
    ),
  )
}

///|
/// The same for text broken into `<tspan>`s that each have an `x`, under
/// the anchors and baselines a stylesheet can ask for.
test "chunks anchored and aligned" {
  let f = Float::from_double
  // Baselines of two lines: the `y` of the text, then `dy` further down,
  // summed in single precision.
  let chunks = (lines : Array[String], x : Double, y : Double, dy : Double) => {
    let chunks : Array[@font.Chunk] = []
    let mut shift : Float = 0
    for i, text in lines {
      if i > 0 {
        shift = shift + f(dy)
      }
      // `x` as the browser's number parser reads the attribute.
      chunks.push({ text, x: f(x).to_double(), y: (f(y) + shift).to_double(), })
    }
    chunks
  }
  debug_inspect(
    @font.Stack::default().chunks_box(
      chunks(
        ["Shutter speed", "too slow"],
        -69.32959735556467,
        270.7294348970042,
        16.8,
      ),
      16.0,
      anchor="end",
      baseline=Middle,
    ),
    content=(
      #|{
      #|  x: -168.72021484375,
      #|  y: 259.91693115234375,
      #|  width: 99.390625,
      #|  height: 35.79998779296875,
      #|}
    ),
  )
  debug_inspect(
    @font.Stack::default(bold=true).chunks_box(
      chunks(["Blurry", "Photo"], 0.0, -8.4, 16.8),
      14.0,
      anchor="middle",
      baseline=Middle,
    ),
    content=(
      #|{
      #|  x: -20.0859375,
      #|  y: -17.743749618530273,
      #|  width: 40.171875,
      #|  height: 32.79999923706055,
      #|}
    ),
  )
  // The hanging baseline is eight tenths of the ascent up.
  debug_inspect(
    @font.Stack::for_family("verdana").chunks_box(
      chunks(["Wave To", "AV, Ty."], -243.140380859375, 98.80789518492597, 21.0),
      20.0,
      anchor="end",
      baseline=Hanging,
    ),
    content=(
      #|{
      #|  x: -326.718505859375,
      #|  y: 94.80789184570312,
      #|  width: 83.578125,
      #|  height: 45.0234375,
      #|}
    ),
  )
  debug_inspect(
    @font.Stack::for_family("arial").chunks_box(
      chunks(["if x < y"], 163.03125, -6.945028642320949, 0.0),
      12.5,
      anchor="middle",
      baseline=Central,
    ),
    content="{ x: 144.796875, y: -13.945028305053711, width: 36.46875, height: 14 }",
  )
}

///|
/// Text measured under a `viewBox` shown smaller than its size: the
/// widths are whole layout units at the size on screen, scaled back.
test "chunks under a scale" {
  let width = (text : String, scale : Double) => {
    @font.Stack::default().chunks_box(
      [{ text, x: 0.0, y: 13.0, }],
      12.0,
      anchor="middle",
      baseline=Central,
      scale~,
    )
  }
  debug_inspect(
    width("Market research", 0.8238511085510254),
    content=(
      #|{
      #|  x: -43.242034912109375,
      #|  y: 6.32403564453125,
      #|  width: 86.48406982421875,
      #|  height: 13.351926803588867,
      #|}
    ),
  )
  debug_inspect(
    width("Competitive analysis", 0.8238511085510254),
    content=(
      #|{
      #|  x: -55.45601272583008,
      #|  y: 6.32403564453125,
      #|  width: 110.91202545166016,
      #|  height: 13.383695602416992,
      #|}
    ),
  )
  inspect(width("a", 0.840895414352417).width, content="6.3176703453063965")
}
