// The labels at the ends of an edge, such as the cardinalities of a class
// diagram: measured before the layout, handed to ELK as head and tail
// labels, and moved to where they belong once the routes are final.
// Mermaid's `insertEdgeLabel` for terminal labels and the terminal-label
// passes of `layout-algorithms/elk/render.ts`.

///|
/// A label at one end of an edge.
priv struct TerminalLabel {
  /// `startLeft`, `startRight`, `endLeft` or `endRight`.
  key : String
  text : String
  /// The group to position once the edge is laid out.
  element : @dom.Element
  width : Double
  height : Double
  /// Where the layout puts the centre of the label, if it places it.
  mut centre : Point?
  /// The port ELK routed the edge from at the end the label belongs to.
  mut port : Point?
}

///|
/// The size terminal labels are set in: the class diagram's stylesheet
/// fixes it (`.edgeTerminals { font-size: 11px }`).
fn terminal_label_font_size(
  diagram_type : String,
  font_size : Double,
) -> Double {
  match diagram_type {
    "classDiagram" => 11.0
    _ => font_size
  }
}

///|
/// The terminal labels an edge asks for, in the order upstream creates
/// them.
fn terminal_label_texts(edge : Edge) -> Array[(String, String)] {
  [
    ("startLeft", edge.start_label_left),
    ("startRight", edge.start_label_right),
    ("endLeft", edge.end_label_left),
    ("endRight", edge.end_label_right),
  ].filter(entry => entry.1 != "")
}

///|
/// Whether the edge has any label to create: mermaid's `hasEdgeLabel`.
fn has_edge_label(edge : Edge) -> Bool {
  edge.label != "" || !terminal_label_texts(edge).is_empty()
}

///|
/// Create and measure every label of an edge: mermaid's `insertEdgeLabel`.
/// Returns the group of the centre label.
fn insert_edge_labels(
  group : @dom.Element,
  edge : Edge,
  base_env : Env,
  env : Env,
  diagram_type : String,
) -> @dom.Element {
  let edge_label = if edge.label == "" && !env.html_labels {
    insert_empty_text_label(group, edge)
  } else {
    insert_edge_label(
      group,
      edge,
      base_env,
      env,
      padding_x=label_background_padding(diagram_type),
      own_styles=edge_label_uses_own_styles(diagram_type),
    )
  }
  insert_terminal_labels(group, edge, {
    ..base_env,
    font_size: terminal_label_font_size(diagram_type, base_env.font_size),
  })
  edge_label
}

///|
/// The centre label of an edge that only has terminal labels, as SVG
/// text. Upstream makes the label inside the group of all edge labels and
/// moves what the label code returns into the label's own group: without
/// text that is the `<text>` alone, and the group made around it stays
/// behind with its background rectangle.
fn insert_empty_text_label(group : @dom.Element, edge : Edge) -> @dom.Element {
  let edge_label = group.append("g").attr("class", "edgeLabel")
  let label = edge_label
    .append("g")
    .attr("class", "label")
    .attr("data-id", edge.id)
  group
  .append("g")
  .append("rect")
  .attr("class", "background")
  .attr("style", "stroke: none")
  |> ignore
  label
  .append("text")
  .attr("y", "-10.1")
  .attr("text-anchor", "middle")
  .append("tspan")
  .attr("class", "text-outer-tspan row")
  .attr("x", "0")
  .attr("y", "-0.1em")
  .attr("dy", "1.1em")
  .attr("text-anchor", "middle")
  |> ignore
  label.attr("transform", "translate(0, 0)") |> ignore
  edge.width = 0.0
  edge.height = 0.0
  edge_label
}

