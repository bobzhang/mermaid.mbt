///|
/// A node of the flowchart. Agentflow diagrams build on the same database,
/// hence the open fields.
pub(all) struct Vertex {
  id : String
  /// The id of the node's SVG element, without the diagram prefix.
  dom_id : String
  mut text : String?
  /// How `text` is to be read: `text`, `string` or `markdown`.
  mut label_type : String
  /// The shape keyword from the source (`square`, `diamond`, ...) or a
  /// shape name given in `@{ shape: ... }`.
  mut shape : String?
  styles : Array[String]
  classes : Array[String]
  mut link : String?
  mut link_target : String?
  mut have_callback : Bool
  mut icon : String?
  mut form : String?
  mut pos : String?
  mut img : String?
  mut constraint : String?
  mut asset_width : Double?
  mut asset_height : Double?
}

///|
/// A link between two nodes.
pub struct Edge {
  start : String
  end : String
  mut id : String
  mut is_user_defined_id : Bool
  /// `arrow_point`, `arrow_open`, `double_arrow_cross`, ...
  mut kind : String?
  mut text : String
  mut label_type : String
  /// `normal`, `thick`, `dotted` or `invisible`.
  mut stroke : String?
  /// How many ranks the link spans, from the number of dashes.
  mut length : Int32?
  mut style : Array[String]?
  mut interpolate : String?
  classes : Array[String]
  mut animate : Bool?
  mut animation : String?
}

///|
/// A `classDef`.
pub struct StyleClass {
  id : String
  styles : Array[String]
  text_styles : Array[String]
}

///|
/// A `subgraph`.
pub(all) struct SubGraph {
  id : String
  nodes : Array[String]
  mut title : String
  classes : Array[String]
  mut dir : String?
  label_type : String
  metadata : Map[String, Json]
}

///|
/// The parsed flowchart: mermaid's `FlowDB`.
pub struct FlowDb {
  priv config : @config.Config
  priv mut vertex_counter : Int32
  vertices : Map[String, Vertex]
  edges : Array[Edge]
  priv mut default_interpolate : String?
  priv mut default_style : Array[String]?
  classes : Map[String, StyleClass]
  sub_graphs : Array[SubGraph]
  sub_graph_lookup : Map[String, SubGraph]
  tooltips : Map[String, String]
  priv mut sub_count : Int32
  priv mut first_graph_flag : Bool
  priv mut direction : String?
  mut acc_title : String
  mut acc_description : String
  mut title : String
  /// A link the port cannot sanitize as upstream does; the diagram is
  /// refused when drawn.
  priv mut unsupported_link : String?
}

///|
/// A flowchart that cannot be built from its source.
pub(all) suberror FlowError {
  FlowError(String)
} derive(Eq, Debug)

///|
/// An empty database.
pub fn FlowDb::new(config : @config.Config) -> FlowDb {
  {
    config,
    vertex_counter: 0,
    vertices: Map([]),
    edges: [],
    default_interpolate: None,
    default_style: None,
    classes: Map([]),
    sub_graphs: [],
    sub_graph_lookup: Map([]),
    tooltips: Map([]),
    sub_count: 0,
    first_graph_flag: true,
    direction: None,
    acc_title: "",
    acc_description: "",
    title: "",
    unsupported_link: None,
  }
}

///|
/// The direction of the flowchart, `TB` unless the source says otherwise.
pub fn FlowDb::direction(self : FlowDb) -> String? {
  self.direction.map(d => d.trim().to_owned())
}

///|
pub fn FlowDb::default_interpolate(self : FlowDb) -> String? {
  self.default_interpolate
}

///|
pub fn FlowDb::default_style(self : FlowDb) -> Array[String]? {
  self.default_style
}

///|
/// mermaid's `sanitizeText` for text without markup. Text carrying HTML is
/// passed through for now; upstream runs it through DOMPurify.
pub fn FlowDb::sanitize_text(self : FlowDb, text : String) -> String {
  ignore(self)
  text
}

///|
/// mermaid's `sanitizeNodeLabelType`: an unknown kind of label is markdown.
pub fn sanitize_label_type(label_type : String?) -> String {
  match label_type {
    Some("markdown" | "string" | "text" as known) => known
    _ => "markdown"
  }
}

