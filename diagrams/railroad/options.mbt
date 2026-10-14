///|
/// What the stylesheet and the renderer are configured with: upstream's
/// `RailroadStyleOptions`, less the fields nothing reads.
priv struct Options {
  padding : Double
  vertical_separation : Double
  horizontal_separation : Double
  arc_radius : Double
  font_size : Double
  font_family : String
  terminal_fill : String
  terminal_stroke : String
  terminal_text_color : String
  non_terminal_fill : String
  non_terminal_stroke : String
  non_terminal_text_color : String
  line_color : String
  stroke_width : Double
  marker_fill : String
  comment_fill : String
  comment_stroke : String
  comment_text_color : String
  special_fill : String
  special_stroke : String
  rule_name_color : String
  marker_radius : Double
}

///|
/// The default theme: upstream lays the variables of the theme in use
/// over its variables, so that it supplies what the other lacks.
let default_theme : @theme.Theme = {
  let theme = @theme.Theme::new("default") catch { _ => None }
  theme.unwrap_or(@theme.Theme::from_variables(Map([])))
}

///|
/// `COLOR_VALUE_PATTERN`: what passes for a color.
let color_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  (
    #|^#(?:[\da-f]{3,4}|[\da-f]{6}|[\da-f]{8})$|^(?:rgb|rgba|hsl|hsla|hwb|lab|lch|oklab|oklch)\([\d\s%+,./-]+\)$|^[a-z]+$
  ),
  flags="i",
)

///|
/// `FONT_FAMILY_PATTERN`: what passes for a list of font families.
let font_family_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  (
    #|^[\w "',.-]+$
  ),
)

///|
/// `sanitizeColorValue`: the first of `values` that is set, when it is a
/// string that looks like a color, else `fallback`.
fn color_value(values : Array[Json], fallback : String) -> String {
  for value in values {
    // `a ?? b`: only an unset value gives way to the next.
    if value is Null {
      continue
    }
    if value is String(text) {
      let normalized = @journeycommon.js_trim(text)
      if color_pattern.matches(normalized) {
        return normalized
      }
    }
    break
  }
  fallback
}

///|
/// `sanitizeFontFamilyValue`.
fn font_family_value(value : Json, fallback : String) -> String {
  if value is String(text) {
    let normalized = @journeycommon.js_trim(text)
    if font_family_pattern.matches(normalized) {
      return normalized
    }
  }
  fallback
}

///|
/// A number, or the number a string starts with.
fn number_of(value : Json) -> Double {
  match value {
    Number(number, ..) => number
    String(text) => @diagram.parse_float(text)
    _ => @double.not_a_number
  }
}

///|
/// `sanitizeNumberValue`: a finite number that is not negative, else
/// `fallback`.
fn number_value(value : Json, fallback : Double) -> Double {
  let parsed = number_of(value)
  if parsed >= 0.0 && parsed < @double.infinity {
    parsed
  } else {
    fallback
  }
}

///|
/// `buildRailroadStyleOptions`: the defaults, overridden by what the
/// theme says, overridden by the `railroad` section of the configuration.
fn Options::new(config : @config.Config) -> Options {
  let theme = config.theme()
  let variable = (name : String) => {
    match theme.get(name) {
      Null => default_theme.get(name)
      value => value
    }
  }
  let option = (name : String) => config.get("railroad.\{name}")
  let color = (name : String, variables : Array[String], fallback : String) => {
    color_value([option(name)], color_value(variables.map(variable), fallback))
  }
  // `parseThemeFontSize`: the number the theme's size starts with, in
  // pixels whatever its unit.
  let theme_font_size = {
    let parsed = number_of(variable("fontSize"))
    if parsed > 0.0 && parsed < @double.infinity {
      parsed
    } else {
      14.0
    }
  }
  {
    padding: number_value(option("padding"), 10.0),
    vertical_separation: number_value(option("verticalSeparation"), 8.0),
    horizontal_separation: number_value(option("horizontalSeparation"), 10.0),
    arc_radius: number_value(option("arcRadius"), 10.0),
    font_size: number_value(option("fontSize"), theme_font_size),
    font_family: font_family_value(
      option("fontFamily"),
      font_family_value(variable("fontFamily"), "monospace"),
    ),
    terminal_fill: color(
      "terminalFill",
      ["secondBkg", "secondaryColor"],
      "#FFFFC0",
    ),
    terminal_stroke: color(
      "terminalStroke",
      ["secondaryBorderColor", "lineColor"],
      "#000000",
    ),
    terminal_text_color: color(
      "terminalTextColor",
      ["secondaryTextColor", "textColor"],
      "#000000",
    ),
    non_terminal_fill: color(
      "nonTerminalFill",
      ["mainBkg", "background"],
      "#FFFFFF",
    ),
    non_terminal_stroke: color(
      "nonTerminalStroke",
      ["primaryBorderColor", "lineColor"],
      "#000000",
    ),
    non_terminal_text_color: color(
      "nonTerminalTextColor",
      ["primaryTextColor", "textColor"],
      "#000000",
    ),
    line_color: color("lineColor", ["lineColor"], "#000000"),
    stroke_width: number_value(option("strokeWidth"), 2.0),
    marker_fill: color("markerFill", ["lineColor"], "#000000"),
    comment_fill: color(
      "commentFill",
      ["labelBackground", "tertiaryColor"],
      "#E8E8E8",
    ),
    comment_stroke: color(
      "commentStroke",
      ["tertiaryBorderColor", "lineColor"],
      "#888888",
    ),
    comment_text_color: color(
      "commentTextColor",
      ["tertiaryTextColor", "textColor"],
      "#666666",
    ),
    special_fill: color(
      "specialFill",
      ["tertiaryColor", "secondaryColor"],
      "#F0E0FF",
    ),
    special_stroke: color(
      "specialStroke",
      ["tertiaryBorderColor", "secondaryBorderColor"],
      "#8800CC",
    ),
    rule_name_color: color(
      "ruleNameColor",
      ["titleColor", "textColor"],
      "#000066",
    ),
    marker_radius: number_value(option("markerRadius"), 5.0),
  }
}
