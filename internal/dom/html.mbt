///|
/// Resolve the character references in HTML text: `&amp;`, `&#38;`,
/// `&#x26;`. Unknown names are left as written.
fn resolve_references(text : String) -> String {
  if !text.contains("&") {
    return text
  }
  let out = StringBuilder()
  let mut rest = text[:]
  while rest.find("&") is Some(start) {
    out.write_view(rest[:start])
    let after = rest[start + 1:]
    let end = after.find(";")
    guard end is Some(end) && end > 0 && end <= 32 else {
      out.write_char('&')
      rest = after
      continue
    }
    let name = after[:end].to_owned()
    let hex = match name.strip_prefix("#x") {
      Some(digits) => Some(digits)
      None => name.strip_prefix("#X")
    }
    let radix_digits = (digits : StringView, radix : Int32) => {
      let mut value = 0
      let mut ok = digits.length() > 0
      for c in digits {
        let digit = match c {
          '0'..<='9' => c.to_int() - '0'
          'a'..<='f' => c.to_int() - 'a' + 10
          'A'..<='F' => c.to_int() - 'A' + 10
          _ => 99
        }
        if digit >= radix {
          ok = false
        }
        value = value * radix + digit
      }
      if ok {
        Some(value)
      } else {
        None
      }
    }
    let code = match (hex, name.strip_prefix("#")) {
      (Some(digits), _) => radix_digits(digits, 16)
      (None, Some(digits)) => radix_digits(digits, 10)
      (None, None) => named_entities.get(name)
    }
    match code.bind(Int32::to_char) {
      Some(c) => {
        out.write_char(c)
        rest = after[end + 1:]
      }
      None => {
        out.write_char('&')
        rest = after
      }
    }
  }
  out.write_view(rest)
  out.to_string()
}

///|
/// Replace the element's content with parsed HTML, like setting
/// `innerHTML`. This covers what labels contain: nested tags with quoted
/// attributes, void elements such as `<br>`, text and character
/// references. Anything malformed is kept as text.
pub fn Element::set_inner_html(self : Element, html : String) -> Unit {
  self.children.clear()
  let n = html.length()
  let stack = [self]
  let text = StringBuilder()
  let flush = () => {
    if !text.is_empty() {
      stack[stack.length() - 1].children.push(
        Text(resolve_references(text.to_string())),
      )
      text.reset()
    }
  }
  let is_name = (unit : UInt16) => {
    unit is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-' | ':' | '_')
  }
  let mut i = 0
  while i < n {
    if html[i] != '<' {
      // Both halves of a character outside the basic plane go together.
      let code = html[i].to_int()
      let width = if code >= 0xD800 && code < 0xDC00 && i + 1 < n {
        2
      } else {
        1
      }
      text.write_view(html[i:i + width])
      i += width
      continue
    }
    // An end tag closes the innermost open element of that name.
    if i + 1 < n && html[i + 1] == '/' {
      let mut j = i + 2
      while j < n && is_name(html[j]) {
        j += 1
      }
      let name = html[i + 2:j].to_owned().to_lower()
      while j < n && html[j] != '>' {
        j += 1
      }
      flush()
      for depth = stack.length() - 1; depth > 0; depth = depth - 1 {
        if stack[depth].tag == name {
          stack.truncate(depth)
          break
        }
      }
      i = j + 1
      continue
    }
    let mut j = i + 1
    while j < n && is_name(html[j]) {
      j += 1
    }
    if j == i + 1 {
      text.write_char('<')
      i += 1
      continue
    }
    flush()
    let element = Element::new(html[i + 1:j].to_owned().to_lower())
    // Attributes: name, name=value, name="value", name='value'.
    let mut self_closing = false
    while j < n && html[j] != '>' {
      if html[j] is (' ' | '\t' | '\n' | '\r') {
        j += 1
        continue
      }
      if html[j] == '/' {
        self_closing = true
        j += 1
        continue
      }
      let name_start = j
      while j < n && !(html[j] is (' ' | '\t' | '\n' | '\r' | '=' | '>' | '/')) {
        j += 1
      }
      let name = html[name_start:j].to_owned().to_lower()
      let mut value = ""
      if j < n && html[j] == '=' {
        j += 1
        if j < n && html[j] is ('"' | '\'') {
          let quote = html[j]
          let value_start = j + 1
          j = value_start
          while j < n && html[j] != quote {
            j += 1
          }
          value = html[value_start:j].to_owned()
          j += 1
        } else {
          let value_start = j
          while j < n && !(html[j] is (' ' | '\t' | '\n' | '\r' | '>')) {
            j += 1
          }
          value = html[value_start:j].to_owned()
        }
      }
      if name != "" && element.get_attr(name) is None {
        element.attr(name, resolve_references(value)) |> ignore
      }
    }
    let parent = stack[stack.length() - 1]
    element.parent = Some(parent)
    parent.children.push(Element(element))
    if !is_void(element.tag) && !self_closing {
      stack.push(element)
    }
    i = j + 1
  }
  flush()
}

///|
/// mermaid's `decodeEntities`: turn the placeholders that shield entity
/// codes back into character references, for text about to be parsed as
/// HTML.
pub fn placeholders_to_references(text : String) -> String {
  text
  .replace_all(old="ﬂ°°", new="&#")
  .replace_all(old="ﬂ°", new="&")
  .replace_all(old="¶ß", new=";")
}

///|
/// The text an HTML fragment's character data sanitizes to: every
/// character reference becomes its character, except that `&`, `<` and
/// `>` stay written as references, as HTML serialization writes them.
pub fn sanitized_text(text : String) -> String {
  let out = StringBuilder()
  let mut rest = text[:]
  while rest.find("&") is Some(start) {
    out.write_view(rest[:start])
    let after = rest[start + 1:]
    // A reference ends at its semicolon, a few characters on.
    match after.find(";") {
      Some(end) if end > 0 && end <= 32 => {
        let reference = "&" + after[:end].to_owned() + ";"
        let resolved = resolve_references(reference)
        out.write_string(
          match resolved {
            "&" => "&amp;"
            "<" => "&lt;"
            ">" => "&gt;"
            _ => resolved
          },
        )
        rest = after[end + 1:]
      }
      _ => {
        out.write_string("&")
        rest = after
      }
    }
  }
  out.write_view(rest)
  out.to_string()
}
