///|
/// A label drawn as SVG text by mermaid's `createText` without HTML.
pub struct SvgTextLabel {
  /// The group holding the background rectangle and the text.
  group : @dom.Element
  /// The `<text>` element.
  text : @dom.Element
  /// The box `getBBox()` reports for the text element.
  box : @dom.Rect
}

///|
/// mermaid's `createText(parent, text, { useHtmlLabels: false, width })`
/// for a diagram that draws its own labels: the label is laid out in the
/// diagram's font and broken into lines no wider than `width`. Its text
/// inherits `text-anchor` (`anchor_middle`) and `dominant-baseline`
/// (`baseline`) from the element it is drawn in, which only change where
/// the browser puts the glyphs and so the box.
pub fn create_svg_text(
  parent : @dom.Element,
  text : String,
  config : @config.Config,
  diagram_id : String,
  width? : Double,
  anchor_middle~ : Bool = false,
  baseline~ : @font.Baseline = Alphabetic,
) -> SvgTextLabel {
  let env = Env::new(config, diagram_id)
  let label = create_svg_label(parent, text, env, width?, anchor_middle~)
  let box = if baseline == Alphabetic {
    label.text_box
  } else {
    text_box_on_baseline(label.lines, env, anchor_middle, baseline)
  }
  if text != "" {
    label.element.set_text_box(box)
  }
  { group: label.group, text: label.element, box, }
}

///|
/// `text_box` for text on another baseline than the alphabetic one: every
/// cell reaches as far above and below that baseline as Blink rounds it,
/// and the glyphs move down with it.
fn text_box_on_baseline(
  lines : Array[Array[Word]],
  env : Env,
  anchor_middle : Bool,
  baseline : @font.Baseline,
) -> @dom.Rect {
  let mut box : BoxF = { x: 0, y: 0, width: 0, height: 0, }
  let size = env.font_size
  let f = Float::from_double
  for index, line in lines {
    let y = em_to_px(index.to_double() * 1.1 - 0.1, size)
    let line_baseline = y + em_to_px(1.1, size)
    let items = line_items_text(line)
    let widths = item_widths(items, env)
    let inks = item_inks(items, env)
    let total = widths.fold(init=0.0, (a, b) => a + b)
    let mut x = if anchor_middle { -total / 2.0 } else { 0.0 }
    for k, item in items {
      let font = env.font(bold=item.bold, italic=item.italic)
      let (font_ascent, _) = font.line_metrics(size)
      let (ascent, descent) = font.baseline_extents(size, baseline)
      let cell : BoxF = {
        x: f(x),
        y: line_baseline - ascent,
        width: f(widths[k]),
        height: ascent + descent,
      }
      let ink = inks[k]
      let ink_box : BoxF = {
        x: f(ink.x) + cell.x,
        y: f(ink.y) + f(font_ascent) + cell.y,
        width: f(ink.width),
        height: f(ink.height),
      }
      box = box.unite(ink_box.unite(cell))
      x += widths[k]
    }
  }
  {
    x: box.x.to_double(),
    y: box.y.to_double(),
    width: box.width.to_double(),
    height: box.height.to_double(),
  }
}
