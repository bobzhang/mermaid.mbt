///|
/// Draw the flowchart into the context's `<svg>` element: mermaid's
/// `flowRenderer-v3-unified`.
pub fn draw(
  db : FlowDb,
  context : @diagram.Context,
) -> Unit raise @rendering.LayoutError {
  let config = context.config
  let (nodes, edges) = db.layout_data()
  let data : @rendering.LayoutData = {
    nodes,
    edges,
    config,
    diagram_type: "flowchart-v2",
    diagram_id: context.id,
    direction: db.direction().unwrap_or("TB"),
    markers: ["point", "circle", "cross"],
  }
  @rendering.render(data, context.svg)
  insert_title(db.title, context)
  let padding = config.number("flowchart.diagramPadding").unwrap_or(8.0)
  @rendering.setup_viewport(
    context.svg,
    padding,
    "flowchart",
    config.flag("flowchart.useMaxWidth"),
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
  let margin = match config.number("flowchart.titleTopMargin") {
    Some(margin) => margin
    None => 0.0
  }
  let x = bounds.x + bounds.width / 2.0
  let y = -margin
  let text = svg
    .append("text")
    .text(title)
    .attr("text-anchor", "middle")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("class", "flowchartTitleText")
  // The stylesheet sets titles at 18px in the diagram's font.
  let font = @font.Stack::for_family(config.theme().text("fontFamily"))
  let size = 18.0
  let box = font.bbox(title, size)
  // Anchored in the middle of its advance, which is whole layout units.
  text.set_text_box({
    x: x - font.advance(title, size) / 2.0 + box.x,
    y: y + box.y,
    width: box.width,
    height: box.height,
  })
}
