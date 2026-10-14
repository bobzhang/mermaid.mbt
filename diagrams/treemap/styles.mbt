///|
/// The default theme, whose variables stand in for those a theme lacks.
let default_theme : @theme.Theme = {
  let theme = @theme.Theme::new("default") catch { _ => None }
  theme.unwrap_or(@theme.Theme::from_variables(Map([])))
}

///|
/// A theme variable as a template literal writes it.
fn css_value(value : Json) -> String {
  match value {
    String(text) => text
    Number(number, ..) => @dom.number(number)
    True => "true"
    False => "false"
    Null => "undefined"
    _ => "[object Object]"
  }
}

///|
/// One of the theme's `treemap` variables, or upstream's default for it.
fn style_option(theme : @theme.Theme, name : String, default : Json) -> Json {
  match theme.nested("treemap", name) {
    Null => default
    value => value
  }
}

///|
/// A variable of the theme, or of the default theme when it has none.
fn variable(theme : @theme.Theme, name : String) -> Json {
  match theme.get(name) {
    Null => default_theme.get(name)
    value => value
  }
}

///|
/// The size of the title, which the stylesheet sets.
fn title_font_size(theme : @theme.Theme) -> String {
  css_value(style_option(theme, "titleFontSize", "14px"))
}

///|
/// The treemap's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String {
  let option = (name : String, default : String) => {
    css_value(style_option(theme, name, Json::string(default)))
  }
  let color = (name : String, fallback : String) => {
    css_value(style_option(theme, name, variable(theme, fallback)))
  }
  (
    $|
    $|  .treemapNode.section {
    $|    stroke: \{option("sectionStrokeColor", "black")};
    $|    stroke-width: \{option("sectionStrokeWidth", "1")};
    $|    fill: \{option("sectionFillColor", "#efefef")};
    $|  }
    $|  .treemapNode.leaf {
    $|    stroke: \{option("leafStrokeColor", "black")};
    $|    stroke-width: \{option("leafStrokeWidth", "1")};
    $|    fill: \{option("leafFillColor", "#efefef")};
    $|  }
    $|  .treemapLabel {
    $|    fill: \{color("labelColor", "textColor")};
    $|    font-size: \{option("labelFontSize", "12px")};
    $|  }
    $|  .treemapValue {
    $|    fill: \{color("valueColor", "textColor")};
    $|    font-size: \{option("valueFontSize", "10px")};
    $|  }
    $|  .treemapTitle {
    $|    fill: \{color("titleColor", "titleColor")};
    $|    font-size: \{title_font_size(theme)};
    $|  }
    $|  
  )
}
