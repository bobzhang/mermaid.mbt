///|
/// What the port cannot reproduce exactly and therefore refuses.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// A C4 diagram that cannot be drawn, with upstream's message.
pub(all) suberror C4Error {
  C4Error(String)
} derive(Eq, Debug)

///|
/// A person, system, container or component, or a boundary around them:
/// upstream's `C4Shape` and `C4Boundary`.
///
/// The grammar hands the database positional values and `$key="value"`
/// pairs, and a pair sets whatever key it names, so the parsed fields are
/// kept as the properties of upstream's object.
priv struct Element {
  props : Map[String, Json]
  // Filled in by the renderer: the top left corner and the size.
  mut x : Double
  mut y : Double
  mut width : Double
  mut height : Double
  /// Where the line from the centre towards a point leaves the outline,
  /// once the element is drawn.
  mut intersect : ((@rendering.Point) -> @rendering.Point)?
}

///|
/// A relationship: upstream's `C4Rel`.
priv struct Rel {
  props : Map[String, Json]
}

///|
/// The alias of an element. Like every other field it can be renamed by a
/// `$alias="..."` attribute.
fn Element::name(self : Element) -> String {
  string_of_prop(self.props, "alias").unwrap_or("")
}

///|
/// The alias of the element a relationship starts at.
fn Rel::from(self : Rel) -> String {
  string_of_prop(self.props, "from").unwrap_or("")
}

///|
/// The alias of the element a relationship ends at.
fn Rel::to(self : Rel) -> String {
  string_of_prop(self.props, "to").unwrap_or("")
}

///|
/// The parsed diagram: mermaid's `c4Db`.
pub struct C4Db {
  priv config : @config.Config
  priv shapes : Array[Element]
  priv boundaries : Array[Element]
  priv rels : Array[Rel]
  priv boundary_parse_stack : Array[String]
  priv mut current_boundary_parse : String
  priv mut parent_boundary_parse : String
  /// The root `wrap` setting, which every element copies: `null` when it is
  /// not configured.
  priv wrap : Json
  priv mut shape_in_row : Int32
  priv mut boundary_in_row : Int32
  priv mut c4_type : String
  mut title : String
  mut acc_description : String
}

///|
fn text_object(text : Json) -> Json {
  let fields : Map[String, Json] = { "text": text }
  Json::object(fields)
}

///|
fn C4Db::new(config : @config.Config) -> C4Db {
  let global : Map[String, Json] = {
    "alias": "global",
    "label": text_object("global"),
    "type": text_object("global"),
    "tags": Json::null(),
    "link": Json::null(),
    "parentBoundary": "",
  }
  {
    config,
    shapes: [],
    boundaries: [Element::new(global)],
    rels: [],
    boundary_parse_stack: [""],
    current_boundary_parse: "global",
    parent_boundary_parse: "",
    wrap: config.get("wrap"),
    shape_in_row: 4,
    boundary_in_row: 2,
    c4_type: "",
    title: "",
    acc_description: "",
  }
}

///|
fn Element::new(props : Map[String, Json]) -> Element {
  { props, x: 0.0, y: 0.0, width: 0.0, height: 0.0, intersect: None, }
}

///|
/// The text of a `{ text }` property: `element[field]?.text`, `None` when
/// there is no such property.
fn text_of(props : Map[String, Json], field : String) -> String? {
  match props.get(field) {
    Some(Object({ "text": String(text), .. })) => Some(text)
    _ => None
  }
}

