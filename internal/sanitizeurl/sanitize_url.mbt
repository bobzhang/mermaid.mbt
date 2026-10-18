// `@braintree/sanitize-url` 7.1.2, which mermaid's `formatUrl` and the
// links of sequence popup menus go through outside the loose security
// level.

///|
/// A link address whose normalization by the browser's URL parser the port
/// does not reproduce: internationalized host names, credentials, IPv6 and
/// unusual IPv4 spellings.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// `String.prototype.trim`.
fn js_trim(text : StringView) -> String {
  text
  .trim(
    chars=" \t\n\u{0b}\u{0c}\r\u{a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}",
  )
  .to_owned()
}

///|
const BLANK_URL : String = "about:blank"

///|
/// `decodeURIComponent`, or the text itself where that would throw.
fn decode_uri(text : String) -> String {
  guard text.contains("%") else { return text }
  let chars = text.to_array()
  let out = StringBuilder()
  let hex = (c : Char) => {
    match c {
      '0'..<='9' => Some(c.to_int() - '0'.to_int())
      'a'..<='f' => Some(c.to_int() - 'a'.to_int() + 10)
      'A'..<='F' => Some(c.to_int() - 'A'.to_int() + 10)
      _ => None
    }
  }
  // The byte a `%XX` escape at `i` stands for.
  let byte_at = (i : Int32) => {
    guard i + 2 < chars.length() && chars[i] == '%' else { return None }
    match (hex(chars[i + 1]), hex(chars[i + 2])) {
      (Some(high), Some(low)) => Some(high * 16 + low)
      _ => None
    }
  }
  let mut i = 0
  while i < chars.length() {
    if chars[i] != '%' {
      out.write_char(chars[i])
      i += 1
      continue
    }
    guard byte_at(i) is Some(first) else { return text }
    // One UTF-8 sequence: the lead byte tells its length.
    let (length, lead, least) = if first < 0x80 {
      (1, first, 0)
    } else if first >= 0xC2 && first < 0xE0 {
      (2, first & 0x1F, 0x80)
    } else if first >= 0xE0 && first < 0xF0 {
      (3, first & 0x0F, 0x800)
    } else if first >= 0xF0 && first < 0xF5 {
      (4, first & 0x07, 0x10000)
    } else {
      return text
    }
    let mut code = lead
    for k = 1; k < length; k = k + 1 {
      guard byte_at(i + 3 * k) is Some(next) && (next & 0xC0) == 0x80 else {
        return text
      }
      code = code * 64 + (next & 0x3F)
    }
    guard code >= least &&
      code <= 0x10FFFF &&
      !(code >= 0xD800 && code <= 0xDFFF) else {
      return text
    }
    out.write_char(Int32::unsafe_to_char(code))
    i += 3 * length
  }
  out.to_string()
}

///|
/// The characters a URL component is percent-encoded for, on top of
/// controls and everything outside ASCII.
fn percent_encode(text : StringView, reserved : String) -> String {
  let out = StringBuilder()
  let digits = "0123456789ABCDEF"
  let byte = (value : Int32) => {
    out.write_char('%')
    out.write_char(digits.get_char(value / 16).unwrap_or('0'))
    out.write_char(digits.get_char(value % 16).unwrap_or('0'))
  }
  for c in text {
    let code = c.to_int()
    if code > 0x20 && code < 0x7F && !reserved.contains_char(c) {
      out.write_char(c)
    } else if code < 0x80 {
      byte(code)
    } else if code < 0x800 {
      byte(0xC0 | (code >> 6))
      byte(0x80 | (code & 0x3F))
    } else if code < 0x10000 {
      byte(0xE0 | (code >> 12))
      byte(0x80 | ((code >> 6) & 0x3F))
      byte(0x80 | (code & 0x3F))
    } else {
      byte(0xF0 | (code >> 18))
      byte(0x80 | ((code >> 12) & 0x3F))
      byte(0x80 | ((code >> 6) & 0x3F))
      byte(0x80 | (code & 0x3F))
    }
  }
  out.to_string()
}

