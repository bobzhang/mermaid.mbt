///|
/// How many sections the stylesheet colours before the colours repeat:
/// the theme's `THEME_COLOR_LIMIT` when that is a sensible count.
fn color_slot_count(theme : @theme.Theme) -> Int32 {
  match theme.get("THEME_COLOR_LIMIT") {
    Number(limit, ..) if limit == limit.floor() && limit > 0.0 && limit <= 64.0 =>
      limit.to_int()
    _ => 12
  }
}

///|
/// A theme variable, or `fallback` where the theme leaves it undefined.
fn or_default(theme : @theme.Theme, name : String, fallback : String) -> String {
  match theme.get(name) {
    Null => fallback
    _ => theme.text(name)
  }
}

///|
/// The rules colouring each section from the theme's colour scale.
fn section_styles(theme : @theme.Theme) -> String {
  let v = (name : String) => theme.text(name)
  let out = StringBuilder()
  for i in 0..<color_slot_count(theme) {
    let k = i - 1
    out.write_string(
      (
        $|
        $|    .section-\{k} rect, .section-\{k} path, .section-\{k} circle, .section-\{k} path  {
        $|      fill: \{v("cScale\{i}")};
        $|    }
        $|    .section-\{k} text {
        $|     fill: \{v("cScaleLabel\{i}")};
        $|    }
        $|    .node-icon-\{k} {
        $|      font-size: 40px;
        $|      color: \{v("cScaleLabel\{i}")};
        $|    }
        $|    .section-edge-\{k}{
        $|      stroke: \{v("cScale\{i}")};
        $|    }
        $|    .edge-depth-\{k}{
        $|      stroke-width: \{17 - 3 * i};
        $|    }
        $|    .section-\{k} line {
        $|      stroke: \{v("cScaleInv\{i}")} ;
        $|      stroke-width: 3;
        $|    }
        $|
        $|    .lineWrapper line{
        $|      stroke: \{v("cScaleLabel\{i}")} ;
        $|    }
        $|
        $|    .disabled, .disabled circle, .disabled text {
        $|      fill: \{or_default(theme, "tertiaryColor", "lightgray")};
        $|    }
        $|    .disabled text {
        $|      fill: \{or_default(theme, "clusterBorder", "#efefef")};
        $|    }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// The section rules of the redux themes: one look for every section,
/// unless the theme is a colour theme with a palette of borders.
fn redux_section_styles(
  theme : @theme.Theme,
  theme_name : String,
  svg_id : String,
) -> String {
  let v = (name : String) => theme.text(name)
  let is_dark = theme_name.contains("dark")
  let palette = match theme.get("borderColorArray") {
    Array(colours) if !colours.is_empty() => colours
    _ => []
  }
  let is_color = ["redux-color", "redux-dark-color"].contains(theme_name) &&
    !palette.is_empty()
  let drop_shadow = if svg_id != "" {
    "url(#\{svg_id}-drop-shadow)"
  } else {
    or_default(theme, "dropShadow", "none")
  }
  let out = StringBuilder()
  for i in 0..<color_slot_count(theme) {
    let k = i - 1
    let slot = if is_color {
      match palette[i % palette.length()] {
        String(colour) => Some(colour)
        Null => None
        other => Some(other.stringify())
      }
    } else {
      None
    }
    let colour = slot.unwrap_or(v("mainBkg"))
    let stroke = slot.unwrap_or(v("nodeBorder"))
    let fill = if is_dark && is_color { v("mainBkg") } else { colour }
    out.write_string(
      (
        $|
        $|    .section-\{k} rect,
        $|    .section-\{k} path,
        $|    .section-\{k} circle {
        $|      fill: \{fill};
        $|      stroke: \{stroke};
        $|      stroke-width: \{v("strokeWidth")};
        $|      filter: \{drop_shadow};
        $|    }
        $|
        $|    .section-\{k} text {
        $|      fill: \{v("nodeBorder")};
        $|      font-weight: \{v("fontWeight")}
        $|    }
        $|
        $|    .node-icon-\{k} {
        $|      font-size: 40px;
        $|      color: \{v("cScaleLabel\{i}")};
        $|    }
        $|
        $|    .section-edge-\{k} {
        $|      stroke: \{v("cScale\{i}")};
        $|    }
        $|
        $|    .edge-depth-\{k} {
        $|      stroke-width: \{17 - 3 * i};
        $|    }
        $|
        $|    .section-\{k} line {
        $|      stroke: \{v("cScaleInv\{i}")};
        $|      stroke-width: 3;
        $|    }
        $|
        $|    .lineWrapper line {
        $|      stroke: \{v("nodeBorder")};
        $|      stroke-width:\{v("strokeWidth")}
        $|    }
        $|
        $|    .disabled,
        $|    .disabled circle,
        $|    .disabled text {
        $|      fill: \{or_default(theme, "tertiaryColor", "lightgray")};
        $|    }
        $|
        $|    .disabled text {
        $|      fill: \{or_default(theme, "clusterBorder", "#efefef")};
        $|    }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// The timeline's stylesheet, before it is scoped to the diagram.
/// `theme_name` is the configured theme, `svg_id` the id of the `<svg>`
/// element, which the gradient and drop shadow references carry.
pub fn styles(
  theme : @theme.Theme,
  theme_name : String,
  svg_id : String,
) -> String {
  let v = (name : String) => theme.text(name)
  let sections = if theme_name.contains("redux") {
    redux_section_styles(theme, theme_name, svg_id)
  } else {
    section_styles(theme)
  }
  // The neo look outlines nodes with the theme's gradient.
  let gradients = StringBuilder()
  if theme.flag("useGradient") &&
    svg_id != "" &&
    theme.flag("THEME_COLOR_LIMIT") &&
    theme_name != "neutral" {
    for i in 0..<color_slot_count(theme) {
      let k = i - 1
      gradients.write_string(
        (
          $|
          $|      .section-\{k}[data-look="neo"] rect,
          $|      .section-\{k}[data-look="neo"] path,
          $|      .section-\{k}[data-look="neo"] circle {
          $|        fill: \{v("mainBkg")};
          $|        stroke: url(#\{svg_id}-gradient);
          $|        stroke-width: 2;
          $|      }
          $|      .section-\{k}[data-look="neo"] line {
          $|        stroke: url(#\{svg_id}-gradient);
          $|        stroke-width: 2;
          $|      }
        ),
      )
    }
  }
  (
    $|
    $|  .edge {
    $|    stroke-width: 3;
    $|  }
    $|  \{sections}
    $|  \{gradients.to_string()}
    $|  .section-root rect, .section-root path, .section-root circle  {
    $|    fill: \{v("git0")};
    $|  }
    $|  .section-root text {
    $|    fill: \{v("gitBranchLabel0")};
    $|  }
    $|  .icon-container {
    $|    height:100%;
    $|    display: flex;
    $|    justify-content: center;
    $|    align-items: center;
    $|  }
    $|  .edge {
    $|    fill: none;
    $|  }
    $|  .eventWrapper  {
    $|   filter: brightness(120%);
    $|  }
    $|
  )
}