///|
/// A property that is a string, as `$tags`, `$sprite` and the colours are.
fn string_of_prop(props : Map[String, Json], field : String) -> String? {
  match props.get(field) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
/// JavaScript truthiness of a property.
fn truthy(props : Map[String, Json], field : String) -> Bool {
  match props.get(field) {
    None | Some(Null | False) => false
    Some(String(text)) => text != ""
    Some(Number(number, ..)) => number != 0.0 && !number.is_nan()
    Some(_) => true
  }
}

///|
/// The fields stored as `{ text }` whichever slot they arrive through.
fn is_text_field(key : String) -> Bool {
  key is ("label" | "descr" | "techn" | "type")
}

///|
/// The only entry of a `$key="value"` attribute.
fn named(value : Json) -> (String, Json)? {
  guard value is Object(fields) else { return None }
  for key, item in fields {
    return Some((key, item))
  }
  None
}

///|
/// An alias, which upstream compares by identity when it is not a string.
fn name_of(value : Json, what : String) -> String raise Unsupported {
  match value {
    String(name) => name
    _ => raise Unsupported("C4: a named attribute in the place of the \{what}")
  }
}

///|
/// A positional text slot: nothing leaves the field as it is or gives it
/// its default, a named attribute sets the field it names, and anything
/// else is the text of `field`.
fn set_text_slot(
  props : Map[String, Json],
  field : String,
  value : Json?,
  default~ : String = "",
  keep~ : Bool = true,
) -> Unit {
  match value {
    None =>
      if !keep || props.get(field) is (None | Some(Null)) {
        props[field] = text_object(Json::string(default))
      }
    Some(value) =>
      match named(value) {
        Some((key, item)) =>
          props[key] = if is_text_field(key) { text_object(item) } else { item }
        None => props[field] = text_object(value)
      }
  }
}

///|
/// upstream's `assignAttributes`: `$tags`, `$sprite` and `$link` slots.
fn assign_attributes(
  props : Map[String, Json],
  slots : Array[(String, Json?)],
) -> Unit {
  for slot in slots {
    guard slot.1 is Some(value) else { continue }
    match named(value) {
      Some((key, item)) =>
        props[key] = if is_text_field(key) { text_object(item) } else { item }
      None => props[slot.0] = value
    }
  }
}

///|
/// A label, which every consumer reads as a string.
fn label_object(value : Json?) -> Json raise Unsupported {
  match value {
    None => text_object("")
    Some(String(_) as label) => text_object(label)
    Some(_) =>
      raise Unsupported("C4: a named attribute in the place of the label")
  }
}

///|
fn C4Db::set_wrap(self : C4Db, props : Map[String, Json]) -> Unit {
  if !(self.wrap is Null) {
    props["wrap"] = self.wrap
  }
}

///|
/// `addRel(type, from, to, label, techn?, descr?, sprite?, tags?, link?)`
fn C4Db::add_rel(
  self : C4Db,
  kind : String,
  args : Array[Json],
) -> Unit raise Unsupported {
  guard args.get(0) is Some(from) &&
    args.get(1) is Some(to) &&
    args.get(2) is Some(label) else {
    return
  }
  let from = name_of(from, "source of a relationship")
  let to = name_of(to, "target of a relationship")
  let rel = match
    self.rels.search_by(rel => rel.from() == from && rel.to() == to) {
    Some(index) => self.rels[index]
    None => {
      let rel : Rel = { props: Map([]), }
      self.rels.push(rel)
      rel
    }
  }
  let props = rel.props
  props["type"] = Json::string(kind)
  props["from"] = Json::string(from)
  props["to"] = Json::string(to)
  props["label"] = label_object(Some(label))
  set_text_slot(props, "techn", args.get(3))
  set_text_slot(props, "descr", args.get(4))
  assign_attributes(props, [
    ("sprite", args.get(5)),
    ("tags", args.get(6)),
    ("link", args.get(7)),
  ])
  self.set_wrap(props)
}

///|
/// The shape called `name`, created at the end of the list when new.
fn C4Db::shape(self : C4Db, name : String) -> Element {
  match self.shapes.search_by(shape => shape.name() == name) {
    Some(index) => self.shapes[index]
    None => {
      let props : Map[String, Json] = { "alias": Json::string(name) }
      let shape = Element::new(props)
      self.shapes.push(shape)
      shape
    }
  }
}

///|
/// `addPersonOrSystem(type, alias, label, descr?, sprite?, tags?, link?)`
fn C4Db::add_person_or_system(
  self : C4Db,
  kind : String,
  args : Array[Json],
) -> Unit raise Unsupported {
  guard args.get(0) is Some(name) else { return }
  let props = self.shape(name_of(name, "alias")).props
  props["label"] = label_object(args.get(1))
  set_text_slot(props, "descr", args.get(2))
  assign_attributes(props, [
    ("sprite", args.get(3)),
    ("tags", args.get(4)),
    ("link", args.get(5)),
  ])
  props["typeC4Shape"] = text_object(Json::string(kind))
  props["parentBoundary"] = Json::string(self.current_boundary_parse)
  self.set_wrap(props)
}

///|
/// `addContainer` and `addComponent`:
/// `(type, alias, label, techn?, descr?, sprite?, tags?, link?)`
fn C4Db::add_container(
  self : C4Db,
  kind : String,
  args : Array[Json],
) -> Unit raise Unsupported {
  guard args.get(0) is Some(name) else { return }
  let props = self.shape(name_of(name, "alias")).props
  props["label"] = label_object(args.get(1))
  set_text_slot(props, "techn", args.get(2))
  set_text_slot(props, "descr", args.get(3))
  assign_attributes(props, [
    ("sprite", args.get(4)),
    ("tags", args.get(5)),
    ("link", args.get(6)),
  ])
  self.set_wrap(props)
  props["typeC4Shape"] = text_object(Json::string(kind))
  props["parentBoundary"] = Json::string(self.current_boundary_parse)
}

///|
/// The boundary called `name`, created at the end of the list when new.
fn C4Db::boundary(self : C4Db, name : String) -> Element {
  match self.boundaries.search_by(boundary => boundary.name() == name) {
    Some(index) => self.boundaries[index]
    None => {
      let props : Map[String, Json] = { "alias": Json::string(name) }
      let boundary = Element::new(props)
      self.boundaries.push(boundary)
      boundary
    }
  }
}

///|
/// Make the boundary called `name` the one elements are added to.
fn C4Db::enter_boundary(self : C4Db, name : String) -> Unit {
  self.parent_boundary_parse = self.current_boundary_parse
  self.current_boundary_parse = name
  self.boundary_parse_stack.push(self.parent_boundary_parse)
}

///|
/// `addPersonOrSystemBoundary` and `addContainerBoundary`:
/// `(alias, label, type?, tags?, link?)`; they differ in the default type.
fn C4Db::add_boundary(
  self : C4Db,
  default_type : String,
  args : Array[Json],
) -> Unit raise Unsupported {
  guard args.get(0) is Some(name) else { return }
  let name = name_of(name, "alias")
  let props = self.boundary(name).props
  props["label"] = label_object(args.get(1))
  set_text_slot(props, "type", args.get(2), default=default_type, keep=false)
  assign_attributes(props, [("tags", args.get(3)), ("link", args.get(4))])
  props["parentBoundary"] = Json::string(self.current_boundary_parse)
  self.set_wrap(props)
  self.enter_boundary(name)
}

///|
/// `addDeploymentNode(nodeType, alias, label, type?, descr?, sprite?, tags?, link?)`.
/// Upstream takes the sprite slot and does not store it.
fn C4Db::add_deployment_node(
  self : C4Db,
  node_type : String,
  args : Array[Json],
) -> Unit raise Unsupported {
  guard args.get(0) is Some(name) else { return }
  let name = name_of(name, "alias")
  let props = self.boundary(name).props
  props["label"] = label_object(args.get(1))
  set_text_slot(props, "type", args.get(2), default="node", keep=false)
  set_text_slot(props, "descr", args.get(3))
  assign_attributes(props, [("tags", args.get(5)), ("link", args.get(6))])
  props["nodeType"] = Json::string(node_type)
  props["parentBoundary"] = Json::string(self.current_boundary_parse)
  self.set_wrap(props)
  self.enter_boundary(name)
}

///|
fn C4Db::pop_boundary_parse_stack(self : C4Db) -> Unit {
  self.current_boundary_parse = self.parent_boundary_parse
  self.boundary_parse_stack.pop() |> ignore
  // Popping the last entry leaves upstream with `undefined`, which no
  // alias equals.
  self.parent_boundary_parse = self.boundary_parse_stack.pop().unwrap_or("")
  self.boundary_parse_stack.push(self.parent_boundary_parse)
}

///|
/// A style slot: a named attribute sets the field it names, anything else
/// sets `field`; both as plain values.
fn set_style_slot(
  props : Map[String, Json],
  field : String,
  value : Json?,
  convert~ : (Json) -> Json = value => value,
) -> Unit {
  guard value is Some(value) else { return }
  match named(value) {
    Some((key, item)) => props[key] = convert(item)
    None => props[field] = convert(value)
  }
}

///|
/// `updateElStyle(elementName, bgColor?, fontColor?, borderColor?,
/// shadowing?, shape?, sprite?, techn?, legendText?, legendSprite?)`
fn C4Db::update_el_style(self : C4Db, args : Array[Json]) -> Unit {
  guard args.get(0) is Some(String(name)) else { return }
  let element = match self.shapes.search_by(shape => shape.name() == name) {
    Some(index) => self.shapes[index]
    None =>
      match self.boundaries.search_by(boundary => boundary.name() == name) {
        Some(index) => self.boundaries[index]
        None => return
      }
  }
  let fields = [
    "bgColor", "fontColor", "borderColor", "shadowing", "shape", "sprite", "techn",
    "legendText", "legendSprite",
  ]
  for index, field in fields {
    set_style_slot(element.props, field, args.get(index + 1))
  }
}

///|
/// JavaScript's `parseInt` of a string, `None` for `NaN`.
fn js_parse_int(text : String) -> Double? {
  let chars = text.trim().to_owned().to_array()
  let mut index = 0
  let mut negative = false
  if index < chars.length() && chars[index] is ('+' | '-') {
    negative = chars[index] == '-'
    index += 1
  }
  let mut radix = 10.0
  if index + 1 < chars.length() &&
    chars[index] == '0' &&
    chars[index + 1] is ('x' | 'X') {
    radix = 16.0
    index += 2
  }
  let mut value = 0.0
  let mut digits = 0
  while index < chars.length() {
    let digit = match chars[index] {
      '0'..<='9' as c => c.to_int() - '0'.to_int()
      'a'..<='f' as c if radix == 16.0 => c.to_int() - 'a'.to_int() + 10
      'A'..<='F' as c if radix == 16.0 => c.to_int() - 'A'.to_int() + 10
      _ => break
    }
    value = value * radix + digit.to_double()
    digits += 1
    index += 1
  }
  if digits == 0 {
    None
  } else if negative {
    Some(-value)
  } else {
    Some(value)
  }
}

///|
/// `parseInt` of a parsed value, `NaN` as `null`.
fn parse_int(value : Json) -> Json {
  match value {
    String(text) =>
      match js_parse_int(text) {
        Some(number) => Json::number(number)
        None => Json::null()
      }
    _ => Json::null()
  }
}

///|
/// `updateRelStyle(from, to, textColor?, lineColor?, offsetX?, offsetY?)`
fn C4Db::update_rel_style(self : C4Db, args : Array[Json]) -> Unit {
  guard args.get(0) is Some(String(from)) && args.get(1) is Some(String(to)) else {
    return
  }
  guard self.rels.search_by(rel => rel.from() == from && rel.to() == to)
    is Some(index) else {
    return
  }
  let props = self.rels[index].props
  set_style_slot(props, "textColor", args.get(2))
  set_style_slot(props, "lineColor", args.get(3))
  set_style_slot(props, "offsetX", args.get(4), convert=parse_int)
  set_style_slot(props, "offsetY", args.get(5), convert=parse_int)
}

///|
/// `updateLayoutConfig(c4ShapeInRow?, c4BoundaryInRow?)`
fn C4Db::update_layout_config(self : C4Db, args : Array[Json]) -> Unit {
  let count = (value : Json?) => {
    let value = match value {
      Some(value) =>
        match named(value) {
          Some((_, item)) => item
          None => value
        }
      None => Json::null()
    }
    match parse_int(value) {
      Number(n, ..) if n >= 1.0 => Some(n.to_int())
      _ => None
    }
  }
  if count(args.get(0)) is Some(shapes) {
    self.shape_in_row = shapes
  }
  if count(args.get(1)) is Some(boundaries) {
    self.boundary_in_row = boundaries
  }
}

///|
/// The shapes directly inside the boundary called `parent`.
fn C4Db::shapes_in(self : C4Db, parent : String) -> Array[Element] {
  self.shapes.filter(shape => {
    shape.props.get("parentBoundary") is Some(String(found)) && found == parent
  })
}

///|
/// The boundaries directly inside the boundary called `parent`.
fn C4Db::boundaries_in(self : C4Db, parent : String) -> Array[Element] {
  self.boundaries.filter(boundary => {
    boundary.props.get("parentBoundary") is Some(String(found)) &&
    found == parent
  })
}

///|
/// The end of a relationship: a shape, or else a boundary.
fn C4Db::element(self : C4Db, name : String) -> Element? {
  match self.shapes.search_by(shape => shape.name() == name) {
    Some(index) => Some(self.shapes[index])
    None =>
      match self.boundaries.search_by(boundary => boundary.name() == name) {
        Some(index) => Some(self.boundaries[index])
        None => None
      }
  }
}

///|
/// The database as JSON, with upstream's field names, for comparing
/// against mermaid's own parse.
pub fn C4Db::dump(self : C4Db) -> Json {
  let objects = (elements : Array[Element]) => {
    Json::array(elements.map(element => Json::object(element.props)))
  }
  {
    "shapes": objects(self.shapes),
    "boundaries": objects(self.boundaries),
    "rels": Json::array(self.rels.map(rel => Json::object(rel.props))),
    "title": Json::string(self.title),
    "c4Type": Json::string(self.c4_type),
    "c4ShapeInRow": Json::number(self.shape_in_row.to_double()),
    "c4BoundaryInRow": Json::number(self.boundary_in_row.to_double()),
    "accDescription": Json::string(self.acc_description),
  }
}
