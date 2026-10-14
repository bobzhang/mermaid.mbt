///|
test "the scale a viewBox is shown at in the reference page" {
  // The default Cynefin diagram: taller than the window, so the page has
  // a scrollbar and is 725 px wide; the height that follows from the
  // aspect ratio, rounded down to 1/64 px, gives the scale.
  debug_inspect(
    @diagram.text_scale(880.0, 680.0, true),
    content="Some(0.8238511085510254)",
  )
  // Short enough to fit the window: no scrollbar, 740 px.
  debug_inspect(
    @diagram.text_scale(880.0, 520.0, true),
    content="Some(0.840895414352417)",
  )
  // Narrower than the page, or sized by its attributes: not scaled.
  debug_inspect(@diagram.text_scale(680.0, 380.0, true), content="Some(1)")
  debug_inspect(@diagram.text_scale(420.0, 920.0, true), content="Some(1)")
  debug_inspect(@diagram.text_scale(1025.0, 725.0, false), content="Some(1)")
  // Sizes off the layout-unit grid are not modelled.
  debug_inspect(@diagram.text_scale(880.3, 680.0, true), content="None")
}
