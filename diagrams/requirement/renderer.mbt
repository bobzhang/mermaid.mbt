///|
/// Draw the diagram into the context's `<svg>` element: mermaid's
/// `requirementRenderer`.
pub fn draw(
  db : RequirementDb,
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
  // Upstream draws a requirement and an element of one name as two nodes
  // with the same id, one of which is then never placed.
  for name, _ in db.elements {
    if db.requirements.contains(name) {
      raise @rendering.LayoutError(
        "A requirement and an element both named \{name} are not supported.",
      )
    }
  }
  let (nodes, edges) = db.layout_data()
  let markers = if config.text("look") == Some("neo") {
    ["requirement_contains_neo", "requirement_arrow_neo"]
  } else {
    ["requirement_contains", "requirement_arrow"]
  }
  let data : @rendering.LayoutData = {
    nodes,
    edges,
    config,
    diagram_type: "requirement",
    diagram_id: context.id,
    direction: db.direction(),
    markers,
  }
  @rendering.render(data, context.svg)
  // Upstream reads the state diagram's settings for the title and the size.
  @rendering.insert_title(
    context.svg,
    db.title,
    "requirementDiagramTitleText",
    config.number("state.titleTopMargin").unwrap_or(25.0),
    config,
  )
  @rendering.setup_viewport(
    context.svg,
    8.0,
    "requirementDiagram",
    match config.get("state.useMaxWidth") {
      Null => true
      value => @config.evaluate(value)
    },
  )
}
