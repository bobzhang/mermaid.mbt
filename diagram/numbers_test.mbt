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

///|
test "Number() of configuration and metadata values" {
  let number = (value : Json) => @diagram.to_number(value).to_string()
  inspect(number(Json::number(96)), content="96")
  inspect(number(Json::string(" 20 ")), content="20")
  inspect(number(Json::string("0x20")), content="32")
  inspect(number(Json::string("")), content="0")
  inspect(number(Json::string("20px")), content="NaN")
  inspect(number(Json::boolean(true)), content="1")
  inspect(number(Json::null()), content="0")
  inspect(number(Json::array([])), content="0")
  inspect(number(Json::array([Json::string("5")])), content="5")
  inspect(
    number(Json::array([Json::number(1), Json::number(2)])),
    content="NaN",
  )
  inspect(number(Json::object(Map([]))), content="NaN")
}
