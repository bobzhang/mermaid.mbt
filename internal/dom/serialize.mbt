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
/// A carriage return comes out as a line feed, and takes a line feed
/// after it along: the sanitizer parses the markup again, and the HTML
/// parser normalizes line breaks.
fn escape_text(value : String, out : StringBuilder) -> Unit {
  let mut after_return = false
  for c in value {
    let skipped = after_return && c == '\n'
    after_return = c == '\r'
    if skipped {
      continue
    }
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '\u{a0}' => out.write_string("&nbsp;")
      '\r' => out.write_char('\n')
      _ => out.write_char(c)
    }
  }
}

///|
/// Whether `c` is white space or a line terminator to JavaScript, as
/// `String.prototype.trim` and `\s` take them.
fn is_js_space(c : Char) -> Bool {
  c
  is ('\t'
  | '\n'
  | '\u{0b}'
  | '\u{0c}'
  | '\r'
  | ' '
  | '\u{a0}'
  | '\u{1680}'
  | '\u{2000}'..<='\u{200a}'
  | '\u{2028}'
  | '\u{2029}'
  | '\u{202f}'
  | '\u{205f}'
  | '\u{3000}'
  | '\u{feff}')
}

///|
/// `String.prototype.trim`. Every such space is in the basic plane, so
/// code units can be tested one by one.
fn js_trim(value : String) -> String {
  let space = (i : Int32) => {
    is_js_space(Int32::unsafe_to_char(value[i].to_int()))
  }
  let mut start = 0
  let mut end = value.length()
  while start < end && space(start) {
    start += 1
  }
  while end > start && space(end - 1) {
    end -= 1
  }
  if start == 0 && end == value.length() {
    value
  } else {
    value[start:end].to_owned()
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
    // The sanitizer mermaid runs its output through trims attribute values
    // as `String.prototype.trim` does (except `value`), then removes those
    // that could end a comment or raw-text element (`SAFE_FOR_XML`).
    let value = decode_entities(attribute.1, in_attribute=true)
    let value = if attribute.0 == "value" { value } else { js_trim(value) }
    if !is_safe_for_xml(value) {
      continue
    }
    out.write_char(' ')
    out.write_string(attribute.0)
    out.write_string("=\"")
    escape_attribute(value, out)
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
