///|
/// Resolve the character references in HTML text as the HTML parser does:
/// `&amp;`, `&#38;`, `&#x26;`, also without their semicolon where the
/// parser allows it. `in_attribute` tells whether the text is an attribute
/// value, where a legacy name followed by a letter, digit or `=` is no
/// reference. An ampersand that starts none is text. `fast_path` reads
/// them as Chrome's fast-path parser does (see `FastPath`): attribute
/// values as text, and `&#x;` as U+FFFD.
fn resolve_references(
  text : String,
  in_attribute~ : Bool = false,
  fast_path~ : Bool = false,
) -> String {
  if !text.contains("&") {
    return text
  }
  let out = StringBuilder()
  let mut rest = text[:]
  while rest.find("&") is Some(start) {
    out.write_view(rest[:start])
    let after = rest[start + 1:]
    rest = after
    match after {
      ['#', 'x' | 'X', .. digits] | ['#', .. digits] => {
        let radix = if after is ['#', 'x' | 'X', ..] { 16 } else { 10 }
        let mut length = 0
        while length < digits.length() &&
              (
                digits[length] is ('0'..<='9') ||
                (radix == 16 && digits[length] is ('a'..<='f' | 'A'..<='F'))
              ) {
          length += 1
        }
        if length == 0 {
          if fast_path && radix == 16 && digits is [';', .. tail] {
            out.write_char('\u{fffd}')
            rest = tail
          } else {
            out.write_char('&')
          }
          continue
        }
        out.write_string(
          numeric_reference(reference_code(digits[:length], radix)),
        )
        rest = if digits[length:] is [';', .. tail] {
          tail
        } else {
          digits[length:]
        }
      }
      ['a'..<='z' | 'A'..<='Z' | '0'..<='9', ..] => {
        // The longest name of the table the text starts with; none is
        // longer than 32 characters, semicolon included.
        let longest = if after.length() < 32 { after.length() } else { 32 }
        let mut matched = false
        for length = longest; length > 0; length = length - 1 {
          guard named_references.get(after[:length].to_owned()) is Some(value) else {
            continue
          }
          if in_attribute &&
            !fast_path &&
            after[length - 1] != ';' &&
            after[length:] is ['a'..<='z' | 'A'..<='Z' | '0'..<='9' | '=', ..] {
            break
          }
          out.write_string(value)
          rest = after[length:]
          matched = true
          break
        }
        if !matched {
          out.write_char('&')
        }
      }
      _ => out.write_char('&')
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
///
/// Character references are resolved as Chrome resolves them for markup
/// parsed into an element named `context`, by default this one: with
/// its fast-path parser where that takes the markup.
pub fn Element::set_inner_html(
  self : Element,
  html : String,
  context? : String,
) -> Unit {
  let fast_path = fast_path_parses(html, context.unwrap_or(self.tag))
  self.children.clear()
  let n = html.length()
  let stack = [self]
  let text = StringBuilder()
  let flush = () => {
    if !text.is_empty() {
      stack[stack.length() - 1].children.push(
        Text(resolve_references(text.to_string(), fast_path~)),
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
        if stack[depth].tag.to_lower() == name {
          stack.truncate(depth)
          break
        }
      }
      i = j + 1
      continue
    }
    let mut j = i + 1
    // A tag name starts with a letter; any other `<` is text.
    if j < n && html[j] is ('a'..<='z' | 'A'..<='Z') {
      while j < n && is_name(html[j]) {
        j += 1
      }
    }
    if j == i + 1 {
      text.write_char('<')
      i += 1
      continue
    }
    flush()
    let tag = html[i + 1:j].to_owned().to_lower()
    // Inside `<svg>`, or in an SVG element's content, names keep their
    // SVG case.
    let svg = tag == "svg" || children_in_svg(stack[stack.length() - 1])
    let element = Element::new(adjusted_tag(tag, svg))
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
      let name = adjusted_attribute(
        html[name_start:j].to_owned().to_lower(),
        svg,
      )
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
        element.attr(
          name,
          resolve_references(value, in_attribute=true, fast_path~),
        )
        |> ignore
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
/// Text as the sanitizer hands it back when it has to parse it, which it
/// does whenever the text has a `<` in it: the HTML is parsed and
/// serialized again. Every character reference becomes its character,
/// except that `&`, `<` and `>` are written as references, also where the
/// source had the bare character (a `<` that starts no tag, any `>`);
/// tags come back in their serialized form (`<br/>` as `<br>`).
///
/// Elements and attributes the sanitizer would remove are kept.
pub fn sanitized_text(text : String) -> String {
  let scratch = Element::new("div")
  scratch.set_inner_html(text)
  let out = StringBuilder()
  for node in scratch.children {
    match node {
      Text(content) => escape_text(content, out)
      Element(child) => child.write(out)
    }
  }
  out.to_string()
}
