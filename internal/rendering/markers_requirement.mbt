// The markers of requirement diagrams: `requirement_arrow`,
// `requirement_contains` and their neo variants in mermaid's
// rendering-elements/markers.js. They carry no class.

///|
/// Insert the definition of a requirement marker. `stroke` is the theme's
/// stroke width in the neo look. Returns whether `kind` was one.
fn insert_requirement_marker(
  parent : @dom.Element,
  kind : String,
  diagram_type : String,
  diagram_id : String,
  stroke : String?,
) -> Bool {
  let frame = (suffix : String, ref_x : String) => {
    let marker = parent
      .append("defs")
      .append("marker")
      .attr("id", "\{diagram_id}_\{diagram_type}-\{suffix}")
      .attr("refX", ref_x)
      .attr("refY", "10")
      .attr("markerWidth", "20")
      .attr("markerHeight", "20")
      .attr("orient", "auto")
    if stroke is Some(_) {
      marker.attr("markerUnits", "userSpaceOnUse") |> ignore
    }
    marker
  }
  match kind {
    "requirement_arrow" | "requirement_arrow_neo" => {
      let marker = frame("requirement_arrowEnd", "20")
      if stroke is Some(width) {
        marker.attr("stroke-width", width).attr("viewBox", "0 0 25 20")
        |> ignore
      }
      // The path data is written over four lines upstream.
      let path = marker
        .append("path")
        .attr("d", "M0,0\n      L20,10\n      M20,10\n      L0,20")
      if stroke is Some(_) {
        path.attr("stroke-linejoin", "miter") |> ignore
      }
      true
    }
    "requirement_contains" | "requirement_contains_neo" => {
      let group = frame("requirement_containsStart", "0").append("g")
      let shapes = [
        group
        .append("circle")
        .attr("cx", "10")
        .attr("cy", "10")
        .attr("r", "9")
        .attr("fill", "none"),
        group
        .append("line")
        .attr("x1", "1")
        .attr("x2", "19")
        .attr("y1", "10")
        .attr("y2", "10"),
        group
        .append("line")
        .attr("y1", "1")
        .attr("y2", "19")
        .attr("x1", "10")
        .attr("x2", "10"),
      ]
      if stroke is Some(width) {
        for shape in shapes {
          shape.attr("stroke-width", width) |> ignore
        }
      }
      true
    }
    _ => false
  }
}
