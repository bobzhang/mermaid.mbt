///|
/// Draw the diagram into the context's `<svg>` element: mermaid's
/// `erRenderer-unified`.
pub fn draw(
  db : ErDb,
  context : @diagram.Context,
) -> Unit raise @rendering.LayoutError {
  let config = context.config
  // What the port cannot draw yet is refused rather than drawn differently.
  // Only `elk` names the layered ELK layout; every other name, known or
  // not, ends in another engine upstream.
  let layout = config.text("layout").unwrap_or("elk")
  if layout != "elk" {
    raise @rendering.LayoutError("The \{layout} layout is not supported yet.")
  }
  if config.text("look") == Some("handDrawn") {
    raise @rendering.LayoutError("The hand-drawn look is not supported yet.")
  }
  let (nodes, edges) = db.layout_data()
  let markers = if config.text("look") == Some("neo") {
    ["only_one_neo", "zero_or_one_neo", "one_or_more_neo", "zero_or_more_neo"]
  } else {
    ["only_one", "zero_or_one", "one_or_more", "zero_or_more"]
  }
  let data : @rendering.LayoutData = {
    nodes,
    edges,
    config,
    diagram_type: "er",
    diagram_id: context.id,
    direction: db.direction(),
    markers,
  }
  @rendering.render(data, context.svg)
  insert_title(db.title, context)
  @rendering.setup_viewport(
    context.svg,
    8.0,
    "erDiagram",
    match config.get("er.useMaxWidth") {
      Null => true
      value => @config.evaluate(value)
    },
  )
}

///|
/// The diagram title, centred above the chart: mermaid's `insertTitle`.
fn insert_title(title : String, context : @diagram.Context) -> Unit {
  if title == "" {
    return
  }
  let config = context.config
  let svg = context.svg
  let bounds = svg.bbox()
  let margin = config.number("er.titleTopMargin").unwrap_or(25.0)
  let x = bounds.x + bounds.width / 2.0
  let y = -margin
  let text = svg
    .append("text")
    .text(title)
    .attr("text-anchor", "middle")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("class", "erDiagramTitleText")
  // No rule sizes this class: the title is set in the diagram's font.
  let theme = config.theme()
  let font = @font.Stack::for_family(theme.text("fontFamily"))
  let size = @diagram.parse_font_size(theme.text("fontSize")).unwrap_or(16.0)
  let box = font.bbox(title, size)
  text.set_text_box({
    x: x - font.advance(title, size) / 2.0 + box.x,
    y: y + box.y,
    width: box.width,
    height: box.height,
  })
}
