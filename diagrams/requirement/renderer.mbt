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
  if layout != "elk" {
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
  insert_title(db.title, context)
  // Upstream reads the state diagram's settings here.
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

///|
/// The diagram title, centred above the chart: mermaid's `insertTitle`.
fn insert_title(title : String, context : @diagram.Context) -> Unit {
  if title == "" {
    return
  }
  let config = context.config
  let svg = context.svg
  let bounds = svg.bbox()
  let margin = config.number("state.titleTopMargin").unwrap_or(25.0)
  let x = bounds.x + bounds.width / 2.0
  let y = -margin
  let text = svg
    .append("text")
    .text(title)
    .attr("text-anchor", "middle")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("class", "requirementDiagramTitleText")
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
