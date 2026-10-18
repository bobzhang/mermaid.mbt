// Drawing edges and their labels: mermaid's `rendering-elements/edges.js`.

///|
/// How far a path is pulled back from a marker of this type.
fn marker_offset(arrow_type : String) -> Double {
  match arrow_type {
    "aggregation" | "extension" | "composition" => 17.25
    "dependency" => 6.0
    "lollipop" => 13.5
    "arrow_point" => 4.0
    "arrow_barb_neo" => 5.5
    _ => 0.0
  }
}

///|
/// The stretch at an end of the path left undashed for its marker.
fn marker_offset2(arrow_type : String) -> Double {
  match arrow_type {
    "arrow_point" => 4.0
    "arrow_cross" | "arrow_circle" => 12.5
    _ => 0.0
  }
}

///|
/// Shorten the route at both ends by the room their markers need.
fn apply_marker_offsets(points : Array[Point], edge : Edge) -> Array[Point] {
  let result = points.copy()
  let n = points.length()
  let start_offset = marker_offset(edge.arrow_type_start)
  if n >= 2 && start_offset != 0.0 {
    let p1 = points[0]
    let p2 = points[1]
    let angle = @jsmath.atan2(p2.y - p1.y, p2.x - p1.x)
    result[0] = {
      x: p1.x + start_offset * @jsmath.cos(angle),
      y: p1.y + start_offset * @jsmath.sin(angle),
    }
  }
  let end_offset = marker_offset(edge.arrow_type_end)
  if n >= 2 && end_offset != 0.0 {
    let p1 = points[n - 1]
    let p2 = points[n - 2]
    let angle = @jsmath.atan2(p1.y - p2.y, p1.x - p2.x)
    result[n - 1] = {
      x: p1.x - end_offset * @jsmath.cos(angle),
      y: p1.y - end_offset * @jsmath.sin(angle),
    }
  }
  result
}

///|
/// A polyline with its corners rounded by quadratic curves: mermaid's
/// `generateRoundedPath`.
fn rounded_path(points : Array[Point], radius : Double) -> String {
  let size = points.length()
  if size < 2 {
    return ""
  }
  let n = @dom.number
  let path = StringBuilder()
  let epsilon = 1.0e-5
  let pi = 3.141592653589793
  for i, curr in points {
    if i == 0 {
      path.write_string("M\{n(curr.x)},\{n(curr.y)}")
    } else if i == size - 1 {
      path.write_string("L\{n(curr.x)},\{n(curr.y)}")
    } else {
      let prev = points[i - 1]
      let next = points[i + 1]
      let dx1 = curr.x - prev.x
      let dy1 = curr.y - prev.y
      let dx2 = next.x - curr.x
      let dy2 = next.y - curr.y
      let len1 = @jsmath.hypot(dx1, dy1)
      let len2 = @jsmath.hypot(dx2, dy2)
      if len1 < epsilon || len2 < epsilon {
        path.write_string("L\{n(curr.x)},\{n(curr.y)}")
        continue
      }
      let nx1 = dx1 / len1
      let ny1 = dy1 / len1
      let nx2 = dx2 / len2
      let ny2 = dy2 / len2
      let dot = nx1 * nx2 + ny1 * ny2
      let angle = @jsmath.acos((-1.0).max(dot.min(1.0)))
      if angle < epsilon || (pi - angle).abs() < epsilon {
        path.write_string("L\{n(curr.x)},\{n(curr.y)}")
        continue
      }
      let cut = (radius / @jsmath.sin(angle / 2.0))
        .min(len1 / 2.0)
        .min(len2 / 2.0)
      let start_x = curr.x - nx1 * cut
      let start_y = curr.y - ny1 * cut
      let end_x = curr.x + nx2 * cut
      let end_y = curr.y + ny2 * cut
      path.write_string("L\{n(start_x)},\{n(start_y)}")
      path.write_string("Q\{n(curr.x)},\{n(curr.y)} \{n(end_x)},\{n(end_y)}")
    }
  }
  path.to_string()
}

