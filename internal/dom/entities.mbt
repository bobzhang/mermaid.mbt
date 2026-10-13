///|
/// Named character references mermaid users reach for in labels
/// (`#quot;`, `#hearts;`, ...). The browser resolves the full HTML table;
/// names missing here are left as written.
let named_entities : Map[String, Int32] = {
  "quot": 0x22,
  "amp": 0x26,
  "apos": 0x27,
  "lt": 0x3c,
  "gt": 0x3e,
  "nbsp": 0xa0,
  "iexcl": 0xa1,
  "cent": 0xa2,
  "pound": 0xa3,
  "curren": 0xa4,
  "yen": 0xa5,
  "brvbar": 0xa6,
  "sect": 0xa7,
  "uml": 0xa8,
  "copy": 0xa9,
  "ordf": 0xaa,
  "laquo": 0xab,
  "not": 0xac,
  "shy": 0xad,
  "reg": 0xae,
  "macr": 0xaf,
  "deg": 0xb0,
  "plusmn": 0xb1,
  "sup2": 0xb2,
  "sup3": 0xb3,
  "acute": 0xb4,
  "micro": 0xb5,
  "para": 0xb6,
  "middot": 0xb7,
  "cedil": 0xb8,
  "sup1": 0xb9,
  "ordm": 0xba,
  "raquo": 0xbb,
  "frac14": 0xbc,
  "frac12": 0xbd,
  "frac34": 0xbe,
  "iquest": 0xbf,
  "times": 0xd7,
  "divide": 0xf7,
  "ndash": 0x2013,
  "mdash": 0x2014,
  "lsquo": 0x2018,
  "rsquo": 0x2019,
  "ldquo": 0x201c,
  "rdquo": 0x201d,
  "bull": 0x2022,
  "hellip": 0x2026,
  "prime": 0x2032,
  "Prime": 0x2033,
  "euro": 0x20ac,
  "trade": 0x2122,
  "larr": 0x2190,
  "uarr": 0x2191,
  "rarr": 0x2192,
  "darr": 0x2193,
  "harr": 0x2194,
  "lArr": 0x21d0,
  "rArr": 0x21d2,
  "hArr": 0x21d4,
  "forall": 0x2200,
  "part": 0x2202,
  "exist": 0x2203,
  "empty": 0x2205,
  "isin": 0x2208,
  "sum": 0x2211,
  "minus": 0x2212,
  "radic": 0x221a,
  "infin": 0x221e,
  "and": 0x2227,
  "or": 0x2228,
  "cap": 0x2229,
  "cup": 0x222a,
  "ne": 0x2260,
  "equiv": 0x2261,
  "le": 0x2264,
  "ge": 0x2265,
  "spades": 0x2660,
  "clubs": 0x2663,
  "hearts": 0x2665,
  "diams": 0x2666,
  "check": 0x2713,
  "equals": 0x3d,
  "num": 0x23,
  "colon": 0x3a,
  "semi": 0x3b,
  "lpar": 0x28,
  "rpar": 0x29,
  "lbrack": 0x5b,
  "rbrack": 0x5d,
  "lbrace": 0x7b,
  "rbrace": 0x7d,
  "verbar": 0x7c,
  "sol": 0x2f,
  "bsol": 0x5c,
  "percnt": 0x25,
  "commat": 0x40,
  "ast": 0x2a,
  "plus": 0x2b,
  "comma": 0x2c,
  "period": 0x2e,
  "excl": 0x21,
  "quest": 0x3f,
  "dollar": 0x24,
  "lowbar": 0x5f,
  "grave": 0x60,
  "Hat": 0x5e,
  "tilde": 0x2dc,
}

///|
/// Undo mermaid's entity shielding. The diagram text had `#name;` and
/// `#123;` rewritten with placeholder characters so the grammars would not
/// trip over them; upstream turns the placeholders back into `&name;` in
/// the serialized SVG and the browser resolves those when it re-parses.
/// Here the placeholders become the characters themselves.
fn decode_entities(text : String) -> String {
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
    let body = after[:end].to_owned()
    rest = after[end + 2:]
    if body.strip_prefix("°") is Some(digits) {
      // Numeric: `#9829;`
      let mut code = 0
      for c in digits {
        if c is ('0'..<='9') {
          code = code * 10 + (c.to_int() - '0')
        }
      }
      match Int32::to_char(code) {
        Some(c) if code != 0 => out.write_char(c)
        _ => out.write_char('\u{fffd}')
      }
    } else {
      match named_entities.get(body) {
        Some(code) => out.write_char(Int32::unsafe_to_char(code))
        None => out.write_string("&\{body};")
      }
    }
  }
  out.write_view(rest)
  out.to_string()
}
