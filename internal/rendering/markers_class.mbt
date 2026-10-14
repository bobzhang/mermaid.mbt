// The markers of class diagrams: `aggregation`, `extension`,
// `composition`, `dependency` and `lollipop` in mermaid's
// rendering-elements/markers.js. Each kind has a start and an end marker
// and a `-margin` variant of both for the neo look.

///|
/// One marker of a relation end, in output order: the suffix of its id,
/// its `refX` and size, the attributes after `markerUnits`, and its only
/// child with its attributes and the styles set on it through the CSSOM,
/// which are written last.
priv struct ClassMarker {
  suffix : String
  ref_x : String
  width : String
  height : String
  extra : Array[(String, String)]
  child : String
  child_attributes : Array[(String, String)]
  child_styles : Array[(String, String)]
  /// Whether the marker sits in a `<defs>`; one of them does not.
  in_defs : Bool
}

///|
fn ClassMarker::new(
  suffix : String,
  ref_x : String,
  large~ : Bool = false,
  extra~ : Array[(String, String)] = [],
  child~ : String = "path",
  attributes : Array[(String, String)],
  styles~ : Array[(String, String)] = [],
  in_defs~ : Bool = true,
) -> ClassMarker {
  {
    suffix,
    ref_x,
    width: if large {
      "190"
    } else {
      "20"
    },
    height: if large {
      "240"
    } else {
      "28"
    },
    extra,
    child,
    child_attributes: attributes,
    child_styles: styles,
    in_defs,
  }
}

///|
/// The markers of one kind of relation end.
fn class_markers(kind : String) -> Array[ClassMarker]? {
  let diamond = ("d", "M 18,7 L9,13 L1,7 L9,1 Z")
  let view_box = [("viewBox", "0 0 20 14")]
  let dash = [("stroke-width", "2"), ("stroke-dasharray", "0")]
  let circle = [("fill", "transparent"), ("cx", "7"), ("cy", "7"), ("r", "6")]
  match kind {
    "extension" =>
      Some([
        ClassMarker::new("Start", "18", [("d", "M 1,7 L18,13 V 1 Z")]),
        ClassMarker::new("End", "1", [("d", "M 1,1 V 13 L18,7 Z")]),
        ClassMarker::new(
          "Start-margin",
          "18",
          extra=view_box,
          child="polygon",
          [("points", "10,7 18,13 18,1")],
          styles=dash,
          in_defs=false,
        ),
        ClassMarker::new(
          "End-margin",
          "9",
          extra=view_box,
          child="polygon",
          [("points", "10,1 10,13 18,7")],
          styles=dash,
        ),
      ])
    "composition" =>
      Some([
        ClassMarker::new("Start", "18", large=true, [diamond]),
        ClassMarker::new("End", "1", [diamond]),
        ClassMarker::new(
          "Start-margin",
          "15",
          large=true,
          [("viewBox", "0 0 15 15"), diamond],
          styles=[("stroke-width", "0")],
        ),
        ClassMarker::new("End-margin", "3.5", [diamond], styles=[
          ("stroke-width", "0"),
        ]),
      ])
    "aggregation" =>
      Some([
        ClassMarker::new("Start", "18", large=true, [diamond]),
        ClassMarker::new("End", "1", [diamond]),
        ClassMarker::new("Start-margin", "15", large=true, [diamond], styles=[
          ("stroke-width", "2"),
        ]),
        ClassMarker::new("End-margin", "1", [diamond], styles=[
          ("stroke-width", "2"),
        ]),
      ])
    "dependency" => {
      let start = ("d", "M 5,7 L9,13 L1,7 L9,1 Z")
      let end = ("d", "M 18,7 L9,13 L14,7 L9,1 Z")
      Some([
        ClassMarker::new("Start", "6", large=true, [start]),
        ClassMarker::new("End", "13", [end]),
        ClassMarker::new("Start-margin", "4", large=true, [start], styles=[
          ("stroke-width", "0"),
        ]),
        ClassMarker::new("End-margin", "16", [end], styles=[
          ("stroke-width", "0"),
        ]),
      ])
    }
    "lollipop" =>
      Some([
        ClassMarker::new("Start", "13", large=true, child="circle", circle),
        ClassMarker::new("End", "1", large=true, child="circle", circle),
        ClassMarker::new(
          "Start-margin",
          "13",
          large=true,
          child="circle",
          [..circle, ("stroke-width", "2")],
        ),
        ClassMarker::new(
          "End-margin",
          "1",
          large=true,
          child="circle",
          [..circle, ("stroke-width", "2")],
        ),
      ])
    _ => None
  }
}

///|
/// Insert the definitions of a class diagram marker kind. Returns whether
/// `kind` was one.
fn insert_class_marker(
  parent : @dom.Element,
  kind : String,
  diagram_type : String,
  diagram_id : String,
) -> Bool {
  guard class_markers(kind) is Some(markers) else { return false }
  for marker in markers {
    let holder = if marker.in_defs { parent.append("defs") } else { parent }
    let element = holder
      .append("marker")
      .attr("id", "\{diagram_id}_\{diagram_type}-\{kind}\{marker.suffix}")
      .attr("class", "marker \{kind} \{diagram_type}")
      .attr("refX", marker.ref_x)
      .attr("refY", "7")
      .attr("markerWidth", marker.width)
      .attr("markerHeight", marker.height)
      .attr("orient", "auto")
      .attr("markerUnits", "userSpaceOnUse")
    for attribute in marker.extra {
      element.attr(attribute.0, attribute.1) |> ignore
    }
    let child = element.append(marker.child)
    for attribute in marker.child_attributes {
      child.attr(attribute.0, attribute.1) |> ignore
    }
    for style in marker.child_styles {
      child.style(style.0, style.1) |> ignore
    }
  }
  true
}
