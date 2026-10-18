// `data:` URLs, read as the URL parser and the fetch standard's data: URL
// processor read them: the type before the comma, the body
// percent-decoded and, with `;base64`, decoded by forgiving-base64.

///|
fn is_ascii_whitespace(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\r' | '\u{0c}')
}

///|
/// The natural size of the image in a `data:` URL; `None` when `url` is
/// not one. A malformed URL fails to load, which `decode()` reports as an
/// undecodable image.
pub fn data_url_size(url : String) -> Decoded? {
  // The URL parser drops leading and trailing C0 controls and spaces,
  // and tabs and newlines everywhere.
  let cleaned = StringBuilder()
  for
    c in url.trim(
      chars=" \u{00}\u{01}\u{02}\u{03}\u{04}\u{05}\u{06}\u{07}\u{08}\t\n\u{0b}\u{0c}\r\u{0e}\u{0f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}",
    ) {
    if !(c is ('\t' | '\n' | '\r')) {
      cleaned.write_char(c)
    }
  }
  let url = cleaned.to_string()
  guard url.length() >= 5 && url[:5].to_lower() == "data:" else { return None }
  // A fragment is no part of the data.
  let rest = match url[5:].find("#") {
    Some(at) => url[5:5 + at]
    None => url[5:]
  }
  guard rest.find(",") is Some(comma) else { return Some(Undecodable) }
  let mut mime = rest[:comma].to_owned().trim(chars=" \t\n\r\u{0c}").to_owned()
  let body = percent_decode(rest[comma + 1:].to_owned())
  // `;base64` ends the type, possibly after spaces.
  let base64 = {
    let trimmed = mime.trim_end(chars=" ")
    trimmed.length() >= 6 &&
    trimmed[trimmed.length() - 6:].to_lower() == "base64" &&
    trimmed[:trimmed.length() - 6].trim_end(chars=" ").has_suffix(";")
  }
  let data = if base64 {
    let trimmed = mime.trim_end(chars=" ")
    let before = trimmed[:trimmed.length() - 6].trim_end(chars=" ")
    mime = before[:before.length() - 1].to_owned()
    match forgiving_base64(body) {
      Some(data) => data
      None => return Some(Undecodable)
    }
  } else {
    body
  }
  Some(natural_size(data, mime=mime_essence(mime)))
}

///|
/// The type and subtype of a MIME type, in lower case.
fn mime_essence(mime : String) -> String {
  let essence = match mime.find(";") {
    Some(at) => mime[:at]
    None => mime[:]
  }
  essence.trim(chars=" \t\n\r\u{0c}").to_lower().to_owned()
}

///|
/// The bytes of the UTF-8 encoding of `text` with `%XX` escapes decoded.
fn percent_decode(text : String) -> Bytes {
  let utf8 = @utf8.encode(text)
  let out = []
  let hex = (b : Byte) => {
    match b {
      b'0'..<=b'9' => Some(b.to_int() - 0x30)
      b'a'..<=b'f' => Some(b.to_int() - 0x61 + 10)
      b'A'..<=b'F' => Some(b.to_int() - 0x41 + 10)
      _ => None
    }
  }
  let mut i = 0
  while i < utf8.length() {
    if utf8[i] == b'%' &&
      i + 2 < utf8.length() &&
      hex(utf8[i + 1]) is Some(high) &&
      hex(utf8[i + 2]) is Some(low) {
      out.push((high * 16 + low).to_byte())
      i += 3
    } else {
      out.push(utf8[i])
      i += 1
    }
  }
  Bytes::from_array(out)
}

///|
/// The infra standard's forgiving-base64 decode: whitespace ignored, the
/// padding optional, anything else outside the alphabet a failure.
fn forgiving_base64(data : Bytes) -> Bytes? {
  let digits = []
  for b in data {
    if !is_ascii_whitespace(b.to_char()) {
      digits.push(b)
    }
  }
  let mut length = digits.length()
  if length % 4 == 0 && length > 0 && digits[length - 1] == b'=' {
    length -= 1
    if digits[length - 1] == b'=' {
      length -= 1
    }
  }
  guard length % 4 != 1 else { return None }
  let out = []
  let mut buffer = 0
  let mut bits = 0
  for i in 0..<length {
    let b = digits[i]
    let value = match b {
      b'A'..<=b'Z' => b.to_int() - 0x41
      b'a'..<=b'z' => b.to_int() - 0x61 + 26
      b'0'..<=b'9' => b.to_int() - 0x30 + 52
      b'+' => 62
      b'/' => 63
      _ => return None
    }
    buffer = ((buffer << 6) | value) & 0xffffff
    bits += 6
    if bits >= 8 {
      bits -= 8
      out.push(((buffer >> bits) & 0xff).to_byte())
    }
  }
  Some(Bytes::from_array(out))
}
