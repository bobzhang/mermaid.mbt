///|
/// The rules that colour class boxes by their slot in the palette of the
/// colour themes: `genColor`. Nothing for other themes.
fn palette_rules(config : @config.Config) -> String {
  let theme = config.theme()
  guard config.text("theme") is Some("redux-color" | "redux-dark-color") &&
    theme.get("borderColorArray") is Array(borders) &&
    !borders.is_empty() else {
    return ""
  }
  let look = @rendering.safe_look(config.text("look").unwrap_or(""))
  let fills = match theme.get("bkgColorArray") {
    Array(fills) if !fills.is_empty() => Some(fills)
    _ => None
  }
  let color = (palette : Array[Json], index : Int32) => {
    match palette[index % palette.length()] {
      String(color) => color
      other => other.stringify()
    }
  }
  let out = StringBuilder()
  for i in 0..<borders.length() {
    let border = color(borders, i)
    let fill = match fills {
      Some(fills) => "fill: \{color(fills, i)};"
      None => ""
    }
    let slot = "[data-look=\"\{look}\"][data-color-id=\"color-\{i}\"]"
    out.write_string(
      (
        $|
        $|
        $|    \{slot}.node .outer-path path {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|
        $|    \{slot}.node .divider path {
        $|      stroke: \{border};
        $|    }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// The class diagram's stylesheet, before it is scoped to the diagram:
/// mermaid's `class/styles.js`.
pub fn styles(config : @config.Config) -> String {
  let theme = config.theme()
  // A variable the theme lacks is written out as `undefined`.
  let v = (name : String) => {
    match theme.get(name) {
      Null => "undefined"
      _ => theme.text(name)
    }
  }
  // `a || b`
  let or_else = (name : String, fallback : String) => {
    if theme.flag(name) {
      v(name)
    } else {
      v(fallback)
    }
  }
  let marker = (name : String, fill : String) => {
    let rule = (suffix : String) => {
      (
        $|[id$="-\{name}\{suffix}"], .\{name} {
        $|  fill: \{fill} !important;
        $|  stroke: \{v("lineColor")} !important;
        $|  stroke-width: 1;
        $|}
        $|
      )
    }
    rule("Start") + "\n" + rule("End")
  }
  (
    $|\{palette_rules(config)}
    $|  g.classGroup text {
    $|  fill: \{or_else("nodeBorder", "classText")};
    $|  stroke: none;
    $|  font-family: \{v("fontFamily")};
    $|  font-size: 10px;
    $|
    $|  .title {
    $|    font-weight: bolder;
    $|  }
    $|
    $|}
    $|
    $|  .cluster-label text {
    $|    fill: \{v("titleColor")};
    $|  }
    $|  .cluster-label span {
    $|    color: \{v("titleColor")};
    $|  }
    $|  .cluster-label span p {
    $|    background-color: transparent;
    $|  }
    $|
    $|  .cluster rect {
    $|    fill: \{v("clusterBkg")};
    $|    stroke: \{v("clusterBorder")};
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
    $|
    $|.nodeLabel, .edgeLabel {
    $|  color: \{v("classText")};
    $|}
    $|
    $|.noteLabel .nodeLabel, .noteLabel .edgeLabel {
    $|  color: \{v("noteTextColor")};
    $|}
    $|.edgeLabel .label rect {
    $|  fill: \{v("mainBkg")};
    $|}
    $|.label text {
    $|  fill: \{v("classText")};
    $|}
    $|
    $|.labelBkg {
    $|  background: \{v("mainBkg")};
    $|}
    $|.edgeLabel .label span {
    $|  background: \{v("mainBkg")};
    $|}
    $|
    $|.classTitle {
    $|  font-weight: bolder;
    $|}
    $|.node rect,
    $|  .node circle,
    $|  .node ellipse,
    $|  .node polygon,
    $|  .node path {
    $|    fill: \{v("mainBkg")};
    $|    stroke: \{v("nodeBorder")};
    $|    stroke-width: \{v("strokeWidth")};
    $|  }
    $|
    $|
    $|.divider {
    $|  stroke: \{v("nodeBorder")};
    $|  stroke-width: 1;
    $|}
    $|
    $|g.clickable {
    $|  cursor: pointer;
    $|}
    $|
    $|g.classGroup rect {
    $|  fill: \{v("mainBkg")};
    $|  stroke: \{v("nodeBorder")};
    $|}
    $|
    $|g.classGroup line {
    $|  stroke: \{v("nodeBorder")};
    $|  stroke-width: 1;
    $|}
    $|
    $|.classLabel .box {
    $|  stroke: none;
    $|  stroke-width: 0;
    $|  fill: \{v("mainBkg")};
    $|  opacity: 0.5;
    $|}
    $|
    $|.classLabel .label {
    $|  fill: \{v("nodeBorder")};
    $|  font-size: 10px;
    $|}
    $|
    $|.relation {
    $|  stroke: \{v("lineColor")};
    $|  stroke-width: \{v("strokeWidth")};
    $|  fill: none;
    $|}
    $|
    $|.dashed-line{
    $|  stroke-dasharray: 3;
    $|}
    $|
    $|.dotted-line{
    $|  stroke-dasharray: 1 2;
    $|}
    $|
    $|\{marker("composition", v("lineColor"))}
    $|\{marker("dependency", v("lineColor"))}
    $|\{marker("extension", "transparent")}
    $|\{marker("aggregation", "transparent")}
    $|\{marker("lollipop", v("mainBkg"))}
    $|.edgeTerminals {
    $|  font-size: 11px;
    $|  line-height: initial;
    $|}
    $|
    $|.classTitleText {
    $|  text-anchor: middle;
    $|  font-size: 18px;
    $|  fill: \{v("textColor")};
    $|}
    $|
    $|.edgeLabel[data-look="neo"] {
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
