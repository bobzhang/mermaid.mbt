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
}

///|
/// Create a detached element.
pub fn Element::new(tag : String) -> Element {
  { tag, attributes: [], children: [], parent: None, }
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
