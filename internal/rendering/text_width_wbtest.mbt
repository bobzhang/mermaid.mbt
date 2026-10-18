///|
test "text widths in the page's font" {
  // What mermaid's `calculateTextWidth` returns in the reference browser
  // with the default configuration: Times at 16px, rounded.
  let config = @config.Config::new(diagram_type="er")
  inspect(calculate_text_width("ORDER", config), content="54")
  inspect(calculate_text_width("the name", config), content="58")
  inspect(calculate_text_width("", config), content="0")
  // "fi" is one glyph.
  inspect(calculate_text_width("office", config), content="36")
  // The sans-serif measurement wins where it is larger in every way, as
  // with capitals whose accents reach above the line.
  inspect(calculate_text_width("ÉCOLE", config), content="54")
  inspect(calculate_text_width("Ångström", config), content="68")
  inspect(calculate_text_width("Ünïcödé", config), content="54")
}

///|
test "the fontSize setting as a size in pixels" {
  inspect(text_measure_size(20), content="20")
  inspect(text_measure_size("18px"), content="18")
  inspect(text_measure_size("1.5em"), content="24")
  inspect(text_measure_size("150%"), content="24")
  inspect(text_measure_size("12pt"), content="16")
  // Not a size: the page's own stays.
  inspect(text_measure_size("large"), content="16")
  // CSS numbers; a negative size is invalid.
  inspect(text_measure_size("+20px"), content="20")
  inspect(text_measure_size("2e1px"), content="20")
  inspect(text_measure_size("-16px"), content="16")
  inspect(text_measure_size("-1e1px"), content="16")
}

///|
test "the theme's font size for label measurement" {
  // The stylesheet writes it on the diagram; the browser drops a negative
  // size and keeps its 16px.
  let size = (font_size : String) => {
    let config = @config.Config::new(
      site={ "themeVariables": { "fontSize": Json::string(font_size) } },
      diagram_type="flowchart-v2",
    )
    Env::new(config, "id").font_size
  }
  inspect(size("+12px"), content="12")
  inspect(size("1.2e1px"), content="12")
  inspect(size("-16px"), content="16")
  inspect(size("-1.2e1px"), content="16")
  inspect(size("0"), content="0")
  inspect(size("0px"), content="0")
}
