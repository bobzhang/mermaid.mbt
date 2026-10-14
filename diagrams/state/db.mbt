// The database of a state diagram: mermaid's `StateDB`.

///|
/// The diagram could not be read or drawn.
pub(all) suberror StateError {
  StateError(String)
} derive(Eq, Debug)

///|
/// A class defined with `classDef`.
pub struct StyleClass {
  id : String
  styles : Array[String]
  text_styles : Array[String]
}

///|
/// What the database knows of a state named in the root document: the
/// classes and styles given to it.
priv struct StateInfo {
  classes : Array[String]
  mut styles : Array[String]
}

///|
/// A `click` statement: the state it names and where it leads.
priv struct Link {
  id : String
  url : String
  tooltip : String
}

///|
pub struct StateDb {
  priv config : @config.Config
  /// The parsed statements, rewritten in place by `translate_doc`.
  priv mut root_doc : Array[Stmt]
  priv mut divider_count : Int32
  /// How many ids `generate_id` has handed out.
  priv mut generated_ids : Int32
  priv states : Map[String, StateInfo]
  classes : Map[String, StyleClass]
  priv links : Array[Link]
  priv mut nodes : Array[NodeData]
  priv mut edges : Array[EdgeData]
  mut acc_title : String
  mut acc_description : String
  mut title : String
}

///|
fn StateDb::new(config : @config.Config) -> StateDb {
  {
    config,
    root_doc: [],
    divider_count: 0,
    generated_ids: 0,
    states: {},
    classes: {},
    links: [],
    nodes: [],
    edges: [],
    acc_title: "",
    acc_description: "",
    title: "",
  }
}

///|
/// mermaid's `sanitizeText`: DOMPurify leaves text without `<` alone and
/// otherwise parses it as HTML and writes it back, so that `<`, `>` and
/// `&` in plain text come out as character references. The tags DOMPurify
/// would drop are kept.
fn sanitize_text(text : String) -> String {
  if !text.contains("<") {
    return text
  }
  let holder = @dom.Element::new("div")
  holder.set_inner_html(text)
  let html = holder.to_html()
  guard html.strip_prefix("<div>") is Some(rest) &&
    rest.strip_suffix("</div>") is Some(inner) else {
    return text
  }
  inner.to_owned()
}

///|
/// The id of the last region of a composite state split by `--`, which the
/// grammar never names. Upstream draws it from `Math.random()`; the port
/// takes the draw to be 0.5, whose base 36 digits are `i`.
fn StateDb::generate_id(self : StateDb) -> String {
  self.generated_ids += 1
  "id-i-\{self.generated_ids}"
}

///|
/// Rewrite the statements of `node` in place: `[*]` gets the id of the
/// start or end of its document, and a document split by `--` becomes one
/// divider state per region. Mermaid's `docTranslator`.
fn StateDb::translate_doc(
  self : StateDb,
  parent_id : String,
  node : Stmt,
  first : Bool,
) -> Unit {
  if node.kind == "relation" {
    if node.state1 is Some(state1) {
      self.translate_doc(parent_id, state1, true)
    }
    if node.state2 is Some(state2) {
      self.translate_doc(parent_id, state2, false)
    }
    return
  }
  if node.kind == "state" {
    if node.id == "[*]" {
      node.id = parent_id + (if first { "_start" } else { "_end" })
      node.start = Some(first)
    } else {
      node.id = trim(node.id)
    }
  }
  guard node.kind == "state" && node.doc is Some(statements) else { return }
  let regions : Array[Stmt] = []
  let mut current : Array[Stmt] = []
  for statement in statements {
    if statement.state_type == Some("divider") {
      let region = statement.clone()
      region.doc = Some(clone_doc(current))
      regions.push(region)
      current = []
    } else {
      current.push(statement)
    }
  }
  let statements = if regions.length() > 0 && current.length() > 0 {
    regions.push(
      Stmt::new(
        "state",
        id=self.generate_id(),
        state_type="divider",
        doc=clone_doc(current),
      ),
    )
    node.doc = Some(regions)
    regions
  } else {
    statements
  }
  for statement in statements {
    self.translate_doc(node.id, statement, true)
  }
}

///|
/// The root document with its statements translated: mermaid's
/// `getRootDocV2`.
fn StateDb::root_doc_v2(self : StateDb) -> Stmt {
  let root = Stmt::new("state", id="root", doc=self.root_doc)
  // The root is a statement of its own kind upstream; only its document
  // matters here, and it never holds a divider.
  for statement in self.root_doc {
    self.translate_doc("root", statement, true)
  }
  root
}

