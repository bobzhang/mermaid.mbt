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
  ) => stack.bbox_middle(text, size, x~, y~)
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