///|
/// Create and measure the terminal labels of an edge: the second half of
/// mermaid's `insertEdgeLabel`. Each is a group of its own, centred on
/// its origin, to be positioned after the layout.
fn insert_terminal_labels(group : @dom.Element, edge : Edge, env : Env) -> Unit {
  let n = @dom.number
  for entry in terminal_label_texts(edge) {
    let (key, text) = entry
    let element = group.append("g").attr("class", "edgeTerminals")
    let inner = element.append("g").attr("class", "inner")
    let (width, height) = if env.html_labels {
      let (fo, box) = create_html_label(
        inner,
        text,
        env,
        style=edge.label_style,
        is_node=false,
      )
      fo.attr_number("width", box.width).attr_number("height", box.height)
      |> ignore
      inner.attr(
        "transform",
        "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0)})",
      )
      |> ignore
      // Never narrower than nine pixels a character: `setTerminalWidth`.
      fo
      .style(
        "width",
        n((text.length().to_double() * 9.0).max(box.width)) + "px",
      )
      .style("height", n(box.height) + "px")
      |> ignore
      (box.width, box.height)
    } else {
      let label = create_svg_label(
        inner,
        text,
        env,
        style=edge.label_style,
        is_node=false,
        sanitize=false,
      )
      // Upstream styles what the label code returns, which without a
      // background is the text itself: neither the rectangle nor the text
      // inside it is found, and both stay as they were created.
      for rect in label.group.descendants(["rect"]) {
        rect.attr("style", "stroke: none") |> ignore
      }
      label.element.remove_attr("style") |> ignore
      let box = label.text_box
      inner.attr(
        "transform",
        "translate(\{n(or_zero(-(box.x + box.width / 2.0)))}, \{n(or_zero(-(box.y + box.height / 2.0)))})",
      )
      |> ignore
      (box.width, box.height)
    }
    edge.terminals.push({
      key,
      text,
      element,
      width,
      height,
      centre: None,
      port: None,
    })
  }
}

///|
/// The labels ELK gets for the terminal labels of an edge: head and tail
/// labels, padded past the marker of their end, which ELK knows nothing
/// about. Mermaid's `terminalElkLabels`.
fn terminal_elk_labels(edge : Edge) -> Array[Json] {
  edge.terminals.map(terminal => {
    let at_start = terminal.key.has_prefix("start")
    let marker = if at_start {
      edge.arrow_type_start
    } else {
      edge.arrow_type_end
    }
    // Half the width of the relation markers.
    let pad = if marker != "" && marker != "none" { 6.0 } else { 0.0 }
    let json : Json = {
      "terminal": Json::string(terminal.key),
      "text": Json::string(terminal.text),
      "width": Json::number(terminal.width + 2.0 * pad),
      "height": Json::number(terminal.height + 2.0 * pad),
      "layoutOptions": {
        "edgeLabels.placement": if at_start {
          "TAIL"
        } else {
          "HEAD"
        },
      },
    }
    json
  })
}

///|
/// A box by its edges.
priv struct Box {
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
}

///|
/// The box of a label of this size around `centre`.
fn Box::around(centre : Point, width : Double, height : Double) -> Box {
  {
    x1: centre.x - width / 2.0,
    y1: centre.y - height / 2.0,
    x2: centre.x + width / 2.0,
    y2: centre.y + height / 2.0,
  }
}

///|
fn Box::overlaps(self : Box, other : Box) -> Bool {
  self.x1 < other.x2 &&
  other.x1 < self.x2 &&
  self.y1 < other.y2 &&
  other.y1 < self.y2
}

///|
/// Whether the segment from `a` to `b` passes through the box: a
/// Liang-Barsky clip.
fn Box::hit_by(self : Box, a : Point, b : Point) -> Bool {
  let mut t0 = 0.0
  let mut t1 = 1.0
  let dx = b.x - a.x
  let dy = b.y - a.y
  for
    pair in [
      (-dx, a.x - self.x1),
      (dx, self.x2 - a.x),
      (-dy, a.y - self.y1),
      (dy, self.y2 - a.y),
    ] {
    let (p, q) = pair
    if p == 0.0 {
      if q < 0.0 {
        return false
      }
    } else if p < 0.0 {
      t0 = t0.max(q / p)
    } else {
      t1 = t1.min(q / p)
    }
  }
  t0 < t1
}

