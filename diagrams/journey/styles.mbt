///|
/// The journey diagram's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String {
  let v = (name : String) => theme.text(name)
  // A rule is left empty when the theme does not define its variable;
  // the fills all hinge on the first one, as upstream writes them.
  let fill_type = (index : Int32) => {
    if theme.flag("fillType0") {
      "fill: " + v("fillType\{index}")
    } else {
      ""
    }
  }
  let actor = (index : Int32) => {
    if theme.flag("actor\{index}") {
      "fill: " + v("actor\{index}")
    } else {
      ""
    }
  }
  let face = if theme.flag("faceColor") {
    "fill: " + v("faceColor")
  } else {
    "fill: #FFF8DC"
  }
  (
    $|.label {
    $|    font-family: \{v("fontFamily")};
    $|    color: \{v("textColor")};
    $|  }
    $|  .mouth {
    $|    stroke: #666;
    $|  }
    $|
    $|  line {
    $|    stroke: \{v("textColor")}
    $|  }
    $|
    $|  .legend {
    $|    fill: \{v("textColor")};
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .label text {
    $|    fill: #333;
    $|  }
    $|  .label {
    $|    color: \{v("textColor")}
    $|  }
    $|
    $|  .face {
    $|    \{face};
    $|    stroke: #999;
    $|  }
    $|
    $|  .node rect,
    $|  .node circle,
    $|  .node ellipse,
    $|  .node polygon,
    $|  .node path {
    $|    fill: \{v("mainBkg")};
    $|    stroke: \{v("nodeBorder")};
    $|    stroke-width: 1px;
    $|  }
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
    $|    stroke-width: 1.5px;
    $|  }
    $|
    $|  .flowchart-link {
    $|    stroke: \{v("lineColor")};
    $|    fill: none;
    $|  }
    $|
    $|  .edgeLabel {
    $|    background-color: \{v("edgeLabelBackground")};
    $|    rect {
    $|      opacity: 0.5;
    $|    }
    $|    text-align: center;
    $|  }
    $|
    $|  .cluster rect {
    $|  }
    $|
    $|  .cluster text {
    $|    fill: \{v("titleColor")};
    $|  }
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
    $|  .task-type-0, .section-type-0  {
    $|    \{fill_type(0)};
    $|  }
    $|  .task-type-1, .section-type-1  {
    $|    \{fill_type(1)};
    $|  }
    $|  .task-type-2, .section-type-2  {
    $|    \{fill_type(2)};
    $|  }
    $|  .task-type-3, .section-type-3  {
    $|    \{fill_type(3)};
    $|  }
    $|  .task-type-4, .section-type-4  {
    $|    \{fill_type(4)};
    $|  }
    $|  .task-type-5, .section-type-5  {
    $|    \{fill_type(5)};
    $|  }
    $|  .task-type-6, .section-type-6  {
    $|    \{fill_type(6)};
    $|  }
    $|  .task-type-7, .section-type-7  {
    $|    \{fill_type(7)};
    $|  }
    $|
    $|  .actor-0 {
    $|    \{actor(0)};
    $|  }
    $|  .actor-1 {
    $|    \{actor(1)};
    $|  }
    $|  .actor-2 {
    $|    \{actor(2)};
    $|  }
    $|  .actor-3 {
    $|    \{actor(3)};
    $|  }
    $|  .actor-4 {
    $|    \{actor(4)};
    $|  }
    $|  .actor-5 {
    $|    \{actor(5)};
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
