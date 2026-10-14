// The shared drawing code for a diagram that places its own nodes and
// edges instead of handing them to `render`: mermaid's `insertNode`,
// `insertEdge` and `insertEdgeLabel` as the block diagram calls them.

///|
/// Draws nodes, edges and edge labels of one diagram where it is told to.
pub struct Painter {
  priv data : LayoutData
  priv env : Env
}

///|
pub fn Painter::new(
  config : @config.Config,
  diagram_type~ : String,
  diagram_id~ : String,
) -> Painter {
  let data = {
    nodes: [],
    edges: [],
    config,
    diagram_type,
    diagram_id,
    direction: "TB",
    markers: [],
  }
  let env = {
    ..Env::new(config, diagram_id),
    node_text_centred: node_text_centred(diagram_type),
  }
  { data, env, }
}

///|
/// Append the definitions the look's stylesheet rules point at to `svg`.
pub fn Painter::insert_look_defs(self : Painter, svg : @dom.Element) -> Unit {
  insert_look_defs(svg, self.data)
}

///|
/// The node placed at `(x, y)`, with the size it is to be drawn at, if it
/// has one already, and the style of its label.
pub fn Node::placed(
  self : Node,
  x~ : Double,
  y~ : Double,
  width? : Double,
  height? : Double,
  label_style~ : String,
) -> Node {
  { ..self, x, y, width, height, label_style, }
}

///|
/// Draw `node` into `parent` with its shape and return its element:
/// mermaid's `insertNode`. The node records its size and how to clip an
/// edge at its outline.
pub fn Painter::insert_node(
  self : Painter,
  parent : @dom.Element,
  node : Node,
) -> @dom.Element raise LayoutError {
  insert_node(parent, node, self.env, self.data.direction)
}

///|
/// mermaid's `extractCornerPoints`: the indices of the points where a
/// route turns by a right angle between two axis-parallel stretches of
/// more than five pixels.
fn corner_positions(points : Array[Point]) -> Array[Int32] {
  let positions = []
  for i in 1..<(points.length() - 1) {
    let prev = points[i - 1]
    let curr = points[i]
    let next = points[i + 1]
    if prev.x == curr.x &&
      curr.y == next.y &&
      (curr.x - next.x).abs() > 5.0 &&
      (curr.y - prev.y).abs() > 5.0 {
      positions.push(i)
    } else if prev.y == curr.y &&
      curr.x == next.x &&
      (curr.x - prev.x).abs() > 5.0 &&
      (curr.y - next.y).abs() > 5.0 {
      positions.push(i)
    }
  }
  positions
}

///|
/// The point `distance` before `b` on the way from `a`: mermaid's
/// `findAdjacentPoint`.
fn adjacent_point(a : Point, b : Point, distance : Double) -> Point {
  let x_diff = b.x - a.x
  let y_diff = b.y - a.y
  let length = (x_diff * x_diff + y_diff * y_diff).sqrt()
  let ratio = distance / length
  { x: b.x - ratio * x_diff, y: b.y - ratio * y_diff, }
}

///|
/// Cut the right-angled corners of a route so that a curve through its
/// points rounds them: mermaid's `fixCorners`.
fn fix_corners(line_data : Array[Point]) -> Array[Point] {
  let corners = corner_positions(line_data)
  let result = []
  for i, point in line_data {
    guard corners.contains(i) else {
      result.push(point)
      continue
    }
    let prev = line_data[i - 1]
    let next = line_data[i + 1]
    let new_prev = adjacent_point(prev, point, 5.0)
    let new_next = adjacent_point(next, point, 5.0)
    let x_diff = new_next.x - new_prev.x
    let y_diff = new_next.y - new_prev.y
    result.push(new_prev)
    let a = 2.0.sqrt() * 2.0
    let mut corner = point
    if (next.x - prev.x).abs() > 10.0 && (next.y - prev.y).abs() >= 10.0 {
      let r = 5.0
      corner = if point.x == new_prev.x {
        {
          x: if x_diff < 0.0 {
            new_prev.x - r + a
          } else {
            new_prev.x + r - a
          },
          y: if y_diff < 0.0 {
            new_prev.y - a
          } else {
            new_prev.y + a
          },
        }
      } else {
        {
          x: if x_diff < 0.0 {
            new_prev.x - a
          } else {
            new_prev.x + a
          },
          y: if y_diff < 0.0 {
            new_prev.y - r + a
          } else {
            new_prev.y + r - a
          },
        }
      }
    }
    result.push(corner)
    result.push(new_next)
  }
  result
}