///|
/// The text without the quotes around it, if it has them.
pub fn unquote(text : String) -> String {
  if text.length() >= 2 && text.has_prefix("\"") && text.has_suffix("\"") {
    text[1:text.length() - 1].to_owned()
  } else if text == "\"" {
    // A lone quote starts and ends with a quote too.
    ""
  } else {
    text
  }
}

///|
/// The fields of a text object `{ text, type }` built by the grammar.
pub fn text_object(value : Json) -> (String, String)? {
  match value {
    Object({ "text": String(text), "type": String(kind), .. }) =>
      Some((text, kind))
    Object({ "text": String(text), .. }) => Some((text, "text"))
    _ => None
  }
}

///|
/// Parse the body of a `@{ ... }` shape data block as YAML.
pub fn parse_metadata(metadata : String) -> Json raise {
  let source = if metadata.contains("\n") {
    metadata + "\n"
  } else {
    "{\n" + metadata + "\n}"
  }
  // js-yaml's leniency, as upstream loads it with js-yaml.
  match
    @yaml.Yaml::load_from_string(source, lenient_quoted_scalar_indentation=true) {
    [document, ..] => Json(document)
    [] => Json::null()
  }
}

///|
/// JavaScript truthiness of a metadata field.
pub fn truthy(value : Json?) -> Bool {
  match value {
    None | Some(Null | False) => false
    Some(String(s)) => s != ""
    Some(Number(n, ..)) => n != 0.0
    Some(_) => true
  }
}

///|
/// A truthy metadata field as text.
pub fn metadata_string(doc : Map[String, Json], key : String) -> String? {
  match doc.get(key) {
    Some(String(s)) if s != "" => Some(s)
    Some(Number(n, ..)) if n != 0.0 => Some(n.to_string())
    Some(True) => Some("true")
    _ => None
  }
}

///|
/// Attach `@{ ... }` metadata to the subgraph called `id`: the same syntax
/// serves nodes, subgraphs and edges. Whether there was such a subgraph
/// and metadata for it.
pub fn FlowDb::annotate_sub_graph(
  self : FlowDb,
  id : String,
  doc : Map[String, Json]?,
) -> Bool {
  guard self.sub_graph_lookup.get(id) is Some(sub_graph) && doc is Some(doc) else {
    return false
  }
  for key, value in doc {
    sub_graph.metadata[key] = value
  }
  true
}

///|
/// Attach `@{ ... }` metadata to the edge with the id `id`. Whether there
/// is such an edge.
pub fn FlowDb::annotate_edge(
  self : FlowDb,
  id : String,
  doc : Map[String, Json]?,
) -> Bool {
  for edge in self.edges {
    if edge.id == id {
      if doc is Some(doc) {
        match doc.get("animate") {
          Some(True) => edge.animate = Some(true)
          Some(False) => edge.animate = Some(false)
          _ => ()
        }
        if doc.get("animation") is Some(String(animation)) {
          edge.animation = Some(animation)
        }
        if doc.get("curve") is Some(String(curve)) {
          edge.interpolate = Some(curve)
        }
      }
      return true
    }
  }
  false
}

///|
/// The number the next new vertex takes in its element id.
pub fn FlowDb::vertex_counter(self : FlowDb) -> Int32 {
  self.vertex_counter
}

///|
/// Count a vertex declared apart from `declare_vertex`.
pub fn FlowDb::count_vertex(self : FlowDb) -> Unit {
  self.vertex_counter += 1
}

///|
/// A vertex with nothing but its ids.
pub fn Vertex::new(id : String, dom_id : String) -> Vertex {
  {
    id,
    dom_id,
    text: None,
    label_type: "text",
    shape: None,
    styles: [],
    classes: [],
    link: None,
    link_target: None,
    have_callback: false,
    icon: None,
    form: None,
    pos: None,
    img: None,
    constraint: None,
    asset_width: None,
    asset_height: None,
  }
}

///|
/// Add a node, or add to one that exists: its label, shape and styles.
/// `dom_prefix` starts the ids of the elements of new nodes.
pub fn FlowDb::declare_vertex(
  self : FlowDb,
  id : String,
  text? : (String, String),
  shape? : String,
  style? : Array[String],
  dom_prefix~ : String = "flowchart-",
) -> Vertex {
  let vertex = match self.vertices.get(id) {
    Some(vertex) => vertex
    None => {
      let vertex = Vertex::new(id, "\{dom_prefix}\{id}-\{self.vertex_counter}")
      self.vertices[id] = vertex
      vertex
    }
  }
  self.vertex_counter += 1
  match text {
    Some((text, label_type)) => {
      vertex.label_type = label_type
      vertex.text = Some(unquote(self.sanitize_text(text.trim().to_owned())))
    }
    None => if vertex.text is None { vertex.text = Some(id) }
  }
  if shape is Some(shape) {
    vertex.shape = Some(shape)
  }
  if style is Some(style) {
    vertex.styles.append(style)
  }
  vertex
}

