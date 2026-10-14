// mermaid's `sanitizeText`, as far as the port can follow the sanitizer.

///|
/// The tags the sanitizer keeps as they are when they carry no attribute.
/// Other markup it may rewrite or remove, and telling which takes its
/// whole allow-list.
fn is_plain_tag(name : String) -> Bool {
  name
  is ("br"
  | "b"
  | "i"
  | "u"
  | "s"
  | "em"
  | "strong"
  | "sub"
  | "sup"
  | "small"
  | "code"
  | "span")
}

///|
/// Whether every `<` in `text` either starts no tag or starts one of the
/// plain tags, without attributes.
fn only_plain_markup(text : String) -> Bool {
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n {
    guard chars[i] == '<' else {
      i += 1
      continue
    }
    let mut j = i + 1
    if j < n && chars[j] == '/' {
      j += 1
    }
    // Comments, declarations and processing instructions.
    if j < n && chars[j] is ('!' | '?') {
      return false
    }
    guard j < n && chars[j] is ('a'..<='z' | 'A'..<='Z') else {
      // A stray `</` is a comment to the parser; a stray `<` is text.
      if j > i + 1 {
        return false
      }
      i += 1
      continue
    }
    let start = j
    while j < n && chars[j] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9') {
      j += 1
    }
    guard is_plain_tag(String::from_array(chars[start:j]).to_lower()) else {
      return false
    }
    while j < n && chars[j] is (' ' | '\t' | '\n' | '/') {
      j += 1
    }
    guard j < n && chars[j] == '>' else { return false }
    i = j + 1
  }
  true
}

///|
/// mermaid's `sanitizeText`: text without a `<` comes back untouched;
/// anything else is parsed as HTML and serialized again, which the port
/// follows for plain formatting tags and for angle brackets that are not
/// tags.
fn sanitize_text(
  text : String,
  config : @config.Config,
  what : String,
) -> String raise Unsupported {
  guard text.contains("<") else { return text }
  // Any other level escapes the text instead of sanitizing it.
  guard config.text("securityLevel")
    is Some("strict" | "loose" | "antiscript" | "sandbox") else {
    raise Unsupported("C4: markup in \{what} with this securityLevel")
  }
  guard config.get("dompurifyConfig") is Null && only_plain_markup(text) else {
    raise Unsupported("C4: markup in \{what}: \{text}")
  }
  @dom.sanitized_text(text)
}
