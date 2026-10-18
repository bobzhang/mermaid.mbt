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
/// Refuse labels the port cannot measure as the browser does: characters
/// no embedded face has (the browser draws them from a system fallback
/// font) unless their advances were read off it, and then only in HTML
/// labels (SVG text takes the height of the fallback font), and subscripts
/// and superscripts (which change the height of their line).
fn check_measurable(
  db : MindmapDb,
  config : @config.Config,
) -> Unit raise MindmapError {
  let family = config.theme().text("fontFamily")
  let html_labels = match config.get("htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
  let stacks = [
    @font.Stack::for_family(family),
    @font.Stack::for_family(family, bold=true),
  ]
  for node in db.nodes() {
    // The text as the browser has it: references resolved.
    let text = @dom.sanitized_text(@dom.placeholders_to_references(node.descr))
    let lower = text.to_lower()
    if lower.contains("<sub") || lower.contains("<sup") {
      raise Unsupported(
        "subscripts and superscripts in mindmap labels are not measured: \{node.descr}",
      )
    }
    // Line breaks and tabs are laid out, not drawn.
    let drawn = String::from_iter(
      text.iter().map(c => if c is ('\n' | '\r' | '\t') { ' ' } else { c }),
    )
    for stack in stacks {
      let missing = if html_labels {
        stack.first_unmeasured(drawn)
      } else {
        stack.first_uncovered(drawn)
      }
      if missing is Some(c) {
        raise Unsupported(
          "the character \{c} has no embedded font to measure it with: \{node.descr}",
        )
      }
    }
  }
}

///|
/// Draw the mindmap into the context's `<svg>` element.
pub fn draw(
  db : MindmapDb,
  context : @diagram.Context,
) -> Unit raise MindmapError {
  let config = context.config
  // Without a node upstream returns before anything is laid out.
  guard db.root() is Some(_) else { return }
  let layout = layout_algorithm(config)
  if layout.has_prefix("elk") {
    // Upstream's ELK layout fails on what the mindmap hands it.
    raise Invalid("Cannot read properties of null (reading 're')")
  }
  if !(layout is ("cose-bilkent" | "dagre")) {
    raise Unsupported("The \{layout} layout is not supported yet.")
  }
  check_measurable(db, config)
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
  let render = if layout == "dagre" {
    @rendering.render
  } else {
    @rendering.render_cose
  }
  render(data, context.svg) catch {
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
