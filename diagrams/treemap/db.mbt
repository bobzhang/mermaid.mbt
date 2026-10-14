///|
/// A node of the treemap: a section with its children, or a leaf.
pub struct Node {
  name : String
  /// `None` for a leaf. A section may have no children, and is then drawn
  /// as a leaf.
  children : Array[Node]?
  value : Double?
  class_selector : String?
  /// The declarations of the node's class, when it has any.
  css_compiled_styles : Array[String]
}

///|
/// A class defined with `classDef`.
pub struct StyleClass {
  id : String
  styles : Array[String]
  text_styles : Array[String]
}

///|
/// A parsed treemap.
pub struct Treemap {
  /// The nodes without a parent. They are drawn inside an invisible root.
  outer_nodes : Array[Node]
  classes : Map[String, StyleClass]
  mut title : String
  acc_title : String
  acc_description : String
}

///|
fn Treemap::new(
  title : String,
  acc_title : String,
  acc_description : String,
) -> Treemap {
  { outer_nodes: [], classes: Map([]), title, acc_title, acc_description, }
}

///|
/// Give the diagram a title, as its frontmatter does.
pub fn Treemap::set_title(self : Treemap, title : String) -> Unit {
  self.title = title
}

///|
/// Whether a CSS property styles text rather than a shape: mermaid's
/// `isLabelStyle`.
fn is_label_style(key : String) -> Bool {
  key
  is ("color"
  | "font-size"
  | "font-family"
  | "font-weight"
  | "font-style"
  | "text-decoration"
  | "text-align"
  | "text-transform"
  | "line-height"
  | "letter-spacing"
  | "word-spacing"
  | "text-shadow"
  | "text-overflow"
  | "white-space"
  | "word-wrap"
  | "word-break"
  | "overflow-wrap"
  | "hyphens")
}

///|
/// `addClass`: the declarations of a `classDef`, separated by commas or
/// semicolons (`\,` is a comma inside a value), are added to the class.
fn Treemap::add_class(self : Treemap, id : String, style : String) -> Unit {
  let style_class = match self.classes.get(id) {
    Some(style_class) => style_class
    None => {
      let style_class = { id, styles: [], text_styles: [], }
      self.classes[id] = style_class
      style_class
    }
  }
  let styles = style
    .replace_all(old="\\,", new="§§§")
    .replace_all(old=",", new=";")
    .replace_all(old="§§§", new=",")
  for part in styles.split(";") {
    let part = part.to_owned()
    // Upstream asks whether the whole declaration is the name of a label
    // property, which only a bare name such as `color` is.
    if is_label_style(part) {
      style_class.text_styles.push(part)
    }
    style_class.styles.push(part)
  }
}

///|
/// `populate`: classes first, so that an item may use a class defined
/// after it, then the items as a tree by indentation (`buildHierarchy`).
fn Treemap::populate(self : Treemap, rows : Array[Row]) -> Unit {
  for row in rows {
    if row is ClassDef(name~, style_text~) {
      self.add_class(name, style_text)
    }
  }
  // The sections that may still get children, innermost last.
  let stack : Array[(Node, Int32)] = []
  for row in rows {
    guard row is Item(indent~, name~, value~, class_selector~) else { continue }
    // `row.indent ? parseInt(row.indent) : 0`
    let level = indent.unwrap_or(0)
    // `item.classSelector ? db.getStylesForClass(item.classSelector) : []`
    let styles = match class_selector {
      Some(selector) if selector != "" =>
        match self.classes.get(selector) {
          Some(style_class) => style_class.styles
          None => []
        }
      _ => []
    }
    let node = {
      name,
      children: if value is Some(_) {
        None
      } else {
        Some([])
      },
      value,
      class_selector,
      css_compiled_styles: styles,
    }
    while stack.last() is Some((_, parent_level)) && parent_level >= level {
      stack.pop() |> ignore
    }
    match stack.last() {
      Some((parent, _)) =>
        if parent.children is Some(children) {
          children.push(node)
        }
      None => self.outer_nodes.push(node)
    }
    // Only a section can have children.
    if value is None {
      stack.push((node, level))
    }
  }
}
