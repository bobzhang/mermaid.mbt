///|
/// The rules that colour elements by their slot in the palette of the
/// colour themes: `genColor`. System boundaries are always numbered;
/// actors and use cases only with `colorScheme: rotate`. Nothing for
/// other themes.
fn palette_rules(config : @config.Config) -> String {
  let theme = config.theme()
  guard config.text("theme") is Some("redux-color" | "redux-dark-color") &&
    theme.get("borderColorArray") is Array(borders) &&
    !borders.is_empty() else {
    return ""
  }
  let rotate = config.text("usecase.colorScheme") == Some("rotate")
  let look = @rendering.safe_look(config.text("look").unwrap_or(""))
  let hand_drawn = look == "handDrawn"
  let fills = match theme.get("bkgColorArray") {
    Array(fills) if !fills.is_empty() => Some(fills)
    _ => None
  }
  let color = (palette : Array[Json], index : Int32) => {
    match palette[index % palette.length()] {
      String(color) => color
      other => other.stringify()
    }
  }
  let out = StringBuilder()
  for i in 0..<borders.length() {
    let border = color(borders, i)
    let fill = match fills {
      Some(fills) => "fill: \{color(fills, i)};"
      None => ""
    }
    let slot = "[data-look=\"\{look}\"][data-color-id=\"color-\{i}\"]"
    out.write_string(
      (
        $|
        $|
        $|    & \{slot}.system-boundary rect.boundary-body,
        $|    & \{slot}.system-boundary rect.boundary-tab,
        $|    & \{slot}.system-boundary .boundary-body path,
        $|    & \{slot}.system-boundary .boundary-tab path {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|    
      ),
    )
    if !rotate {
      continue
    }
    // Under the hand-drawn look rough.js draws outline and fill as paths
    // nothing tells apart, so the glyph's children are not named there.
    let glyph = if hand_drawn {
      ""
    } else {
      (
        $|
        $|    & \{slot}.usecase-actor .usecase-actor-glyph path,
        $|    & \{slot}.usecase-actor .usecase-actor-glyph circle {
        $|      stroke: \{border};
        $|    }
        $|
      )
    }
    out.write_string(
      (
        $|
        $|
        $|    & \{slot}.usecase-element ellipse,
        $|    & \{slot}.usecase-element rect {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|
        $|    & \{slot}.usecase-element .usecase-business-marker {
        $|      stroke: \{border};
        $|    }
        $|
        $|    & \{slot}.usecase-actor .usecase-actor-shape,
        $|    & \{slot}.usecase-actor .usecase-actor-hollow,
        $|    & \{slot}.usecase-actor .usecase-actor-awesome,
        $|    & \{slot}.usecase-actor .usecase-actor-icon {
        $|      stroke: \{border};
        $|      \{fill}
        $|    }
        $|\{glyph}
        $|    
      ),
    )
  }
  out.to_string()
}

///|
/// The use case diagram's stylesheet, before it is scoped to the diagram:
/// mermaid's `usecase/styles.ts`.
pub fn styles(config : @config.Config) -> String {
  let theme = config.theme()
  // The first of the variables the theme has; `undefined` when it has
  // none of them, as a template writes a missing value.
  let v = (names : Array[String]) => {
    for name in names {
      if !(theme.get(name) is Null) {
        return theme.text(name)
      }
    }
    "undefined"
  }
  let look = @rendering.safe_look(config.text("look").unwrap_or(""))
  let hand_drawn = look == "handDrawn"
  let actor_bkg = v(["usecaseActorBkg", "actorBkg", "mainBkg"])
  let actor_border = v(["usecaseActorBorder", "actorBorder", "primaryColor"])
  let bkg = v(["usecaseBkg", "mainBkg"])
  let border = v(["usecaseBorder", "nodeBorder", "primaryColor"])
  let boundary_bkg = v(["usecaseBoundaryBkg", "clusterBkg"])
  let boundary_border = v(["usecaseBoundaryBorder", "clusterBorder"])
  let include_line = v(["usecaseIncludeLine", "lineColor"])
  let extend_line = v(["usecaseExtendLine", "lineColor"])
  let actor_text = v(["actorTextColor", "primaryTextColor"])
  let text = v(["primaryTextColor"])
  let title = v(["titleColor", "primaryTextColor"])
  let font_family = v(["fontFamily"])
  let line = v(["lineColor"])
  let edge_label_background = v(["edgeLabelBackground"])
  // The neo look's own rules reach the children of a glyph or a use case
  // directly; these restate the role colours where they would win.
  let glyph = if hand_drawn {
    ""
  } else {
    (
      $|
      $|  & .node.usecase-actor .usecase-actor-glyph path,
      $|  & .node.usecase-actor .usecase-actor-glyph circle {
      $|    stroke: \{actor_border};
      $|  }
      $|
    )
  }
  let element = if hand_drawn {
    ""
  } else {
    (
      $|
      $|  & [data-look="\{look}"].node.usecase-element ellipse,
      $|  & [data-look="\{look}"].node.usecase-element rect {
      $|    fill: \{bkg};
      $|    stroke: \{border};
      $|  }
      $|
      $|  & [data-look="\{look}"].node.usecase-element .usecase-business-marker {
      $|    stroke: \{border};
      $|  }
      $|
    )
  }
  (
    $|
    $|  \{palette_rules(config)}
    $|  & .usecase-actor {
    $|    color: \{actor_text};
    $|  }
    $|
    $|  & .usecase-actor-shape,
    $|  & .usecase-actor-hollow,
    $|  & .usecase-actor-awesome,
    $|  & .usecase-actor-icon {
    $|    fill: \{actor_bkg};
    $|    stroke: \{actor_border};
    $|    stroke-width: 2px;
    $|  }
    $|\{glyph}
    $|  & .usecase-actor .nodeLabel,
    $|  & .actor-label {
    $|    color: \{actor_text};
    $|    fill: \{actor_text};
    $|    font-family: var(--mermaid-usecase-actor-font-family, \{font_family});
    $|    font-size: var(--mermaid-usecase-actor-font-size, 14px);
    $|    font-weight: var(--mermaid-usecase-actor-font-weight, normal);
    $|  }
    $|
    $|  & .usecase-element ellipse,
    $|  & .usecase-element rect,
    $|  & .usecase-business ellipse,
    $|  & .usecase-business rect {
    $|    fill: \{bkg};
    $|    stroke: \{border};
    $|    stroke-width: 2px;
    $|  }
    $|\{element}
    $|  & .usecase-element .nodeLabel,
    $|  & .usecase-label {
    $|    color: \{text};
    $|    fill: \{text};
    $|    font-family: var(--mermaid-usecase-font-family, \{font_family});
    $|    font-size: var(--mermaid-usecase-font-size, 12px);
    $|    font-weight: var(--mermaid-usecase-font-weight, normal);
    $|  }
    $|
    $|  & .usecase-stereotype,
    $|  & .usecase-business-marker {
    $|    color: \{text};
    $|    fill: \{text};
    $|    stroke: \{border};
    $|  }
    $|
    $|  & .system-boundary rect.boundary-body,
    $|  & .system-boundary rect.boundary-tab,
    $|  & .system-boundary-package-tab {
    $|    fill: \{boundary_bkg};
    $|    stroke: \{boundary_border};
    $|    stroke-width: 1px;
    $|  }
    $|
    $|  & .system-boundary-title text {
    $|    fill: \{title};
    $|  }
    $|
    $|  & .system-boundary-title span {
    $|    color: \{title};
    $|  }
    $|
    $|  & .usecase-note {
    $|    fill: \{v(["noteBkgColor"])};
    $|    stroke: \{v(["noteBorderColor"])};
    $|    color: \{v(["noteTextColor"])};
    $|  }
    $|
    $|  & .usecase-note .nodeLabel {
    $|    color: \{v(["noteTextColor"])};
    $|    fill: \{v(["noteTextColor"])};
    $|  }
    $|
    $|  & .usecase-json-table,
    $|  & .usecase-json-table rect,
    $|  & .usecase-json-cell {
    $|    fill: \{v(["mainBkg"])};
    $|    stroke: \{v(["nodeBorder", "primaryColor"])};
    $|  }
    $|
    $|  & .usecase-json-title,
    $|  & .usecase-json-key,
    $|  & .usecase-json-value {
    $|    color: \{text};
    $|    fill: \{text};
    $|  }
    $|
    $|  & .relationship {
    $|    fill: none;
    $|    stroke: \{line};
    $|  }
    $|
    $|  & .relationship-include,
    $|  & .relationship-extend,
    $|  & .relationship-note {
    $|    stroke-dasharray: 3;
    $|  }
    $|
    $|  & .relationship-include {
    $|    stroke: \{include_line};
    $|  }
    $|
    $|  & .relationship-extend {
    $|    stroke: \{extend_line};
    $|  }
    $|
    $|  & .relationship.edge-animation-fast,
    $|  & .relationship.edge-animation-slow {
    $|    stroke-linecap: round;
    $|  }
    $|
    $|  & .edgeLabel,
    $|  & .edgeLabel p {
    $|    background-color: \{edge_label_background};
    $|  }
    $|
    $|  & .labelBkg {
    $|    background-color: \{edge_label_background};
    $|    padding: 0 2px;
    $|  }
    $|
    $|  & .edgeLabel .label rect {
    $|    fill: \{edge_label_background};
    $|  }
    $|
    $|  & .relationship-label,
    $|  & .edgeLabel {
    $|    color: \{text};
    $|    fill: \{text};
    $|    font-family: \{font_family};
    $|    font-size: 10px;
    $|    font-weight: normal;
    $|  }
    $|
    $|  & .marker,
    $|  & .marker.point,
    $|  & .marker.circle,
    $|  & .marker.cross {
    $|    fill: \{line};
    $|    stroke: \{line};
    $|  }
    $|
    $|  & .marker.extension {
    $|    fill: \{v(["mainBkg"])};
    $|    stroke: \{line};
    $|  }
    $|
  )
}
