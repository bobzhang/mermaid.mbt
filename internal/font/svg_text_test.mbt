// Lengths and boxes measured in the reference browser, for `<text>` in an
// `<svg width="100%" viewBox="0 0 1000 430">` displayed 740 pixels wide.

///|
const SCALE : Double = 0.7399709224700928

///|
test "text in a scaled diagram is measured in a scaled font" {
  let stack = @font.Stack::default()
  inspect(
    stack.svg_text_length("Sales by category and region", 14.0),
    content="179.53125",
  )
  inspect(
    stack.svg_text_length("Sales by category and region", 14.0, scale=SCALE),
    content="179.35670471191406",
  )
  inspect(
    stack.svg_text_length("Item A1", 38.0, scale=SCALE),
    content="129.56590270996094",
  )
}

///|
test "the box of placed text, anchored and hung from its baseline" {
  let stack = @font.Stack::default()
  let box = stack.svg_text_box(
    "Sales by category and region",
    14.0,
    x=500.0,
    y=15.0,
    anchor="middle",
    baseline="middle",
    scale=SCALE,
  )
  json_inspect([box.x, box.y, box.width, box.height], content=[
    410.3216552734375, 5.138970375061035, 179.35670471191406, 16.382478713989258,
  ])
  let unscaled = stack.svg_text_box(
    "Sales by category and region",
    14.0,
    x=500.0,
    y=15.0,
    anchor="middle",
    baseline="middle",
  )
  json_inspect([unscaled.x, unscaled.y, unscaled.width, unscaled.height], content=[
    410.234375, 5.65625, 179.53125, 16,
  ])
}