///|
/// Mermaid's `addState`, as far as the renderer reads the result: a state
/// exists, with classes.
fn StateDb::add_state(
  self : StateDb,
  id : String,
  classes~ : Array[String] = [],
) -> Unit {
  let id = trim(id)
  if !self.states.contains(id) {
    self.states[id] = { classes: [], styles: [], }
  }
  for css_class in classes {
    self.set_css_class(id, trim(css_class))
  }
}

///|
/// Mermaid's `setCssClass`: give the class to each of the comma-separated
/// states.
fn StateDb::set_css_class(
  self : StateDb,
  ids : String,
  css_class : String,
) -> Unit {
  for id in ids.split(",") {
    let id = id.to_owned()
    let state = match self.states.get(id) {
      Some(state) => state
      None => {
        let id = trim(id)
        self.add_state(id)
        self.states[id]
      }
    }
    state.classes.push(css_class)
  }
}

///|
/// Mermaid's `handleStyleDef`: a `style` statement.
fn StateDb::set_styles(self : StateDb, ids : String, styles : String) -> Unit {
  let styles = styles
    .split(",")
    .map(style => trim(style.to_owned().replace_all(old=";", new="")))
    .collect()
  for id in trim(ids).split(",") {
    let id = id.to_owned()
    let state = match self.states.get(id) {
      Some(state) => state
      None => {
        let id = trim(id)
        self.add_state(id)
        self.states[id]
      }
    }
    state.styles = styles
  }
}

///|
/// Mermaid's `addStyleClass`: a `classDef` statement.
fn StateDb::add_style_class(
  self : StateDb,
  id : String,
  attributes : String,
) -> Unit {
  let found = match self.classes.get(id) {
    Some(found) => found
    None => {
      let found = { id, styles: [], text_styles: [], }
      self.classes[id] = found
      found
    }
  }
  if attributes == "" {
    return
  }
  for attribute in attributes.split(",") {
    let attribute = attribute.to_owned()
    // `attrib.replace(/([^;]*);/, '$1')` drops the first semicolon.
    let fixed = trim(attribute.replace(old=";", new=""))
    if attribute.contains("color") {
      found.text_styles.push(
        fixed.replace(old="fill", new="bgFill").replace(old="color", new="fill"),
      )
    }
    found.styles.push(fixed)
  }
}

///|
/// Read states, classes and links out of the translated root document and
/// build the nodes and edges to lay out. Mermaid's `extract`.
fn StateDb::extract(self : StateDb) -> Unit raise StateError {
  let root = self.root_doc_v2()
  self.states.clear()
  self.classes.clear()
  self.links.clear()
  for item in self.root_doc {
    match item.kind {
      "state" => self.add_state(item.id)
      "relation" =>
        if item.state1 is Some(state1) && item.state2 is Some(state2) {
          self.add_state(state1.id, classes=state1.classes)
          self.add_state(state2.id, classes=state2.classes)
        }
      "classDef" => self.add_style_class(trim(item.id), item.value)
      "style" => self.set_styles(item.id, item.value)
      "applyClass" => self.set_css_class(trim(item.id), item.value)
      "click" =>
        if item.state1 is Some(target) {
          self.links.push({
            id: target.id,
            url: item.value,
            tooltip: item.tooltip,
          })
        }
      _ => ()
    }
  }
  let fetcher = DataFetcher::new(self)
  fetcher.fetch(None, root, true)
  self.nodes = fetcher.nodes
  self.edges = fetcher.edges
  // A state with several descriptions is titled by the first.
  for node in self.nodes {
    guard node.label is Many(lines) else { continue }
    node.description = lines[1:].to_owned()
    if node.is_group && node.description.length() > 0 {
      raise StateError(
        "Group nodes can only have label. Remove the additional description for node [\{node.id}]",
      )
    }
    node.label = One(lines[0])
  }
}

///|
/// What the parser does with the document it has read: mermaid's
/// `setRootDoc`.
fn StateDb::set_root_doc(self : StateDb) -> Unit raise StateError {
  self.extract()
}

///|
/// The direction of the last `direction` statement of a document:
/// mermaid's `getDir`.
fn document_direction(doc : Array[Stmt]?) -> String {
  let mut direction = "TB"
  for statement in doc.unwrap_or([]) {
    if statement.kind == "dir" {
      direction = statement.value
    }
  }
  direction
}

///|
/// The same diagram under another title: that of the frontmatter.
pub fn StateDb::set_title(self : StateDb, title : String) -> Unit {
  self.title = sanitize_text(title)
}
