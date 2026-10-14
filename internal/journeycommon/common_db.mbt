// What the journey and timeline diagrams share of mermaid's commonDb: the
// sanitizing of titles and accessibility text.

///|
/// Text the port cannot sanitize exactly as upstream does.
pub(all) suberror SanitizeError {
  SanitizeError(String)
} derive(Eq, Debug)

///|
/// Inline elements the sanitizer lets through unchanged.
let inline_tags : Array[String] = [
  "b", "i", "u", "s", "em", "strong", "sub", "sup", "small", "code", "span",
]

///|
/// mermaid's `sanitizeText` under the default security level.
///
/// DOMPurify returns text without `<` untouched. Anything else it parses
/// as HTML and serializes again; that is reproduced for plain inline
/// elements without attributes and for `<br>`, and refused otherwise —
/// as are character references, which would have to be resolved.
pub fn sanitize_text(text : String) -> String raise SanitizeError {
  if !text.contains("<") {
    return text
  }
  let unsupported = () => {
    SanitizeError("sanitizing this markup is not ported: \{text}")
  }
  let out = StringBuilder()
  let open = []
  let n = text.length()
  let is_letter = (unit : UInt16) => unit is ('a'..<='z' | 'A'..<='Z')
  let mut i = 0
  while i < n {
    let unit = text[i]
    if unit == '>' {
      out.write_string("&gt;")
      i += 1
      continue
    }
    if unit == '&' {
      // What could be a character reference would have to be resolved
      // and written back; an ampersand before anything else is text.
      if i + 1 < n &&
        (is_letter(text[i + 1]) || text[i + 1] is ('0'..<='9' | '#')) {
        raise unsupported()
      }
      out.write_string("&amp;")
      i += 1
      continue
    }
    if unit != '<' {
      out.write_view(text[i:i + 1])
      i += 1
      continue
    }
    let closing = i + 1 < n && text[i + 1] == '/'
    let name_start = if closing { i + 2 } else { i + 1 }
    if name_start >= n || !is_letter(text[name_start]) {
      // `<` before anything but a name is text; `</` before anything but
      // a name starts a comment, which is not handled here.
      if closing {
        raise unsupported()
      }
      out.write_string("&lt;")
      i += 1
      continue
    }
    let mut j = name_start
    while j < n && (is_letter(text[j]) || text[j] is ('0'..<='9')) {
      j += 1
    }
    let name = text[name_start:j].to_owned().to_lower()
    // Only `<name>`, `</name>` and `<br/>`, without attributes.
    let self_closing = !closing && j + 1 < n && text[j] == '/' && name == "br"
    if self_closing {
      j += 1
    }
    if j >= n || text[j] != '>' {
      raise unsupported()
    }
    i = j + 1
    if name == "br" {
      // An end tag `</br>` is parsed as a start tag.
      out.write_string("<br>")
    } else if !inline_tags.contains(name) {
      raise unsupported()
    } else if closing {
      // Misnested end tags are rearranged by the parser.
      if open.pop() != Some(name) {
        raise unsupported()
      }
      out.write_string("</\{name}>")
    } else {
      open.push(name)
      out.write_string("<\{name}>")
    }
  }
  // Elements still open at the end are closed, innermost first.
  while open.pop() is Some(name) {
    out.write_string("</\{name}>")
  }
  out.to_string()
}

///|
/// commonDb's `setAccTitle`: sanitized, without leading white space.
pub fn acc_title(text : String) -> String raise SanitizeError {
  let leading = try! @jsregex.Regex::compile("^\\s+")
  leading.replace(sanitize_text(text), _ => "")
}

///|
/// commonDb's `setAccDescription`: sanitized, with the indentation of
/// continuation lines removed.
pub fn acc_description(text : String) -> String raise SanitizeError {
  let indent = try! @jsregex.Regex::compile("\\n\\s+")
  indent.replace_all(sanitize_text(text), _ => "\n")
}
