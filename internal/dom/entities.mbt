///|
/// What the HTML parser makes of the numeric reference `&#code;`: the C1
/// controls a windows-1252 page would hold become those characters, and
/// NUL, surrogates and codes beyond Unicode become U+FFFD. `None` stands
/// for a code too large for an `Int`, which is beyond Unicode too.
fn numeric_reference(code : Int32?) -> String {
  guard code is Some(code) else { return "\u{fffd}" }
  if code == 0 || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF) {
    return "\u{fffd}"
  }
  let code = if code >= 0x80 && code <= 0x9F {
    windows_1252[code - 0x80]
  } else {
    code
  }
  Int32::unsafe_to_char(code).to_string()
}

///|
/// The characters of windows-1252 at 0x80 to 0x9F; the five it leaves
/// undefined stay as they are.
let windows_1252 : FixedArray[Int32] = [
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160,
  0x2039, 0x0152, 0x8D, 0x017D, 0x8F, 0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022,
  0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
]

///|
/// The value of a run of digits in `radix`, `None` once it exceeds
/// Unicode (the parser only needs to know it is too large).
fn reference_code(digits : StringView, radix : Int32) -> Int32? {
  let mut value = 0
  for c in digits {
    let digit = match c {
      '0'..<='9' => c.to_int() - '0'
      'a'..<='f' => c.to_int() - 'a' + 10
      'A'..<='F' => c.to_int() - 'A' + 10
      _ => return None
    }
    value = value * radix + digit
    if value > 0x10FFFF {
      return None
    }
  }
  Some(value)
}

///|
/// Undo mermaid's entity shielding. The diagram text had `#name;` and
/// `#123;` rewritten with placeholder characters so the grammars would not
/// trip over them; upstream turns the placeholders back into `&name;` and
/// `&#123;` in the serialized SVG, and the sanitizer's HTML parser resolves
/// those when it parses that markup again. Here the placeholders become
/// what that parser makes of them; `in_attribute` tells whether the text
/// is an attribute value.
fn decode_entities(text : String, in_attribute~ : Bool = false) -> String {
  if !text.contains("ﬂ°") {
    return text
  }
  let out = StringBuilder()
  let mut rest = text[:]
  while rest.find("ﬂ°") is Some(start) {
    out.write_view(rest[:start])
    let after = rest[start + 2:]
    guard after.find("¶ß") is Some(end) else {
      out.write_view(rest[start:])
      return out.to_string()
    }
    let body = after[:end]
    rest = after[end + 2:]
    if body.strip_prefix("°") is Some(digits) {
      // Numeric: `#9829;` (digits only, as mermaid's `/^\+?\d+$/` and
      // `\w` leave them).
      out.write_string(numeric_reference(reference_code(digits, 10)))
    } else {
      out.write_string(
        resolve_references("&" + body.to_owned() + ";", in_attribute~),
      )
    }
  }
  out.write_view(rest)
  out.to_string()
}
