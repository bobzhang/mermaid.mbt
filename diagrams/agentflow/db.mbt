///|
/// The parsed agentflow: mermaid's `AgentFlowDB`. It is the flowchart's
/// database with containers that are `flow`s, a `global` block whose
/// nodes belong to no container, and `connector` declarations; links,
/// classes, styles and clicks behave exactly as in a flowchart and are
/// kept by the flowchart's database.
pub struct AgentDb {
  flow : @flowchart.FlowDb
  priv config : @config.Config
  /// The nodes of `global` blocks.
  priv global_nodes : Map[String, Unit]
  /// The ids declared with `connector`, in order.
  priv connectors : Map[String, Unit]
  priv mut sub_count : Int32
  mut acc_title : String
  mut acc_description : String
  mut title : String
}

///|
/// An agentflow that cannot be built from its source.
pub(all) suberror AgentflowError {
  AgentflowError(String)
} derive(Eq, Debug)

///|
fn AgentDb::new(config : @config.Config) -> AgentDb {
  {
    flow: @flowchart.FlowDb::new(config),
    config,
    global_nodes: Map([]),
    connectors: Map([]),
    sub_count: 0,
    acc_title: "",
    acc_description: "",
    title: "",
  }
}

///|
/// The prefix of the element ids of nodes.
const DOM_ID_PREFIX : String = "agentflow-"

///|
/// mermaid's `JSON.stringify` of a metadata value, for error messages.
fn json_text(value : Json) -> String {
  match value {
    Number(n, ..) if n == n.floor() && n.abs() < 1.0e21 =>
      n.to_int64().to_string()
    other => other.stringify()
  }
}

///|
/// Add a node, or add to one that exists, or attach `@{ ... }` metadata
/// to the container, connector or edge called `id`: mermaid's
/// `AgentFlowDB.addVertex`.
fn AgentDb::add_vertex(
  self : AgentDb,
  id : String,
  text? : (String, String),
  shape? : String,
  style? : Array[String],
  metadata? : String,
) -> Unit raise {
  if id.trim().is_empty() {
    return
  }
  let doc = match metadata {
    Some(metadata) => Some(parse_shape_data(metadata))
    None => None
  }
  // A shape alias is resolved in place; errors name what was written.
  let authored_shape = match doc {
    Some(doc) =>
      match doc.get("shape") {
        Some(String(authored)) => {
          let resolved = resolve_shape_alias(authored)
          if resolved != authored {
            doc["shape"] = Json::string(resolved)
          }
          Some(authored)
        }
        _ => None
      }
    None => None
  }
  if self.flow.annotate_sub_graph(id, doc) {
    return
  }
  // Metadata on a connector configures it; nothing of it is drawn.
  if self.connectors.contains(id) && doc is Some(_) {
    return
  }
  if id == "connectors" {
    return
  }
  if self.flow.annotate_edge(id, doc) {
    return
  }
  let vertex = self.flow.declare_vertex(
    id,
    text?,
    shape?,
    style?,
    dom_prefix=DOM_ID_PREFIX,
  )
  guard doc is Some(doc) else { return }
  match doc.get("shape") {
    Some(shape) if @flowchart.truthy(Some(shape)) => {
      let authored = match authored_shape {
        Some(authored) => authored
        None => raise AgentflowError("No such shape: \{json_text(shape)}.")
      }
      if authored != authored.to_lower() || authored.contains("_") {
        raise AgentflowError(
          "No such shape: \{authored}. Shape names should be lowercase.",
        )
      }
      guard shape is String(shape) && @rendering.is_valid_shape(shape) else {
        raise AgentflowError("No such shape: \{json_text(shape)}.")
      }
      vertex.shape = Some(shape)
    }
    _ => ()
  }
  if @flowchart.metadata_string(doc, "label") is Some(label) {
    vertex.text = Some(self.flow.sanitize_text(label))
    vertex.label_type = @flowchart.sanitize_label_type(
      @flowchart.metadata_string(doc, "labelType"),
    )
  }
}

