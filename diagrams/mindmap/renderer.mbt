// The mindmap renderer: mermaid's `mindmapRenderer.ts`.

///|
/// The layouts mermaid registers, by the names a configuration gives
/// them: `getRegisteredLayoutAlgorithm` hands any other name the
/// fallback.
let registered_layouts : Array[String] = [
  "dagre", "swimlane", "cose-bilkent", "elk", "elk.stress", "elk.force", "elk.mrtree",
  "elk.sporeOverlap", "elk.box", "elk.rectpacking",
]

///|
/// The layout a mindmap is drawn with: cose-bilkent unless the site
/// configuration or the diagram names a layout mermaid has.
fn layout_algorithm(config : @config.Config) -> String {
  match config.user_defined("layout") {
    String(name) if registered_layouts.contains(name) => name
    _ => "cose-bilkent"
  }
}

///|
/// Draw the mindmap into the context's `<svg>` element.
pub fn draw(
  db : MindmapDb,
  context : @diagram.Context,
) -> Unit raise MindmapError {
  let config = context.config
  let layout = layout_algorithm(config)
  if layout.has_prefix("elk") {
    // Upstream's ELK layout fails on what the mindmap hands it.
    raise Invalid("Cannot read properties of null (reading 're')")
  }
  if layout != "cose-bilkent" {
    raise Unsupported("The \{layout} layout is not supported yet.")
  }
  if config.text("look") == Some("handDrawn") {
    raise Unsupported("The hand-drawn look is not supported yet.")
  }
  guard db.root() is Some(_) else { return }
  let (nodes, edges) = db.layout_data()
  let data : @rendering.LayoutData = {
    nodes,
    edges,
    config,
    diagram_type: "mindmap",
    diagram_id: context.id,
    direction: "TB",
    markers: ["point"],
  }
  @rendering.render_cose(data, context.svg) catch {
    @rendering.LayoutError(message) => raise Unsupported(message)
  }
  let theme = config.theme()
  if theme.flag("useGradient") &&
    theme.flag("gradientStart") &&
    theme.flag("gradientStop") {
    let gradient = context.svg
      .append("defs")
      .append("linearGradient")
      .attr("id", "\{context.id}-gradient")
      .attr("gradientUnits", "objectBoundingBox")
      .attr("x1", "0%")
      .attr("y1", "0%")
      .attr("x2", "100%")
      .attr("y2", "0%")
    gradient
    .append("stop")
    .attr("offset", "0%")
    .attr("stop-color", theme.text("gradientStart"))
    .attr("stop-opacity", "1")
    |> ignore
    gradient
    .append("stop")
    .attr("offset", "100%")
    .attr("stop-color", theme.text("gradientStop"))
    .attr("stop-opacity", "1")
    |> ignore
  }
  @rendering.setup_viewport(
    context.svg,
    config.number("mindmap.padding").unwrap_or(10.0),
    "mindmapDiagram",
    match config.get("mindmap.useMaxWidth") {
      Null => true
      value => @config.evaluate(value)
    },
  )
}
