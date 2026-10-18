// CSSOM's serialization of identifiers, strings and URLs.

///|
/// A code point as an escape: its hex value and a space.
fn escape_code_point(out : StringBuilder, c : Char) -> Unit {
  out.write_string("\\\{c.to_int().to_string(radix=16)} ")
}

///|
/// CSSOM's "serialize an identifier".
fn serialize_identifier(name : String) -> String {
  let out = StringBuilder()
  let chars = name.to_array()
  for i, c in chars {
    let code = c.to_int()
    if code == 0 {
      out.write_char('\u{fffd}')
    } else if (code >= 0x1 && code <= 0x1f) || code == 0x7f {
      escape_code_point(out, c)
    } else if (i == 0 && c is ('0'..<='9')) ||
      (i == 1 && c is ('0'..<='9') && chars[0] == '-') {
      escape_code_point(out, c)
    } else if i == 0 && c == '-' && chars.length() == 1 {
      out.write_string("\\-")
    } else if code >= 0x80 ||
      c is ('-' | '_' | '0'..<='9' | 'a'..<='z' | 'A'..<='Z') {
      out.write_char(c)
    } else {
      out.write_char('\\')
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// CSSOM's "serialize a string": double quotes, with quotes, backslashes
/// and control characters escaped.
fn serialize_string(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in text {
    let code = c.to_int()
    if code == 0 {
      out.write_char('\u{fffd}')
    } else if (code >= 0x1 && code <= 0x1f) || code == 0x7f {
      escape_code_point(out, c)
    } else if c is ('"' | '\\') {
      out.write_char('\\')
      out.write_char(c)
    } else {
      out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// CSSOM's "serialize a URL": `url(` and the URL as a string.
fn serialize_url(url : String) -> String {
  "url(\{serialize_string(url)})"
}
