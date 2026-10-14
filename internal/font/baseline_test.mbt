// The tops of the boxes `getBBox()` reports in the reference browser for
// `<text y="0">Hxg</text>` under `dominant-baseline`: auto, middle,
// central, hanging, text-before-edge, mathematical, text-after-edge.

///|
fn tops(family : String, size : Double) -> Array[Double] {
  let stack = @font.Stack::for_family(family)
  let top = stack.bbox("Hxg", size).y
  [
    "auto", "middle", "central", "hanging", "text-before-edge", "mathematical", "text-after-edge",
  ].map(baseline => top + stack.baseline_shift(baseline, size))
}

///|
test "dominant-baseline moves the box of Trebuchet MS text" {
  json_inspect(tops("trebuchet ms", 10.0), content=[
    -9, -6.390625, -5.5, -1.796875, 0, -4.5, -11,
  ])
  json_inspect(tops("trebuchet ms", 12.0), content=[
    -11, -7.859375, -7, -2.203125, 0, -5.5, -14,
  ])
  json_inspect(tops("trebuchet ms", 14.0), content=[
    -13, -9.34375, -8, -2.59375, 0, -6.5, -16,
  ])
  json_inspect(tops("trebuchet ms", 17.0), content=[
    -16, -11.5625, -10, -3.203125, 0, -8, -20,
  ])
  json_inspect(tops("trebuchet ms", 23.0), content=[
    -22, -15.984375, -13.5, -4.40625, 0, -11, -27,
  ])
  json_inspect(tops("trebuchet ms", 28.0), content=[
    -26, -18.671875, -16, -5.203125, 0, -13, -32,
  ])
  json_inspect(tops("trebuchet ms", 38.0), content=[
    -36, -26.0625, -22, -7.203125, 0, -18, -44,
  ])
}

///|
test "dominant-baseline moves the box of Verdana and Arial text" {
  json_inspect(tops("verdana", 10.0), content=[
    -10, -7.265625, -6, -2, 0, -5, -12,
  ])
  json_inspect(tops("verdana", 17.0), content=[
    -17, -12.359375, -10.5, -3.40625, 0, -8.5, -21,
  ])
  json_inspect(tops("verdana", 38.0), content=[
    -38, -27.640625, -23, -7.59375, 0, -19, -46,
  ])
  json_inspect(tops("arial", 12.0), content=[
    -11, -7.890625, -7, -2.203125, 0, -5.5, -14,
  ])
  json_inspect(tops("arial", 16.0), content=[
    -14, -9.859375, -8.5, -2.796875, 0, -7, -17,
  ])
  json_inspect(tops("arial", 38.0), content=[
    -34, -24.140625, -21, -6.796875, 0, -17, -42,
  ])
}
