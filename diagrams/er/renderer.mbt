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
  if layout != "elk" &&
    layout != "swimlane" &&
    !@rendering.is_dagre_layout(layout) {
    raise @rendering.LayoutError("The \{layout} layout is not supported yet.")
  }
  if config.text("look") == Some("handDrawn") {
    raise @rendering.LayoutError("The hand-drawn look is not supported yet.")
  }
  let (nodes, edges) = db.layout_data(dagre=layout != "elk")
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
  @rendering.insert_title(
    context.svg,
    db.title,
    "erDiagramTitleText",
    config.number("er.titleTopMargin").unwrap_or(25.0),
    config,
  )
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