///|
/// Add a node, or add to one that exists: its label, shape, styles,
/// classes and `@{ ... }` metadata.
fn FlowDb::add_vertex(
  self : FlowDb,
  id : String,
  text? : (String, String),
  shape? : String,
  style? : Array[String],
  metadata? : String,
) -> Unit raise {
  if id.trim().is_empty() {
    return
  }
  let doc : Map[String, Json]? = match metadata {
    Some(metadata) =>
      match parse_metadata(metadata) {
        Object(fields) => Some(fields)
        _ => Some(Map([]))
      }
    None => None
  }
  // The same syntax attaches metadata to subgraphs and to edges by id.
  if self.annotate_sub_graph(id, doc) || self.annotate_edge(id, doc) {
    return
  }
  let vertex = self.declare_vertex(id, text?, shape?, style?)
  guard doc is Some(doc) else { return }
  if doc.get("shape") is Some(String(shape)) && shape != "" {
    if shape != shape.to_lower() || shape.contains("_") {
      raise FlowError(
        "No such shape: \{shape}. Shape names should be lowercase.",
      )
    }
    if !@rendering.is_valid_shape(shape) {
      raise FlowError("No such shape: \{shape}.")
    }
    vertex.shape = Some(shape)
  } else if doc.get("shape") is Some(shape) && truthy(Some(shape)) {
    // Upstream calls `doc.shape.toLowerCase()` on whatever is there.
    raise FlowError("doc.shape.toLowerCase is not a function")
  }
  let label = metadata_string(doc, "label")
  if label is Some(label) {
    vertex.text = Some(label)
    vertex.label_type = sanitize_label_type(metadata_string(doc, "labelType"))
  }
  let label_is_blank = label.map(l => l.trim().is_empty()).unwrap_or(true)
  if metadata_string(doc, "icon") is Some(icon) {
    vertex.icon = Some(icon)
    if label_is_blank && vertex.text == Some(id) {
      vertex.text = Some("")
    }
  }
  if metadata_string(doc, "form") is Some(form) {
    vertex.form = Some(form)
  }
  if metadata_string(doc, "pos") is Some(pos) {
    vertex.pos = Some(pos)
  }
  if metadata_string(doc, "img") is Some(img) {
    vertex.img = Some(img)
    if label_is_blank && vertex.text == Some(id) {
      vertex.text = Some("")
    }
  }
  if metadata_string(doc, "constraint") is Some(constraint) {
    vertex.constraint = Some(constraint)
  }
  // `Number(doc.w)`: a size may be given as text.
  if doc.get("w") is Some(w) && truthy(Some(w)) {
    vertex.asset_width = Some(@diagram.to_number(w))
  }
  if doc.get("h") is Some(h) && truthy(Some(h)) {
    vertex.asset_height = Some(@diagram.to_number(h))
  }
}

///|
/// mermaid's `getEdgeId`.
pub fn edge_id(
  from : String,
  to : String,
  counter~ : Int32,
  id? : String,
) -> String {
  match id {
    Some(id) => id
    None => "L_\{from}_\{to}_\{counter}"
  }
}