///|
/// `new URL(url).toString()` for an `http:` or `https:` address without a
/// port or credentials, which is all that reaches here: the address has
/// exactly one colon. `None` when the browser cannot parse it.
fn normalize_http_url(url : String) -> String? raise Unsupported {
  guard url.find(":") is Some(colon) else { return None }
  let scheme = url[:colon].to_owned().to_lower()
  let mut rest = url[colon + 1:]
  // Any number of slashes introduces the host.
  while rest.strip_prefix("/") is Some(tail) {
    rest = tail
  }
  let cut = (text : StringView, marks : String) => {
    for i, c in text {
      if marks.contains_char(c) {
        return i
      }
    }
    text.length()
  }
  let host_end = cut(rest, "/?#")
  let host = decode_uri(rest[:host_end].to_owned()).to_lower()
  let after_host = rest[host_end:]
  if host == "" {
    return None
  }
  for c in host {
    if c.to_int() >= 0x80 || c == '@' || c == '[' {
      // Internationalized names, credentials and IPv6 literals.
      raise Unsupported("link address: \{url}")
    }
    if c.to_int() <= 0x20 || " #/<>?\\]^|%".contains_char(c) {
      return None
    }
  }
  // A host ending in a number is an IPv4 address, in any of its spellings.
  let labels = host.split(".").map(label => label.to_owned()).collect()
  let last = match labels.last() {
    Some("") if labels.length() > 1 => labels[labels.length() - 2]
    Some(label) => label
    None => ""
  }
  let is_decimal = (label : String) => {
    label != "" && label.iter().all(c => c is ('0'..<='9'))
  }
  if is_decimal(last) || last.has_prefix("0x") {
    let plain = labels.length() == 4 &&
      labels
      .iter()
      .all(label => {
        is_decimal(label) &&
        (label == "0" || !label.has_prefix("0")) &&
        label.length() <= 3 &&
        (@string.parse_double(label) catch { _ => 256.0 }) < 256.0
      })
    guard plain else { raise Unsupported("link address: \{url}") }
  }
  let path_end = cut(after_host, "?#")
  let segments : Array[String] = []
  let raw_segments = after_host[:path_end].split("/").collect()
  for index, segment in raw_segments {
    // The path starts with a slash, so the first piece is empty.
    if index == 0 {
      continue
    }
    let is_last = index == raw_segments.length() - 1
    match segment.to_owned().to_lower() {
      ".." | ".%2e" | "%2e." | "%2e%2e" => {
        ignore(segments.pop())
        if is_last {
          segments.push("")
        }
      }
      "." | "%2e" => if is_last { segments.push("") }
      _ => segments.push(percent_encode(segment, "\"#<>?`{}|^"))
    }
  }
  let out = StringBuilder()
  out.write_string(scheme)
  out.write_string("://")
  out.write_string(host)
  out.write_string("/")
  out.write_string(segments.join("/"))
  let after_path = after_host[path_end:]
  let query_end = cut(after_path, "#")
  if query_end > 0 {
    out.write_string("?")
    out.write_string(percent_encode(after_path[1:query_end], "\"#<>'"))
  }
  let fragment = after_path[query_end:]
  if fragment.length() > 0 {
    out.write_string("#")
    out.write_string(percent_encode(fragment[1:], "\"<>`"))
  }
  Some(out.to_string())
}

///|
/// What `sanitizeUrl` makes of a link: encodings that could hide a scheme
/// are undone, scripting schemes are replaced by a blank page, and a plain
/// web address comes back as the browser's URL parser spells it.
pub fn sanitize_url(url : String) -> String raise Unsupported {
  if url == "" {
    return BLANK_URL
  }
  let control = try! @jsregex.Regex::compile(
    "[\\u0000-\\u001F\\u007F-\\u009F\\u2000-\\u200D\\uFEFF]",
    flags="gim",
  )
  let entity = try! @jsregex.Regex::compile("&#(\\w+)(^\\w|;)?", flags="g")
  let control_entity = try! @jsregex.Regex::compile(
    "&(newline|tab);",
    flags="gi",
  )
  let escaped_space = try! @jsregex.Regex::compile(
    "(\\\\|%5[cC])((%(6[eE]|72|74))|[nrt])",
    flags="g",
  )
  let mut decoded = decode_uri(js_trim(url))
  while true {
    decoded = control.replace_all(decoded, _ => "")
    decoded = entity.replace_all(decoded, found => {
      // `String.fromCharCode` of the reference, read as a number.
      let digits = found.group(1).unwrap_or("")
      let code = @string.parse_double(digits) catch { _ => 0.0 }
      let unit = code.to_int() % 65536
      if digits.iter().all(c => c is ('0'..<='9')) &&
        !(unit >= 0xD800 && unit <= 0xDFFF) {
        Int32::unsafe_to_char(unit).to_string()
      } else {
        "\u{0}"
      }
    })
    decoded = control_entity.replace_all(decoded, _ => "")
    decoded = control.replace_all(decoded, _ => "")
    decoded = escaped_space.replace_all(decoded, _ => "")
    decoded = decode_uri(js_trim(decoded))
    if !(control.exec(decoded) is Some(_) ||
      entity.exec(decoded) is Some(_) ||
      control_entity.exec(decoded) is Some(_) ||
      escaped_space.exec(decoded) is Some(_)) {
      break
    }
  }
  if decoded == "" {
    return BLANK_URL
  }
  if decoded.has_prefix(".") || decoded.has_prefix("/") {
    return decoded
  }
  // The scheme is everything up to the last colon of the first line.
  let scheme_pattern = try! @jsregex.Regex::compile(
    "^.+(:|&colon;)",
    flags="im",
  )
  guard scheme_pattern.exec(decoded) is Some(found) else { return decoded }
  let scheme = js_trim(found.text().to_lower())
  let scripting = try! @jsregex.Regex::compile(
    "^([^\\w]*)(javascript|data|vbscript)",
    flags="im",
  )
  if scripting.exec(scheme) is Some(_) {
    return BLANK_URL
  }
  let back_sanitized = decoded.replace_all(old="\\", new="/")
  if scheme == "mailto:" || scheme.contains("://") {
    return back_sanitized
  }
  if scheme == "http:" || scheme == "https:" {
    return normalize_http_url(back_sanitized).unwrap_or(BLANK_URL)
  }
  back_sanitized
}
