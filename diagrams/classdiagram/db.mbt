///|
/// What every DOM id of a class starts with.
const DOM_ID_PREFIX : String = "classId-"

///|
/// A class: mermaid's `ClassNode`.
pub struct ClassNode {
  id : String
  /// The generic type the class was declared with, if any.
  type_ : String
  mut label : String
  /// The title of the class box: the label with the generic type.
  mut text : String
  mut css_classes : String
  methods : Array[ClassMember]
  members : Array[ClassMember]
  annotations : Array[String]
  styles : Array[String]
  /// The id of the class's SVG element, without the diagram prefix.
  dom_id : String
  /// The namespace the class was declared in.
  mut parent : String?
  mut link : String?
  mut link_target : String?
  mut have_callback : Bool
  mut tooltip : String?
}

///|
/// A `note`, attached to a class or free.
pub struct ClassNote {
  id : String
  /// The class a `note for` names.
  class_ : String?
  text : String
  index : Int32
  mut parent : String?
}

///|
/// A relation between two classes. The ends are `relation_type`s, or
/// nothing for a plain line end.
pub struct ClassRelation {
  id1 : String
  id2 : String
  title1 : String
  title2 : String
  /// The label, if the statement has one.
  title : String?
  type1 : Int32?
  type2 : Int32?
  dotted : Bool
}

///|
/// The end of a lollipop relation that names the interface.
pub struct Interface {
  id : String
  label : String
  class_id : String
}

///|
/// A `namespace`: mermaid's `NamespaceNode`.
pub struct Namespace {
  id : String
  mut label : String
  parent : String?
  /// Whether the source declares it, rather than a dotted name implying
  /// it.
  mut explicit : Bool
}

///|
/// The kinds of relation ends, as the grammar numbers them.
const AGGREGATION : Int32 = 0

///|
const EXTENSION : Int32 = 1

///|
const COMPOSITION : Int32 = 2

///|
const DEPENDENCY : Int32 = 3

///|
const LOLLIPOP : Int32 = 4

///|
/// The parsed class diagram: mermaid's `ClassDB`.
pub struct ClassDb {
  priv config : @config.Config
  relations : Array[ClassRelation]
  classes : Map[String, ClassNode]
  notes : Map[String, ClassNote]
  interfaces : Array[Interface]
  namespaces : Map[String, Namespace]
  priv namespace_stack : Array[String]
  /// Upstream counts classes across all the diagrams of a page; a diagram
  /// rendered on its own starts at zero.
  priv mut class_counter : Int32
  priv mut direction : String
  mut acc_title : String
  mut acc_description : String
  mut title : String
}

///|
fn ClassDb::new(config : @config.Config) -> ClassDb {
  {
    config,
    relations: [],
    classes: Map([]),
    notes: Map([]),
    interfaces: [],
    namespaces: Map([]),
    namespace_stack: [],
    class_counter: 0,
    direction: "TB",
    acc_title: "",
    acc_description: "",
    title: "",
  }
}

///|
/// `TB`, `BT`, `LR` or `RL`.
pub fn ClassDb::direction(self : ClassDb) -> String {
  self.direction
}

///|
pub fn ClassDb::set_title(self : ClassDb, title : String) -> Unit {
  self.title = title
}

///|
/// A class name and the generic type written after it between tildes:
/// `splitClassNameAndType`.
fn split_class_name_and_type(id : String) -> (String, String) raise ClassError {
  let id = sanitize_text(id)
  if id.find("~") is Some(at) && at > 0 {
    let parts = id.split("~").map(part => part.to_owned()).collect()
    return (sanitize_text(parts[0]), sanitize_text(parts[1]))
  }
  (id, "")
}

///|
/// The class a statement names, which must exist.
fn ClassDb::class_of(self : ClassDb, id : String) -> ClassNode raise ClassError {
  let (class_name, _) = split_class_name_and_type(id)
  match self.classes.get(class_name) {
    Some(node) => node
    // Upstream dereferences the missing class and fails with a
    // `TypeError`.
    None =>
      raise Invalid(
        "Cannot read properties of undefined (reading 'annotations')",
      )
  }
}

///|
/// Called when a class is named: `addClass`.
fn ClassDb::add_class(self : ClassDb, id : String) -> Unit raise ClassError {
  let id = sanitize_text(id)
  let (class_name, type_) = split_class_name_and_type(id)
  if self.classes.contains(class_name) {
    return
  }
  let name = sanitize_text(class_name)
  self.classes[name] = {
    id: name,
    type_,
    label: name,
    text: name + (if type_ == "" { "" } else { "&lt;\{type_}&gt;" }),
    css_classes: "default",
    methods: [],
    members: [],
    annotations: [],
    styles: [],
    dom_id: "\{DOM_ID_PREFIX}\{name}-\{self.class_counter}",
    parent: None,
    link: None,
    link_target: None,
    have_callback: false,
    tooltip: None,
  }
  self.class_counter += 1
}

