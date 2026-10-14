// The mindmap database: mermaid's `mindmapDb.ts`.

///|
/// What goes wrong while a mindmap is read or drawn.
pub(all) suberror MindmapError {
  /// The source is not a mindmap upstream accepts.
  Invalid(String)
  /// Upstream accepts it; the port cannot reproduce what it makes of it.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// The kinds of node, by the brackets around the text: mermaid's
/// `nodeType`. A node without brackets is `Default`, which upstream also
/// calls `NO_BORDER`.
pub(all) enum NodeType {
  Default
  RoundedRect
  Rect
  Circle
  Cloud
  Bang
  Hexagon
} derive(Eq, Debug)

///|
/// The number upstream gives the type, which the class of the default
/// shape's outline shows (`node-0`).
pub fn NodeType::number(self : NodeType) -> Int32 {
  match self {
    Default => 0
    RoundedRect => 1
    Rect => 2
    Circle => 3
    Cloud => 4
    Bang => 5
    Hexagon => 6
  }
}

///|
/// A node of the mindmap tree.
pub struct MindmapNode {
  /// The node's number in the order of the source.
  id : Int32
  /// The text before the brackets, or the text when there are none.
  node_id : String
  /// The indentation relative to that of the root.
  level : Int32
  descr : String
  type_ : NodeType
  children : Array[MindmapNode]
  /// The width labels wrap at: `mindmap.maxNodeWidth`.
  width : Double
  padding : Double
  is_root : Bool
  mut icon : String?
  mut class : String?
  /// The colour section: the branch of the root the node is in.
  mut section : Int32?
}

///|
/// The nodes of one mindmap in the order of the source.
pub struct MindmapDb {
  priv config : @config.Config
  priv nodes : Array[MindmapNode]
  priv mut count : Int32
  /// The indentation of the root.
  priv mut base_level : Int32?
}

///|
fn MindmapDb::new(config : @config.Config) -> MindmapDb {
  { config, nodes: [], count: 0, base_level: None, }
}

///|
/// The root, if the mindmap has a node at all.
pub fn MindmapDb::root(self : MindmapDb) -> MindmapNode? {
  self.nodes.get(0)
}

///|
/// `getParent`: the last node above `level`.
fn MindmapDb::parent(self : MindmapDb, level : Int32) -> MindmapNode? {
  for i = self.nodes.length() - 1; i >= 0; i = i - 1 {
    if self.nodes[i].level < level {
      return Some(self.nodes[i])
    }
  }
  None
}

///|
/// `addNode`.
fn MindmapDb::add_node(
  self : MindmapDb,
  level : Int32,
  id : String,
  descr : String,
  type_ : NodeType,
) -> Unit raise MindmapError {
  let mut level = level
  let mut is_root = false
  if self.nodes.is_empty() {
    self.base_level = Some(level)
    level = 0
    is_root = true
  } else if self.base_level is Some(base) {
    level = level - base
  }
  let mut padding = self.config.number("mindmap.padding").unwrap_or(10.0)
  if type_ is (RoundedRect | Rect | Hexagon) {
    padding *= 2.0
  }
  let node = {
    id: self.count,
    node_id: sanitize_text(id),
    level,
    descr: sanitize_text(descr),
    type_,
    children: [],
    width: self.config.number("mindmap.maxNodeWidth").unwrap_or(200.0),
    padding,
    is_root,
    icon: None,
    class: None,
    section: None,
  }
  self.count += 1
  match self.parent(level) {
    Some(parent) => {
      parent.children.push(node)
      self.nodes.push(node)
    }
    None if is_root => self.nodes.push(node)
    None =>
      raise Invalid(
        "There can be only one root. No parent could be found for (\"\{node.descr}\")",
      )
  }
}

///|
/// `getType`: the kind of node its brackets make.
fn node_type(start : String, end : String) -> NodeType {
  match start {
    "[" => Rect
    "(" => if end == ")" { RoundedRect } else { Cloud }
    "((" => Circle
    ")" => Cloud
    "))" => Bang
    "{{" => Hexagon
    _ => Default
  }
}

///|
/// `decorateNode`: an icon or a class for the node added last.
fn MindmapDb::decorate_node(
  self : MindmapDb,
  icon? : String,
  class? : String,
) -> Unit raise MindmapError {
  guard self.nodes.last() is Some(node) else {
    // Upstream fails reading a property of the missing node.
    raise Invalid(
      "Cannot set properties of undefined (setting '\{if icon is Some(_) { "icon" } else { "class" }}')",
    )
  }
  if icon is Some(icon) && icon != "" {
    node.icon = Some(sanitize_text(icon))
  }
  if class is Some(class) && class != "" {
    node.class = Some(sanitize_text(class))
  }
}

///|
/// mermaid's `sanitizeText`: the text as DOMPurify hands it back, which
/// differs from what went in only when there is a `<` in it.
fn sanitize_text(text : String) -> String raise MindmapError {
  @dom.sanitize_fragment(text) catch {
    _ => raise Unsupported("mindmap text with this markup: \{text}")
  }
}

///|
/// The number of colour sections: `MAX_SECTIONS` of `svgDraw.ts`.
let max_sections : Int32 = 12

///|
/// `assignSections`: every node takes the section of the branch of the
/// root it is in (or, with `mindmap.colorBy: depth`, of its depth); the
/// root has none.
fn assign_sections(
  node : MindmapNode,
  section_number : Int32?,
  depth : Int32,
  color_by_depth : Bool,
) -> Unit {
  node.section = if node.level == 0 {
    None
  } else if color_by_depth {
    Some((depth - 1) % (max_sections - 1))
  } else {
    section_number
  }
  for index, child in node.children {
    let child_section_number = if node.level == 0 {
      Some(index % (max_sections - 1))
    } else {
      section_number
    }
    assign_sections(child, child_section_number, depth + 1, color_by_depth)
  }
}

///|
/// The nodes in the order of the source, which is a depth-first walk of
/// the tree.
pub fn MindmapDb::nodes(self : MindmapDb) -> Array[MindmapNode] {
  self.nodes
}

///|
/// The database as JSON, for comparing it with upstream's.
pub fn MindmapDb::dump(self : MindmapDb) -> Json {
  fn node_json(node : MindmapNode) -> Json {
    let object : Map[String, Json] = {
      "id": Json::number(node.id.to_double()),
      "nodeId": Json::string(node.node_id),
      "level": Json::number(node.level.to_double()),
      "descr": Json::string(node.descr),
      "type": Json::number(node.type_.number().to_double()),
      "children": Json::array(node.children.map(node_json)),
      "width": Json::number(node.width),
      "padding": Json::number(node.padding),
      "isRoot": Json::boolean(node.is_root),
    }
    if node.icon is Some(icon) {
      object["icon"] = Json::string(icon)
    }
    if node.class is Some(class) {
      object["class"] = Json::string(class)
    }
    Json::object(object)
  }

  match self.root() {
    Some(root) => node_json(root)
    None => Json::null()
  }
}
