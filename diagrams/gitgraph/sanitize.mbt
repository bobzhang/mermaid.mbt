///|
/// What the port cannot reproduce exactly and therefore refuses.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// mermaid's `lineBreakRegex`.
let line_break : @jsregex.Regex = try! @jsregex.Regex::compile(
  "</?br\\s*/?>",
  flags="gi",
)

///|
/// mermaid's `sanitizeText` as the git graph database calls it, with its
/// own configuration section: that section has no `securityLevel`, so
/// angle brackets and equal signs are always written as entities, and the
/// result goes through DOMPurify.
///
/// DOMPurify returns text without a `<` untouched, which leaves those
/// entities in place: an id `a=b` really is displayed as `a&equals;b`
/// upstream. Only a line break (`<br>`, or mermaid's own `#br#`
/// placeholder) sends the text through the HTML parser, which resolves
/// character references and serializes the tree again.
fn sanitize_text(text : String, html_labels : Bool) -> String raise Unsupported {
  if text == "" {
    return text
  }
  if !html_labels {
    // Nothing is escaped, so any tag reaches the HTML parser as markup.
    if text.contains("<") {
      raise Unsupported(
        "git graph text with markup and htmlLabels off: \{text}",
      )
    }
    return text
  }
  let marked = line_break.replace_all(text, _ => "#br#")
  if !marked.contains("#br#") {
    return text
      .replace_all(old="<", new="&lt;")
      .replace_all(old=">", new="&gt;")
      .replace_all(old="=", new="&equals;")
  }
  // The pieces between the breaks are text for the HTML parser.
  let pieces = []
  for piece in marked.split("#br#") {
    pieces.push(reserialize(piece.to_owned()))
  }
  pieces.join("<br>")
}

///|
/// The character references the sanitizer itself writes, and what the
/// HTML serializer makes of the characters they stand for.
let known_references : Array[(String, String)] = [
  ("&amp;", "&amp;"),
  ("&lt;", "&lt;"),
  ("&gt;", "&gt;"),
  ("&nbsp;", "&nbsp;"),
  ("&equals;", "="),
]

///|
/// Text as it comes back from the HTML parser and serializer: character
/// references are resolved, and `&`, `<`, `>` and the no-break space are
/// written as references. Only the references in `known_references` are
/// resolved here; any other candidate is refused, since the parser
/// matches against the whole table of names.
fn reserialize(text : String) -> String raise Unsupported {
  let out = StringBuilder()
  let mut rest = text[:]
  while !rest.is_empty() {
    guard rest.find("&") is Some(at) else { break }
    out.write_string(escape_text(rest[:at].to_owned()))
    rest = rest[at:]
    let mut resolved = false
    for reference in known_references {
      if rest.has_prefix(reference.0) {
        out.write_string(reference.1)
        rest = rest[reference.0.length():]
        resolved = true
        break
      }
    }
    if resolved {
      continue
    }
    if rest.length() > 1 &&
      rest[1] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '#') {
      raise Unsupported(
        "git graph text with a line break and a character reference: \{text}",
      )
    }
    out.write_string("&amp;")
    rest = rest[1:]
  }
  out.write_string(escape_text(rest.to_owned()))
  out.to_string()
}

///|
/// Text without ampersands, as the HTML serializer writes it.
fn escape_text(text : String) -> String {
  text
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\u{a0}", new="&nbsp;")
}

///|
/// The elements a title may be marked up with and still come out of the
/// sanitizer as written.
let formatting_elements : Array[String] = [
  "b", "i", "u", "s", "em", "strong", "small", "sub", "sup", "code", "span",
]

///|
/// mermaid's `sanitizeText` as the title and the accessibility texts get
/// it, under the default configuration. Text without a `<` is returned
/// as it is. Anything else is parsed as HTML and serialized again, which
/// writes `&`, `<` and `>` as entities: a title `a < b` is displayed as
/// `a &lt; b` upstream.
///
/// Only what is certain to survive that round trip is accepted: plain
/// text, and balanced formatting elements without attributes.
fn sanitize_common(text : String) -> String raise Unsupported {
  if !text.contains("<") {
    return text
  }
  let unsupported = Unsupported("markup in a title or description: \{text}")
  let chars = text.to_array()
  let n = chars.length()
  let out = StringBuilder()
  let open : Array[String] = []
  let is_letter = (c : Char) => c is ('a'..<='z' | 'A'..<='Z')
  let mut i = 0
  while i < n {
    let c = chars[i]
    let next = if i + 1 < n { chars[i + 1] } else { ' ' }
    match c {
      '&' => {
        // What follows could be a character reference.
        if next is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '#') {
          raise unsupported
        }
        out.write_string("&amp;")
        i += 1
      }
      '>' => {
        out.write_string("&gt;")
        i += 1
      }
      '\u{a0}' => {
        out.write_string("&nbsp;")
        i += 1
      }
      '<' => {
        let closing = next == '/'
        let start = if closing { i + 2 } else { i + 1 }
        let mut end = start
        while end < n && is_letter(chars[end]) {
          end += 1
        }
        if end == start {
          // Not a tag: `<` before anything but a letter is text, except
          // where it starts a comment or a declaration.
          if closing || next is ('!' | '?') {
            raise unsupported
          }
          out.write_string("&lt;")
          i += 1
          continue
        }
        let name = String::from_array(chars[start:end])
        if end >= n || chars[end] != '>' || !formatting_elements.contains(name) {
          raise unsupported
        }
        if closing {
          if open.pop() != Some(name) {
            raise unsupported
          }
          out.write_string("</\{name}>")
        } else {
          open.push(name)
          out.write_string("<\{name}>")
        }
        i = end + 1
      }
      '\r' | '\u{0}' => raise unsupported
      _ => {
        out.write_char(c)
        i += 1
      }
    }
  }
  if !open.is_empty() {
    raise unsupported
  }
  out.to_string()
}
