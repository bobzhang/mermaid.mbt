// From statements to the nodes and edges of the layout: mermaid's
// `dataFetcher.ts`.

///|
/// A node of the layout, with upstream's field names in mind.
priv struct NodeData {
  id : String
  shape : String
  /// The description lines until `extract` splits the title off.
  mut label : Description
  mut description : Array[String]
  css_classes : String
  mut css_compiled_styles : Array[String]
  css_styles : Array[String]
  dir : String?
  dom_id : String
  /// `group`, `node` or unset.
  node_type : String?
  is_group : Bool
  color_index : Int32?
  padding : Double?
  /// Whether the node asks for rounded corners (`rx` and `ry` of 10).
  rounded : Bool
  mut parent_id : String?
  center_label : Bool
  label_type : String?
  /// The side of the state a note stands on.
  position : String?
}

///|
/// An edge of the layout.
priv struct EdgeData {
  id : String
  start : String
  end : String
  label : String
  arrow_type_end : String
  classes : String
  /// `dashed` for the line from a note to its state.
  pattern : String?
}

///|
/// What is remembered of a state from one statement to the next:
/// upstream's `nodeDb` entry.
priv struct Known {
  mut shape : String
  mut description : Description
  mut css_classes : String
  css_styles : Array[String]
  mut node_type : String?
  mut dir : String?
  mut color_index : Int32?
}

///|
/// The state of one pass over the document.
priv struct DataFetcher {
  db : StateDb
  look : String
  known : Map[String, Known]
  mut item_count : Int32
  mut next_color : Int32
  /// The palette slot of each container; `None` for one the author styled.
  container_color : Map[String, Int32?]
  nodes : Array[NodeData]
  edges : Array[EdgeData]
}

///|
fn DataFetcher::new(db : StateDb) -> DataFetcher {
  {
    db,
    look: db.config.text("look").unwrap_or("classic"),
    known: {},
    item_count: 0,
    next_color: 0,
    container_color: {},
    nodes: [],
    edges: [],
  }
}

///|
/// The palette slot of a container: the next one, except that the regions
/// of a composite state share their parent's. Mermaid's `colorSlotFor`.
fn DataFetcher::color_slot(
  self : DataFetcher,
  shape : String,
  id : String,
  parent : Stmt?,
  user_styled : Bool,
) -> Int32? {
  if shape == "divider" &&
    parent is Some(parent) &&
    self.container_color.get(parent.id) is Some(inherited) {
    self.container_color[id] = inherited
    return inherited
  }
  let slot = self.next_color
  self.next_color += 1
  let effective = if user_styled { None } else { Some(slot) }
  self.container_color[id] = effective
  effective
}

///|
/// Mermaid's `stateDomId`.
fn state_dom_id(id : String, counter : Int32, kind~ : String = "") -> String {
  let kind = if kind == "" { "" } else { "----\{kind}" }
  "state-\{id}\{kind}-\{counter}"
}

///|
/// Add a node, or replace the fields of the one with its id: mermaid's
/// `insertOrUpdateNode`.
fn DataFetcher::insert_or_update(self : DataFetcher, node : NodeData) -> Unit {
  if node.id == "" || node.id == "</join></fork>" || node.id == "</choice>" {
    return
  }
  if node.css_classes != "" {
    for css_class in node.css_classes.split(" ") {
      if self.db.classes.get(css_class.to_owned()) is Some(found) {
        node.css_compiled_styles = [..node.css_compiled_styles, ..found.styles]
      }
    }
  }
  match self.nodes.search_by(existing => existing.id == node.id) {
    Some(index) => {
      // `Object.assign` leaves alone what the new data does not name.
      if node.parent_id is None {
        node.parent_id = self.nodes[index].parent_id
      }
      self.nodes[index] = node
    }
    None => self.nodes.push(node)
  }
}

///|
/// Mermaid's `setupDoc`: the statements of a document.
fn DataFetcher::setup_doc(
  self : DataFetcher,
  parent : Stmt,
  doc : Array[Stmt],
  alt : Bool,
) -> Unit raise StateError {
  for item in doc {
    match item.kind {
      "state" => self.fetch(Some(parent), item, alt)
      "relation" => {
        guard item.state1 is Some(state1) && item.state2 is Some(state2) else {
          continue
        }
        self.fetch(Some(parent), state1, alt)
        self.fetch(Some(parent), state2, alt)
        self.edges.push({
          id: "edge\{self.item_count}",
          start: state1.id,
          end: state2.id,
          label: sanitize_text(
            match item.description {
              One(text) => text
              _ => ""
            },
          ),
          arrow_type_end: if self.look == "neo" {
            "arrow_barb_neo"
          } else {
            "arrow_barb"
          },
          classes: "transition",
          pattern: None,
        })
        self.item_count += 1
      }
      _ => ()
    }
  }
}

