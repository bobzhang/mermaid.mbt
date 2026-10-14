// The database of a kanban diagram: mermaid's `kanbanDb.ts`.

///|
/// What goes wrong while a kanban diagram is read or drawn.
pub(all) suberror KanbanError {
  /// The source is not a kanban diagram upstream accepts.
  Invalid(String)
  /// Upstream accepts it; the port cannot reproduce what it makes of it.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// A node of the diagram: a section, or an item of one.
priv struct KanbanNode {
  id : String
  /// The indentation the node was written at.
  level : Int32
  mut label : String
  /// The section an item belongs to; sections have none.
  mut parent_id : String?
  mut icon : String?
  mut assigned : String?
  mut ticket : String?
  /// Any truthy `priority` of the metadata; one that is no text is the
  /// empty text, which names no priority.
  mut priority : String?
}

///|
/// Everything the parser collects.
pub struct KanbanDb {
  priv config : @config.Config
  priv nodes : Array[KanbanNode]
  priv sections : Array[KanbanNode]
  /// How many ids were made up for nodes without one.
  priv mut count : Int32
}

///|
fn KanbanDb::new(config : @config.Config) -> KanbanDb {
  { config, nodes: [], sections: [], count: 0, }
}

///|
/// mermaid's `sanitizeText`: the text as DOMPurify hands it back, which
/// differs from what went in only when there is markup in it.
fn KanbanDb::sanitize_text(
  self : KanbanDb,
  text : String,
) -> String raise KanbanError {
  let config = self.config
  let escaped = (c : Char) => c is ('<' | '>' | '=')
  // Any level but these escapes the text instead of sanitizing it.
  if !(config.text("securityLevel") is Some("strict" | "antiscript" | "loose")) &&
    !(config.get("flowchart.htmlLabels") is False) &&
    text.iter().any(escaped) {
    raise Unsupported("markup in text with this securityLevel: \{text}")
  }
  guard text.contains("<") else { return text }
  guard config.get("dompurifyConfig") is Null else {
    raise Unsupported("markup in text with a dompurifyConfig: \{text}")
  }
  @dom.sanitize_fragment(text) catch {
    _ => raise Unsupported("kanban text with markup: \{text}")
  }
}

///|
/// The section a node at `level` belongs to, `None` when it is a section
/// itself: mermaid's `getSection`. Sections are the nodes written at the
/// indentation of the first node.
fn KanbanDb::section_of(
  self : KanbanDb,
  level : Int32,
) -> KanbanNode? raise KanbanError {
  guard self.nodes is [first, ..] else { return None }
  let section_level = first.level
  let mut last_section : KanbanNode? = None
  for node in self.nodes.rev() {
    if node.level == section_level && last_section is None {
      last_section = Some(node)
    }
    if node.level < section_level {
      raise Invalid(
        "Items without section detected, found section (\"\{node.label}\")",
      )
    }
  }
  match last_section {
    Some(section) if section.level == level => None
    section => section
  }
}

///|
/// Read the `@{ ... }` block of a node into it: the part of mermaid's
/// `addNode` that follows `yaml.load`.
fn KanbanNode::apply_metadata(
  self : KanbanNode,
  shape_data : String,
) -> Unit raise KanbanError {
  let source = if shape_data.contains("\n") {
    shape_data + "\n"
  } else {
    "{\n" + shape_data + "\n}"
  }
  let fields = match load_yaml(source) {
    // Reading a property of nothing is a `TypeError`.
    None | Some(Null) =>
      raise Invalid("Cannot read properties of undefined (reading 'shape')")
    Some(Record(fields)) => fields
    // Anything else has none of the properties asked for.
    Some(_) => return
  }
  let truthy = (name : String) => fields.get(name).filter(Meta::truthy)
  match truthy("shape") {
    // The only shape the code goes on to accept has a capital in it.
    Some(Text(shape)) if shape == shape.to_lower() && !shape.contains("_") => ()
    Some(Text(shape)) =>
      raise Invalid("No such shape: \{shape}. Shape names should be lowercase.")
    Some(_) => raise Invalid("doc.shape.toLowerCase is not a function")
    None => ()
  }
  if truthy("label") is Some(label) {
    self.label = label.js_string()
  }
  if truthy("icon") is Some(icon) {
    self.icon = Some(icon.js_string())
  }
  if truthy("assigned") is Some(assigned) {
    self.assigned = Some(assigned.js_string())
  }
  if truthy("ticket") is Some(ticket) {
    self.ticket = Some(ticket.js_string())
  }
  match truthy("priority") {
    Some(Text(priority)) => self.priority = Some(priority)
    Some(_) => self.priority = Some("")
    None => ()
  }
}

///|
/// mermaid's `addNode`: a section when written at the indentation of the
/// first node, an item of the last section otherwise. The brackets
/// around the description only change a padding nothing draws with.
fn KanbanDb::add_node(
  self : KanbanDb,
  level : Int32,
  id : String,
  description : String,
  shape_data : String?,
) -> Unit raise KanbanError {
  let id = match self.sanitize_text(id) {
    "" => {
      self.count += 1
      "kbn\{self.count - 1}"
    }
    id => id
  }
  let node : KanbanNode = {
    id,
    level,
    label: self.sanitize_text(description),
    parent_id: None,
    icon: None,
    assigned: None,
    ticket: None,
    priority: None,
  }
  if shape_data is Some(shape_data) {
    node.apply_metadata(shape_data)
  }
  match self.section_of(level) {
    Some(section) => node.parent_id = Some(section.id)
    None => self.sections.push(node)
  }
  self.nodes.push(node)
}

///|
/// mermaid's `decorateNode` for `::icon(...)`: the icon of the last node.
/// A class given with `:::` reaches nothing that is drawn.
fn KanbanDb::set_icon(self : KanbanDb, icon : String) -> Unit raise KanbanError {
  guard icon != "" else { return }
  guard self.nodes.last() is Some(node) else {
    raise Invalid("Cannot set properties of undefined (setting 'icon')")
  }
  node.icon = Some(self.sanitize_text(icon))
}

///|
/// A node as the renderer gets it: mermaid's `getData`.
priv struct LayoutNode {
  node : KanbanNode
  /// The text to show, sanitized once more.
  label : String
  is_group : Bool
}

///|
/// The sections, each followed by its items: mermaid's `getData`. Items
/// are found by the id of their section, so sections sharing an id share
/// their items.
fn KanbanDb::data(self : KanbanDb) -> Array[LayoutNode] raise KanbanError {
  let nodes = []
  for section in self.sections {
    nodes.push({
      node: section,
      label: self.sanitize_text(section.label),
      is_group: true,
    })
    for item in self.nodes {
      if item.parent_id == Some(section.id) {
        nodes.push({
          node: item,
          label: self.sanitize_text(item.label),
          is_group: false,
        })
      }
    }
  }
  nodes
}
