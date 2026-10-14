///|
/// A requirement. Its type, risk and verification method are the words
/// shown in the diagram (`Functional Requirement`, `High`, `Test`, ...).
pub struct Requirement {
  name : String
  type_ : String
  requirement_id : String
  text : String
  risk : String
  verify_method : String
  css_styles : Array[String]
  classes : Array[String]
}

///|
/// An element that requirements are related to.
pub struct Element {
  name : String
  type_ : String
  doc_ref : String
  css_styles : Array[String]
  classes : Array[String]
}

///|
/// A relationship from `src` to `dst`: `contains`, `copies`, `derives`,
/// `satisfies`, `verifies`, `refines` or `traces`.
pub struct Relation {
  type_ : String
  src : String
  dst : String
}

///|
/// A `classDef`.
pub struct RequirementClass {
  id : String
  styles : Array[String]
  text_styles : Array[String]
}

///|
/// The parsed diagram: mermaid's `RequirementDB`.
pub struct RequirementDb {
  priv config : @config.Config
  requirements : Map[String, Requirement]
  elements : Map[String, Element]
  relations : Array[Relation]
  classes : Map[String, RequirementClass]
  // The body of the requirement or element being read: the grammar sees
  // the fields before the name they belong to.
  priv mut new_id : String
  priv mut new_text : String
  priv mut new_risk : String
  priv mut new_verify_method : String
  priv mut new_type : String
  priv mut new_doc_ref : String
  priv mut direction : String
  mut acc_title : String
  mut acc_description : String
  mut title : String
}

///|
fn RequirementDb::new(config : @config.Config) -> RequirementDb {
  {
    config,
    requirements: Map([]),
    elements: Map([]),
    relations: [],
    classes: Map([]),
    new_id: "",
    new_text: "",
    new_risk: "",
    new_verify_method: "",
    new_type: "",
    new_doc_ref: "",
    direction: "TB",
    acc_title: "",
    acc_description: "",
    title: "",
  }
}

///|
/// The direction of the layout, `TB` unless the source says otherwise.
pub fn RequirementDb::direction(self : RequirementDb) -> String {
  self.direction
}

///|
/// The same diagram under another title.
pub fn RequirementDb::set_title(self : RequirementDb, title : String) -> Unit {
  self.title = title
}

///|
/// Close a requirement over the body read so far. The first definition
/// of a name stays.
fn RequirementDb::add_requirement(
  self : RequirementDb,
  name : String,
  type_ : String,
) -> Unit {
  if !self.requirements.contains(name) {
    self.requirements[name] = {
      name,
      type_,
      requirement_id: self.new_id,
      text: self.new_text,
      risk: self.new_risk,
      verify_method: self.new_verify_method,
      css_styles: [],
      classes: ["default"],
    }
  }
  self.new_id = ""
  self.new_text = ""
  self.new_risk = ""
  self.new_verify_method = ""
}

///|
fn RequirementDb::add_element(self : RequirementDb, name : String) -> Unit {
  if !self.elements.contains(name) {
    self.elements[name] = {
      name,
      type_: self.new_type,
      doc_ref: self.new_doc_ref,
      css_styles: [],
      classes: ["default"],
    }
  }
  self.new_type = ""
  self.new_doc_ref = ""
}

///|
/// The styles and classes of the requirement or element called `id`.
fn RequirementDb::styling(
  self : RequirementDb,
  id : String,
) -> (Array[String], Array[String])? {
  match self.requirements.get(id) {
    Some(requirement) => Some((requirement.css_styles, requirement.classes))
    None =>
      match self.elements.get(id) {
        Some(element) => Some((element.css_styles, element.classes))
        None => None
      }
  }
}

///|
/// `style a,b fill:...`: a declaration holding commas is several.
fn RequirementDb::set_css_style(
  self : RequirementDb,
  ids : Array[String],
  styles : Array[String],
) -> Unit {
  for id in ids {
    // An unknown name ends the statement.
    guard self.styling(id) is Some((css_styles, _)) else { return }
    for style in styles {
      for part in style.split(",") {
        css_styles.push(part.to_owned())
      }
    }
  }
}

///|
/// `class a,b name`: the nodes take the class and what it defines so far.
fn RequirementDb::set_class(
  self : RequirementDb,
  ids : Array[String],
  class_names : Array[String],
) -> Unit {
  for id in ids {
    guard self.styling(id) is Some((css_styles, classes)) else { continue }
    for class_name in class_names {
      classes.push(class_name)
      if self.classes.get(class_name) is Some(style_class) {
        css_styles.append(style_class.styles)
      }
    }
  }
}

///|
/// `classDef a,b fill:...`: nodes that already have the class take the
/// styles too.
fn RequirementDb::define_class(
  self : RequirementDb,
  ids : Array[String],
  styles : Array[String],
) -> Unit {
  for id in ids {
    let style_class = match self.classes.get(id) {
      Some(style_class) => style_class
      None => {
        let style_class : RequirementClass = {
          id,
          styles: [],
          text_styles: [],
        }
        self.classes[id] = style_class
        style_class
      }
    }
    for style in styles {
      if style.contains("color") {
        style_class.text_styles.push(style.replace(old="fill", new="bgFill"))
      }
      style_class.styles.push(style)
    }
    let split = []
    for style in styles {
      for part in style.split(",") {
        split.push(part.to_owned())
      }
    }
    for _, requirement in self.requirements {
      if requirement.classes.contains(id) {
        requirement.css_styles.append(split)
      }
    }
    for _, element in self.elements {
      if element.classes.contains(id) {
        element.css_styles.append(split)
      }
    }
  }
}