///|
/// What a terminal label must not touch: nodes, centre labels, the
/// frames of groups, other edges and other terminal labels. Mermaid's
/// `terminalLabelObstacles`.
priv struct Obstacles {
  edges : Array[Edge]
  node_boxes : Array[Box]
  /// A group is hollow: only the four sides of its frame are in the way.
  frame_segments : Array[(Point, Point)]
  centre_label_boxes : Array[Box]
}

///|
fn Obstacles::new(edges : Array[Edge], nodes : Array[Node]) -> Obstacles {
  let box_of = (node : Node) => {
    Box::around(
      { x: node.x, y: node.y, },
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
    )
  }
  let node_boxes = []
  let frame_segments = []
  for node in nodes {
    let box = box_of(node)
    if node.is_group {
      let corners = [
        { x: box.x1, y: box.y1, },
        { x: box.x2, y: box.y1, },
        { x: box.x2, y: box.y2, },
        { x: box.x1, y: box.y2, },
      ]
      for index, corner in corners {
        frame_segments.push((corner, corners[(index + 1) % 4]))
      }
    } else {
      node_boxes.push(box)
    }
  }
  let centre_label_boxes = []
  for edge in edges {
    if edge.label != "" &&
      edge.width != 0.0 &&
      edge.height != 0.0 &&
      edge.position is Some(centre) {
      centre_label_boxes.push(Box::around(centre, edge.width, edge.height))
    }
  }
  { edges, node_boxes, frame_segments, centre_label_boxes, }
}

///|
/// Whether the box, grown by `clearance`, touches the frame of a group.
fn Obstacles::hits_frame(
  self : Obstacles,
  box : Box,
  clearance~ : Double = 0.0,
) -> Bool {
  let padded = {
    x1: box.x1 - clearance,
    y1: box.y1 - clearance,
    x2: box.x2 + clearance,
    y2: box.y2 + clearance,
  }
  self.frame_segments.iter().any(segment => padded.hit_by(segment.0, segment.1))
}

///|
/// Whether a label of `edge` cannot sit in `box`. `segment` is the
/// stretch of its own edge the label sits beside, which is not in its
/// way.
fn Obstacles::blocked(
  self : Obstacles,
  box : Box,
  edge : Edge,
  key : String,
  segment : Int32,
  clearance~ : Double = 0.0,
) -> Bool {
  if self.node_boxes.iter().any(node => box.overlaps(node)) ||
    self.centre_label_boxes.iter().any(label => box.overlaps(label)) ||
    self.hits_frame(box, clearance~) {
    return true
  }
  for other in self.edges {
    let own = physical_equal(other, edge)
    for i in 0..<(other.points.length() - 1) {
      if !(own && i == segment) &&
        box.hit_by(other.points[i], other.points[i + 1]) {
        return true
      }
    }
  }
  for other in self.edges {
    let own = physical_equal(other, edge)
    for terminal in other.terminals {
      if terminal.centre is Some(centre) &&
        !(own && terminal.key == key) &&
        box.overlaps(Box::around(centre, terminal.width, terminal.height)) {
        return true
      }
    }
  }
  false
}

///|
/// A placed terminal label with the end segment of its edge it sits
/// beside: what mermaid's `placedTerminalLabels` yields.
priv struct PlacedLabel {
  terminal : TerminalLabel
  centre : Point
  at_start : Bool
  segment : Int32
  from : Point
  to : Point
  length : Double
}

