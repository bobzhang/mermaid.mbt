///|
/// The requirement diagram's stylesheet, before it is scoped to the
/// diagram.
pub fn styles(config : @config.Config) -> String {
  let theme = config.theme()
  let look = config.text("look").unwrap_or("")
  let v = (name : String) => theme.text(name)
  let text_color = if theme.flag("nodeTextColor") {
    v("nodeTextColor")
  } else {
    v("textColor")
  }
  let stroke_width = if look == "neo" { v("strokeWidth") } else { "1px" }
  let label_background = match theme.get("requirementEdgeLabelBackground") {
    Null => v("edgeLabelBackground")
    _ => v("requirementEdgeLabelBackground")
  }
  (
    $|
    $|  \{@rendering.node_palette_rules(config)}
    $|  marker {
    $|    fill: \{v("relationColor")};
    $|    stroke: \{v("relationColor")};
    $|  }
    $|
    $|  marker.cross {
    $|    stroke: \{v("lineColor")};
    $|  }
    $|
    $|  svg {
    $|    font-family: \{v("fontFamily")};
    $|    font-size: \{v("fontSize")};
    $|  }
    $|
    $|  .reqBox {
    $|    fill: \{v("requirementBackground")};
    $|    fill-opacity: 1.0;
    $|    stroke: \{v("requirementBorderColor")};
    $|    stroke-width: \{v("requirementBorderSize")};
    $|  }
    $|  
    $|  .reqTitle, .reqLabel{
    $|    fill:  \{v("requirementTextColor")};
    $|  }
    $|  .reqLabelBox {
    $|    fill: \{v("relationLabelBackground")};
    $|    fill-opacity: 1.0;
    $|  }
    $|
    $|  .req-title-line {
    $|    stroke: \{v("requirementBorderColor")};
    $|    stroke-width: \{v("requirementBorderSize")};
    $|  }
    $|  .relationshipLine {
    $|    stroke: \{v("relationColor")};
    $|    stroke-width: \{stroke_width};
    $|  }
    $|  .relationshipLabel {
    $|    fill: \{v("relationLabelColor")};
    $|  }
    $|    .edgeLabel {
    $|    background-color: \{v("edgeLabelBackground")};
    $|  }
    $|  .edgeLabel .label rect {
    $|    fill: \{v("edgeLabelBackground")};
    $|  }
    $|  .edgeLabel .label text {
    $|    fill: \{v("relationLabelColor")};
    $|  }
    $|  .divider {
    $|    stroke: \{v("nodeBorder")};
    $|    stroke-width: 1;
    $|  }
    $|  .label {
    $|    font-family: \{v("fontFamily")};
    $|    color: \{text_color};
    $|  }
    $|  .label text,span {
    $|    fill: \{text_color};
    $|    color: \{text_color};
    $|  }
    $|  .labelBkg {
    $|    background-color: \{label_background};
    $|  }
    $|
    $|
  )
}
