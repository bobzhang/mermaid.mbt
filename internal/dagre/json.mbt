// Graphs and layouts as JSON, in the format of scripts/dagre_oracle.js:
// how the layout is checked against dagre itself.

///|
/// A number of the input, where the strings `NaN`, `Infinity` and
/// `-Infinity` stand for the numbers JSON cannot write.
fn json_number(value : Json?) -> Double? raise LayoutError {
  match value {
    None => None
    Some(Number(number, ..)) => Some(number)
    Some(String("NaN")) => Some(@double.not_a_number)
    Some(String("Infinity")) => Some(@double.infinity)
    Some(String("-Infinity")) => Some(@double.neg_infinity)
    Some(other) => raise LayoutError("\{other.stringify()} is not a number")
  }
}

///|
fn json_text(value : Json?) -> String? raise LayoutError {
  match value {
    None => None
    Some(String(text)) => Some(text)
    Some(other) => raise LayoutError("\{other.stringify()} is not a string")
  }
}

///|
fn number_json(value : Double) -> Json {
  if value.is_nan() {
    Json::string("NaN")
  } else if value.is_inf() {
    Json::string(if value > 0.0 { "Infinity" } else { "-Infinity" })
  } else {
    Json::number(value)
  }
}

///|
/// Lay out a graph given as `{ graph, nodes, edges }` and return
/// `{ width, height, nodes, edges }`.
pub fn layout_json(input : Json) -> Json raise LayoutError {
  guard input is Object(input) else {
    raise LayoutError("a graph is an object")
  }
  let graph : Map[String, Json] = match input.get("graph") {
    Some(Object(graph)) => graph
    _ => Map([])
  }
  let attrs : GraphAttrs = {
    rankdir: json_text(graph.get("rankdir")),
    nodesep: json_number(graph.get("nodesep")),
    edgesep: json_number(graph.get("edgesep")),
    ranksep: json_number(graph.get("ranksep")),
    marginx: json_number(graph.get("marginx")),
    marginy: json_number(graph.get("marginy")),
    acyclicer: json_text(graph.get("acyclicer")),
    ranker: json_text(graph.get("ranker")),
    align: json_text(graph.get("align")),
  }
  let nodes : Array[NodeAttrs] = []
  if input.get("nodes") is Some(Array(items)) {
    for item in items {
      guard item is Object(node) && node.get("id") is Some(String(id)) else {
        raise LayoutError("a node is an object with an id")
      }
      nodes.push({
        id,
        width: json_number(node.get("width")),
        height: json_number(node.get("height")),
        parent: json_text(node.get("parent")),
      })
    }
  }
  let edges : Array[EdgeAttrs] = []
  if input.get("edges") is Some(Array(items)) {
    for item in items {
      guard item is Object(edge) &&
        edge.get("v") is Some(String(v)) &&
        edge.get("w") is Some(String(w)) else {
        raise LayoutError("an edge is an object with its ends v and w")
      }
      edges.push({
        v,
        w,
        name: json_text(edge.get("name")),
        minlen: json_number(edge.get("minlen")),
        weight: json_number(edge.get("weight")),
        width: json_number(edge.get("width")),
        height: json_number(edge.get("height")),
        labeloffset: json_number(edge.get("labeloffset")),
        labelpos: json_text(edge.get("labelpos")),
      })
    }
  }
  let result = layout(attrs, nodes, edges)
  let node_items : Array[Json] = []
  for i, node in nodes {
    let out = result.nodes[i]
    let item : Map[String, Json] = {
      "id": Json::string(node.id),
      "x": number_json(out.x),
      "y": number_json(out.y),
    }
    // The size of a node is the layout's only when it has children.
    let (width, height) = if out.compound {
      (Some(out.width), Some(out.height))
    } else {
      (node.width, node.height)
    }
    if width is Some(width) {
      item["width"] = number_json(width)
    }
    if height is Some(height) {
      item["height"] = number_json(height)
    }
    node_items.push(Json::object(item))
  }
  let edge_items : Array[Json] = []
  for i, edge in edges {
    let out = result.edges[i]
    let item : Map[String, Json] = {
      "v": Json::string(edge.v),
      "w": Json::string(edge.w),
    }
    if edge.name is Some(name) {
      item["name"] = Json::string(name)
    }
    item["points"] = Json::array(
      out.points.map(p => {
        Json::object({ "x": number_json(p.x), "y": number_json(p.y) })
      }),
    )
    if out.label is Some(label) {
      item["x"] = number_json(label.x)
      item["y"] = number_json(label.y)
    }
    edge_items.push(Json::object(item))
  }
  Json::object({
    "width": number_json(result.width),
    "height": number_json(result.height),
    "nodes": Json::array(node_items),
    "edges": Json::array(edge_items),
  })
}
