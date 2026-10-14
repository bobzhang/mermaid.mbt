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
  text.set_text_box({
    x: x - font.advance(title, env.font_size) / 2.0 + box.x,
    y: y + box.y,
    width: box.width,
    height: box.height,
  })
}
