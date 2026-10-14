///|
/// A row of an entity: its type, name, keys and comment.
pub struct Attribute {
  type_ : String
  name : String
  keys : Array[String]
  comment : String
}

///|
/// An entity of the diagram.
pub struct Entity {
  /// `entity-<name>-<position>`: the id of its node.
  id : String
  label : String
  attributes : Array[Attribute]
  mut alias_name : String
  mut css_classes : String
  css_styles : Array[String]
}

///|
/// A line between two entities. The cardinalities are `ZERO_OR_ONE`,
/// `ZERO_OR_MORE`, `ONE_OR_MORE`, `ONLY_ONE` or `MD_PARENT`; the type is
/// `IDENTIFYING` or `NON_IDENTIFYING`.
pub struct Relationship {
  entity_a : String
  role_a : String
  entity_b : String
  card_a : String
  card_b : String
  rel_type : String
}

///|
/// A `classDef`.
pub struct EntityClass {
  id : String
  styles : Array[String]
  text_styles : Array[String]
}

///|
/// A `subgraph`.
pub struct SubGraph {
  id : String
  nodes : Array[String]
  title : String
  classes : Array[String]
  css_styles : Array[String]
  dir : String?
  label_type : String
}

///|
/// The parsed diagram: mermaid's `ErDB`.
pub struct ErDb {
  priv config : @config.Config
  entities : Map[String, Entity]
  relationships : Array[Relationship]
  classes : Map[String, EntityClass]
  sub_graphs : Array[SubGraph]
  priv sub_graph_lookup : Map[String, SubGraph]
  /// How many subgraphs enclose the statement being parsed.
  priv mut subgraph_depth : Int32
  priv mut direction : String
  mut acc_title : String
  mut acc_description : String
  mut title : String
}

///|
fn ErDb::new(config : @config.Config) -> ErDb {
  {
    config,
    entities: Map([]),
    relationships: [],
    classes: Map([]),
    sub_graphs: [],
    sub_graph_lookup: Map([]),
    subgraph_depth: 0,
    direction: "TB",
    acc_title: "",
    acc_description: "",
    title: "",
  }
}

///|
/// The direction of the layout, `TB` unless the source says otherwise.
pub fn ErDb::direction(self : ErDb) -> String {
  self.direction
}

///|
/// The same diagram under another title.
pub fn ErDb::set_title(self : ErDb, title : String) -> Unit {
  self.title = title
}

///|
/// Register an entity, or give an existing one its alias.
fn ErDb::add_entity(
  self : ErDb,
  name : String,
  alias_name~ : String = "",
) -> Entity {
  match self.entities.get(name) {
    Some(entity) => {
      if entity.alias_name == "" && alias_name != "" {
        entity.alias_name = alias_name
      }
      entity
    }
    None => {
      let entity : Entity = {
        id: "entity-\{name}-\{self.entities.length()}",
        label: name,
        attributes: [],
        alias_name,
        css_classes: "default",
        css_styles: [],
      }
      self.entities[name] = entity
      entity
    }
  }
}

///|
/// The grammar builds attribute lists back to front.
fn ErDb::add_attributes(
  self : ErDb,
  name : String,
  attributes : Array[Attribute],
) -> Unit {
  let entity = self.add_entity(name)
  for i = attributes.length() - 1; i >= 0; i = i - 1 {
    entity.attributes.push(attributes[i])
  }
}

///|
/// An end of a relationship is a subgraph or, failing that, an entity.
fn ErDb::end_id(self : ErDb, name : String) -> String {
  if self.sub_graph_lookup.contains(name) {
    name
  } else {
    self.add_entity(name).id
  }
}

///|
fn ErDb::add_relationship(
  self : ErDb,
  ent_a : String,
  role_a : String,
  ent_b : String,
  card_a~ : String,
  card_b~ : String,
  rel_type~ : String,
) -> Unit {
  let entity_a = self.end_id(ent_a)
  let entity_b = self.end_id(ent_b)
  self.relationships.push({
    entity_a,
    role_a,
    entity_b,
    card_a,
    card_b,
    rel_type,
  })
}

///|
/// The styles of several classes, in order: mermaid's `getCompiledStyles`.
fn ErDb::compiled_styles(
  self : ErDb,
  class_names : Array[String],
) -> Array[String] {
  let mut compiled : Array[String] = []
  for name in class_names {
    guard self.classes.get(name) is Some(style_class) else { continue }
    compiled = [..compiled, ..style_class.styles].map(style => {
      style.trim().to_owned()
    })
    compiled = [..compiled, ..style_class.text_styles].map(style => {
      style.trim().to_owned()
    })
  }
  compiled
}

///|
/// `style a,b fill:...`
fn ErDb::add_css_styles(
  self : ErDb,
  ids : Array[String],
  styles : Array[String],
) -> Unit {
  for id in ids {
    if self.entities.get(id) is Some(entity) {
      entity.css_styles.append(styles)
    }
    if self.sub_graph_lookup.get(id) is Some(sub_graph) {
      sub_graph.css_styles.append(styles)
    }
  }
}

///|
/// `classDef a,b fill:...`
fn ErDb::add_class(
  self : ErDb,
  ids : Array[String],
  styles : Array[String],
) -> Unit {
  for id in ids {
    let class_node = match self.classes.get(id) {
      Some(class_node) => class_node
      None => {
        let class_node : EntityClass = { id, styles: [], text_styles: [], }
        self.classes[id] = class_node
        class_node
      }
    }
    for style in styles {
      if style.contains("color") {
        class_node.text_styles.push(style.replace(old="fill", new="bgFill"))
      }
      class_node.styles.push(style)
    }
  }
}

///|
/// `class a,b name1,name2`
fn ErDb::set_class(
  self : ErDb,
  ids : Array[String],
  class_names : Array[String],
) -> Unit {
  for id in ids {
    if self.entities.get(id) is Some(entity) {
      for class_name in class_names {
        entity.css_classes = entity.css_classes + " " + class_name
      }
    }
    if self.sub_graph_lookup.get(id) is Some(sub_graph) {
      sub_graph.classes.append(class_names)
    }
  }
}

///|
/// What a statement inside a subgraph contributes to it.
priv enum Member {
  Name(String)
  Dir(String)
}

///|
/// Close a subgraph over what its statements listed.
fn ErDb::add_sub_graph(
  self : ErDb,
  id : String,
  list : Array[Member],
  title : String,
) -> String {
  let id = id.trim().to_owned()
  let seen : Set[String] = Set([])
  let mut dir : String? = None
  let nodes = []
  for item in list {
    match item {
      Dir(value) => dir = Some(value)
      Name(name) => {
        let trimmed = name.trim().to_owned()
        if trimmed == "" || seen.contains(trimmed) {
          continue
        }
        seen.add(trimmed)
        nodes.push(name)
      }
    }
  }
  // Every entity belongs to the first subgraph that lists it.
  let taken : Set[String] = Set([])
  for sub_graph in self.sub_graphs {
    for node in sub_graph.nodes {
      taken.add(node)
    }
  }
  let sub_graph : SubGraph = {
    id,
    nodes: nodes.filter(node => !taken.contains(node)),
    title: title.trim().to_owned(),
    classes: [],
    css_styles: [],
    dir,
    label_type: "markdown",
  }
  self.sub_graphs.push(sub_graph)
  self.sub_graph_lookup[id] = sub_graph
  id
}
