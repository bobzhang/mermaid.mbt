///|
/// The palette rules of colour themes: a colour per node kind, and the
/// slots above the kinds cycled by containers, expanded or collapsed.
fn color_sections(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  let borders = theme.get("borderColorArray")
  let fills = theme.get("bkgColorArray")
  if !@flowchart.is_color_theme(theme_name, borders) {
    return ""
  }
  let look = @rendering.safe_look(look)
  let has_fills = fills is Array([_, ..])
  let palette_length = match borders {
    Array(colors) => colors.length()
    _ => 0
  }
  let border = (slot : Int32) => @flowchart.palette_color(borders, slot)
  let fill = (slot : Int32) => {
    if has_fills {
      "fill: \{@flowchart.palette_color(fills, slot)};"
    } else {
      ""
    }
  }
  let out = StringBuilder()
  for entry in kind_slots {
    let (kind, slot) = entry
    let sel = "[data-look=\"\{look}\"].node.af-kind-\{kind}"
    out.write_string(
      (
        $|
        $|
        $|    \{sel} rect,
        $|    \{sel} path,
        $|    \{sel} polygon {
        $|      stroke: \{border(slot)};
        $|      \{fill(slot)}
        $|    }
        $|
      ),
    )
  }
  for i in 0..<container_slot_count(palette_length) {
    let slot = container_slot(i, palette_length)
    let expanded = "[data-look=\"\{look}\"][data-color-id=\"color-\{slot}\"].cluster"
    let collapsed = "[data-look=\"\{look}\"][data-color-id=\"color-\{slot}\"].node"
    let rule = (suffix : String) => {
      "\{expanded} \{suffix}, \{collapsed} \{suffix}"
    }
    out.write_string(
      (
        $|
        $|
        $|    \{rule("rect")},
        $|    \{rule("path")} {
        $|      stroke: \{border(slot)};
        $|      \{fill(slot)}
        $|    }
        $|
      ),
    )
  }
  out.to_string()
}

///|
/// The agentflow stylesheet, before it is scoped to the diagram: mermaid's
/// `agentflow/styles.ts`.
pub fn styles(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  let v = (name : String) => theme.text(name)
  let text_color = if theme.flag("nodeTextColor") {
    v("nodeTextColor")
  } else {
    v("textColor")
  }
  let stroke_width = (default : String) => {
    match theme.get("strokeWidth") {
      Null => default
      _ => v("strokeWidth")
    }
  }
  let background = v("edgeLabelBackground")
  (
    $|\{color_sections(theme, theme_name, look)}
    $|  .label {
    $|    font-family: \{v("fontFamily")};
    $|    color: \{text_color};
    $|  }
    $|  .cluster-label text {
    $|    fill: \{v("titleColor")};
    $|  }
    $|  .cluster-label span {
    $|    color: \{v("titleColor")};
    $|  }
    $|  .cluster-label span p {
    $|    background-color: transparent;
    $|  }
    $|  .label text,span {
    $|    fill: \{text_color};
    $|    color: \{text_color};
    $|  }
    $|  .node rect,
    $|  .node circle,
    $|  .node ellipse,
    $|  .node polygon,
    $|  .node path {
    $|    fill: \{v("mainBkg")};
    $|    stroke: \{v("nodeBorder")};
    $|    stroke-width: \{stroke_width("1")}px;
    $|  }
    $|  .rough-node .label text , .node .label text, .image-shape .label, .icon-shape .label {
    $|    text-anchor: middle;
    $|  }
    $|  .node .katex path {
    $|    fill: \{text_color};
    $|    stroke: \{text_color};
    $|    stroke-width: 1px;
    $|  }
    $|  .rough-node .label,.node .label, .image-shape .label, .icon-shape .label {
    $|    text-align: center;
    $|  }
    $|  .node.clickable {
    $|    cursor: pointer;
    $|  }
    $|  .root .anchor path {
    $|    fill: \{v("lineColor")} !important;
    $|    stroke-width: 0;
    $|    stroke: \{v("lineColor")};
    $|  }
    $|  .arrowheadPath {
    $|    fill: \{v("arrowheadColor")};
    $|  }
    $|  .edgePaths .path {
    $|    stroke: \{v("lineColor")};
    $|    stroke-width: \{stroke_width("2")}px;
    $|  }
    $|  .flowchart-link {
    $|    stroke: \{v("lineColor")};
    $|    fill: none;
    $|  }
    $|  .edgeLabel {
    $|    background-color: \{background};
    $|    p {
    $|      background-color: \{background};
    $|    }
    $|    rect {
    $|      opacity: 0.5;
    $|      background-color: \{background};
    $|      fill: \{background};
    $|    }
    $|    text-align: center;
    $|  }
    $|  /* For html labels only */
    $|  .labelBkg {
    $|    background-color: \{@flowchart.fade(background, 0.5)};
    $|  }
    $|  .cluster rect {
    $|    fill: \{v("clusterBkg")};
    $|    stroke: \{v("clusterBorder")};
    $|    stroke-width: 1px;
    $|  }
    $|  .flow-cluster rect {
    $|    fill: none;
    $|    stroke: \{v("clusterBorder")};
    $|    stroke-width: 0.75px;
    $|  }
    $|  .node .collapsed-indicator {
    $|    fill: \{v("nodeBorder")};
    $|    stroke: none;
    $|    stroke-width: 0;
    $|    opacity: 0.5;
    $|  }
    $|  .node .collapsed-separator {
    $|    stroke-width: 0.75px;
    $|  }
    $|  .cluster text {
    $|    fill: \{v("titleColor")};
    $|  }
    $|  .cluster span {
    $|    color: \{v("titleColor")};
    $|  }
    $|  /* .cluster div {
    $|    color: \{v("titleColor")};
    $|  } */
    $|  div.mermaidTooltip {
    $|    position: absolute;
    $|    text-align: center;
    $|    max-width: 200px;
    $|    padding: 2px;
    $|    font-family: \{v("fontFamily")};
    $|    font-size: 12px;
    $|    background: \{v("tertiaryColor")};
    $|    border: 1px solid \{v("border2")};
    $|    border-radius: 2px;
    $|    pointer-events: none;
    $|    z-index: 100;
    $|  }
    $|  .agentflowTitleText {
    $|    text-anchor: middle;
    $|    font-size: 18px;
    $|    fill: \{v("textColor")};
    $|  }
    $|  rect.text {
    $|    fill: none;
    $|    stroke-width: 0;
    $|  }
    $|  .icon-shape, .image-shape {
    $|    background-color: \{background};
    $|    p {
    $|      background-color: \{background};
    $|      padding: 2px;
    $|    }
    $|    .label rect {
    $|      opacity: 0.5;
    $|      background-color: \{background};
    $|      fill: \{background};
    $|    }
    $|    text-align: center;
    $|  }
    $|
    $|  /* Font Awesome icon styling - consolidated */
    $|  .label-icon {
    $|    display: inline-block;
    $|    height: 1em;
    $|    overflow: visible;
    $|    vertical-align: -0.125em;
    $|  }
    $|
    $|  .node .label-icon path {
    $|    fill: currentColor;
    $|    stroke: revert;
    $|    stroke-width: revert;
    $|  }
    $|
    $|
  )
}
