///|
fn escape_attribute(value : String, out : StringBuilder) -> Unit {
  for c in value {
    match c {
      '&' => out.write_string("&amp;")
      '"' => out.write_string("&quot;")
      '\u{a0}' => out.write_string("&nbsp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(c)
    }
  }
}

///|
fn escape_text(value : String, out : StringBuilder) -> Unit {
  for c in value {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '\u{a0}' => out.write_string("&nbsp;")
      _ => out.write_char(c)
    }
  }
}

///|
/// HTML elements that never have an end tag.
fn is_void(tag : String) -> Bool {
  tag
  is ("area"
  | "base"
  | "br"
  | "col"
  | "embed"
  | "hr"
  | "img"
  | "input"
  | "link"
  | "meta"
  | "source"
  | "track"
  | "wbr")
}

///|
fn Element::write(self : Element, out : StringBuilder) -> Unit {
  self.sync_style()
  out.write_char('<')
  out.write_string(self.tag)
  for attribute in self.attributes {
    out.write_char(' ')
    out.write_string(attribute.0)
    out.write_string("=\"")
    escape_attribute(decode_entities(attribute.1), out)
    out.write_char('"')
  }
  out.write_char('>')
  if is_void(self.tag) {
    return
  }
  for node in self.children {
    match node {
      Text(content) => escape_text(decode_entities(content), out)
      Element(child) => child.write(out)
    }
  }
  out.write_string("</")
  out.write_string(self.tag)
  out.write_char('>')
}

///|
/// Serialize the element and its subtree the way a browser serializes
/// `outerHTML`: every element gets an explicit end tag, attributes keep
/// their order.
pub fn Element::to_html(self : Element) -> String {
  let out = StringBuilder()
  self.write(out)
  out.to_string()
}
