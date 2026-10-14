// The expected placements were read out of the reference browser:
// `getScreenCTM()` inside an `<svg width="100%" style="max-width: Wpx">`
// with the view box `0 0 W H`, alone in the page.

///|
fn placed(width : Double, height : Double) -> String raise {
  let context = @diagram.Context::new(
    "id",
    @config.Config::new(),
    @dom.Element::new("svg"),
    now=0.0,
    page=@diagram.Page::new(),
  )
  let placement = context.placement(width, height, max_width=width)
  "\{placement.scale} \{placement.left + placement.dx} \{placement.top + placement.dy}"
}

///|
test "a diagram narrower than the page is drawn at its own size" {
  inspect(placed(700.0, 500.0), content="1 8 8")
}

///|
test "a wider diagram is scaled down to the page" {
  inspect(placed(1000.0, 400.0), content="0.74 8 8")
  inspect(placed(1500.0, 900.0), content="0.49333333333333335 8 8")
  inspect(placed(2000.0, 300.0), content="0.37 8 8")
  inspect(placed(800.0, 100.0), content="0.925 8 8")
  inspect(placed(760.0, 380.0), content="0.9736842105263158 8 8")
  // Tall enough for a scrollbar, which narrows the page.
  inspect(placed(5000.0, 5000.0), content="0.145 8 8")
}

///|
test "a height cut to whole layout units leaves the diagram centred" {
  inspect(placed(900.0, 600.0), content="0.805546875 8.003906249999979 8")
  inspect(
    placed(726.0, 485.0),
    content="0.9986146907216494 8.002867268041234 8",
  )
  inspect(
    placed(741.0, 300.0),
    content="0.9986458333333333 8.001718750000014 8",
  )
  inspect(
    placed(720.0, 500.3),
    content="0.9999937781470224 8.002239867071955 8",
  )
  inspect(
    placed(733.7, 211.9),
    content="0.9999557862352325 8.009963716359186 8",
  )
  inspect(placed(700.3, 500.0), content="0.99996875 8.009385790824904 8")
  inspect(placed(333.3, 444.4), content="0.9999789178744081 8.00195693961684 8")
}