///|
/// The placed labels of one edge, as they stand when the edge is reached.
fn placed_terminal_labels(edge : Edge) -> Array[PlacedLabel] {
  let points = edge.points
  let placed = []
  if points.length() < 2 {
    return placed
  }
  for terminal in edge.terminals {
    guard terminal.centre is Some(centre) else { continue }
    let at_start = terminal.key.has_prefix("start")
    let segment = if at_start { 0 } else { points.length() - 2 }
    let from = points[segment]
    let to = points[segment + 1]
    let length = @jsmath.hypot(to.x - from.x, to.y - from.y)
    if length == 0.0 {
      continue
    }
    placed.push({ terminal, centre, at_start, segment, from, to, length, })
  }
  placed
}

///|
/// How far a label that was slid stays off the border of a frame.
const TERMINAL_LABEL_FRAME_CLEARANCE : Double = 2.0

///|
/// ELK can place the end label of an edge that crosses into another group
/// across that group's frame. Such a label is slid along its end segment,
/// by the shortest distance, until it is clear: mermaid's
/// `slideTerminalLabelsOffFrames`.
fn slide_terminal_labels_off_frames(
  edges : Array[Edge],
  nodes : Array[Node],
) -> Unit {
  let obstacles = Obstacles::new(edges, nodes)
  for edge in edges {
    for label in placed_terminal_labels(edge) {
      let terminal = label.terminal
      let centre = label.centre
      let box_at = (centre : Point) => {
        Box::around(centre, terminal.width, terminal.height)
      }
      if !obstacles.hits_frame(box_at(centre)) {
        continue
      }
      // The direction from the far point of the end segment to its end.
      let (far, end) = if label.at_start {
        (label.to, label.from)
      } else {
        (label.from, label.to)
      }
      let length = label.length
      let dir = { x: (end.x - far.x) / length, y: (end.y - far.y) / length, }
      let half_extent = (
          dir.x.abs() * terminal.width + dir.y.abs() * terminal.height
        ) /
        2.0
      // Where a centre sits along the segment: 0 at its end, `-length` at
      // the far point.
      let along = (c : Point) => (c.x - end.x) * dir.x + (c.y - end.y) * dir.y
      let on_segment = (c : Point) => {
        along(c) + half_extent <= 0.0 && along(c) - half_extent >= -length
      }
      let mut step = 1.0
      while step <= length {
        let mut found : Point? = None
        for shift in [step, -step] {
          let moved = {
            x: centre.x + shift * dir.x,
            y: centre.y + shift * dir.y,
          }
          if on_segment(moved) &&
            !obstacles.blocked(
              box_at(moved),
              edge,
              terminal.key,
              label.segment,
              clearance=TERMINAL_LABEL_FRAME_CLEARANCE,
            ) {
            found = Some(moved)
            break
          }
        }
        if found is Some(_) {
          terminal.centre = found
          break
        }
        step += 1.0
      }
    }
  }
}

///|
/// ELK puts every end label on one fixed side of its edge, but a "right"
/// label belongs on the right of the direction of travel and a "left"
/// one on the left. A label on the wrong side is mirrored across its end
/// segment if the spot there is free: mermaid's
/// `putTerminalLabelsOnTheirSide`.
fn put_terminal_labels_on_their_side(
  edges : Array[Edge],
  nodes : Array[Node],
) -> Unit {
  let obstacles = Obstacles::new(edges, nodes)
  for edge in edges {
    for label in placed_terminal_labels(edge) {
      let terminal = label.terminal
      let centre = label.centre
      let from = label.from
      let to = label.to
      // The unit normal pointing to the right of travel; y points down.
      let normal = {
        x: -(to.y - from.y) / label.length,
        y: (to.x - from.x) / label.length,
      }
      let offset = (centre.x - from.x) * normal.x +
        (centre.y - from.y) * normal.y
      if offset == 0.0 || (offset > 0.0) == terminal.key.has_suffix("Right") {
        continue
      }
      let mirrored = {
        x: centre.x - 2.0 * offset * normal.x,
        y: centre.y - 2.0 * offset * normal.y,
      }
      if !obstacles.blocked(
          Box::around(mirrored, terminal.width, terminal.height),
          edge,
          terminal.key,
          label.segment,
        ) {
        terminal.centre = Some(mirrored)
      }
    }
  }
}