///|
/// The marker offsets `getLineFunctionsWithOffset` knows: `Object.hasOwn`
/// of its table.
fn line_marker_offset(arrow_type : String) -> Double? {
  match arrow_type {
    "aggregation" | "extension" | "composition" => Some(17.25)
    "dependency" => Some(6.0)
    "lollipop" => Some(13.5)
    "arrow_point" => Some(4.0)
    "arrow_barb" => Some(0.0)
    "arrow_barb_neo" => Some(5.5)
    _ => None
  }
}

///|
/// The points a curve is drawn through: the route with its ends pulled
/// back from their markers. Mermaid's `getLineFunctionsWithOffset`, whose
/// `x` and `y` accessors `d3.line` calls on every point.
fn offset_line_points(
  data : Array[Point],
  edge : Edge,
) -> Array[(Double, Double)] {
  let n = data.length()
  let first = data[0]
  let last = data[n - 1]
  let start_offset = line_marker_offset(edge.arrow_type_start)
  let end_offset = line_marker_offset(edge.arrow_type_end)
  // `Math.atan(deltaY / deltaX)` between two points, and the deltas.
  let delta_and_angle = (p1 : Point?, p2 : Point?) => {
    guard p1 is Some(p1) && p2 is Some(p2) else { return (0.0, 0.0, 0.0) }
    let delta_x = p2.x - p1.x
    let delta_y = p2.y - p1.y
    (@jsmath.atan(delta_y / delta_x), delta_x, delta_y)
  }
  // A comparison with a marker height that is not in the table is one
  // with `undefined`, which is never true.
  let below = (value : Double, height : Double?) => {
    match height {
      Some(height) => value < height
      None => false
    }
  }
  data.mapi((i, d) => {
    // The x coordinate.
    let mut offset_x = 0.0
    if i == 0 && start_offset is Some(marker) {
      let (angle, delta_x, _) = delta_and_angle(data.get(0), data.get(1))
      offset_x = marker *
        @jsmath.cos(angle) *
        (if delta_x >= 0.0 { 1.0 } else { -1.0 })
    } else if i == n - 1 && end_offset is Some(marker) {
      let (angle, delta_x, _) = delta_and_angle(
        data.get(n - 1),
        data.get(n - 2),
      )
      offset_x = marker *
        @jsmath.cos(angle) *
        (if delta_x >= 0.0 { 1.0 } else { -1.0 })
    }
    let to_end_x = (d.x - last.x).abs()
    let to_end_y = (d.y - last.y).abs()
    let to_start_x = (d.x - first.x).abs()
    let to_start_y = (d.y - first.y).abs()
    // Points closer to an end than its marker is long make room for it.
    if below(to_end_x, end_offset) &&
      to_end_x > 0.0 &&
      below(to_end_y, end_offset) {
      let adjustment = end_offset.unwrap_or(0.0) + 1.0 - to_end_x
      offset_x -= adjustment * (if first.x < last.x { 1.0 } else { -1.0 })
    }
    if below(to_start_x, start_offset) &&
      to_start_x > 0.0 &&
      below(to_start_y, start_offset) {
      let adjustment = start_offset.unwrap_or(0.0) + 1.0 - to_start_x
      offset_x += adjustment * (if first.x < last.x { 1.0 } else { -1.0 })
    }
    // The y coordinate.
    let mut offset_y = 0.0
    if i == 0 && start_offset is Some(marker) {
      let (angle, _, delta_y) = delta_and_angle(data.get(0), data.get(1))
      offset_y = marker *
        @jsmath.sin(angle).abs() *
        (if delta_y >= 0.0 { 1.0 } else { -1.0 })
    } else if i == n - 1 && end_offset is Some(marker) {
      let (angle, _, delta_y) = delta_and_angle(
        data.get(n - 1),
        data.get(n - 2),
      )
      offset_y = marker *
        @jsmath.sin(angle).abs() *
        (if delta_y >= 0.0 { 1.0 } else { -1.0 })
    }
    if below(to_end_y, end_offset) &&
      to_end_y > 0.0 &&
      below(to_end_x, end_offset) {
      let adjustment = end_offset.unwrap_or(0.0) + 1.0 - to_end_y
      offset_y -= adjustment * (if first.y < last.y { 1.0 } else { -1.0 })
    }
    if below(to_start_y, start_offset) &&
      to_start_y > 0.0 &&
      below(to_start_x, start_offset) {
      let adjustment = start_offset.unwrap_or(0.0) + 1.0 - to_start_y
      offset_y += adjustment * (if first.y < last.y { 1.0 } else { -1.0 })
    }
    (d.x + offset_x, d.y + offset_y)
  })
}