///|
fn FlowDb::add_single_link(
  self : FlowDb,
  start : String,
  end : String,
  link : Json,
  id : String?,
) -> Unit raise {
  let edge : Edge = {
    start,
    end,
    id: "",
    is_user_defined_id: false,
    kind: None,
    text: "",
    label_type: "text",
    stroke: None,
    length: None,
    style: None,
    interpolate: self.default_interpolate,
    classes: [],
    animate: None,
    animation: None,
  }
  guard link is Object(fields) else { return }
  if fields.get("text") is Some(text) && text_object(text) is Some((text, kind)) {
    edge.text = unquote(self.sanitize_text(text.trim().to_owned()))
    edge.label_type = sanitize_label_type(Some(kind))
  }
  if fields.get("type") is Some(String(kind)) {
    edge.kind = Some(kind)
  }
  if fields.get("stroke") is Some(String(stroke)) {
    edge.stroke = Some(stroke)
  }
  if fields.get("length") is Some(Number(length, ..)) {
    edge.length = Some(if length > 10.0 { 10 } else { length.to_int() })
  }
  let taken = (id : String) => self.edges.iter().any(e => e.id == id)
  match id {
    Some(id) if id != "" && !taken(id) => {
      edge.id = id
      edge.is_user_defined_id = true
    }
    _ => {
      let existing = self.edges
        .iter()
        .filter(e => e.start == start && e.end == end)
        .count()
      edge.id = edge_id(
        start,
        end,
        counter=if existing == 0 { 0 } else { existing + 1 },
      )
    }
  }
  let max_edges = self.config.number("maxEdges").unwrap_or(500.0).to_int()
  if self.edges.length() >= max_edges {
    raise FlowError(
      "Edge limit exceeded. \{self.edges.length()} edges found, but the limit is \{max_edges}.\nInitialize mermaid with maxEdges set to a higher number to allow more edges.\nYou cannot set this config via configuration inside the diagram as it is a secure config.\nYou have to call mermaid.initialize.",
    )
  }
  self.edges.push(edge)
}

///|
/// Link every start node to every end node. A user-defined id names the
/// link between the last start and the first end.
pub fn FlowDb::add_link(
  self : FlowDb,
  starts : Array[String],
  ends : Array[String],
  link : Json,
) -> Unit raise {
  let id = match link {
    Object({ "id": String(id), .. }) => Some(id.replace(old="@", new=""))
    _ => None
  }
  for start in starts {
    for end in ends {
      let is_last_start = start == starts[starts.length() - 1]
      let is_first_end = end == ends[0]
      self.add_single_link(
        start,
        end,
        link,
        if is_last_start && is_first_end {
          id
        } else {
          None
        },
      )
    }
  }
}

///|
/// A position in a `linkStyle` statement: a link number or `default`.
pub fn link_positions(value : Json) -> Array[Int32?] {
  let position = (item : Json) => {
    match item {
      Number(n, ..) => Some(n.to_int())
      String(s) =>
        if s == "default" {
          None
        } else {
          let mut n = 0
          for c in s {
            if c is ('0'..<='9') {
              n = n * 10 + (c.to_int() - '0')
            }
          }
          Some(n)
        }
      _ => None
    }
  }
  match value {
    Array(items) => items.map(position)
    other => [position(other)]
  }
}

///|
/// `linkStyle ... interpolate ...`: the curve of some links, or of all
/// that name none.
pub fn FlowDb::update_link_interpolate(
  self : FlowDb,
  positions : Array[Int32?],
  interpolate : String,
) -> Unit raise FlowError {
  for position in positions {
    match position {
      None => self.default_interpolate = Some(interpolate)
      Some(index) => {
        // Upstream assigns to a link that does not exist and fails.
        guard self.edges.get(index) is Some(edge) else {
          raise FlowError(
            "Cannot set properties of undefined (setting 'interpolate')",
          )
        }
        edge.interpolate = Some(interpolate)
      }
    }
  }
}

///|
/// `linkStyle`: the styles of some links, or of all that have none.
pub fn FlowDb::update_link(
  self : FlowDb,
  positions : Array[Int32?],
  style : Array[String],
) -> Unit raise {
  for position in positions {
    match position {
      None => self.default_style = Some(style)
      Some(index) => {
        guard self.edges.get(index) is Some(edge) else {
          raise FlowError(
            "The index \{index} for linkStyle is out of bounds. Valid indices for linkStyle are between 0 and \{self.edges.length() - 1}. (Help: Ensure that the index is within the range of existing edges.)",
          )
        }
        // The array is shared between the links of one statement, as in
        // the JavaScript, so `fill:none` is added to it once.
        edge.style = Some(style)
        if style.length() > 0 && !style.iter().any(s => s.has_prefix("fill")) {
          style.push("fill:none")
        }
      }
    }
  }
}