///|
/// `class Name["label"]`: `setClassLabel`.
fn ClassDb::set_class_label(
  self : ClassDb,
  id : String,
  label : String,
) -> Unit raise ClassError {
  let id = sanitize_text(id)
  let label = sanitize_text(label)
  let (class_name, _) = split_class_name_and_type(id)
  guard self.classes.get(class_name) is Some(node) else {
    raise Invalid("Cannot set properties of undefined (setting 'label')")
  }
  node.label = label
  // The brackets are written out here, not as entities.
  node.text = label + (if node.type_ == "" { "" } else { "<\{node.type_}>" })
}

///|
fn ClassDb::add_interface(
  self : ClassDb,
  label : String,
  class_id : String,
) -> Unit {
  self.interfaces.push({
    id: "interface\{self.interfaces.length()}",
    label,
    class_id,
  })
}

///|
/// `addRelation`: a lollipop end with a plain other end stands for an
/// interface, a node of its own.
fn ClassDb::add_relation(
  self : ClassDb,
  id1 : String,
  id2 : String,
  type1 : Int32?,
  type2 : Int32?,
  dotted : Bool,
  title1 : String,
  title2 : String,
  title : String?,
) -> Unit raise ClassError {
  let mut id1 = id1
  let mut id2 = id2
  if type1 == Some(LOLLIPOP) && type2 is None {
    self.add_class(id2)
    self.add_interface(id1, id2)
    id1 = "interface\{self.interfaces.length() - 1}"
  } else if type2 == Some(LOLLIPOP) && type1 is None {
    self.add_class(id1)
    self.add_interface(id2, id1)
    id2 = "interface\{self.interfaces.length() - 1}"
  } else {
    self.add_class(id1)
    self.add_class(id2)
  }
  self.relations.push({
    id1: split_class_name_and_type(id1).0,
    id2: split_class_name_and_type(id2).0,
    title1: sanitize_text(js_trim(title1)),
    title2: sanitize_text(js_trim(title2)),
    title,
    type1,
    type2,
    dotted,
  })
}

///|
/// `<<annotation>> Name`: `addAnnotation`.
fn ClassDb::add_annotation(
  self : ClassDb,
  class_name : String,
  annotation : String,
) -> Unit raise ClassError {
  self.class_of(class_name).annotations.push(annotation)
}

///|
/// A line of a class body, or `Name : member`: `addMember`. A line in
/// double angle brackets is an annotation, one with a closing parenthesis
/// a method, anything else an attribute.
fn ClassDb::add_member(
  self : ClassDb,
  class_name : String,
  line : String,
) -> Unit raise ClassError {
  self.add_class(class_name)
  let node = self.class_of(class_name)
  let line = js_trim(line)
  if line.has_prefix("<<") && line.has_suffix(">>") {
    let inner = line[2:line.length() - 2].to_owned()
    node.annotations.push(sanitize_text(inner))
  } else if line.find(")") is Some(at) && at > 0 {
    node.methods.push(ClassMember::new(sanitize_text(line), "method"))
  } else if line != "" {
    node.members.push(ClassMember::new(sanitize_text(line), "attribute"))
  }
}

///|
/// The lines of a class body, which the grammar collects last first.
fn ClassDb::add_members(
  self : ClassDb,
  class_name : String,
  members : Array[String],
) -> Unit raise ClassError {
  for line in members.rev() {
    self.add_member(class_name, line)
  }
}

///|
/// `addNote`; returns the id of the note.
fn ClassDb::add_note(
  self : ClassDb,
  text : String,
  class_name : String?,
) -> String {
  let index = self.notes.length()
  let id = "note\{index}"
  self.notes[id] = { id, class_: class_name, text, index, parent: None, }
  id
}

///|
/// The text after the colon of a statement: `cleanupLabel`.
fn cleanup_label(label : String) -> String raise ClassError {
  let label = if label.has_prefix(":") { label[1:].to_owned() } else { label }
  sanitize_text(js_trim(label))
}

///|
/// The class a comma-separated id of a styling statement names. An id
/// that starts with a digit is looked up with the DOM id prefix.
fn ClassDb::styled_class(
  self : ClassDb,
  id : String,
) -> ClassNode? raise ClassError {
  let id = if id.get_char(0) is Some('0'..<='9') {
    DOM_ID_PREFIX + id
  } else {
    id
  }
  self.classes.get(split_class_name_and_type(id).0)
}