///|
/// Whether the last `intersect_polygon` found no crossing and answered
/// with the centre of its node. Upstream answers with the node itself,
/// which callers that write the route out have to tell from a crossing
/// that happens to lie at the centre (as on the long side of a
/// triangle).
let polygon_missed : Ref[Bool] = Ref(false)

///|
/// Where the line from the centre of a drawn node towards `point` leaves
/// its outline. `None` when the node clips by a polygon the line does not
/// cross, as for a point inside it: mermaid's `intersect.polygon` then
/// hands back the node itself, which stands at its centre and is written
/// out whole wherever the route is.
pub fn Node::leaves_at(self : Node, point : Point) -> Point? {
  guard self.intersect is Some(intersect) else { return Some(point) }
  polygon_missed.val = false
  let found = intersect(point)
  if polygon_missed.val {
    None
  } else {
    Some(found)
  }
}

///|
/// Draw `edge` through `points`: mermaid's `insertEdge` for a route in
/// the curve the configuration names (`flowchart.curve`). `points_json`
/// is `JSON.stringify` of the route when it is not one of plain points.
pub fn Painter::insert_edge(
  self : Painter,
  parent : @dom.Element,
  edge : Edge,
  points : Array[Point],
  points_json? : String,
) -> @dom.Element raise LayoutError {
  edge.points = points
  let mut line_data = points.filter(p => !p.y.is_nan())
  if line_data.is_empty() {
    // Upstream then draws a path without data.
    raise LayoutError("An edge without a point to draw is not supported.")
  }
  let curve = self.data.config.text("flowchart.curve").unwrap_or("basis")
  if curve != "rounded" {
    line_data = fix_corners(line_data)
  }
  let path = if curve == "rounded" {
    rounded_path(apply_marker_offsets(line_data, edge), 5.0)
  } else {
    // An unknown curve is drawn as a basis curve.
    let points = offset_line_points(line_data, edge)
    match @d3.line(curve, points) {
      Some(path) => path
      None => @d3.line("basis", points).unwrap_or("")
    }
  }
  insert_edge(parent, edge, self.data, path~, points_text?=points_json)
}

///|
/// Create the label of `edge` in `parent`, centred on its own origin, and
/// return the group to position: mermaid's `insertEdgeLabel`.
pub fn Painter::insert_edge_label(
  self : Painter,
  parent : @dom.Element,
  edge : Edge,
) -> @dom.Element {
  let label_env = {
    ..self.env,
    font_size: edge_label_font_size(self.data.diagram_type, self.env.font_size),
  }
  insert_edge_label(parent, edge, self.env, label_env)
}