///|
/// `btoa` of ASCII text.
fn base64(text : String) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let bytes = text.to_array().map(c => c.to_int() & 0xff)
  let out = StringBuilder()
  let digit = (value : Int32) => {
    out.write_char(alphabet.get_char(value & 63).unwrap_or('A'))
  }
  for i = 0; i < bytes.length(); i = i + 3 {
    let b0 = bytes[i]
    let b1 = if i + 1 < bytes.length() { bytes[i + 1] } else { 0 }
    let b2 = if i + 2 < bytes.length() { bytes[i + 2] } else { 0 }
    digit(b0 >> 2)
    digit((b0 << 4) | (b1 >> 4))
    if i + 1 < bytes.length() {
      digit((b1 << 2) | (b2 >> 6))
    } else {
      out.write_char('=')
    }
    if i + 2 < bytes.length() {
      digit(b2)
    } else {
      out.write_char('=')
    }
  }
  out.to_string()
}

///|
/// `JSON.stringify` of a route.
fn points_json(points : Array[Point]) -> String {
  // A number that is not finite is `null` in JSON.
  let n = (value : Double) => {
    if value.is_nan() || value.is_inf() {
      "null"
    } else {
      @dom.number(value)
    }
  }
  let parts = points.map(p => "{\"x\":\{n(p.x)},\"y\":\{n(p.y)}}")
  "[" + parts.join(",") + "]"
}

///|
/// The dash pattern of a dotted edge in the neo look.
fn dash_array(len : Double, start : Double, end : Double) -> String {
  let n = @dom.number
  let middle = len - start - end
  let pairs = (middle / 4.0).floor()
  let count = if pairs.is_nan() || pairs.is_inf() || pairs < 0.0 {
    0
  } else {
    pairs.to_int()
  }
  let pattern = Array::make(count, "2 2").join(" ")
  "0 \{n(start)} \{pattern} \{n(end)}"
}

///|
/// The marker type and whether it is filled, for an arrow type.
fn marker_kind(arrow_type : String) -> (String, Bool)? {
  match arrow_type {
    "arrow_cross" => Some(("cross", false))
    "arrow_point" => Some(("point", true))
    "arrow_barb" | "arrow_barb_neo" => Some(("barb", true))
    "arrow_circle" => Some(("circle", false))
    "arrow_hierarchy" => Some(("hierarchy", false))
    "aggregation" => Some(("aggregation", false))
    "extension" => Some(("extension", false))
    "composition" => Some(("composition", true))
    "dependency" => Some(("dependency", true))
    "lollipop" => Some(("lollipop", false))
    "only_one" => Some(("onlyOne", false))
    "zero_or_one" => Some(("zeroOrOne", false))
    "one_or_more" => Some(("oneOrMore", false))
    "zero_or_more" => Some(("zeroOrMore", false))
    "requirement_arrow" => Some(("requirement_arrow", false))
    "requirement_contains" => Some(("requirement_contains", false))
    _ => None
  }
}

///|
/// Point one end of a path at its marker. An edge with its own stroke
/// colour gets a copy of the marker in that colour.
fn add_edge_marker(
  path : @dom.Element,
  at_start : Bool,
  arrow_type : String,
  data : LayoutData,
  use_margin : Bool,
  stroke_color : String?,
) -> Unit {
  if arrow_type == "" || arrow_type == "none" {
    return
  }
  guard marker_kind(arrow_type) is Some((kind, filled)) else { return }
  let margin_support = kind
    is ("cross"
    | "point"
    | "circle"
    | "lollipop"
    | "aggregation"
    | "extension"
    | "composition"
    | "dependency"
    | "barb")
  let suffix = if at_start { "Start" } else { "End" }
  let offset = if use_margin && margin_support { "-margin" } else { "" }
  let original_id = "\{data.diagram_id}_\{data.diagram_type}-\{kind}\{suffix}\{offset}"
  let position = if at_start { "start" } else { "end" }
  guard stroke_color is Some(color) && color.trim().to_owned() != "" else {
    path.attr("marker-\{position}", "url(#\{original_id})") |> ignore
    return
  }
  let color_id = StringBuilder()
  for c in color {
    color_id.write_char(
      if c is ('0'..<='9' | 'A'..<='Z' | 'a'..<='z') {
        c
      } else {
        '_'
      },
    )
  }
  let colored_id = "\{original_id}_\{color_id.to_string()}"
  let root = document_root(path)
  if root.find_by_id(colored_id) is None &&
    root.find_by_id(original_id) is Some(original) &&
    original.parent() is Some(parent) {
    let colored = original.clone_deep().attr("id", colored_id)
    // The sanitizer drops a colour that looks like an address with a
    // scheme, such as the `stroke:red` of the hand-drawn look.
    let kept = @dom.is_allowed_uri(color)
    for shape in colored.descendants(["path", "circle", "line"]) {
      guard kept else { break }
      shape.attr("stroke", color) |> ignore
      if filled {
        shape.attr("fill", color) |> ignore
      }
    }
    parent.append_child(colored)
  }
  path.attr("marker-\{position}", "url(#\{colored_id})") |> ignore
}

