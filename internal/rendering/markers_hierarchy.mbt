///|
/// The double chevrons of the `hierarchy` marker kind, which agentflow
/// diagrams define: mermaid's `hierarchy` marker. Whether `kind` was it.
fn insert_hierarchy_marker(
  parent : @dom.Element,
  kind : String,
  diagram_type : String,
  diagram_id : String,
) -> Bool {
  guard kind == "hierarchy" else { return false }
  for
    end in [
      ("End", "10", "M 0 0 L 6 5 L 0 10 M 4 0 L 10 5 L 4 10"),
      ("Start", "2", "M 12 0 L 6 5 L 12 10 M 8 0 L 2 5 L 8 10"),
    ] {
    let (suffix, ref_x, d) = end
    parent
    .append("marker")
    .attr("id", "\{diagram_id}_\{diagram_type}-hierarchy\{suffix}")
    .attr("class", "marker hierarchy \{diagram_type}")
    .attr("viewBox", "0 0 12 10")
    .attr("refX", ref_x)
    .attr("refY", "5")
    .attr("markerUnits", "userSpaceOnUse")
    .attr("markerWidth", "12")
    .attr("markerHeight", "10")
    .attr("orient", "auto")
    .append("path")
    .attr("d", d)
    .attr("class", "arrowMarkerPath")
    .attr("style", "stroke-width: 1; stroke-dasharray: 1, 0; fill: none;")
    |> ignore
  }
  true
}