///|
/// `classDef ids styles`.
pub fn FlowDb::add_class(
  self : FlowDb,
  ids : String,
  style : Array[String],
) -> Unit {
  // Commas separate declarations; an escaped comma belongs to a value.
  let joined = style
    .join(",")
    .replace_all(old="\\,", new="§§§")
    .replace_all(old=",", new=";")
    .replace_all(old="§§§", new=",")
  let declarations = joined.split(";").map(part => part.to_owned()).collect()
  for id in ids.split(",") {
    let id = id.to_owned()
    let style_class = match self.classes.get(id) {
      Some(style_class) => style_class
      None => {
        let style_class = { id, styles: [], text_styles: [], }
        self.classes[id] = style_class
        style_class
      }
    }
    for declaration in declarations {
      if declaration.contains("color") {
        style_class.text_styles.push(
          declaration.replace(old="fill", new="bgFill"),
        )
      }
      style_class.styles.push(declaration)
    }
  }
}

///|
/// The direction after the diagram keyword, in any of its spellings.
pub fn FlowDb::set_direction(self : FlowDb, direction : String) -> Unit {
  let mut direction = direction.trim().to_owned()
  if direction.contains("<") {
    direction = "RL"
  }
  if direction.contains("^") {
    direction = "BT"
  }
  if direction.contains(">") {
    direction = "LR"
  }
  if direction.contains("v") {
    direction = "TB"
  }
  if direction == "TD" {
    direction = "TB"
  }
  self.direction = Some(direction)
}

///|
/// Add a class to nodes, links and subgraphs by id.
pub fn FlowDb::set_class(
  self : FlowDb,
  ids : String,
  class_name : String,
) -> Unit {
  for id in ids.split(",") {
    let id = id.to_owned()
    if self.vertices.get(id) is Some(vertex) {
      vertex.classes.push(class_name)
    }
    for edge in self.edges {
      if edge.id == id {
        edge.classes.push(class_name)
        break
      }
    }
    if self.sub_graph_lookup.get(id) is Some(sub_graph) {
      sub_graph.classes.push(class_name)
    }
  }
}

///|
/// The tooltip of some nodes.
pub fn FlowDb::set_tooltip(
  self : FlowDb,
  ids : String,
  tooltip : String,
) -> Unit {
  let tooltip = self.sanitize_text(tooltip)
  for id in ids.split(",") {
    self.tooltips[id.to_owned()] = tooltip
  }
}

///|
/// `click id href "url" target`.
pub fn FlowDb::set_link(
  self : FlowDb,
  ids : String,
  link : String,
  target : String?,
) -> Unit {
  for id in ids.split(",") {
    if self.vertices.get(id.to_owned()) is Some(vertex) {
      vertex.link = Some(self.format_url(link))
      vertex.link_target = target
    }
  }
  self.set_class(ids, "clickable")
}

///|
/// `click id callback`: only the `clickable` class shows in the output;
/// the callback itself is wired up at run time upstream.
pub fn FlowDb::set_click_event(self : FlowDb, ids : String) -> Unit {
  if self.config.text("securityLevel") is Some("loose") {
    for id in ids.split(",") {
      if self.vertices.get(id.to_owned()) is Some(vertex) {
        vertex.have_callback = true
      }
    }
  }
  self.set_class(ids, "clickable")
}

///|
/// mermaid's `formatUrl`: outside the loose security level a link goes
/// through `sanitizeUrl`, which decodes it, blanks scripting schemes and
/// normalizes web addresses as the browser's URL parser does.
fn FlowDb::format_url(self : FlowDb, link : String) -> String {
  let url = link.trim().to_owned()
  if url == "" {
    return url
  }
  if self.config.text("securityLevel") is Some("loose") {
    return url
  }
  @diagram.sanitize_url(url) catch {
    UnsupportedUrl(message) => {
      self.unsupported_link = Some(message)
      url
    }
  }
}

///|
/// The reason the diagram cannot be drawn exactly, if it has one.
pub fn FlowDb::unsupported(self : FlowDb) -> String? {
  self.unsupported_link
}

///|
/// Whether a subgraph already lists `id`.
fn exists(sub_graphs : Array[SubGraph], id : String) -> Bool {
  sub_graphs.iter().any(sub_graph => sub_graph.nodes.contains(id))
}

