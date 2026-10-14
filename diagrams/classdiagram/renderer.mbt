///|
/// Draw the diagram into the context's `<svg>` element: mermaid's
/// `classRenderer-v3-unified`.
pub fn draw(
  db : ClassDb,
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
  let data : @rendering.LayoutData = {
    nodes,
    edges,
    config,
    diagram_type: "classDiagram",
    diagram_id: context.id,
    direction: db.direction(),
    markers: [
      "aggregation", "extension", "composition", "dependency", "lollipop",
    ],
  }
  @rendering.render(data, context.svg)
  // The renderer reads the title margin and the width setting of state
  // diagrams.
  @rendering.insert_title(
    context.svg,
    db.title,
    "classDiagramTitleText",
    config.number("state.titleTopMargin").unwrap_or(25.0),
    config,
  )
  @rendering.setup_viewport(
    context.svg,
    8.0,
    "classDiagram",
    match config.get("state.useMaxWidth") {
      Null => true
      value => @config.evaluate(value)
    },
  )
}
