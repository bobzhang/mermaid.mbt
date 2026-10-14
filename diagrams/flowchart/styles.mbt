///|
/// The themes whose palettes color subgraphs by slot.
pub fn is_color_theme(theme_name : String, palette : Json) -> Bool {
  theme_name is ("redux-color" | "redux-dark-color") &&
  palette is Array([_, ..])
}

///|
/// `look`, if it is safe to put in a selector.
fn safe_look(look : String) -> String {
  if look != "" &&
    look
    .iter()
    .all(c => c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_' | '-')) {
    look
  } else {
    "classic"
  }
}

///|
/// The colour of a palette slot, cycling.
pub fn palette_color(palette : Json, index : Int32) -> String {
  match palette {
    Array(colors) if colors.length() > 0 =>
      match colors[index % colors.length()] {
        String(color) => color
        other => other.stringify()
      }
    _ => "undefined"
  }
}

///|
/// Cycling per-subgraph colors: one block of rules per palette slot.
fn color_sections(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  let borders = theme.get("borderColorArray")
  let fills = theme.get("bkgColorArray")
  if !is_color_theme(theme_name, borders) {
    return ""
  }
  let look = safe_look(look)
  let has_fills = fills is Array([_, ..])
  let slots = match borders {
    Array(colors) => colors.length()
    _ => 12
  }
  let out = StringBuilder()
  for i in 0..<slots {
    let border = palette_color(borders, i)
    let fill = if has_fills { "fill: \{palette_color(fills, i)};" } else { "" }
    let slot = "[data-look=\"\{look}\"][data-color-id=\"color-\{i}\"]"
    let collapsed = (suffix : String) => {
      "\{slot}.node \{suffix}, \{slot}.rough-node \{suffix}"
    }
    let lane = (suffix : String) => {
      "\{slot}.swimlane.cluster .swimlane-title\{suffix}, \{slot}.swimlane.cluster .swimlane-body\{suffix}"
    }
    let lane_fill = if has_fills {
      "\n    \{lane(" path:first-of-type")} {\n      stroke: \{palette_color(fills, i)};\n    }\n"
    } else {
      ""
    }
    out.write_string(
      (
        $|
        $|    \{slot}.cluster:not(.swimlane) rect {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|    \{slot}.cluster:not(.swimlane) path {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|    \{slot}.swimlane.cluster rect.swimlane-title,
        $|    \{slot}.swimlane.cluster rect.swimlane-body {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|    \{lane(" path:nth-of-type(2)")} {
        $|      stroke: \{border};
        $|    }
        $|\{lane_fill}
        $|    \{collapsed(".collapsed-group")},
        $|    \{collapsed(".collapsed-group path")} {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|    \{collapsed(".collapsed-indicator")} {
        $|      fill: \{border};
        $|    }
        $|    \{collapsed(".collapsed-separator")} {
        $|      stroke: \{border};
        $|    }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// `color` at the given opacity, as khroma prints it.
pub fn fade(color : String, opacity : Double) -> String {
  let channels = @color.Channels::parse(color) catch { _ => return color }
  let round = (v : Double) => (v * 10000000000.0 + 0.5).floor() / 10000000000.0
  @color.rgba(
    round(channels.r()),
    round(channels.g()),
    round(channels.b()),
    a=opacity,
  )
}

///|
/// The flowchart's stylesheet, before it is scoped to the diagram.
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
    $|    fill: #000;
    $|    stroke: #000;
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
    $|    background-color: \{fade(background, 0.5)};
    $|    // background-color:
    $|  }
    $|  .cluster rect {
    $|    fill: \{v("clusterBkg")};
    $|    stroke: \{v("clusterBorder")};
    $|    stroke-width: 1px;
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
    $|  /* Collapsed subgraph node (@{ view: collapsed }) */
    $|  .node .collapsed-indicator {
    $|    fill: \{v("clusterBorder")};
    $|    stroke: none;
    $|    opacity: 0.6;
    $|  }
    $|  .node .collapsed-separator {
    $|    stroke: \{v("clusterBorder")};
    $|    stroke-width: 0.75px;
    $|  }
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
    $|  .flowchartTitleText {
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