///|
/// `cssClass "a,b" name` and `class a:::name`: `setCssClass`.
fn ClassDb::set_css_class(
  self : ClassDb,
  ids : String,
  class_name : String,
) -> Unit raise ClassError {
  for id in ids.split(",") {
    if self.styled_class(id.to_owned()) is Some(node) {
      node.css_classes += " " + class_name
    }
  }
}

///|
/// `classDef a,b styles`: `defineClass`. The styles reach the classes
/// that carry the name at this point, and any class whose list of names
/// merely contains it as text.
fn ClassDb::define_class(
  self : ClassDb,
  ids : Array[String],
  styles : Array[String],
) -> Unit {
  for id in ids {
    for _, node in self.classes {
      if node.css_classes.contains(id) {
        for style in styles {
          for part in style.split(",") {
            node.styles.push(part.to_owned())
          }
        }
      }
    }
  }
}

///|
/// `setTooltip`
fn ClassDb::set_tooltip(
  self : ClassDb,
  ids : String,
  tooltip : String,
) -> Unit raise ClassError {
  for id in ids.split(",") {
    let (class_name, _) = split_class_name_and_type(id.to_owned())
    if self.classes.get(class_name) is Some(node) {
      node.tooltip = Some(sanitize_text(tooltip))
    }
  }
}

///|
/// `link Name "url" target` and `click Name href "url" target`: `setLink`.
fn ClassDb::set_link(
  self : ClassDb,
  ids : String,
  link : String,
  target : String?,
) -> Unit raise ClassError {
  for id in ids.split(",") {
    if self.styled_class(id.to_owned()) is Some(node) {
      // An empty link is no link.
      node.link = match format_url(link, self.config) {
        "" => None
        url => Some(url)
      }
      node.link_target = if self.config.text("securityLevel") is Some("sandbox") {
        Some("_top")
      } else {
        match target {
          Some(target) => Some(sanitize_text(target))
          None => Some("_blank")
        }
      }
    }
  }
  self.set_css_class(ids, "clickable")
}

///|
/// `callback Name "function"` and `click Name call function()`:
/// `setClickEvent`. The handler is bound at run time upstream; what shows
/// in the output is that the class is clickable.
fn ClassDb::set_click_event(
  self : ClassDb,
  ids : String,
) -> Unit raise ClassError {
  for id in ids.split(",") {
    let (class_name, _) = split_class_name_and_type(id.to_owned())
    if self.classes.get(class_name) is Some(node) {
      node.have_callback = true
    }
  }
  self.set_css_class(ids, "clickable")
}

///|
/// `namespace Name["label"] {`: `addNamespace`. A dotted name declares
/// its ancestors too. Returns the qualified id.
fn ClassDb::add_namespace(
  self : ClassDb,
  id : String,
  label : String?,
) -> String {
  let qualified = match self.namespace_stack.last() {
    Some(prefix) if prefix != "" => "\{prefix}.\{id}"
    _ => id
  }
  self.namespace_stack.push(qualified)
  let label = match label {
    Some("") | None => None
    label => label
  }
  if self.namespaces.get(qualified) is Some(existing) {
    existing.explicit = true
    if label is Some(label) {
      existing.label = label
    }
    return qualified
  }
  let parts = qualified.split(".").map(part => part.to_owned()).collect()
  let mut current = ""
  let mut parent : String? = None
  for index, part in parts {
    current = if index == 0 { part } else { "\{current}.\{part}" }
    let leaf = index == parts.length() - 1
    match self.namespaces.get(current) {
      None =>
        self.namespaces[current] = {
          id: current,
          label: match label {
            Some(label) if leaf => label
            _ => part
          },
          parent,
          explicit: leaf,
        }
      Some(existing) => if leaf { existing.explicit = true }
    }
    parent = Some(current)
  }
  qualified
}

///|
/// The classes and notes declared inside a namespace:
/// `addClassesToNamespace`.
fn ClassDb::add_classes_to_namespace(
  self : ClassDb,
  id : String,
  class_names : Array[String],
  note_names : Array[String],
) -> Unit raise ClassError {
  guard self.namespaces.contains(id) else { return }
  for name in class_names {
    let (class_name, _) = split_class_name_and_type(name)
    guard self.classes.get(class_name) is Some(node) else {
      raise Invalid("Cannot set properties of undefined (setting 'parent')")
    }
    node.parent = Some(id)
  }
  for name in note_names {
    guard self.notes.get(name) is Some(note) else {
      raise Invalid("Cannot set properties of undefined (setting 'parent')")
    }
    note.parent = Some(id)
  }
}

///|
/// `style Name styles`: `setCssStyle`.
fn ClassDb::set_css_style(
  self : ClassDb,
  id : String,
  styles : Array[String],
) -> Unit {
  guard self.classes.get(id) is Some(node) else { return }
  for style in styles {
    for part in style.split(",") {
      node.styles.push(part.to_owned())
    }
  }
}
