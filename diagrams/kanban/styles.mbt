// The kanban diagram's stylesheet: mermaid's `kanban/styles.ts`.

///|
/// How many sections the stylesheet colours before the colours repeat:
/// the theme's `THEME_COLOR_LIMIT`.
fn color_slot_count(theme : @theme.Theme) -> Int32 raise KanbanError {
  match theme.get("THEME_COLOR_LIMIT") {
    Number(limit, ..) if limit <= 64.0 => limit.ceil().to_int().max(0)
    _ => raise Unsupported("a THEME_COLOR_LIMIT that is no small count")
  }
}

///|
/// The rules colouring each section from the theme's colour scale.
fn section_styles(theme : @theme.Theme) -> String raise KanbanError {
  let v = (name : String) => theme.text(name)
  // Sections stand out from the scale: darker in a dark theme, lighter
  // otherwise.
  let adjusted = (name : String) => {
    let color = v(name)
    try {
      if theme.flag("darkMode") {
        @color.darken(color, 10.0)
      } else {
        @color.lighten(color, 10.0)
      }
    } catch {
      _ => raise Unsupported("the colour \{color} of the theme's \{name}")
    }
  }
  let out = StringBuilder()
  for i in 0..<color_slot_count(theme) {
    let k = i - 1
    out.write_string(
      (
        $|
        $|    .section-\{k} rect, .section-\{k} path, .section-\{k} circle, .section-\{k} polygon, .section-\{k} path  {
        $|      fill: \{adjusted("cScale\{i}")};
        $|      stroke: \{adjusted("cScale\{i}")};
        $|
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
        $|    .disabled, .disabled circle, .disabled text {
        $|      fill: lightgray;
        $|    }
        $|    .disabled text {
        $|      fill: #efefef;
        $|    }
        $|
        $|  .node rect,
        $|  .node circle,
        $|  .node ellipse,
        $|  .node polygon,
        $|  .node path {
        $|    fill: \{v("background")};
        $|    stroke: \{v("nodeBorder")};
        $|    stroke-width: 1px;
        $|  }
        $|
        $|  .kanban-ticket-link {
        $|    fill: \{v("background")};
        $|    stroke: \{v("nodeBorder")};
        $|    text-decoration: underline;
        $|  }
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// The rules every diagram with Font Awesome icons in its labels shares:
/// mermaid's `getIconStyles`.
let icon_styles : String =
  #|
  #|  /* Font Awesome icon styling - consolidated */
  #|  .label-icon {
  #|    display: inline-block;
  #|    height: 1em;
  #|    overflow: visible;
  #|    vertical-align: -0.125em;
  #|  }
  #|  
  #|  .node .label-icon path {
  #|    fill: currentColor;
  #|    stroke: revert;
  #|    stroke-width: revert;
  #|  }
  #|

///|
/// The kanban diagram's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String raise KanbanError {
  let v = (name : String) => theme.text(name)
  (
    $|
    $|  .edge {
    $|    stroke-width: 3;
    $|  }
    $|  \{section_styles(theme)}
    $|  .section-root rect, .section-root path, .section-root circle, .section-root polygon  {
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
    $|  .cluster-label, .label {
    $|    color: \{v("textColor")};
    $|    fill: \{v("textColor")};
    $|    }
    $|  .kanban-label {
    $|    dy: 1em;
    $|    alignment-baseline: middle;
    $|    text-anchor: middle;
    $|    dominant-baseline: middle;
    $|    text-align: center;
    $|  }
    $|    \{icon_styles}
    $|
  )
}
