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
/// The default theme, whose variables stand in for those a theme lacks.
let default_theme : @theme.Theme = {
  let theme = @theme.Theme::new("default") catch { _ => None }
  theme.unwrap_or(@theme.Theme::from_variables(Map([])))
}

///|
/// The radar chart's stylesheet, before it is scoped to the diagram: the
/// theme's `radar` variables, and one color of the theme's scale per
/// curve.
///
/// Upstream merges the theme over the variables of the default theme
/// first, so a theme without a `radar` section (`neo`, `redux`, ...) is
/// drawn with the default theme's.
pub fn styles(theme : @theme.Theme) -> String {
  let or_default = (value : Json, default : Json) => {
    if value is Null {
      default
    } else {
      value
    }
  }
  let variable = (name : String) => {
    or_default(theme.get(name), default_theme.get(name))
  }
  let v = (name : String) => css_value(variable(name))
  let r = (name : String) => {
    css_value(
      or_default(
        theme.nested("radar", name),
        default_theme.nested("radar", name),
      ),
    )
  }
  let out = StringBuilder()
  out.write_string(
    (
      $|
      $|	.radarTitle {
      $|		font-size: \{v("fontSize")};
      $|		color: \{v("titleColor")};
      $|		dominant-baseline: hanging;
      $|		text-anchor: middle;
      $|	}
      $|	.radarAxisLine {
      $|		stroke: \{r("axisColor")};
      $|		stroke-width: \{r("axisStrokeWidth")};
      $|	}
      $|	.radarAxisLabel {
      $|		font-size: \{r("axisLabelFontSize")}px;
      $|		color: \{r("axisColor")};
      $|	}
      $|	.radarGraticule {
      $|		fill: \{r("graticuleColor")};
      $|		fill-opacity: \{r("graticuleOpacity")};
      $|		stroke: \{r("graticuleColor")};
      $|		stroke-width: \{r("graticuleStrokeWidth")};
      $|	}
      $|	.radarLegendText {
      $|		text-anchor: start;
      $|		font-size: \{r("legendFontSize")}px;
      $|		dominant-baseline: hanging;
      $|	}
      $|	
    ),
  )
  let limit = match variable("THEME_COLOR_LIMIT") {
    Number(limit, ..) => limit.to_int()
    _ => 0
  }
  for i in 0..<limit {
    let color = v("cScale\{i}")
    out.write_string(
      (
        $|
        $|		.radarCurve-\{i} {
        $|			color: \{color};
        $|			fill: \{color};
        $|			fill-opacity: \{r("curveOpacity")};
        $|			stroke: \{color};
        $|			stroke-width: \{r("curveStrokeWidth")};
        $|		}
        $|		.radarLegendBox-\{i} {
        $|			fill: \{color};
        $|			fill-opacity: \{r("curveOpacity")};
        $|			stroke: \{color};
        $|		}
        $|		
      ),
    )
  }
  out.write_string("\n\t")
  out.to_string()
}
