///|
/// Whether the final sanitizing pass keeps a link with this address:
/// DOMPurify's `IS_ALLOWED_URI`, which it tests the value against once
/// white space is taken out of it. A few schemes are allowed by name;
/// anything else must not look like a scheme at all, that is, must not
/// start with letters, `+`, `.` or `-` followed by a colon.
fn allowed_uri(value : String) -> Bool {
  let chars = []
  for c in value {
    let code = c.to_int()
    let white = code <= 0x20 ||
      code == 0xa0 ||
      code == 0x1680 ||
      code == 0x180e ||
      (code >= 0x2000 && code <= 0x2029) ||
      code == 0x205f ||
      code == 0x3000
    if !white {
      chars.push(c.to_ascii_lowercase())
    }
  }
  let text = String::from_array(chars)
  for
    scheme in [
      "ftp:", "ftps:", "http:", "https:", "mailto:", "tel:", "callto:", "sms:", "cid:",
      "xmpp:", "matrix:",
    ] {
    if text.has_prefix(scheme) {
      return true
    }
  }
  guard chars is [first, ..] else { return false }
  if !(first is ('a'..<='z')) {
    return true
  }
  let mut end = 0
  while end < chars.length() && chars[end] is ('a'..<='z' | '+' | '.' | '-') {
    end += 1
  }
  end == chars.length() || chars[end] != ':'
}
