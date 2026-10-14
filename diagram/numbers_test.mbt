///|
test "parseFloat reads the longest numeric prefix" {
  inspect(@diagram.parse_float("12.5"), content="12.5")
  inspect(@diagram.parse_float("  -3e2xyz"), content="-300")
  inspect(@diagram.parse_float(".5"), content="0.5")
  inspect(@diagram.parse_float("5."), content="5")
  inspect(@diagram.parse_float("1e"), content="1")
  inspect(@diagram.parse_float("12abc"), content="12")
  inspect(@diagram.parse_float("-Infinity"), content="-Infinity")
  inspect(@diagram.parse_float("x").is_nan(), content="true")
  inspect(@diagram.parse_float("").is_nan(), content="true")
  inspect(@diagram.parse_float("-.e3").is_nan(), content="true")
}