///|
/// `flow id["title"] ... end`. `list` holds what the body's statements
/// produced: node ids, and direction statements as `{ stmt: "dir" }`.
/// Returns the container's id.
fn AgentDb::add_sub_graph(
  self : AgentDb,
  id : Json?,
  list : Json,
  title : Json?,
) -> String {
  let id_text = id.bind(@flowchart.text_object).map(t => t.0.trim().to_owned())
  let (title_text, title_type) = match title.bind(@flowchart.text_object) {
    Some((text, kind)) => (text, Some(kind))
    None => ("", None)
  }
  // Flatten one level, drop directions and blanks, keep first occurrences.
  let mut dir : String? = None
  let nodes : Array[String] = []
  let visit = (item : Json) => {
    match item {
      Object({ "stmt": String("dir"), "value": String(value), .. }) =>
        dir = Some(value)
      String(node) =>
        if !node.trim().is_empty() && !nodes.contains(node) {
          nodes.push(node)
        }
      _ => ()
    }
  }
  if list is Array(items) {
    for item in items {
      match item {
        Array(inner) =>
          for element in inner {
            visit(element)
          }
        other => visit(other)
      }
    }
  }
  if dir is None && self.config.flag("flowchart.inheritDir") {
    dir = self.flow.direction()
  }
  let id = match id_text {
    Some(id) => id
    None => "subGraph\{self.sub_count}"
  }
  let title = self.flow.sanitize_text(title_text).trim().to_owned()
  self.sub_count += 1
  // A container never holds itself, nor a node of a `global` block, nor
  // a node another container already holds.
  let sub_graphs = self.flow.sub_graphs
  let held = (node : String) => {
    sub_graphs.iter().any(sub_graph => sub_graph.nodes.contains(node))
  }
  let members = nodes.filter(node => {
    node != id && !self.global_nodes.contains(node) && !held(node)
  })
  match sub_graphs.search_by(sub_graph => sub_graph.id == id) {
    Some(index) => {
      let existing = sub_graphs[index]
      for node in members {
        if !existing.nodes.contains(node) {
          existing.nodes.push(node)
        }
      }
      if title != "" {
        existing.title = title
      }
      if dir is Some(_) {
        existing.dir = dir
      }
      self.flow.sub_graph_lookup[id] = existing
    }
    None => {
      let sub_graph : @flowchart.SubGraph = {
        id,
        nodes: members,
        title,
        classes: [],
        dir,
        label_type: @flowchart.sanitize_label_type(title_type),
        metadata: Map([]),
      }
      sub_graphs.push(sub_graph)
      self.flow.sub_graph_lookup[id] = sub_graph
    }
  }
  id
}

///|
/// `global ... end`: the nodes named in the block belong to no container,
/// wherever else they are mentioned.
fn AgentDb::add_global(self : AgentDb, list : Json) -> Unit {
  let add = (item : Json) => {
    if item is String(id) {
      let id = id.trim().to_owned()
      if id != "" {
        self.global_nodes[id] = ()
      }
    }
  }
  if list is Array(items) {
    for item in items {
      match item {
        Array(inner) =>
          for element in inner {
            add(element)
          }
        other => add(other)
      }
    }
  }
  for sub_graph in self.flow.sub_graphs {
    let kept = sub_graph.nodes.filter(id => !self.global_nodes.contains(id))
    sub_graph.nodes.clear()
    sub_graph.nodes.append(kept)
  }
}

///|
/// `connector id["title"]`: a node standing for an external system. It
/// replaces a node of the same id. Returns the id.
fn AgentDb::add_connector(self : AgentDb, id : Json, title : Json) -> String {
  let id = match @flowchart.text_object(id) {
    Some((text, _)) => text.trim().to_owned()
    None => ""
  }
  if id == "" {
    return ""
  }
  let title = match @flowchart.text_object(title) {
    Some((text, _)) => text.trim().to_owned()
    None => ""
  }
  let resolved = if title != "" { self.flow.sanitize_text(title) } else { id }
  if !self.connectors.contains(id) {
    let connector = @flowchart.Vertex::new(
      id,
      "\{DOM_ID_PREFIX}\{id}-\{self.flow.vertex_counter()}",
    )
    connector.text = Some(resolved)
    self.connectors[id] = ()
    self.flow.vertices[id] = connector
    self.flow.count_vertex()
  } else if title != "" {
    if self.flow.vertices.get(id) is Some(connector) {
      connector.text = Some(resolved)
    }
  }
  id
}

///|
/// Work out a link's arrow type, stroke and length from its text: `-->`,
/// `--x`, `-.-`, and from the opening `--` of a link with text.
fn destruct_link(text : String, start? : String) -> Json {
  let text = text.trim().to_owned()
  let n = text.length()
  let mut line = if n > 0 { text[:n - 1].to_owned() } else { "" }
  let kind = match text.get_char(n - 1) {
    Some('x') => "arrow_cross"
    Some('>') => "arrow_point"
    Some('-' | '.') => {
      line = text
      "arrow_open"
    }
    _ => "arrow_open"
  }
  let mut stroke = "normal"
  let mut length = line.length() - 1
  let dots = line.iter().filter(c => c == '.').count()
  if dots > 0 {
    stroke = "dotted"
    length = dots
  }
  if start is Some(start) && start != "" {
    let start_stroke = if start.contains(".") { "dotted" } else { "normal" }
    if start_stroke != stroke {
      return { "type": "INVALID", "stroke": "INVALID" }
    }
  }
  { "type": kind, "stroke": stroke, "length": length }
}

///|
/// The direction of the diagram, `TB` unless the source says otherwise.
pub fn AgentDb::direction(self : AgentDb) -> String? {
  self.flow.direction()
}

///|
/// The same diagram under another title.
pub fn AgentDb::set_title(self : AgentDb, title : String) -> Unit {
  self.title = title
}
