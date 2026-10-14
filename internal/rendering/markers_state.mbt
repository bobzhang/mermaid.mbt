// The arrowheads of state diagram transitions: `barb` and `barbNeo` of
// mermaid's rendering-elements/markers.js. Unlike the flowchart markers
// they sit in a `defs` each and carry no class.

///|
/// One barb marker in a `defs` of its own.
fn insert_barb(
  parent : @dom.Element,
  id : String,
  units : String,
  ref_x : String,
  path : String,
  fill? : String,
) -> Unit {
  let shape = parent
    .append("defs")
    .append("marker")
    .attr("id", id)
    .attr("refX", ref_x)
    .attr("refY", "7")
    .attr("markerWidth", "20")
    .attr("markerHeight", "14")
    .attr("markerUnits", units)
    .attr("orient", "auto")
    .append("path")
    .attr("d", path)
  if fill is Some(fill) {
    shape.attr("fill", fill) |> ignore
  }
}

///|
/// Insert the markers of `kind` if it is one of the barbs; whether it was.
fn insert_state_markers(
  parent : @dom.Element,
  kind : String,
  diagram_type : String,
  diagram_id : String,
  config : @config.Config,
) -> Bool {
  let id = "\{diagram_id}_\{diagram_type}-barbEnd"
  match kind {
    "barb" => {
      insert_barb(
        parent, id, "userSpaceOnUse", "19", "M 19,7 L9,13 L14,7 L9,1 Z",
      )
      true
    }
    "barbNeo" => {
      let path = "M 19,7 L11,14 L13,7 L11,0 Z"
      insert_barb(parent, id, "strokeWidth", "19", path)
      insert_barb(
        parent,
        id + "-margin",
        "userSpaceOnUse",
        "17",
        path,
        fill=config.theme().text("transitionColor"),
      )
      true
    }
    _ => false
  }
}
