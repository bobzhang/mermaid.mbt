// The expected scales were read out of the reference browser
// (`getScreenCTM()` of an `<svg width="100%">` with the given view box,
// alone in the page).

///|
fn scale(
  width : Double,
  height : Double,
  font_family? : String,
) -> Double raise {
  let site : Json = match font_family {
    Some(family) => { "fontFamily": Json::string(family) }
    None => Json::object(Map([]))
  }
  let context = @diagram.Context::new(
    "id",
    @config.Config::new(site~),
    @dom.Element::new("svg"),
    now=0.0,
    page=@diagram.Page::new(),
  )
  context.view_box_scale(width, height)
}

///|
test "a diagram as wide as its container is drawn at its own size" {
  inspect(scale(740.0, 196.0), content="1")
  inspect(scale(740.0, 449.0), content="1")
}

///|
test "a tall diagram brings a scrollbar and shrinks with the page" {
  // 449.5 units and the 4 pixels of line below round to more than the
  // viewport holds.
  inspect(scale(740.0, 449.484375), content="1")
  inspect(scale(740.0, 449.5), content="0.9796996662958843")
  inspect(scale(740.0, 508.0), content="0.9796998031496063")
  // Verdana leaves a pixel less below the baseline.
  inspect(scale(740.0, 450.0, font_family="verdana"), content="1")
  inspect(
    scale(740.0, 450.5, font_family="verdana"),
    content="0.9797100443951166",
  )
}

///|
test "a diagram of another width is fitted to the container" {
  inspect(scale(1000.0, 500.0), content="0.74")
  inspect(scale(1000.0, 333.33), content="0.7399761795704064")
  inspect(scale(333.0, 777.0), content="2.177163770913771")
  inspect(scale(1234.5, 567.8), content="0.5994078149295349")
}

///|
/// The scale of a diagram whose `<svg>` is limited to the width of its
/// view box (`max-width`), or has its size as attributes (`fixed`).
fn limited_scale(
  width : Double,
  height : Double,
  fixed~ : Bool = false,
) -> Double raise {
  let context = @diagram.Context::new(
    "id",
    @config.Config::new(),
    @dom.Element::new("svg"),
    now=0.0,
    page=@diagram.Page::new(),
  )
  context.view_box_scale(width, height, max_width=width, fixed~)
}

///|
test "a diagram limited to its own width shrinks but does not grow" {
  inspect(limited_scale(1000.0, 400.0), content="0.74")
  // The height is cut to a layout unit, and decides.
  inspect(limited_scale(1000.0, 430.0), content="0.7399709302325581")
  inspect(limited_scale(960.0, 500.0), content="0.7708125")
  // Tall enough for a scrollbar, which narrows the page.
  inspect(limited_scale(1000.0, 607.42), content="0.7399894432950906")
  inspect(limited_scale(1000.0, 607.5), content="0.725")
  // Narrower than the page: as drawn, or a hair less when its size is
  // not a whole number of layout units.
  inspect(limited_scale(500.0, 300.0), content="1")
  inspect(limited_scale(333.33, 100.0), content="0.99984375")
}

///|
test "a diagram of a fixed size is drawn at that size" {
  inspect(limited_scale(1000.0, 400.0, fixed=true), content="1")
  inspect(limited_scale(2000.0, 3000.0, fixed=true), content="1")
}
