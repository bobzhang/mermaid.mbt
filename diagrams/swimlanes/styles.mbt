// Swimlane diagrams are flowcharts laid out in lanes: mermaid's
// `diagrams/swimlanes`, a "layout-variant diagram" that reuses the
// flowchart parser, database and renderer and only adds the lane rules of
// `styles.ts`.

///|
/// The stylesheet: the flowchart's, then the lane rules. The swimlane
/// cluster shape draws its own border, so the generic cluster border of
/// lanes without a palette slot takes the theme's cluster border colour.
pub fn styles(
  theme : @theme.Theme,
  theme_name : String,
  look : String,
) -> String {
  let border = theme.text("clusterBorder")
  let lanes =
    $|
    $|  .swimlane.cluster:not([data-color-id]) rect {
    $|    stroke: \{border} !important;
    $|  }
    $|  [data-look="neo"].cluster rect {
    $|    filter: none;
    $|  }
    $|
  @flowchart.styles(theme, theme_name, look) + lanes
}
