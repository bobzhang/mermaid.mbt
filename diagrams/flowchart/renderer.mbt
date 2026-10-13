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
  let padding = config.number("flowchart.diagramPadding").unwrap_or(8.0)
  @rendering.setup_viewport(
    context.svg,
    padding,
    "flowchart",
    config.flag("flowchart.useMaxWidth"),
  )
}
