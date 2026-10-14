///|
/// The Sankey diagram's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String {
  let v = (name : String) => theme.text(name)
  // `options.mainBkg || options.background || '#fff'`
  let background = match (v("mainBkg"), v("background")) {
    ("", "") => "#fff"
    ("", background) => background
    (main, _) => main
  }
  (
    $|.label {
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .node-labels {
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  /* Outlined label style - background stroke for better readability */
    $|  .sankey-label-bg {
    $|    stroke: \{background};
    $|    stroke-width: 4px;
    $|    stroke-linejoin: round;
    $|    paint-order: stroke;
    $|  }
    $|
    $|  /* Foreground label text */
    $|  .sankey-label-fg {
    $|    fill: \{v("textColor")};
    $|  }
    $|
    $|  /* Node styling */
    $|  .node rect {
    $|    shape-rendering: crispEdges;
    $|  }
    $|
    $|  /* Link styling */
    $|  .link {
    $|    fill: none;
    $|    stroke-opacity: 0.5;
    $|    mix-blend-mode: multiply;
    $|  }
    $|
  )
}