///|
/// The topmost ancestor of an element.
fn document_root(element : @dom.Element) -> @dom.Element {
  let mut current = element
  while current.parent() is Some(parent) {
    current = parent
  }
  current
}

///|
/// The stroke colour an inline style asks for: `/stroke:([^;]+)/`.
fn stroke_color_of(style : String) -> String? {
  guard style.find("stroke:") is Some(start) else { return None }
  let rest = style[start + 7:]
  let end = rest.find(";").unwrap_or(rest.length())
  if end == 0 {
    None
  } else {
    Some(rest[:end].to_owned())
  }
}

///|
/// Draw an edge along its route: mermaid's `insertEdge` for routes that
/// are already clipped to their nodes.
fn insert_edge(
  group : @dom.Element,
  edge : Edge,
  data : LayoutData,
  path? : String,
  points_text? : String,
) -> @dom.Element {
  let points = edge.points
  // What is written of the route, unless the caller wrote it out itself.
  let points_attr = base64(points_text.unwrap_or(points_json(points)))
  let line_data = points.filter(p => !p.y.is_nan())
  let n = @dom.number
  let line_path = if path is Some(path) {
    // Drawn by the caller, in a curve of its own.
    path
  } else if edge.curve == "rounded" {
    rounded_path(apply_marker_offsets(line_data, edge), 5.0)
  } else {
    // A straight line, where ELK returned no route: `d3.line`, whose
    // path keeps three decimals.
    let points = offset_line_points(fix_corners(line_data), edge)
    @d3.line("linear", points).unwrap_or("")
  }
  let thickness = match edge.thickness {
    "thick" => "edge-thickness-thick"
    "invisible" => "edge-thickness-invisible"
    _ => "edge-thickness-normal"
  }
  let pattern = match edge.pattern {
    "dotted" => "edge-pattern-dotted"
    "dashed" => "edge-pattern-dashed"
    _ => "edge-pattern-solid"
  }
  let animation_class = match (edge.animation, edge.animate) {
    (Some(animation), _) => "edge-animation-\{animation}"
    (None, true) => "edge-animation-fast"
    (None, false) => ""
  }
  let styles_from_classes = edge.css_compiled_styles.join(";")
  let styles = edge.style.map(style => style + ";").join("")
  let path_style = (if styles_from_classes != "" {
      styles_from_classes + ";" + styles + ";"
    } else {
      styles
    }) +
    ";" +
    edge.style.map(style => ";" + style).join("")
  let classes = " \{thickness} \{pattern}" +
    (if edge.classes != "" { " " + edge.classes } else { "" }) +
    (if animation_class != "" { " " + animation_class } else { "" })
  let (path, sketched_stroke) = if edge.look == "handDrawn" {
    let (path, stroke) = sketched_edge(group, line_path, edge, data)
    let classes = " \{thickness} \{pattern} transition" +
      classes[thickness.length() + pattern.length() + 2:].to_owned()
    path
    .attr("id", "\{data.diagram_id}-\{edge.id}")
    .attr("class", classes)
    .attr("style", edge.style.map(style => ";" + style).join(""))
    |> ignore
    (path, Some(stroke))
  } else {
    let path = group
      .append("path")
      .attr("d", line_path)
      .attr("id", "\{data.diagram_id}-\{edge.id}")
      .attr("class", classes)
      .attr("style", path_style)
    (path, None)
  }
  let animated = sketched_stroke is None &&
    (
      edge.animate ||
      edge.animation is Some(_) ||
      styles_from_classes.contains("animation")
    )
  if edge.look == "neo" && !animated {
    let len = @dom.path_length(line_path)
    let start = marker_offset2(edge.arrow_type_start)
    let end = marker_offset2(edge.arrow_type_end)
    let dashes = if edge.pattern is ("dotted" | "dashed") {
      dash_array(len, start, end)
    } else {
      "0 \{n(start)} \{n(len - start - end)} \{n(end)}"
    }
    path.attr(
      "style",
      "stroke-dasharray: \{dashes}; stroke-dashoffset: 0;" + path_style,
    )
    |> ignore
  }
  path
  .attr("data-edge", "true")
  .attr("data-et", "edge")
  .attr("data-id", edge.id)
  .attr("data-points", points_attr)
  |> ignore
  // An edge without a look has no such attribute.
  if edge.look != "" {
    path.attr("data-look", edge.look) |> ignore
  }
  let use_margin = !animated && edge.look == "neo"
  let stroke_color = match sketched_stroke {
    Some(stroke) => stroke
    None => stroke_color_of(path_style)
  }
  add_edge_marker(
    path,
    true,
    edge.arrow_type_start,
    data,
    use_margin,
    stroke_color,
  )
  add_edge_marker(
    path,
    false,
    edge.arrow_type_end,
    data,
    use_margin,
    stroke_color,
  )
  path
}

