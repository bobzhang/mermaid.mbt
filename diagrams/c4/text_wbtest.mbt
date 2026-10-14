// Expected sizes are what `getBBox()` reports in the reference browser for
// SVG text in "Open Sans", sans-serif (Helvetica there), rounded.

///|
let open_sans : String = "\"Open Sans\", sans-serif"

///|
test "texts are measured line by line, each box rounded" {
  let bold : Font = { family: open_sans, size: 16.0, weight: "bold", }
  let regular : Font = { family: open_sans, size: 14.0, weight: "normal", }
  let message : Font = { family: open_sans, size: 12.0, weight: "normal", }
  debug_inspect(text_dimensions("global", bold), content="(47, 18)")
  // The tail of `g` hangs below the line: 16.097 high.
  debug_inspect(text_dimensions("[global]", regular), content="(45, 16)")
  debug_inspect(text_dimensions("Uses", message), content="(27, 14)")
  debug_inspect(
    text_dimensions("Uses<br/>[global]", regular),
    content="(45, 32)",
  )
  // Spaces at the ends do not count, and an empty line has no width.
  debug_inspect(text_dimensions(" cat ", regular), content="(19, 16)")
  debug_inspect(text_dimensions("cat<br><br>cat", regular), content="(19, 48)")
  debug_inspect(text_dimensions("", regular), content="(0, 0)")
}

///|
test "weights above 500 are bold" {
  let font = (weight : String) => {
    let font : Font = { family: open_sans, size: 14.0, weight, }
    font
  }
  // 18.6875 wide in the regular face, 20.234375 in the bold one.
  debug_inspect(text_width("cat", font("500")), content="19")
  debug_inspect(text_width("cat", font("600")), content="20")
  debug_inspect(text_width("cat", font("bolder")), content="20")
}

///|
test "a font the port does not embed is refused" {
  let font : Font = { family: "Courier New", size: 14.0, weight: "normal", }
  try text_dimensions("cat", font) catch {
    Unsupported(message) =>
      inspect(
        message,
        content="C4: text in the font family Courier New at weight normal",
      )
    _ => fail("expected Unsupported")
  } noraise {
    _ => fail("expected the font to be refused")
  }
}

///|
test "wrapping breaks before the word that reaches the limit" {
  let font : Font = { family: open_sans, size: 14.0, weight: "normal", }
  inspect(
    wrap_label("the quick brown fox jumps", 80.0, font),
    content="the quick<br/>brown fox<br/>jumps",
  )
  // A word wider than a line is cut and hyphenated.
  inspect(
    wrap_label("incomprehensibilities", 60.0, font),
    content=(
      #|incompreh-<br/>ensibilities
    ),
  )
  // A text with breaks of its own is left alone.
  inspect(wrap_label("a b<br>c d", 10.0, font), content="a b<br>c d")
}

///|
test "font families are written as the CSSOM serializes them" {
  debug_inspect(
    serialize_font_family("'Open Sans' ,sans-serif"),
    content="Some(\"\\\"Open Sans\\\", sans-serif\")",
  )
  debug_inspect(
    serialize_font_family("Trebuchet  MS, Arial"),
    content="Some(\"Trebuchet MS, Arial\")",
  )
  // Anything else would need a CSS parser.
  debug_inspect(
    serialize_font_family("\"Open Sans\", sans-serif;"),
    content="None",
  )
}
