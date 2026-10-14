///|
/// The themes drawn with the redux geometry: square branch labels and
/// smaller bullets.
fn is_redux_theme(theme : String) -> Bool {
  theme is ("redux" | "redux-dark" | "redux-color" | "redux-dark-color")
}

///|
/// The redux themes that color every branch from the border palette.
fn is_color_theme(theme : String) -> Bool {
  theme is ("redux-color" | "redux-dark-color")
}

///|
fn is_neo_theme(theme : String) -> Bool {
  theme is ("neo" | "neo-dark")
}

///|
fn is_dark_theme(theme : String) -> Bool {
  theme is ("dark" | "redux-dark" | "redux-dark-color" | "neo-dark")
}

///|
/// The number of `git0`...`git7` variables a theme defines.
const GIT_NAMED_COLOR_COUNT : Int32 = 8

///|
/// What the stylesheet is built from: the theme variables, the name of
/// the theme, and the selector of the `<svg>` element.
priv struct StyleOptions {
  theme : @theme.Theme
  theme_name : String
  svg_id : String
}

///|
fn StyleOptions::v(self : StyleOptions, name : String) -> String {
  self.theme.text(name)
}

///|
/// `THEME_COLOR_LIMIT`: how many branch color classes there are.
fn StyleOptions::limit(self : StyleOptions) -> Int32 {
  match self.theme.number("THEME_COLOR_LIMIT") {
    // A loop bound: the count of integers below it.
    Some(limit) if limit > 0.0 => limit.ceil().to_int()
    _ => 0
  }
}

///|
/// `genGitGraphGradient`: branch labels outlined with the theme gradient.
fn StyleOptions::gradient_sections(self : StyleOptions) -> String {
  let out = StringBuilder()
  if self.theme.flag("useGradient") && self.svg_id != "" {
    for i in 0..<self.limit() {
      out.write_string(
        (
          $|
          $|      .label\{i}  { fill: \{self.v("mainBkg")}; stroke: url(\{self.svg_id}-gradient); stroke-width: \{self.v("strokeWidth")};}
          $|             
        ),
      )
    }
  }
  out.to_string()
}

///|
/// `genColor`: the per-branch rules of the neo and redux themes.
fn StyleOptions::neo_sections(self : StyleOptions) -> String {
  let v = (name : String) => self.v(name)
  let border = v("nodeBorder")
  let weight = if is_redux_theme(self.theme_name) {
    "font-weight:\{v("noteFontWeight")}"
  } else {
    ""
  }
  let out = StringBuilder()
  if is_neo_theme(self.theme_name) {
    for i in 0..<self.limit() {
      if i == 0 {
        out.write_string(
          (
            $|
            $|        .branch-label\{i} { fill: \{border};}
            $|        .commit\{i} { stroke: \{border};   }
            $|        .commit-highlight\{i} { stroke: \{border}; fill: \{border}; }
            $|        .arrow\{i} { stroke: \{border}; }
            $|        .commit-bullets { fill: \{border}; }
            $|        .commit-cherry-pick\{i} { stroke: \{border}; }
            $|        \{self.gradient_sections()}
          ),
        )
      } else {
        let ci = i % GIT_NAMED_COLOR_COUNT
        out.write_string(
          (
            $|
            $|        .branch-label\{i} { fill: \{v("gitBranchLabel\{ci}")}; }
            $|        .commit\{i} { stroke: \{v("git\{ci}")}; fill: \{v("git\{ci}")}; }
            $|        .commit-highlight\{i} { stroke: \{v("gitInv\{ci}")}; fill: \{v("gitInv\{ci}")}; }
            $|        .arrow\{i} { stroke: \{v("git\{ci}")}; }
            $|        
          ),
        )
      }
    }
  } else if !is_color_theme(self.theme_name) {
    for i in 0..<self.limit() {
      out.write_string(
        (
          $|
          $|        .branch-label\{i} { fill: \{border}; \{weight} }
          $|        .commit\{i} { stroke: \{border};   }
          $|        .commit-highlight\{i} { stroke: \{border}; fill: \{border}; }
          $|        .label\{i}  { fill: \{v("mainBkg")}; stroke: \{border}; stroke-width: \{v("strokeWidth")}; \{weight}}
          $|        .arrow\{i} { stroke: \{border}; }
          $|        .commit-bullets { fill: \{border}; }
          $|        .commit-cherry-pick\{i} { stroke: \{border}; }
          $|        
        ),
      )
    }
  } else {
    let palette = match self.theme.get("borderColorArray") {
      Array(colors) => colors
      _ => []
    }
    for i in 0..<self.limit() {
      if i == 0 {
        out.write_string(
          (
            $|
            $|        .branch-label\{i} { fill: \{border}; \{weight} }
            $|        .commit\{i} { stroke: \{border}; }
            $|        .commit-highlight\{i} { stroke: \{border}; fill: \{v("mainBkg")}; }
            $|        .label\{i}  { fill: \{v("mainBkg")}; stroke: \{border}; stroke-width: \{v("strokeWidth")}; \{weight} }
            $|        .arrow\{i} { stroke: \{border}; }
            $|        .commit-bullets { fill: \{border}; }
            $|        
          ),
        )
      } else {
        let color = if palette.is_empty() {
          "undefined"
        } else {
          match palette[i % palette.length()] {
            String(color) => color
            other => other.stringify()
          }
        }
        let fill = if is_dark_theme(self.theme_name) {
          v("mainBkg")
        } else {
          color
        }
        out.write_string(
          (
            $|
            $|        .branch-label\{i} { fill: \{border}; \{weight} }
            $|        .commit\{i} { stroke: \{color}; fill: \{color}; }
            $|        .commit-highlight\{i} { stroke: \{color}; fill: \{color}; }
            $|        .label\{i}  { fill: \{fill}; stroke: \{color};  stroke-width: \{v("strokeWidth")}; }
            $|        .arrow\{i} { stroke: \{color}; }
            $|        
          ),
        )
      }
    }
  }
  out.to_string()
}