///|
/// Mermaid's `dataFetcher`: the node of a statement, the note attached to
/// it, and the statements inside it.
fn DataFetcher::fetch(
  self : DataFetcher,
  parent : Stmt?,
  item : Stmt,
  alt : Bool,
) -> Unit raise StateError {
  let id = item.id
  let state = self.db.states.get(id)
  let class_text = match state {
    Some(state) => state.classes.join(" ")
    None => ""
  }
  let styles = match state {
    Some(state) => state.styles
    None => []
  }
  let user_styled = trim(class_text) != "" || styles.length() > 0
  if id != "root" {
    let mut shape = match item.start {
      Some(true) => "stateStart"
      Some(false) => "stateEnd"
      None => "rect"
    }
    // A note names no type, and JavaScript compares it as it is.
    if item.state_type != Some("default") {
      shape = item.state_type.unwrap_or("undefined")
    }
    let known = match self.known.get(id) {
      Some(known) => known
      None => {
        let known : Known = {
          shape,
          description: One(sanitize_text(id)),
          css_classes: "\{class_text} statediagram-state",
          css_styles: styles,
          node_type: None,
          dir: None,
          color_index: None,
        }
        self.known[id] = known
        known
      }
    }
    if item.description.is_set() {
      let added = match item.description {
        One(text) => [text]
        Many(lines) => lines
        Missing => []
      }
      known.description = match known.description {
        Many(lines) => {
          known.shape = "rectWithTitle"
          Many([..lines, ..added])
        }
        One(text) if text != "" => {
          known.shape = "rectWithTitle"
          if text == id {
            Many(added)
          } else {
            Many([text, ..added])
          }
        }
        _ => {
          known.shape = "rect"
          item.description.copy()
        }
      }
      known.description = match known.description {
        One(text) => One(sanitize_text(text))
        Many(lines) => Many(lines.map(sanitize_text))
        Missing => Missing
      }
    }
    // A single description is a plain state again.
    let single = match known.description {
      One(text) => text.length() == 1
      Many(lines) => lines.length() == 1
      Missing => false
    }
    if single && known.shape == "rectWithTitle" {
      known.shape = if known.node_type == Some("group") {
        "roundedWithTitle"
      } else {
        "rect"
      }
    }
    if known.node_type is None && item.doc is Some(_) {
      known.node_type = Some("group")
      known.dir = Some(document_direction(item.doc))
      known.shape = if item.state_type == Some("divider") {
        "divider"
      } else {
        "roundedWithTitle"
      }
      known.color_index = self.color_slot(known.shape, id, parent, user_styled)
      known.css_classes = "\{known.css_classes} statediagram-cluster \{if alt { "statediagram-cluster-alt" } else { "" }}"
    }
    let node : NodeData = {
      id,
      shape: known.shape,
      label: if known.shape == "divider" {
        One("")
      } else {
        known.description.copy()
      },
      description: [],
      css_classes: known.css_classes,
      css_compiled_styles: [],
      css_styles: known.css_styles,
      dir: known.dir,
      dom_id: state_dom_id(id, self.item_count),
      node_type: known.node_type,
      is_group: known.node_type == Some("group"),
      color_index: known.color_index,
      padding: Some(8.0),
      rounded: true,
      parent_id: match parent {
        Some(parent) if parent.id != "root" => Some(parent.id)
        _ => None
      },
      center_label: true,
      label_type: Some("markdown"),
      position: None,
    }
    match item.note {
      Some(note) => {
        let note_node : NodeData = {
          id: "\{id}----note-\{self.item_count}",
          shape: "note",
          label: One(note.text),
          description: [],
          css_classes: "statediagram-note",
          css_compiled_styles: [],
          css_styles: [],
          dir: None,
          dom_id: state_dom_id(id, self.item_count, kind="note"),
          node_type: Some("node"),
          is_group: false,
          color_index: None,
          padding: self.db.config.number("flowchart.padding"),
          rounded: false,
          parent_id: Some("\{id}----parent"),
          center_label: false,
          label_type: Some("markdown"),
          position: Some(note.position),
        }
        let group : NodeData = {
          id: "\{id}----parent",
          shape: "noteGroup",
          label: One(note.text),
          description: [],
          css_classes: known.css_classes,
          css_compiled_styles: [],
          css_styles: [],
          dir: None,
          dom_id: state_dom_id(id, self.item_count, kind="parent"),
          node_type: Some("group"),
          is_group: true,
          color_index: None,
          padding: Some(16.0),
          rounded: false,
          parent_id: None,
          center_label: false,
          label_type: None,
          position: Some(note.position),
        }
        self.item_count += 1
        self.insert_or_update(group)
        self.insert_or_update(note_node)
        self.insert_or_update(node)
        let (from, to) = if note.position == "left of" {
          (note_node.id, id)
        } else {
          (id, note_node.id)
        }
        self.edges.push({
          id: "\{from}-\{to}",
          start: from,
          end: to,
          label: "",
          arrow_type_end: "",
          classes: "transition note-edge",
          pattern: Some("dashed"),
        })
      }
      None => self.insert_or_update(node)
    }
  }
  if item.doc is Some(doc) {
    self.setup_doc(item, doc, !alt)
  }
}
