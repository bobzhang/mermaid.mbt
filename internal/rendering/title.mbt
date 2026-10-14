///|
/// The diagram title, centred above what is drawn: mermaid's
/// `insertTitle` for the diagrams whose stylesheet has no rule for the
/// title's class, so that it is set in the diagram's own font and size.
pub fn insert_title(
  svg : @dom.Element,
  title : String,
  css_class : String,
  top_margin : Double,
  config : @config.Config,
) -> Unit {
  if title == "" {
    return
  }
  let bounds = svg.bbox()
  let x = bounds.x + bounds.width / 2.0
  let y = -top_margin
  let text = svg
    .append("text")
    .text(title)
    .attr("text-anchor", "middle")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("class", css_class)
  let env = Env::new(config, "")
  let font = env.font()
  let box = font.bbox(title, env.font_size)
  // Anchored in the middle of its advance, which is whole layout units.
  // Positions are single precision in the browser (which shows once the
  // hand-drawn look leaves the chart at an uneven width), and the shift
  // that centres the text comes from both of its ends.
  let f = Float::from_double
  let left = f(x)
  let right = left + f(font.advance(title, env.font_size))
  let start = left + (left - (left + right) / 2)
  text.set_text_box({
    x: (start + f(box.x)).to_double(),
    y: (f(y) + f(box.y)).to_double(),
    width: box.width,
    height: box.height,
  })
}
