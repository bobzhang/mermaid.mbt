// The cardinality markers of ER diagrams: `only_one`, `zero_or_one`,
// `one_or_more`, `zero_or_more` and their neo variants in mermaid's
// rendering-elements/markers.js. Unlike the arrowheads, each sits in a
// `<defs>` of its own, and the neo ones take their stroke width and the
// fill of their circles from the theme.

///|
/// One marker: the suffix of its id, its attributes after id and class, and
/// its children with their attributes, all in output order.
priv struct MarkerShape {
  suffix : String
  attributes : Array[(String, String)]
  children : Array[(String, Array[(String, String)])]
}

///|
/// The attributes of a cardinality marker after its id and class. Classic
/// markers scale with the stroke; neo ones are in user units, an attribute
/// that comes before or after `orient` depending on the marker.
fn er_frame(
  neo : Bool,
  ref_x : String,
  ref_y : String,
  width : String,
  height : String,
  units_first~ : Bool = false,
) -> Array[(String, String)] {
  let attributes = [
    ("refX", ref_x),
    ("refY", ref_y),
    ("markerWidth", width),
    ("markerHeight", height),
  ]
  if neo && units_first {
    attributes.push(("markerUnits", "userSpaceOnUse"))
  }
  attributes.push(("orient", "auto"))
  if neo && !units_first {
    attributes.push(("markerUnits", "userSpaceOnUse"))
  }
  attributes
}

///|
/// The circle of a "zero" marker. In the neo look its stroke width comes
/// before its radius, except in the markers for zero or more.
fn er_circle(
  stroke : String?,
  fill : String,
  cx : String,
  cy : String,
  radius_first~ : Bool = false,
) -> (String, Array[(String, String)]) {
  let attributes = [("fill", fill), ("cx", cx), ("cy", cy)]
  match stroke {
    Some(width) if radius_first => {
      attributes.push(("r", "6"))
      attributes.push(("stroke-width", width))
    }
    Some(width) => {
      attributes.push(("stroke-width", width))
      attributes.push(("r", "6"))
    }
    None => attributes.push(("r", "6"))
  }
  ("circle", attributes)
}

///|
/// The two markers of a cardinality, for the start and the end of a line.
/// `stroke` is the theme's stroke width in the neo look, `fill` what the
/// circles are filled with.
fn er_marker_shapes(
  kind : String,
  stroke : String?,
  fill : String,
) -> (String, Array[MarkerShape])? {
  let neo = stroke is Some(_)
  let frame = (ref_x : String, ref_y : String, width : String, height : String) => {
    er_frame(neo, ref_x, ref_y, width, height)
  }
  let frame_units_first = (
    ref_x : String,
    ref_y : String,
    width : String,
    height : String,
  ) => er_frame(neo, ref_x, ref_y, width, height, units_first=true)
  let path = (d : String) => {
    let attributes = [("d", d)]
    if stroke is Some(width) {
      attributes.push(("stroke-width", width))
    }
    ("path", attributes)
  }
  let circle = (cx : String, cy : String) => er_circle(stroke, fill, cx, cy)
  let circle_radius_first = (cx : String, cy : String) => {
    er_circle(stroke, fill, cx, cy, radius_first=true)
  }
  match kind {
    "only_one" | "only_one_neo" =>
      Some(
        (
          "onlyOne",
          [
            {
              suffix: "Start",
              attributes: frame("0", "9", "18", "18"),
              children: [path("M9,0 L9,18 M15,0 L15,18")],
            },
            {
              suffix: "End",
              attributes: frame("18", "9", "18", "18"),
              children: [path("M3,0 L3,18 M9,0 L9,18")],
            },
          ],
        ),
      )
    "zero_or_one" | "zero_or_one_neo" =>
      Some(
        (
          "zeroOrOne",
          [
            {
              suffix: "Start",
              attributes: frame("0", "9", "30", "18"),
              children: [circle("21", "9"), path("M9,0 L9,18")],
            },
            {
              suffix: "End",
              attributes: frame_units_first("30", "9", "30", "18"),
              children: [circle("9", "9"), path("M21,0 L21,18")],
            },
          ],
        ),
      )
    "one_or_more" | "one_or_more_neo" =>
      Some(
        (
          "oneOrMore",
          [
            {
              suffix: "Start",
              attributes: frame("18", "18", "45", "36"),
              children: [path("M0,18 Q 18,0 36,18 Q 18,36 0,18 M42,9 L42,27")],
            },
            {
              suffix: "End",
              attributes: frame_units_first("27", "18", "45", "36"),
              children: [path("M3,9 L3,27 M9,18 Q27,0 45,18 Q27,36 9,18")],
            },
          ],
        ),
      )
    "zero_or_more" | "zero_or_more_neo" =>
      Some(
        (
          "zeroOrMore",
          [
            {
              suffix: "Start",
              attributes: frame_units_first("18", "18", "57", "36"),
              children: [
                circle_radius_first(if neo { "45.5" } else { "48" }, "18"),
                path("M0,18 Q18,0 36,18 Q18,36 0,18"),
              ],
            },
            {
              suffix: "End",
              attributes: frame("39", "18", "57", "36"),
              children: [
                circle_radius_first(if neo { "11" } else { "9" }, "18"),
                path("M21,18 Q39,0 57,18 Q39,36 21,18"),
              ],
            },
          ],
        ),
      )
    _ => None
  }
}

///|
/// Insert the definitions of one of the marker kinds that are not plain
/// data. Returns whether `kind` was one.
fn insert_themed_marker(
  parent : @dom.Element,
  kind : String,
  diagram_type : String,
  diagram_id : String,
  config : @config.Config,
) -> Bool {
  let theme = config.theme()
  let neo = kind.has_suffix("_neo")
  let stroke = if neo { Some(theme.text("strokeWidth")) } else { None }
  let fill = match theme.get("mainBkg") {
    String(color) if neo => color
    _ => "white"
  }
  guard er_marker_shapes(kind, stroke, fill) is Some((name, shapes)) else {
    return insert_requirement_marker(
      parent, kind, diagram_type, diagram_id, stroke,
    )
  }
  for shape in shapes {
    let marker = parent
      .append("defs")
      .append("marker")
      .attr("id", "\{diagram_id}_\{diagram_type}-\{name}\{shape.suffix}")
      .attr("class", "marker \{name} \{diagram_type}")
    for attribute in shape.attributes {
      marker.attr(attribute.0, attribute.1) |> ignore
    }
    for child in shape.children {
      let element = marker.append(child.0)
      for attribute in child.1 {
        element.attr(attribute.0, attribute.1) |> ignore
      }
    }
  }
  true
}
