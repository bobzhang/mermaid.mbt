// The mindmap stylesheet: mermaid's `diagrams/mindmap/styles.ts`.

///|
/// How many colour sections the stylesheet has rules for: the loops of
/// upstream run while the index is below the theme's `THEME_COLOR_LIMIT`.
fn color_limit(theme : @theme.Theme) -> Int32 {
  match theme.get("THEME_COLOR_LIMIT") {
    Number(limit, ..) if limit > 0.0 => {
      let mut count = 0
      while count.to_double() < limit && count < 1000 {
        count += 1
      }
      count
    }
    _ => 0
  }
}

///|
/// `genSections`: the rules of every colour section, `section-0` up to
/// the theme's limit, the root's `section--1` first.
fn gen_sections(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  let v = (name : String) => theme.text(name)
  let is_redux = theme_name == "redux" || theme_name == "redux-dark"
  let stroke_width = match theme.get("strokeWidth") {
    Null => "2"
    _ => v("strokeWidth")
  }
  let out = StringBuilder()
  for i in 0..<color_limit(theme) {
    let k = i - 1
    let sw = if look == "neo" {
      let width = 10 - (i - 1) * 2
      if width > 2 {
        width
      } else {
        2
      }
    } else {
      17 - 3 * i
    }
    let neo_label = if is_redux {
      v("nodeBorder")
    } else {
      v("cScaleLabel\{if theme_name == "neutral" { 1 } else { i }}")
    }
    let neo_fill = if is_redux || theme_name == "neutral" {
      v("mainBkg")
    } else {
      v("cScale\{i}")
    }
    let neo_stroke = if is_redux { v("nodeBorder") } else { v("cScale\{i}") }
    let neo_edge = if theme_name.contains("redux") || theme_name == "neo-dark" {
      v("nodeBorder")
    } else {
      v("cScale\{i}")
    }
    out.write_string(
      (
        $|
        $|    .section-\{k} rect, .section-\{k} path, .section-\{k} circle, .section-\{k} polygon, .section-\{k} path  {
        $|      fill: \{v("cScale\{i}")};
        $|    }
        $|    .section-\{k} text {
        $|     fill: \{v("cScaleLabel\{i}")};
        $|    }
        $|     .section-\{k} span {
        $|     color: \{v("cScaleLabel\{i}")};
        $|    }
        $|    .node-icon-\{k} {
        $|      font-size: 40px;
        $|      color: \{v("cScaleLabel\{i}")};
        $|    }
        $|    .section-edge-\{k}{
        $|      stroke: \{v("cScale\{i}")};
        $|    }
        $|    .edge-depth-\{k}{
        $|      stroke-width: \{sw};
        $|    }
        $|    .section-\{k} line {
        $|      stroke: \{v("cScaleInv\{i}")} ;
        $|      stroke-width: 3;
        $|    }
        $|
        $|    .disabled, .disabled circle, .disabled text {
        $|      fill: lightgray;
        $|    }
        $|    .disabled text {
        $|      fill: #efefef;
        $|    }
        $|    [data-look="neo"].mindmap-node.section-\{k} rect, [data-look="neo"].mindmap-node.section-\{k} path, [data-look="neo"].mindmap-node.section-\{k} circle, [data-look="neo"].mindmap-node.section-\{k} polygon {
        $|      fill: \{neo_fill};
        $|      stroke: \{neo_stroke};
        $|      stroke-width: \{stroke_width}px;
        $|    }
        $|    [data-look="neo"].section-edge-\{k}{
        $|      stroke: \{neo_edge};
        $|    }
        $|    [data-look="neo"].mindmap-node.section-\{k} text, [data-look="neo"].mindmap-node.section-\{k} span {
        $|     fill: \{neo_label};
        $|     color: \{neo_label};
        $|    }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// `genGradient`: with a gradient theme the outlines of the neo look are
/// painted with it.
fn gen_gradient(limit : Int32, svg_id : String, main_bkg : String) -> String {
  let out = StringBuilder()
  for i in 0..<limit {
    let k = i - 1
    out.write_string(
      (
        $|
        $|    [data-look="neo"].mindmap-node.section-\{k} rect, [data-look="neo"].mindmap-node.section-\{k} path, [data-look="neo"].mindmap-node.section-\{k} circle, [data-look="neo"].mindmap-node.section-\{k} polygon {
        $|      stroke: url(\{svg_id}-gradient);
        $|      fill: \{main_bkg};
        $|    }
        $|    .section-\{k} line {
        $|      stroke-width: 0;
        $|    }
      ),
    )
  }
  out.to_string()
}

///|
/// The diagram's stylesheet before it is scoped and compiled. `svg_id`
/// is the id of the `<svg>` element with its `#`.
pub fn styles(config : @config.Config, svg_id : String) -> String {
  let theme = config.theme()
  let theme_name = config.text("theme").unwrap_or("")
  let look = config.text("look").unwrap_or("")
  let v = (name : String) => theme.text(name)
  let is_redux = theme_name.contains("redux")
  let neo_root_label = if is_redux {
    v("nodeBorder")
  } else {
    v("cScaleLabel\{if theme_name == "neutral" { 1 } else { 0 }}")
  }
  let scoped_drop_shadow = match theme.get("dropShadow") {
    Null | False | String("") => "none"
    _ =>
      v("dropShadow").replace(
        old="url(#drop-shadow)",
        new="url(\{svg_id}-drop-shadow)",
      )
  }
  let gradient = if theme.flag("useGradient") &&
    svg_id != "" &&
    !(theme.get("mainBkg") is (Null | String(""))) {
    gen_gradient(color_limit(theme), svg_id, v("mainBkg"))
  } else {
    ""
  }
  (
    $|
    $|  .edge {
    $|    stroke-width: 3;
    $|  }
    $|  \{gen_sections(theme, theme_name, look)}
    $|  .section-root rect, .section-root path, .section-root circle, .section-root polygon  {
    $|    fill: \{v("git0")};
    $|  }
    $|  .section-root text {
    $|    fill: \{v("gitBranchLabel0")};
    $|  }
    $|  .section-root span {
    $|    color: \{if is_redux { v("nodeBorder") } else { v("gitBranchLabel0") }};
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
    $|  .mindmap-node-label {
    $|    dy: 1em;
    $|    alignment-baseline: middle;
    $|    text-anchor: middle;
    $|    dominant-baseline: middle;
    $|    text-align: center;
    $|  }
    $|  [data-look="neo"].mindmap-node  {
    $|    filter: \{scoped_drop_shadow};
    $|  }
    $|  [data-look="neo"].mindmap-node.section-root rect, [data-look="neo"].mindmap-node.section-root path, [data-look="neo"].mindmap-node.section-root circle, [data-look="neo"].mindmap-node.section-root polygon  {
    $|    fill: \{if is_redux { v("mainBkg") } else { v("git0") }};
    $|  }
    $|  [data-look="neo"].mindmap-node.section-root .text-inner-tspan, [data-look="neo"].mindmap-node.section-root span {
    $|    fill: \{neo_root_label};
    $|    color: \{neo_root_label};
    $|  }
    $|  \{gradient}
    $|
  )
}