///|
/// `normalTheme`: the per-branch rules of the classic themes.
fn StyleOptions::classic_sections(self : StyleOptions) -> String {
  let v = (name : String) => self.v(name)
  let sections = []
  for i in 0..<self.limit() {
    let ci = i % GIT_NAMED_COLOR_COUNT
    sections.push(
      (
        $|
        $|        .branch-label\{i} { fill: \{v("gitBranchLabel\{ci}")}; }
        $|        .commit\{i} { stroke: \{v("git\{ci}")}; fill: \{v("git\{ci}")}; }
        $|        .commit-highlight\{i} { stroke: \{v("gitInv\{ci}")}; fill: \{v("gitInv\{ci}")}; }
        $|        .label\{i}  { fill: \{v("git\{ci}")}; }
        $|        .arrow\{i} { stroke: \{v("git\{ci}")}; }
        $|        
      ),
    )
  }
  sections.join("\n")
}

///|
/// The git graph stylesheet, before it is scoped to the diagram:
/// mermaid's `git/styles.js`. `svg_id` is the selector of the `<svg>`
/// element, which the neo themes' gradient is addressed through.
pub fn styles(config : @config.Config, svg_id : String) -> String {
  let theme = config.theme()
  let theme_name = config.text("theme").unwrap_or("")
  let options = { theme, theme_name, svg_id, }
  let v = (name : String) => theme.text(name)
  let neo = is_neo_theme(theme_name) || is_redux_theme(theme_name)
  let pick = (neo_value : String, classic : String) => {
    if neo {
      neo_value
    } else {
      classic
    }
  }
  let line_color = match theme.get("commitLineColor") {
    Null => v("lineColor")
    _ => v("commitLineColor")
  }
  let sections = if neo {
    options.neo_sections()
  } else {
    options.classic_sections()
  }
  let label_weight = if neo {
    "font-weight:\{v("noteFontWeight")};"
  } else {
    ""
  }
  let tag_filter = if neo { "filter:\{v("dropShadow")}" } else { "" }
  let arrow_width = if is_redux_theme(theme_name) {
    v("strokeWidth")
  } else {
    "8"
  }
  (
    $|
    $|  .commit-id,
    $|  .commit-msg,
    $|  .branch-label {
    $|    fill: lightgrey;
    $|    color: lightgrey;
    $|    font-family: 'trebuchet ms', verdana, arial, sans-serif;
    $|    font-family: var(--mermaid-font-family);
    $|  }
    $|  
    $|  \{sections}
    $|
    $|  .branch {
    $|    stroke-width: \{v("strokeWidth")};
    $|    stroke: \{line_color};
    $|    stroke-dasharray:  \{pick("4 2", "2")};
    $|  }
    $|  .commit-label { font-size: \{v("commitLabelFontSize")}; fill: \{pick(v("nodeBorder"), v("commitLabelColor"))}; \{label_weight}}
    $|  .commit-label-bkg { font-size: \{v("commitLabelFontSize")}; fill: \{pick("transparent", v("commitLabelBackground"))}; opacity: \{pick("", "0.5")};  }
    $|  .tag-label { font-size: \{v("tagLabelFontSize")}; fill: \{v("tagLabelColor")};}
    $|  .tag-label-bkg { fill: \{pick(v("mainBkg"), v("tagLabelBackground"))}; stroke: \{pick(v("nodeBorder"), v("tagLabelBorder"))}; \{tag_filter}  }
    $|  .tag-hole { fill: \{v("textColor")}; }
    $|
    $|  .commit-merge {
    $|    stroke: \{pick(v("mainBkg"), v("primaryColor"))};
    $|    fill: \{pick(v("mainBkg"), v("primaryColor"))};
    $|  }
    $|  .commit-reverse {
    $|    stroke: \{pick(v("mainBkg"), v("primaryColor"))};
    $|    fill: \{pick(v("mainBkg"), v("primaryColor"))};
    $|    stroke-width: \{pick(v("strokeWidth"), "3")};
    $|  }
    $|  .commit-highlight-outer {
    $|  }
    $|  .commit-highlight-inner {
    $|    stroke: \{pick(v("mainBkg"), v("primaryColor"))};
    $|    fill: \{pick(v("mainBkg"), v("primaryColor"))};
    $|  }
    $|
    $|  .arrow {
    $|    /* Intentional: neo themes keep the bold 8px arrow (like classic themes); only redux-geometry themes use the thinner options.strokeWidth. */
    $|    stroke-width: \{arrow_width};
    $|    stroke-linecap: round;
    $|    fill: none
    $|  }
    $|  .gitTitleText {
    $|    text-anchor: middle;
    $|    font-size: 18px;
    $|    fill: \{v("textColor")};
    $|  }
    $|
  )
}
