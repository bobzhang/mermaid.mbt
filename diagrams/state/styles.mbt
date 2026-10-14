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
/// Cycling per-container colors for composite states and their regions:
/// one block of rules per palette slot. Mermaid's `genColor`.
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
    Array(fills) => fills
    _ => []
  }
  let out = StringBuilder()
  for i in 0..<borders.length() {
    let border = palette_color(borders, i)
    let tint = if fills.is_empty() {
      ""
    } else {
      "fill: \{palette_color(fills, i)};"
    }
    let slot = "[data-look=\"\{look}\"][data-color-id=\"color-\{i}\"]"
    out.write_string(
      (
        $|
        $|
        $|    \{slot}.statediagram-cluster rect.outer {
        $|      stroke: \{border};
        $|      \{tint}
        $|    }
        $|
        $|    \{slot}.statediagram-cluster rect.inner {
        $|      stroke: \{border};
        $|    }
        $|
        $|    \{slot}.statediagram-cluster rect.divider {
        $|      stroke: \{border};
        $|      \{tint}
        $|    }
        $|
        $|    \{slot}.statediagram-cluster .outer path[stroke='none'] {
        $|      \{tint}
        $|    }
        $|
        $|    \{slot}.statediagram-cluster .outer path[fill='none'] {
        $|      stroke: \{border};
        $|    }
        $|
        $|    \{slot}.statediagram-cluster .divider path[stroke='none'] {
        $|      \{tint}
        $|    }
        $|
        $|    \{slot}.statediagram-cluster .divider path[fill='none'] {
        $|      stroke: \{border};
        $|    }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// The state diagram's stylesheet, before it is scoped to the diagram:
/// mermaid's `getStyles`. `svg_id` is the selector of the `<svg>` element,
/// which the references to its filters and gradients start with.
pub fn styles(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
  svg_id : String,
) -> String {
  let v = (name : String) => theme.text(name)
  // `a || b`
  let either = (name : String, fallback : String) => {
    if theme.flag(name) {
      v(name)
    } else {
      fallback
    }
  }
  let stroke_width = either("strokeWidth", "1")
  let border = either("stateBorder", v("nodeBorder"))
  let label_color = either("transitionLabelColor", v("tertiaryTextColor"))
  let composite = either("compositeBackground", v("background"))
  let alt = either("altBackground", "#efefef")
  let neo_stroke = if theme.flag("useGradient") {
    "url(\{svg_id}-gradient)"
  } else {
    border
  }
  let neo_stroke_width = match theme.get("strokeWidth") {
    Null => "1"
    _ => v("strokeWidth")
  }
  let shadow = if theme.flag("dropShadow") {
    v("dropShadow").replace(
      old="url(#drop-shadow)",
      new="url(\{svg_id}-drop-shadow)",
    )
  } else {
    "none"
  }
  (
    $|
    $|\{color_sections(theme, theme_name, look)}
    $|defs [id$="-barbEnd"] {
    $|    fill: \{v("transitionColor")};
    $|    stroke: \{v("transitionColor")};
    $|  }
    $|g.stateGroup text {
    $|  fill: \{v("nodeBorder")};
    $|  stroke: none;
    $|  font-size: 10px;
    $|}
    $|g.stateGroup text {
    $|  fill: \{v("textColor")};
    $|  stroke: none;
    $|  font-size: 10px;
    $|
    $|}
    $|g.stateGroup .state-title {
    $|  font-weight: bolder;
    $|  fill: \{v("stateLabelColor")};
    $|}
    $|
    $|g.stateGroup rect {
    $|  fill: \{v("mainBkg")};
    $|  stroke: \{v("nodeBorder")};
    $|}
    $|
    $|g.stateGroup line {
    $|  stroke: \{v("lineColor")};
    $|  stroke-width: \{stroke_width};
    $|}
    $|
    $|.transition {
    $|  stroke: \{v("transitionColor")};
    $|  stroke-width: \{stroke_width};
    $|  fill: none;
    $|}
    $|
    $|.stateGroup .composit {
    $|  fill: \{v("background")};
    $|  border-bottom: 1px
    $|}
    $|
    $|.stateGroup .alt-composit {
    $|  fill: #e0e0e0;
    $|  border-bottom: 1px
    $|}
    $|
    $|.state-note {
    $|  stroke: \{v("noteBorderColor")};
    $|  fill: \{v("noteBkgColor")};
    $|
    $|  text {
    $|    fill: \{v("noteTextColor")};
    $|    stroke: none;
    $|    font-size: 10px;
    $|  }
    $|}
    $|
    $|.stateLabel .box {
    $|  stroke: none;
    $|  stroke-width: 0;
    $|  fill: \{v("mainBkg")};
    $|  opacity: 0.5;
    $|}
    $|
    $|.edgeLabel .label rect {
    $|  fill: \{v("labelBackgroundColor")};
    $|  opacity: 0.5;
    $|}
    $|.edgeLabel {
    $|  background-color: \{v("edgeLabelBackground")};
    $|  p {
    $|    background-color: \{v("edgeLabelBackground")};
    $|  }
    $|  rect {
    $|    opacity: 0.5;
    $|    background-color: \{v("edgeLabelBackground")};
    $|    fill: \{v("edgeLabelBackground")};
    $|  }
    $|  text-align: center;
    $|}
    $|.edgeLabel .label text {
    $|  fill: \{label_color};
    $|}
    $|.label div .edgeLabel {
    $|  color: \{label_color};
    $|}
    $|
    $|.stateLabel text {
    $|  fill: \{v("stateLabelColor")};
    $|  font-size: 10px;
    $|  font-weight: bold;
    $|}
    $|
    $|.node circle.state-start {
    $|  fill: \{v("specialStateColor")};
    $|  stroke: \{v("specialStateColor")};
    $|}
    $|
    $|.node .fork-join {
    $|  fill: \{v("specialStateColor")};
    $|  stroke: \{v("specialStateColor")};
    $|}
    $|
    $|.node circle.state-end {
    $|  fill: \{v("innerEndBackground")};
    $|  stroke: \{v("background")};
    $|  stroke-width: 1.5
    $|}
    $|.end-state-inner {
    $|  fill: \{composite};
    $|  // stroke: \{v("background")};
    $|  stroke-width: 1.5
    $|}
    $|
    $|.node rect {
    $|  fill: \{either("stateBkg", v("mainBkg"))};
    $|  stroke: \{border};
    $|  stroke-width: \{stroke_width}px;
    $|}
    $|.node polygon {
    $|  fill: \{v("mainBkg")};
    $|  stroke: \{border};;
    $|  stroke-width: \{stroke_width}px;
    $|}
    $|[id$="-barbEnd"] {
    $|  fill: \{v("lineColor")};
    $|}
    $|
    $|.statediagram-cluster rect {
    $|  fill: \{v("compositeTitleBackground")};
    $|  stroke: \{border};
    $|  stroke-width: \{stroke_width}px;
    $|}
    $|
    $|.cluster-label, .nodeLabel {
    $|  color: \{v("stateLabelColor")};
    $|  // line-height: 1;
    $|}
    $|
    $|.statediagram-cluster rect.outer {
    $|  rx: 5px;
    $|  ry: 5px;
    $|}
    $|.statediagram-state .divider {
    $|  stroke: \{border};
    $|}
    $|
    $|.statediagram-state .title-state {
    $|  rx: 5px;
    $|  ry: 5px;
    $|}
    $|.statediagram-cluster.statediagram-cluster .inner {
    $|  fill: \{composite};
    $|}
    $|.statediagram-cluster.statediagram-cluster-alt .inner {
    $|  fill: \{alt};
    $|}
    $|
    $|.statediagram-cluster .inner {
    $|  rx:0;
    $|  ry:0;
    $|}
    $|
    $|.statediagram-state rect.basic {
    $|  rx: 5px;
    $|  ry: 5px;
    $|}
    $|.statediagram-state rect.divider {
    $|  stroke-dasharray: 10,10;
    $|  fill: \{alt};
    $|}
    $|
    $|.note-edge {
    $|  stroke-dasharray: 5;
    $|}
    $|
    $|.statediagram-note rect {
    $|  fill: \{v("noteBkgColor")};
    $|  stroke: \{v("noteBorderColor")};
    $|  stroke-width: 1px;
    $|  rx: 0;
    $|  ry: 0;
    $|}
    $|.statediagram-note rect {
    $|  fill: \{v("noteBkgColor")};
    $|  stroke: \{v("noteBorderColor")};
    $|  stroke-width: 1px;
    $|  rx: 0;
    $|  ry: 0;
    $|}
    $|
    $|.statediagram-note text {
    $|  fill: \{v("noteTextColor")};
    $|}
    $|
    $|.statediagram-note .nodeLabel {
    $|  color: \{v("noteTextColor")};
    $|}
    $|.statediagram .edgeLabel {
    $|  color: red; // \{v("noteTextColor")};
    $|}
    $|
    $|[id$="-dependencyStart"], [id$="-dependencyEnd"] {
    $|  fill: \{v("lineColor")};
    $|  stroke: \{v("lineColor")};
    $|  stroke-width: \{stroke_width};
    $|}
    $|
    $|.statediagramTitleText {
    $|  text-anchor: middle;
    $|  font-size: 18px;
    $|  fill: \{v("textColor")};
    $|}
    $|
    $|[data-look="neo"].statediagram-cluster rect {
    $|  fill: \{v("mainBkg")};
    $|  stroke: \{neo_stroke};
    $|  stroke-width: \{neo_stroke_width};
    $|}
    $|[data-look="neo"].statediagram-cluster rect.outer {
    $|  rx: \{v("radius")}px;
    $|  ry: \{v("radius")}px;
    $|  filter: \{shadow}
    $|}
    $|
  )
}
