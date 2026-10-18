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

///|
test "css_font_size reads signs and exponents as CSS does" {
  // The computed sizes in the reference browser, under a 16px parent;
  // `1.5.5px`, which it ignores, is not measured.
  let sizes = [
    "+12px", "1e1px", "+.75em", "1.25e0em", "+150%", "1.5.5px", "1e1",
  ].map(size => {
    match @diagram.css_font_size(Json::string(size), 16.0) {
      Some(value) => value.to_string()
      None => "-"
    }
  })
  inspect(sizes.join(" "), content="12 10 12 20 24 - 16")
  // A negative size is invalid: the parent's stays.
  inspect(
    @diagram.css_font_size(Json::string("-16px"), 20.0).unwrap_or(0.0),
    content="20",
  )
  inspect(
    @diagram.css_font_size(Json::string("-1em"), 20.0).unwrap_or(0.0),
    content="20",
  )
  // Zero is a length with a unit or without; other bare numbers are not.
  inspect(
    ["0", "0px", "-0", "0em", "1"]
    .map(size => {
      @diagram.css_font_size(Json::string(size), 20.0)
      .unwrap_or(-1.0)
      .to_string()
    })
    .join(" "),
    content="0 0 0 0 20",
  )
}

///|
test "a font size given as the number zero is a length, as the string is" {
  debug_inspect(
    @diagram.css_font_size(Json::number(0.0), 16.0),
    content="Some(0)",
  )
  debug_inspect(
    @diagram.css_font_size(Json::string("0"), 16.0),
    content="Some(0)",
  )
  debug_inspect(
    @diagram.css_font_size(Json::number(12.0), 16.0),
    content="Some(16)",
  )
}
