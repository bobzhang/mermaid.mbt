///|
/// The rows a line of 16px Trebuchet MS takes in a box `width` wide.
fn rows_of(text : String, width : Double, bold~ : Bool = false) -> Int32 raise {
  let env = Env::new(@config.Config::new(), "id")
  let line : Array[Run] = [{ text, bold, italic: false, heavy: false, }]
  wrapped_rows(line, width, env).0
}

///|
test "a line may overflow its box by one layout unit" {
  // 200.015625 wide in Chrome, and on one line in a box 200 wide.
  inspect(rows_of("omega theta chi Notes Mind", 200.0), content="1")
  inspect(rows_of("omega theta chi Notes Mind", 199.984375), content="2")
}

///|
test "rows are measured unrounded from where they start" {
  // Chrome's rows, read off with Range client rects: "delta chi chi x ",
  // "Planning a/b #1 ", "well-known ", "epsilon ", "Strategy nu ",
  // "kappa Mind ", "Ideas Strategy". The rounded widths of "epsilon " and
  // "Strategy " add up to 120.015625; their unrounded sum does not fit.
  inspect(
    rows_of(
      "delta chi chi x Planning a/b #1 well-known epsilon Strategy nu kappa Mind Ideas Strategy",
      120.0,
    ),
    content="7",
  )
  // "lambda ", "AV mu ", "a/b ", "gamma ", "Strategy": the row that
  // starts at "AV" is shaped anew, without the kerning of the space
  // before it.
  inspect(
    rows_of("lambda AV mu a/b gamma Strategy", 80.0, bold=true),
    content="5",
  )
}