///|
/// Create the label of an edge and measure it: mermaid's
/// `insertEdgeLabel`. Returns the group to position later.
fn insert_edge_label(
  group : @dom.Element,
  edge : Edge,
  base_env : Env,
  env : Env,
  padding_x~ : Double = 0.0,
  own_styles~ : Bool = true,
) -> @dom.Element {
  let split = split_styles(
    [..edge.css_compiled_styles, ..if own_styles { edge.style } else { [] }],
  )
  edge.label_style = split.label_styles
  let edge_label = group.append("g").attr("class", "edgeLabel")
  let label = edge_label
    .append("g")
    .attr("class", "label")
    .attr("data-id", edge.id)
  let n = @dom.number
  let markdown = edge.label_type == "markdown"
  if !env.html_labels {
    // The label is created outside its group, where it is broken into
    // lines and its background sized, and moved into the group, whose
    // font size the stylesheet may set, before it is measured.
    let text = create_svg_label(
      label,
      edge.label,
      base_env,
      width=200.0,
      style=edge.label_style,
      is_node=false,
      add_background=true,
      markdown~,
      sanitize=false,
    )
    if edge.label == "" {
      // An empty label is its text alone, moved into the label's group;
      // the group with the background stays where it was created, after
      // the edge's label in the group of all of them. It measures nothing.
      group.append_child(text.group)
      label.append_child(text.element)
      label.attr("transform", "translate(0, 0)") |> ignore
      edge.width = 0.0
      edge.height = 0.0
      return edge_label
    }
    let centre = if env.font_size == base_env.font_size {
      text.text_box
    } else {
      let moved = text_box(text.lines, env, true)
      text.element.set_text_box(moved)
      moved
    }
    // The label is as large as its background, and centred on its text.
    let box = text.group.bbox()
    label.attr(
      "transform",
      "translate(\{n(-(centre.x + centre.width / 2.0))}, \{n(-(centre.y + centre.height / 2.0))})",
    )
    |> ignore
    edge.width = box.width
    edge.height = box.height
    return edge_label
  }
  let (fo, box) = create_html_label(
    label,
    edge.label,
    env,
    width=200.0,
    style=edge.label_style,
    is_node=false,
    add_background=true,
    markdown~,
    padding_x~,
  )
  fo.attr_number("width", box.width).attr_number("height", box.height) |> ignore
  label.attr(
    "transform",
    "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0)})",
  )
  |> ignore
  edge.width = box.width
  edge.height = box.height
  edge_label
}
