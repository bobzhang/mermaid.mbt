///|
/// A node of the document being built.
pub(all) enum Node {
  Element(Element)
  Text(String)
}

///|
/// An element with ordered attributes and children — the slice of the DOM
/// that mermaid's renderers drive through d3 selections.
pub struct Element {
  tag : String
  priv attributes : Array[(String, String)]
  priv children : Array[Node]
  priv mut parent : Element?
  /// Inline style declarations set through `style`, as the CSSOM holds
  /// them.
  priv declarations : Array[(String, String)]
  /// Whether `declarations` has changes not yet written to the `style`
  /// attribute. The browser writes them back lazily, which decides where
  /// the attribute lands among the others.
  priv mut style_dirty : Bool
}

///|
/// Create a detached element.
pub fn Element::new(tag : String) -> Element {
  {
    tag,
    attributes: [],
    children: [],
    parent: None,
    declarations: [],
    style_dirty: false,
  }
}

///|
/// Append a new child element and return it, like d3's
/// `selection.append`.
pub fn Element::append(self : Element, tag : String) -> Element {
  let child = Element::new(tag)
  child.parent = Some(self)
  self.children.push(Element(child))
  child
}

///|
/// Insert a new element before all existing children and return it, like
/// d3's `selection.insert(tag, ':first-child')`.
pub fn Element::insert_first(self : Element, tag : String) -> Element {
  let child = Element::new(tag)
  child.parent = Some(self)
  self.children.insert(0, Element(child))
  child
}

///|
/// Insert a detached element before `reference`, a child of this element.
/// Without such a child it goes last.
pub fn Element::insert_before(
  self : Element,
  child : Element,
  reference : Element,
) -> Unit {
  child.remove()
  child.parent = Some(self)
  for i, node in self.children {
    if node is Element(element) && physical_equal(element, reference) {
      self.children.insert(i, Element(child))
      return
    }
  }
  self.children.push(Element(child))
}

///|
/// Move a detached element in as the last child.
pub fn Element::append_child(self : Element, child : Element) -> Unit {
  child.remove()
  child.parent = Some(self)
  self.children.push(Element(child))
}

///|
/// Detach the element from its parent.
pub fn Element::remove(self : Element) -> Unit {
  guard self.parent is Some(parent) else { return }
  for i, node in parent.children {
    if node is Element(element) && physical_equal(element, self) {
      ignore(parent.children.remove(i))
      break
    }
  }
  self.parent = None
}

///|
pub fn Element::parent(self : Element) -> Element? {
  self.parent
}

///|
pub fn Element::children(self : Element) -> ArrayView[Node] {
  self.children[:]
}

///|
/// The child elements, skipping text.
pub fn Element::child_elements(self : Element) -> Array[Element] {
  self.children.filter_map(node => {
    match node {
      Element(element) => Some(element)
      Text(_) => None
    }
  })
}

///|
/// Set an attribute and return the element for chaining. A new attribute
/// goes last; an existing one keeps its position.
pub fn Element::attr(self : Element, name : String, value : String) -> Element {
  if name == "style" {
    // Setting the attribute first flushes pending declarations, then
    // replaces them with what the new text declares.
    self.sync_style()
    self.declarations.clear()
    for declaration in parse_declarations(value) {
      self.declarations.push(declaration)
    }
  }
  for i, attribute in self.attributes {
    if attribute.0 == name {
      self.attributes[i] = (name, value)
      return self
    }
  }
  self.attributes.push((name, value))
  self
}

///|
/// Set a numeric attribute, printed the way JavaScript prints numbers.
pub fn Element::attr_number(
  self : Element,
  name : String,
  value : Double,
) -> Element {
  self.attr(name, number(value))
}

///|
pub fn Element::get_attr(self : Element, name : String) -> String? {
  if name == "style" {
    self.sync_style()
  }
  for attribute in self.attributes {
    if attribute.0 == name {
      return Some(attribute.1)
    }
  }
  None
}

///|
pub fn Element::remove_attr(self : Element, name : String) -> Element {
  for i, attribute in self.attributes {
    if attribute.0 == name {
      ignore(self.attributes.remove(i))
      break
    }
  }
  self
}

///|
/// Replace the element's content with text, like d3's `selection.text`.
pub fn Element::text(self : Element, content : String) -> Element {
  self.children.clear()
  if content != "" {
    self.children.push(Text(content))
  }
  self
}

///|
/// The concatenated text of the element and its descendants.
pub fn Element::text_content(self : Element) -> String {
  let out = StringBuilder()
  fn collect(element : Element) {
    for node in element.children {
      match node {
        Text(content) => out.write_string(content)
        Element(child) => collect(child)
      }
    }
  }

  collect(self)
  out.to_string()
}

///|
/// Print a number the way JavaScript's `String(number)` does.
pub fn number(value : Double) -> String {
  if value == 0.0 {
    "0"
  } else {
    value.to_string()
  }
}

///|
/// A detached copy of the element and everything below it, like
/// `cloneNode(true)`.
pub fn Element::clone_deep(self : Element) -> Element {
  self.sync_style()
  let copy : Element = {
    tag: self.tag,
    attributes: self.attributes.copy(),
    children: [],
    parent: None,
    declarations: self.declarations.copy(),
    style_dirty: false,
  }
  for child in self.children {
    match child {
      Element(element) => {
        let element = element.clone_deep()
        element.parent = Some(copy)
        copy.children.push(Element(element))
      }
      Text(text) => copy.children.push(Text(text))
    }
  }
  copy
}

///|
/// The first element at or below this one with the given `id`.
pub fn Element::find_by_id(self : Element, id : String) -> Element? {
  if self.get_attr("id") == Some(id) {
    return Some(self)
  }
  for child in self.children {
    if child is Element(element) && element.find_by_id(id) is Some(found) {
      return Some(found)
    }
  }
  None
}

///|
/// Every element below this one with one of the given tags, in document
/// order.
pub fn Element::descendants(
  self : Element,
  tags : Array[String],
) -> Array[Element] {
  let found = []
  fn visit(element : Element) {
    for child in element.children {
      if child is Element(child) {
        if tags.contains(child.tag) {
          found.push(child)
        }
        visit(child)
      }
    }
  }
  visit(self)
  found
}