///|
/// `subgraph id [title] ... end`. `list` holds what the body's statements
/// produced: node ids, and direction statements as `{ stmt: "dir" }`.
/// Returns the subgraph's id.
fn FlowDb::add_sub_graph(
  self : FlowDb,
  id : Json?,
  list : Json,
  title : Json?,
  same_text~ : Bool = false,
) -> String {
  let (id_text, _) = id.bind(text_object).unwrap_or(("", "text"))
  let (title_text, title_type) = match title.bind(text_object) {
    Some((text, kind)) => (text, Some(kind))
    None => ("", None)
  }
  let mut sub_graph_id : String? = match id {
    Some(_) => Some(id_text.trim().to_owned())
    None => None
  }
  // `subgraph some title` without an id: the text is only a title.
  if same_text && title_text.iter().any(c => c is (' ' | '\t' | '\n' | '\r')) {
    sub_graph_id = None
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
    dir = self.direction()
  }
  let id = match sub_graph_id {
    Some(id) => id
    None => "subGraph\{self.sub_count}"
  }
  let title = self.sanitize_text(title_text)
  self.sub_count += 1
  // A node belongs to the innermost subgraph that listed it first.
  let unique = nodes.filter(node => !exists(self.sub_graphs, node) && node != id)
  let sub_graph : SubGraph = {
    id,
    nodes: unique,
    title: title.trim().to_owned(),
    classes: [],
    dir,
    label_type: sanitize_label_type(title_type),
    metadata: Map([]),
  }
  let mut existing : SubGraph? = None
  for candidate in self.sub_graphs {
    if candidate.id == id {
      existing = Some(candidate)
      break
    }
  }
  match existing {
    Some(existing) => {
      existing.nodes.append(sub_graph.nodes)
      self.sub_graph_lookup[id] = existing
    }
    None => {
      self.sub_graphs.push(sub_graph)
      self.sub_graph_lookup[id] = sub_graph
    }
  }
  id
}

///|
/// Whether `id` names a subgraph.
pub fn FlowDb::is_sub_graph(self : FlowDb, id : String) -> Bool {
  self.sub_graph_lookup.contains(id)
}

///|
fn destruct_start_link(text : String) -> (String, String) {
  let text = text.trim().to_owned()
  let (kind, rest) = match text.get_char(0) {
    Some('<') => ("arrow_point", text[1:].to_owned())
    Some('x') => ("arrow_cross", text[1:].to_owned())
    Some('o') => ("arrow_circle", text[1:].to_owned())
    _ => ("arrow_open", text)
  }
  let mut stroke = "normal"
  if rest.contains("=") {
    stroke = "thick"
  }
  if rest.contains(".") {
    stroke = "dotted"
  }
  (kind, stroke)
}

///|
fn destruct_end_link(text : String) -> (String, String, Int32) {
  let text = text.trim().to_owned()
  let n = text.length()
  let mut line = if n > 0 { text[:n - 1].to_owned() } else { "" }
  let mut kind = "arrow_open"
  let doubled = (marker : String, name : String) => {
    kind = name
    if text.has_prefix(marker) {
      kind = "double_" + name
      line = line[1:].to_owned()
    }
  }
  match text.get_char(n - 1) {
    Some('x') => doubled("x", "arrow_cross")
    Some('>') => doubled("<", "arrow_point")
    Some('o') => doubled("o", "arrow_circle")
    _ => ()
  }
  let mut stroke = "normal"
  let mut length = line.length() - 1
  if line.has_prefix("=") {
    stroke = "thick"
  }
  if line.has_prefix("~") {
    stroke = "invisible"
  }
  let dots = line.iter().filter(c => c == '.').count()
  if dots > 0 {
    stroke = "dotted"
    length = dots
  }
  (kind, stroke, length)
}

///|
/// Work out a link's arrow type, stroke and length from its text, e.g.
/// `-->`, `==>`, `-.->`, and from the opening part of a link with text.
fn destruct_link(text : String, start? : String) -> Json {
  let (kind, stroke, length) = destruct_end_link(text)
  guard start is Some(start) && start != "" else {
    return { "type": kind, "stroke": stroke, "length": length }
  }
  let (start_kind, start_stroke) = destruct_start_link(start)
  if start_stroke != stroke {
    return { "type": "INVALID", "stroke": "INVALID" }
  }
  let combined = if start_kind == "arrow_open" {
    kind
  } else if start_kind != kind {
    return { "type": "INVALID", "stroke": "INVALID" }
  } else {
    "double_" + start_kind
  }
  let combined = if combined == "double_arrow" {
    "double_arrow_point"
  } else {
    combined
  }
  { "type": combined, "stroke": start_stroke, "length": length }
}
