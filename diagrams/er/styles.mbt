///|
/// The themes whose palettes color entities by slot.
fn is_color_theme(theme_name : String) -> Bool {
  theme_name is ("redux-color" | "redux-dark-color")
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
/// The ER diagram's stylesheet, before it is scoped to the diagram.
pub fn styles(config : @config.Config) -> String {
  let theme = config.theme()
  let look = config.text("look").unwrap_or("")
  let theme_name = config.text("theme").unwrap_or("")
  let v = (name : String) => theme.text(name)
  // `a ?? b`
  let or_else = (name : String, fallback : String) => {
    match theme.get(name) {
      Null => v(fallback)
      _ => v(name)
    }
  }
  let text_color = if theme.flag("nodeTextColor") {
    v("nodeTextColor")
  } else {
    v("textColor")
  }
  let stroke_width = if look == "neo" { v("strokeWidth") } else { "1px" }
  let own_background = is_color_theme(theme_name) &&
    theme.flag("erEdgeLabelBackground")
  let label_background = if own_background {
    v("erEdgeLabelBackground")
  } else {
    fade(v("tertiaryColor"), 0.5)
  }
  let edge_background = if own_background {
    v("erEdgeLabelBackground")
  } else {
    v("edgeLabelBackground")
  }
  (
    $|
    $|    \{@rendering.node_palette_rules(config)}
    $|  .entityBox {
    $|    fill: \{v("mainBkg")};
    $|    stroke: \{v("nodeBorder")};
    $|  }
    $|
    $|  .relationshipLabelBox {
    $|    fill: \{v("tertiaryColor")};
    $|    opacity: 0.7;
    $|    background-color: \{v("tertiaryColor")};
    $|      rect {
    $|        opacity: 0.5;
    $|      }
    $|  }
    $|
    $|  .labelBkg {
    $|    background-color: \{label_background};
    $|  }
    $|
    $|  .edgeLabel {
    $|    background-color: \{edge_background};
    $|  }
    $|  .edgeLabel .label rect {
    $|    fill: \{edge_background};
    $|  }
    $|  .edgeLabel .label text {
    $|    fill: \{v("textColor")};
    $|  }
    $|
    $|  .edgeLabel .label {
    $|    fill: \{v("nodeBorder")};
    $|    font-size: 14px;
    $|  }
    $|
    $|  .label {
    $|    font-family: \{v("fontFamily")};
    $|    color: \{text_color};
    $|  }
    $|
    $|  .edge-pattern-dashed {
    $|    stroke-dasharray: 8,8;
    $|  }
    $|
    $|  .node rect,
    $|  .node circle,
    $|  .node ellipse,
    $|  .node polygon
    $|  {
    $|    fill: \{v("mainBkg")};
    $|    stroke: \{v("nodeBorder")};
    $|    stroke-width: \{stroke_width};
    $|  }
    $|
    $|  .relationshipLine {
    $|    stroke: \{v("lineColor")};
    $|    stroke-width: \{stroke_width};
    $|    fill: none;
    $|  }
    $|
    $|  .marker {
    $|    fill: none !important;
    $|    stroke: \{v("lineColor")} !important;
    $|    stroke-width: 1;
    $|  }
    $|  [data-look=neo].labelBkg {
    $|    background-color: \{fade(v("tertiaryColor"), 0.5)};
    $|  }
    $|
    $|  .cluster rect {
    $|    fill: \{or_else("clusterBkg", "mainBkg")};
    $|    stroke: \{or_else("clusterBorder", "nodeBorder")};
    $|    stroke-width: 1px;
    $|  }
    $|
    $|  .cluster text {
    $|    fill: \{or_else("titleColor", "textColor")};
    $|  }
    $|
    $|  .cluster-label text {
    $|    fill: \{or_else("titleColor", "textColor")};
    $|  }
    $|
  )
}
