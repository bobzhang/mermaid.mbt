// The arrowhead markers of mermaid's rendering-elements/markers.js for the
// marker kinds flowcharts use. They are fixed markup apart from their ids,
// so they are kept as data: each row is the id suffix, the marker's
// attributes, the child element and its attributes, all in output order.

///|
priv struct MarkerDef {
  suffix : String
  /// Extra class between "marker" and the diagram type, e.g. "cross".
  variant : String
  attributes : Array[(String, String)]
  child : String
  child_attributes : Array[(String, String)]
}

///|
let marker_defs : Map[String, Array[MarkerDef]] = {
  "point": [
    {
      suffix: "pointEnd",
      variant: "",
      attributes: [
        ("viewBox", "0 0 10 10"),
        ("refX", "5"),
        ("refY", "5"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "8"),
        ("markerHeight", "8"),
        ("orient", "auto"),
      ],
      child: "path",
      child_attributes: [
        ("d", "M 0 0 L 10 5 L 0 10 z"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 1; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "pointStart",
      variant: "",
      attributes: [
        ("viewBox", "0 0 10 10"),
        ("refX", "4.5"),
        ("refY", "5"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "8"),
        ("markerHeight", "8"),
        ("orient", "auto"),
      ],
      child: "path",
      child_attributes: [
        ("d", "M 0 5 L 10 10 L 10 0 z"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 1; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "pointEnd-margin",
      variant: "",
      attributes: [
        ("viewBox", "0 0 11.5 14"),
        ("refX", "11.5"),
        ("refY", "7"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "10.5"),
        ("markerHeight", "14"),
        ("orient", "auto"),
      ],
      child: "path",
      child_attributes: [
        ("d", "M 0 0 L 11.5 7 L 0 14 z"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 0; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "pointStart-margin",
      variant: "",
      attributes: [
        ("viewBox", "0 0 11.5 14"),
        ("refX", "1"),
        ("refY", "7"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "11.5"),
        ("markerHeight", "14"),
        ("orient", "auto"),
      ],
      child: "polygon",
      child_attributes: [
        ("points", "0,7 11.5,14 11.5,0"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 0; stroke-dasharray: 1, 0;"),
      ],
    },
  ],
  "circle": [
    {
      suffix: "circleEnd",
      variant: "",
      attributes: [
        ("viewBox", "0 0 10 10"),
        ("refX", "11"),
        ("refY", "5"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "11"),
        ("markerHeight", "11"),
        ("orient", "auto"),
      ],
      child: "circle",
      child_attributes: [
        ("cx", "5"),
        ("cy", "5"),
        ("r", "5"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 1; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "circleStart",
      variant: "",
      attributes: [
        ("viewBox", "0 0 10 10"),
        ("refX", "-1"),
        ("refY", "5"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "11"),
        ("markerHeight", "11"),
        ("orient", "auto"),
      ],
      child: "circle",
      child_attributes: [
        ("cx", "5"),
        ("cy", "5"),
        ("r", "5"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 1; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "circleEnd-margin",
      variant: "",
      attributes: [
        ("viewBox", "0 0 10 10"),
        ("refY", "5"),
        ("refX", "12.25"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "14"),
        ("markerHeight", "14"),
        ("orient", "auto"),
      ],
      child: "circle",
      child_attributes: [
        ("cx", "5"),
        ("cy", "5"),
        ("r", "5"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 0; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "circleStart-margin",
      variant: "",
      attributes: [
        ("viewBox", "0 0 10 10"),
        ("refX", "-2"),
        ("refY", "5"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "14"),
        ("markerHeight", "14"),
        ("orient", "auto"),
      ],
      child: "circle",
      child_attributes: [
        ("cx", "5"),
        ("cy", "5"),
        ("r", "5"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 0; stroke-dasharray: 1, 0;"),
      ],
    },
  ],
  "cross": [
    {
      suffix: "crossEnd",
      variant: "cross",
      attributes: [
        ("viewBox", "0 0 11 11"),
        ("refX", "12"),
        ("refY", "5.2"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "11"),
        ("markerHeight", "11"),
        ("orient", "auto"),
      ],
      child: "path",
      child_attributes: [
        ("d", "M 1,1 l 9,9 M 10,1 l -9,9"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 2; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "crossStart",
      variant: "cross",
      attributes: [
        ("viewBox", "0 0 11 11"),
        ("refX", "-1"),
        ("refY", "5.2"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "11"),
        ("markerHeight", "11"),
        ("orient", "auto"),
      ],
      child: "path",
      child_attributes: [
        ("d", "M 1,1 l 9,9 M 10,1 l -9,9"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 2; stroke-dasharray: 1, 0;"),
      ],
    },
    {
      suffix: "crossEnd-margin",
      variant: "cross",
      attributes: [
        ("viewBox", "0 0 15 15"),
        ("refX", "17.7"),
        ("refY", "7.5"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "12"),
        ("markerHeight", "12"),
        ("orient", "auto"),
      ],
      child: "path",
      child_attributes: [
        ("d", "M 1,1 L 14,14 M 1,14 L 14,1"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 2.5;"),
      ],
    },
    {
      suffix: "crossStart-margin",
      variant: "cross",
      attributes: [
        ("viewBox", "0 0 15 15"),
        ("refX", "-3.5"),
        ("refY", "7.5"),
        ("markerUnits", "userSpaceOnUse"),
        ("markerWidth", "12"),
        ("markerHeight", "12"),
        ("orient", "auto"),
      ],
      child: "path",
      child_attributes: [
        ("d", "M 1,1 L 14,14 M 1,14 L 14,1"),
        ("class", "arrowMarkerPath"),
        ("style", "stroke-width: 2.5; stroke-dasharray: 1, 0;"),
      ],
    },
  ],
}

///|
/// Insert the definitions of the given marker kinds ("point", "circle",
/// "cross") into `parent`, with ids of the form
/// "<diagram id>_<diagram type>-<suffix>".
pub fn insert_markers(
  parent : @dom.Element,
  kinds : Array[String],
  diagram_type : String,
  diagram_id : String,
  config? : @config.Config,
) -> Unit {
  for kind in kinds {
    if config is Some(config) &&
      insert_state_markers(parent, kind, diagram_type, diagram_id, config) {
      continue
    }
    if insert_class_marker(parent, kind, diagram_type, diagram_id) {
      continue
    }
    guard marker_defs.get(kind) is Some(defs) else {
      // The other kinds take colours and widths from the theme.
      if config is Some(config) {
        insert_themed_marker(parent, kind, diagram_type, diagram_id, config)
        |> ignore
      }
      continue
    }
    for def in defs {
      let variant = if def.variant == "" { "" } else { def.variant + " " }
      let marker = parent
        .append("marker")
        .attr("id", "\{diagram_id}_\{diagram_type}-\{def.suffix}")
        .attr("class", "marker \{variant}\{diagram_type}")
      for attribute in def.attributes {
        marker.attr(attribute.0, attribute.1) |> ignore
      }
      let child = marker.append(def.child)
      for attribute in def.child_attributes {
        child.attr(attribute.0, attribute.1) |> ignore
      }
    }
  }
}
