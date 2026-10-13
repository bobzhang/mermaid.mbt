///|
/// The rules mermaid derives from configuration rather than from a theme:
/// the font custom properties. Upstream builds them in a `CSSStyleSheet`
/// and reads back the browser's serialization.
fn user_styles(config : @config.Config) -> String {
  let rules = []
  let declaration = (value : String) => value.trim(chars=" \t\n;").to_owned()
  if config.text("fontFamily") is Some(family) {
    rules.push(":root { --mermaid-font-family: \{declaration(family)}; }")
  }
  if config.text("altFontFamily") is Some(family) {
    rules.push(":root { --mermaid-alt-font-family: \{declaration(family)}; }")
  }
  let theme_css = match config.text("themeCSS") {
    Some(css) => css + "\n"
    None => ""
  }
  theme_css + rules.join("\n")
}

///|
/// The stylesheet of a diagram before scoping: rules shared by all
/// diagrams, the diagram's own rules, the neo look, and user styles.
fn diagram_stylesheet(
  svg_id : String,
  diagram_styles : String,
  config : @config.Config,
) -> String {
  let theme = config.theme()
  let v = (name : String) => theme.text(name)
  let stroke_width = match theme.get("strokeWidth") {
    Null => "1"
    _ => v("strokeWidth")
  }
  let gradient_or_border = if theme.flag("useGradient") {
    "url(\{svg_id}-gradient)"
  } else {
    v("nodeBorder")
  }
  let shadow = if theme.flag("dropShadow") {
    v("dropShadow").replace_all(
      old="url(#drop-shadow)",
      new="url(\{svg_id}-drop-shadow)",
    )
  } else {
    "none"
  }
  (
    $|& {
    $|    font-family: \{v("fontFamily")};
    $|    font-size: \{v("fontSize")};
    $|    fill: \{v("textColor")}
    $|  }
    $|  @keyframes edge-animation-frame {
    $|    from {
    $|      stroke-dashoffset: 0;
    $|    }
    $|  }
    $|  @keyframes dash {
    $|    to {
    $|      stroke-dashoffset: 0;
    $|    }
    $|  }
    $|  & .edge-animation-slow {
    $|    stroke-dasharray: 9,5 !important;
    $|    stroke-dashoffset: 900;
    $|    animation: dash 50s linear infinite;
    $|    stroke-linecap: round;
    $|  }
    $|  & .edge-animation-fast {
    $|    stroke-dasharray: 9,5 !important;
    $|    stroke-dashoffset: 900;
    $|    animation: dash 20s linear infinite;
    $|    stroke-linecap: round;
    $|  }
    $|  /* Classes common for multiple diagrams */
    $|
    $|  & .error-icon {
    $|    fill: \{v("errorBkgColor")};
    $|  }
    $|  & .error-text {
    $|    fill: \{v("errorTextColor")};
    $|    stroke: \{v("errorTextColor")};
    $|  }
    $|
    $|  & .edge-thickness-normal {
    $|    stroke-width: \{stroke_width}px;
    $|  }
    $|  & .edge-thickness-thick {
    $|    stroke-width: 3.5px
    $|  }
    $|  & .edge-pattern-solid {
    $|    stroke-dasharray: 0;
    $|  }
    $|  & .edge-thickness-invisible {
    $|    stroke-width: 0;
    $|    fill: none;
    $|  }
    $|  & .edge-pattern-dashed{
    $|    stroke-dasharray: 3;
    $|  }
    $|  .edge-pattern-dotted {
    $|    stroke-dasharray: 2;
    $|  }
    $|
    $|  & .marker {
    $|    fill: \{v("lineColor")};
    $|    stroke: \{v("lineColor")};
    $|  }
    $|  & .marker.cross {
    $|    stroke: \{v("lineColor")};
    $|  }
    $|
    $|  & svg {
    $|    font-family: \{v("fontFamily")};
    $|    font-size: \{v("fontSize")};
    $|  }
    $|   & p {
    $|    margin: 0
    $|   }
    $|
    $|  \{diagram_styles}
    $|  .node .neo-node {
    $|    stroke: \{v("nodeBorder")};
    $|  }
    $|
    $|  [data-look="neo"].node rect, [data-look="neo"].cluster rect, [data-look="neo"].node polygon {
    $|    stroke: \{gradient_or_border};
    $|    filter: \{shadow};
    $|  }
    $|  [data-look="neo"].swimlane.cluster rect {
    $|    filter: none;
    $|  }
    $|
    $|
    $|  [data-look="neo"].node path {
    $|    stroke: \{gradient_or_border};
    $|    stroke-width: \{stroke_width}px;
    $|  }
    $|
    $|  [data-look="neo"].node .outer-path {
    $|    filter: \{shadow};
    $|  }
    $|
    $|  [data-look="neo"].node .neo-line path {
    $|    stroke: \{v("nodeBorder")};
    $|    filter: none;
    $|  }
    $|
    $|  [data-look="neo"].node circle{
    $|    stroke: \{gradient_or_border};
    $|    filter: \{shadow};
    $|  }
    $|
    $|  [data-look="neo"].node circle .state-start{
    $|    fill: #000000;
    $|  }
    $|
    $|  [data-look="neo"].icon-shape .icon {
    $|    fill: \{gradient_or_border};
    $|    filter: \{shadow};
    $|  }
    $|
    $|    [data-look="neo"].icon-shape .icon-neo path {
    $|    stroke: \{gradient_or_border};
    $|    filter: \{shadow};
    $|  }
    $|
    $|  \{user_styles(config)}
    $|
  )
}

///|
/// The compiled stylesheet of a diagram, scoped to its `<svg>` element.
fn compiled_styles(
  id : String,
  diagram_styles : String,
  config : @config.Config,
) -> String {
  let svg_id = "#" + id
  @css.compile(svg_id, diagram_stylesheet(svg_id, diagram_styles, config))
}
