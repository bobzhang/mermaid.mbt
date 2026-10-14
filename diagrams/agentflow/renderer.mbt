///|
/// Draw the agentflow into the context's `<svg>` element: mermaid's
/// `agentflow/renderer.ts`, through the unified renderer.
pub fn draw(
  db : AgentDb,
  context : @diagram.Context,
) -> Unit raise @rendering.LayoutError {
  let config = context.config
  // What the port cannot draw yet is refused rather than drawn differently.
  let layout = config.text("layout").unwrap_or("elk")
  if layout != "elk" && !@rendering.is_dagre_layout(layout) {
    raise @rendering.LayoutError("The \{layout} layout is not supported yet.")
  }
  let (nodes, edges) = db.layout_data()
  let data : @rendering.LayoutData = {
    nodes,
    edges,
    config,
    diagram_type: "agentflow",
    diagram_id: context.id,
    direction: db.direction().unwrap_or("TB"),
    markers: ["point", "circle", "cross", "hierarchy"],
  }
  @rendering.render(data, context.svg)
  @flowchart.insert_title(
    db.title,
    context,
    css_class="agentflowTitleText",
    section="agentflow",
  )
  @rendering.setup_viewport(
    context.svg,
    config.number("agentflow.diagramPadding").unwrap_or(8.0),
    "agentflow",
    config.flag("agentflow.useMaxWidth"),
  )
}
