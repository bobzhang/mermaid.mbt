// What the sanitizer mermaid runs its output through (DOMPurify) does to
// attribute values. Whoever sets an attribute from the diagram's text asks
// here whether the attribute survives.

///|
let clobbering_set : Map[String, Unit] = {
  let set : Map[String, Unit] = Map([])
  for name in clobbering_names {
    set[name] = ()
  }
  set
}

///|
/// Whether an `id` or `name` attribute with this value is removed: the
/// sanitizer drops those that name a property of `document` or of a form
/// element, such as `title`, `links` or `children`.
pub fn is_clobbering_name(value : String) -> Bool {
  clobbering_set.contains(value)
}

///|
/// Whether a value passes for an attribute that may hold an address
/// (everything but `class`, `id`, `name`, `style`, `title` and a few
/// more, and `data-*`): it must not look like a URI with a scheme other
/// than the well-known ones. An `xlink:href` of `about:blank` is removed
/// by this, and so would be a `fill` of `my:color`.
pub fn is_allowed_uri(value : String) -> Bool {
  // White space does not count, wherever it is.
  let compact = StringBuilder()
  for c in value {
    let code = c.to_int()
    let is_space = code <= 0x20 ||
      code == 0xA0 ||
      code == 0x1680 ||
      code == 0x180E ||
      (code >= 0x2000 && code <= 0x2029) ||
      code == 0x205F ||
      code == 0x3000
    if !is_space {
      compact.write_char(c)
    }
  }
  let text = compact.to_string().to_lower()
  if text == "" {
    return value == ""
  }
  let is_scheme_char = (c : Char) => c is ('a'..<='z' | '+' | '.' | '-')
  // A leading run of scheme characters followed by a colon is a scheme.
  let mut end = 0
  for c in text {
    guard is_scheme_char(c) else { break }
    end += 1
  }
  guard text[0:1] is ['a'..<='z', ..] else { return true }
  guard end < text.length() && text[end:end + 1] is [':', ..] else {
    return true
  }
  text[:end].to_owned()
  is ("ftp"
  | "ftps"
  | "http"
  | "https"
  | "mailto"
  | "tel"
  | "callto"
  | "sms"
  | "cid"
  | "xmpp"
  | "matrix")
}
