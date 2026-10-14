///|
/// The gradient the themes with `useGradient` outline shapes with.
fn append_gradient(
  svg : @dom.Element,
  id : String,
  theme : @theme.Theme,
) -> Unit {
  let gradient = svg
    .append("defs")
    .append("linearGradient")
    .attr("id", "\{id}-gradient")
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

///|
/// The diagram title, centred on the graph: mermaid's `insertTitle`.
fn Renderer::insert_title(self : Renderer, svg : @dom.Element) -> Unit {
  let title = self.graph.title
  if title == "" {
    return
  }
  let bounds = svg.bbox()
  let margin = self.config.number("gitGraph.titleTopMargin").unwrap_or(0.0)
  let x = bounds.x + bounds.width / 2.0
  let y = -margin
  let text = svg
    .append("text")
    .text(title)
    .attr("text-anchor", "middle")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("class", "gitTitleText")
  // The stylesheet sets titles at 18px and anchors them in the middle.
  place_text(text, self.font(), 18.0, middle=true)
}

///|
/// Draw the git graph into the context's `<svg>` element: mermaid's
/// `gitGraphRenderer.ts`.
///
/// Raises `GitError` where upstream's renderer throws, and `Unsupported`
/// for a theme whose font sizes cannot be measured.
pub fn draw(graph : GitGraph, context : @diagram.Context) -> Unit raise {
  let config = context.config
  let theme = config.theme()
  let svg = context.svg
  let theme_name = config.text("theme").unwrap_or("")
  // The `<svg>` element takes the theme's font size; the page around it
  // has the browser's default.
  let font_size = css_font_size("fontSize", theme.get("fontSize"), 16.0)
  let renderer : Renderer = {
    graph,
    config,
    id: context.id,
    theme_name,
    dir: graph.direction,
    branch_pos: Map([]),
    commit_pos: Map([]),
    lanes: [],
    max_pos: 0.0,
    family: theme.text("fontFamily"),
    font_size,
    commit_label_size: css_font_size(
      "commitLabelFontSize",
      theme.get("commitLabelFontSize"),
      font_size,
    ),
    tag_label_size: css_font_size(
      "tagLabelFontSize",
      theme.get("tagLabelFontSize"),
      font_size,
    ),
  }
  if theme.flag("useGradient") {
    append_gradient(svg, context.id, theme)
  }
  if config.text("look") == Some("neo") && is_redux_theme(theme_name) {
    svg
    .append("defs")
    .append("filter")
    .attr("id", "\{context.id}-drop-shadow")
    .attr("height", "130%")
    .attr("width", "130%")
    .append("feDropShadow")
    .attr("dx", "4")
    .attr("dy", "4")
    .attr("stdDeviation", "0")
    .attr("flood-opacity", "0.06")
    .attr("flood-color", theme.text("filterColor"))
    |> ignore
  }
  // Branches are spaced by the width of their names, measured in the
  // weight of plain labels whatever the theme draws them in later.
  let branches = graph.branch_names()
  let rotate = renderer.setting("rotateCommitLabel")
  let mut pos = 0.0
  for index, name in branches {
    let (_, box) = branch_label(name, renderer.font(), renderer.font_size)
    renderer.branch_pos[name] = (pos, index)
    pos += 50.0 +
      (if rotate { 40.0 } else { 0.0 }) +
      (if renderer.vertical() { box.width / 2.0 } else { 0.0 })
  }
  renderer.draw_commits(svg, false)
  if renderer.setting("showBranches") {
    renderer.draw_branches(svg, branches)
  }
  renderer.draw_arrows(svg)
  renderer.draw_commits(svg, true)
  renderer.insert_title(svg)
  // `setupGraphViewbox`
  let padding = config.number("gitGraph.diagramPadding").unwrap_or(0.0)
  let bounds = svg.bbox()
  let width = bounds.width + padding * 2.0
  let height = bounds.height + padding * 2.0
  @diagram.configure_svg_size(
    svg,
    height,
    width,
    renderer.setting("useMaxWidth"),
  )
  let n = @dom.number
  svg.attr(
    "viewBox",
    "\{n(bounds.x - padding)} \{n(bounds.y - padding)} \{n(bounds.width + 2.0 * padding)} \{n(bounds.height + 2.0 * padding)}",
  )
  |> ignore
}