///|
/// Read where ELK put the terminal labels, and the ports it routed their
/// edges between: the terminal-label part of the loop over the laid-out
/// edges in mermaid's `applyElkEdgeLayout`.
fn read_terminal_labels(state : ElkState, graph : Json) -> Unit {
  let elk_edges : Map[String, ElkEdge] = Map([])
  for edge in state.edges {
    if !elk_edges.contains(edge.edge.id) {
      elk_edges[edge.edge.id] = edge
    }
  }
  for result in json_items(graph, "edges") {
    guard elk_edges.get(json_text(result, "id")) is Some(elk_edge) else {
      continue
    }
    let edge = elk_edge.edge
    guard !edge.terminals.is_empty() &&
      json_items(result, "sections") is [section, ..] else {
      continue
    }
    let offset = state.edge_offset(edge.start, edge.end)
    // The ports, in the edge's own direction.
    let first = json_point(json_field(section, "startPoint"))
    let last = json_point(json_field(section, "endPoint"))
    let (first, last) = if elk_edge.reversed {
      (last, first)
    } else {
      (first, last)
    }
    let start_port = { x: first.x + offset.x, y: first.y + offset.y, }
    let end_port = { x: last.x + offset.x, y: last.y + offset.y, }
    // The labels after the centre label are the terminal labels, in the
    // order they were handed over.
    let labels = json_items(result, "labels")
    for index, terminal in edge.terminals {
      guard index + 1 < labels.length() else { break }
      let label = labels[index + 1]
      let x = json_number(label, "x")
      let y = json_number(label, "y")
      // A label left at the origin was not placed.
      if x == 0.0 && y == 0.0 {
        continue
      }
      terminal.centre = Some({
        x: x + offset.x + json_number(label, "width") / 2.0,
        y: y + offset.y + json_number(label, "height") / 2.0,
      })
      terminal.port = Some(
        if terminal.key.has_prefix("start") {
          start_port
        } else {
          end_port
        },
      )
    }
  }
}

///|
/// Move the terminal labels to where they belong on the finished routes:
/// what mermaid's `applyElkEdgeLayout` does with them once the routes are
/// clipped and straightened.
fn settle_terminal_labels(edges : Array[Edge], nodes : Array[Node]) -> Unit {
  // ELK places the labels beside the ports it routed from; clipping and
  // straightening can move an end of the route afterwards, and the labels
  // follow it: mermaid's `followMovedEndpoints`.
  for edge in edges {
    let points = edge.points
    guard !points.is_empty() else { continue }
    for terminal in edge.terminals {
      guard terminal.centre is Some(centre) && terminal.port is Some(port) else {
        continue
      }
      let end = if terminal.key.has_prefix("start") {
        points[0]
      } else {
        points[points.length() - 1]
      }
      terminal.centre = Some({
        x: centre.x + (end.x - port.x),
        y: centre.y + (end.y - port.y),
      })
    }
  }
  // Off the frames first: the mirrored spot of a label across a frame is
  // across it too.
  slide_terminal_labels_off_frames(edges, nodes)
  put_terminal_labels_on_their_side(edges, nodes)
}

///|
/// Move the terminal labels of an edge to where the layout placed them.
fn position_terminal_labels(edge : Edge) -> Unit raise LayoutError {
  let n = @dom.number
  for terminal in edge.terminals {
    guard terminal.centre is Some(centre) else {
      // Upstream then walks along the drawn path instead.
      raise LayoutError(
        "A terminal label the layout did not place is not supported yet.",
      )
    }
    terminal.element.attr(
      "transform",
      "translate(\{n(centre.x)}, \{n(centre.y)})",
    )
    |> ignore
  }
}
