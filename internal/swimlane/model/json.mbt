// The layout as JSON, for comparing the port with upstream's engine run
// by `scripts/swimlane_oracle.js` on the same input.

///|
fn field(object : Map[String, Json], key : String) -> Json? {
  match object.get(key) {
    Some(Null) | None => None
    value => value
  }
}

///|
fn text_field(object : Map[String, Json], key : String) -> String? {
  match field(object, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn number_field(object : Map[String, Json], key : String) -> Double? {
  match field(object, key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
fn flag_field(object : Map[String, Json], key : String) -> Bool {
  field(object, key) is Some(True)
}

///|
fn path(json : Json, keys : Array[String]) -> Json? {
  let mut current = json
  for key in keys {
    guard current is Object(fields) && field(fields, key) is Some(next) else {
      return None
    }
    current = next
  }
  Some(current)
}

///|
/// A layout from a capture of `scripts/swimlane_capture.py`: the layout
/// data mermaid's flowchart renderer builds, before the layout prepares it.
pub fn Layout::from_capture(data : Json) -> Layout {
  let nodes = []
  if path(data, ["nodes"]) is Some(Array(items)) {
    for item in items {
      guard item is Object(n) else { continue }
      let label_style = match field(n, "labelStyle") {
        Some(String(s)) => s
        _ => ""
      }
      nodes.push(
        Node::new(
          id=text_field(n, "id").unwrap_or(""),
          label=text_field(n, "label").unwrap_or(""),
          is_group=flag_field(n, "isGroup"),
          parent_id?=text_field(n, "parentId"),
          padding?=number_field(n, "padding"),
          shape=text_field(n, "shape").unwrap_or(""),
          dir?=text_field(n, "dir"),
          look?=text_field(n, "look"),
          color_index?=number_field(n, "colorIndex").map(Double::to_int),
          label_style~,
        ),
      )
    }
  }
  let edges = []
  if path(data, ["edges"]) is Some(Array(items)) {
    for item in items {
      guard item is Object(e) else { continue }
      let label_style = match field(e, "labelStyle") {
        Some(String(s)) => s
        Some(Array([String(s), ..])) => s
        _ => ""
      }
      edges.push(
        Edge::new(
          id=text_field(e, "id").unwrap_or(""),
          start=text_field(e, "start").unwrap_or(""),
          end=text_field(e, "end").unwrap_or(""),
          label?=text_field(e, "label"),
          label_style~,
          curve?=text_field(e, "curve"),
          arrow_type_start?=text_field(e, "arrowTypeStart"),
          arrow_type_end?=text_field(e, "arrowTypeEnd"),
        ),
      )
    }
  }
  let number = (keys : Array[String]) => {
    match path(data, keys) {
      Some(Number(n, ..)) => Some(n)
      _ => None
    }
  }
  let flag = (keys : Array[String], default : Bool) => {
    match path(data, keys) {
      Some(True) => true
      Some(False) => false
      _ => default
    }
  }
  let look = match path(data, ["config", "look"]) {
    Some(String(s)) => Some(s)
    _ => None
  }
  let direction = match path(data, ["direction"]) {
    Some(String(s)) => Some(s)
    _ => None
  }
  {
    nodes,
    edges,
    direction,
    options: {
      node_spacing: number(["config", "flowchart", "nodeSpacing"]),
      rank_spacing: number(["config", "flowchart", "rankSpacing"]),
      ignore_cross_lane_edges: flag(
        ["config", "swimlane", "ignoreCrossLaneEdges"],
        true,
      ),
      optimize_ranks_by_crossings: flag(
        ["config", "swimlane", "optimizeRanksByCrossings"],
        true,
      ),
      automatic_lane_ordering: flag(
        ["config", "swimlane", "automaticLaneOrdering"],
        false,
      ),
      look,
    },
  }
}

///|
/// The sizes a capture measured, by node id.
pub fn capture_sizes(capture : Json) -> Map[String, (Double, Double)] {
  let sizes = Map([])
  if capture is Object(fields) &&
    field(fields, "sizes") is Some(Object(entries)) {
    for id, size in entries {
      if size is Array([Number(w, ..), Number(h, ..)]) {
        sizes[id] = (w, h)
      }
    }
  }
  sizes
}

///|
fn points_json(points : Array[Pt]) -> Json {
  Json::array(
    points.map(p => Json::array([Json::number(p.x), Json::number(p.y)])),
  )
}

///|
/// The fields of a node `scripts/swimlane_oracle.js` prints.
pub fn Node::to_snapshot(self : Node) -> Json {
  let out : Map[String, Json] = Map([])
  out["id"] = Json::string(self.id)
  let put_number = (key : String, value : Double?) => {
    if value is Some(v) {
      out[key] = Json::number(v)
    }
  }
  put_number("x", self.x)
  put_number("y", self.y)
  put_number("width", self.width)
  put_number("height", self.height)
  put_number("layer", self.layer.map(Int32::to_double))
  put_number("order", self.order.map(Int32::to_double))
  if self.parent_id is Some(parent) {
    out["parentId"] = Json::string(parent)
  }
  if self.shape != "" {
    out["shape"] = Json::string(self.shape)
  }
  if self.direction is Some(direction) {
    out["direction"] = Json::string(direction)
  }
  out["isGroup"] = Json::boolean(self.is_group)
  if self.is_edge_label {
    out["isEdgeLabel"] = Json::boolean(true)
  }
  put_number("swimlaneContentTop", self.swimlane_content_top)
  if self.group_title_rect is Some(r) {
    out["groupTitleRect"] = Json::array([
      Json::number(r.left),
      Json::number(r.right),
      Json::number(r.top),
      Json::number(r.bottom),
    ])
  }
  put_number("colorIndex", self.color_index.map(Int32::to_double))
  put_number("padding", self.padding)
  Json::object(out)
}

///|
/// The fields of an edge `scripts/swimlane_oracle.js` prints.
pub fn Edge::to_snapshot(self : Edge) -> Json {
  let out : Map[String, Json] = Map([])
  out["id"] = Json::string(self.id)
  out["start"] = Json::string(self.start)
  out["end"] = Json::string(self.end)
  if self.points is Some(points) {
    out["points"] = points_json(points)
  }
  if self.curve is Some(curve) {
    out["curve"] = Json::string(curve)
  }
  if self.label_node_id is Some(id) {
    out["labelNodeId"] = Json::string(id)
  }
  if self.is_layout_only {
    out["isLayoutOnly"] = Json::boolean(true)
  }
  if self.label is Some(label) {
    out["label"] = Json::string(label)
  }
  Json::object(out)
}

///|
/// A snapshot of the layout under a name.
pub fn Layout::snapshot(self : Layout, name : String) -> Json {
  Json::object(
    Map([
      ("name", Json::string(name)),
      ("nodes", Json::array(self.nodes.map(Node::to_snapshot))),
      ("edges", Json::array(self.edges.map(Edge::to_snapshot))),
    ]),
  )
}

///|
fn snapshot_points(json : Json?) -> Array[Pt]? {
  guard json is Some(Array(items)) else { return None }
  let points = []
  for item in items {
    if item is Array([Number(x, ..), Number(y, ..)]) {
      points.push(pt(x, y))
    }
  }
  Some(points)
}

///|
/// The layout a snapshot shows, to run one step of the layout on it. The
/// snapshot keeps what the steps after the ranking read; points shared by
/// several routes upstream are separate here.
pub fn Layout::from_snapshot(
  snapshot : Json,
  direction? : String,
  options? : Options,
) -> Layout {
  let nodes = []
  if path(snapshot, ["nodes"]) is Some(Array(items)) {
    for item in items {
      guard item is Object(n) else { continue }
      let node = Node::new(
        id=text_field(n, "id").unwrap_or(""),
        is_group=flag_field(n, "isGroup"),
        parent_id?=text_field(n, "parentId"),
        padding?=number_field(n, "padding"),
        shape=text_field(n, "shape").unwrap_or(""),
        direction?=text_field(n, "direction"),
        color_index?=number_field(n, "colorIndex").map(Double::to_int),
        is_edge_label=flag_field(n, "isEdgeLabel"),
        width?=number_field(n, "width"),
        height?=number_field(n, "height"),
      )
      node.x = number_field(n, "x")
      node.y = number_field(n, "y")
      node.layer = number_field(n, "layer").map(Double::to_int)
      node.order = number_field(n, "order").map(Double::to_int)
      node.swimlane_content_top = number_field(n, "swimlaneContentTop")
      if field(n, "groupTitleRect")
        is Some(
          Array(
            [
              Number(left, ..),
              Number(right, ..),
              Number(top, ..),
              Number(bottom, ..),
            ]
          )
        ) {
        node.group_title_rect = Some({ left, right, top, bottom, })
      }
      nodes.push(node)
    }
  }
  let edges = []
  if path(snapshot, ["edges"]) is Some(Array(items)) {
    for item in items {
      guard item is Object(e) else { continue }
      let edge = Edge::new(
        id=text_field(e, "id").unwrap_or(""),
        start=text_field(e, "start").unwrap_or(""),
        end=text_field(e, "end").unwrap_or(""),
        label?=text_field(e, "label"),
        is_layout_only=flag_field(e, "isLayoutOnly"),
        curve?=text_field(e, "curve"),
      )
      edge.points = snapshot_points(field(e, "points"))
      edge.label_node_id = text_field(e, "labelNodeId")
      edges.push(edge)
    }
  }
  { nodes, edges, direction, options: options.unwrap_or(Options::default()), }
}
