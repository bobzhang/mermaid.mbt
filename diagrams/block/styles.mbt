// The block diagram's stylesheet: mermaid's `block/styles.ts`.

///|
/// `look`, if it is safe to put in a selector: mermaid's `safeLook`.
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
fn palette_color(palette : Array[Json], index : Int32) -> String {
  match palette[index % palette.length()] {
    String(color) => color
    other => other.stringify()
  }
}

///|
/// The rules that colour composites by their slot in the palette of the
/// colour themes; nothing for other themes. Mermaid's `genColor`.
fn color_sections(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  guard theme_name is ("redux-color" | "redux-dark-color") &&
    theme.get("borderColorArray") is Array(borders) &&
    !borders.is_empty() else {
    return ""
  }
  let look = safe_look(look)
  let fills = match theme.get("bkgColorArray") {
    Array(fills) if !fills.is_empty() => Some(fills)
    _ => None
  }
  let out = StringBuilder()
  for i in 0..<borders.length() {
    let border = palette_color(borders, i)
    let fill = match fills {
      Some(fills) => "fill: \{palette_color(fills, i)};"
      None => ""
    }
    let slot = "[data-look=\"\{look}\"][data-color-id=\"color-\{i}\"]"
    out.write_string(
      (
        $|
        $|
        $|    \{slot}.node rect.composite {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|
      ),
    )
  }
  out.to_string()
}

///|
/// `color` at the given opacity, as khroma prints it.
fn fade(color : String, opacity : Double) -> String {
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
/// The rules every diagram with Font Awesome icons in its labels shares:
/// mermaid's `getIconStyles`.
let icon_styles : String =
  #|
  #|  /* Font Awesome icon styling - consolidated */
  #|  .label-icon {
  #|    display: inline-block;
  #|    height: 1em;
  #|    overflow: visible;
  #|    vertical-align: -0.125em;
  #|  }
  #|  
  #|  .node .label-icon path {
  #|    fill: currentColor;
  #|    stroke: revert;
  #|    stroke-width: revert;
  #|  }
  #|

///|
/// The block diagram's stylesheet, before it is scoped to the diagram.
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
  let stroke_width = match theme.get("strokeWidth") {
    Null => "1"
    _ => v("strokeWidth")
  }
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
    $|
    $|
    $|
    $|  .label text,span {
    $|    fill: \{text_color};
    $|    color: \{text_color};
    $|  }
    $|
    $|  .node rect,
    $|  .node circle,
    $|  .node ellipse,
    $|  .node polygon,
    $|  .node path {
    $|    fill: \{v("mainBkg")};
    $|    stroke: \{v("nodeBorder")};
    $|    /* From the theme, as every other diagram does. Pinned at 1px here, so block drew a
    $|       thinner border than an identical flowchart node under any theme asking for more --
    $|       the neo theme asks for 2. Nothing downstream corrected it: the neo rules set stroke
    $|       and filter, never stroke-width. */
    $|    stroke-width: \{stroke_width}px;
    $|  }
    $|  .flowchart-label text {
    $|    text-anchor: middle;
    $|  }
    $|  // .flowchart-label .text-outer-tspan {
    $|  //   text-anchor: middle;
    $|  // }
    $|  // .flowchart-label .text-inner-tspan {
    $|  //   text-anchor: start;
    $|  // }
    $|
    $|  .node .label {
    $|    text-align: center;
    $|  }
    $|  .node.clickable {
    $|    cursor: pointer;
    $|  }
    $|
    $|  .arrowheadPath {
    $|    fill: \{v("arrowheadColor")};
    $|  }
    $|
    $|  .edgePaths .path {
    $|    stroke: \{v("lineColor")};
    $|    stroke-width: 2.0px;
    $|  }
    $|
    $|  .flowchart-link {
    $|    stroke: \{v("lineColor")};
    $|    fill: none;
    $|  }
    $|
    $|  .edgeLabel {
    $|    background-color: \{v("edgeLabelBackground")};
    $|    /*
    $|     * This is for backward compatibility with existing code that didn't
    $|     * add a `<p>` around edge labels.
    $|     *
    $|     * TODO: We should probably remove this in a future release.
    $|     */
    $|    p {
    $|      margin: 0;
    $|      padding: 0;
    $|      display: inline;
    $|    }
    $|    rect {
    $|      opacity: 0.5;
    $|      background-color: \{v("edgeLabelBackground")};
    $|      fill: \{v("edgeLabelBackground")};
    $|    }
    $|    text-align: center;
    $|  }
    $|
    $|  /* For html labels only */
    $|  .labelBkg {
    $|    background-color: \{v("edgeLabelBackground")};
    $|  }
    $|
    $|  .node .cluster {
    $|    // fill: \{fade(v("mainBkg"), 0.5)};
    $|    fill: \{fade(v("clusterBkg"), 0.5)};
    $|    stroke: \{fade(v("clusterBorder"), 0.2)};
    $|    box-shadow: rgba(50, 50, 93, 0.25) 0px 13px 27px -5px, rgba(0, 0, 0, 0.3) 0px 8px 16px -8px;
    $|    stroke-width: 1px;
    $|  }
    $|
    $|  .cluster text {
    $|    fill: \{v("titleColor")};
    $|  }
    $|
    $|  .cluster span {
    $|    color: \{v("titleColor")};
    $|  }
    $|  /* .cluster div {
    $|    color: \{v("titleColor")};
    $|  } */
    $|
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
    $|
    $|  .flowchartTitleText {
    $|    text-anchor: middle;
    $|    font-size: 18px;
    $|    fill: \{v("textColor")};
    $|  }
    $|  \{icon_styles}
    $|
  )
}
