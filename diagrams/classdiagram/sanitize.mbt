///|
/// What goes wrong while a class diagram is read or drawn.
pub(all) suberror ClassError {
  /// The source is not a class diagram upstream accepts.
  Invalid(String)
  /// Upstream accepts it; the port cannot reproduce what it makes of it.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// Elements that come out of the sanitizer as they went in, as long as
/// they carry no attributes: plain inline formatting.
let formatting_elements : Array[String] = [
  "b", "i", "u", "s", "em", "strong", "small", "sub", "sup", "code", "mark", "del",
  "ins",
]

///|
/// Every other element name the HTML parser or DOMPurify knows: the tags
/// DOMPurify allows or removes by name, and those the parser treats in a
/// way of its own. What becomes of these is not modelled.
let known_elements : Array[String] = [
  "a", "abbr", "acronym", "address", "area", "article", "aside", "audio", "bdi",
  "bdo", "big", "blink", "blockquote", "body", "button", "canvas", "caption", "center",
  "cite", "col", "colgroup", "content", "data", "datalist", "dd", "decorator", "details",
  "dfn", "dialog", "dir", "div", "dl", "dt", "element", "fieldset", "figcaption",
  "figure", "font", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "head",
  "header", "hgroup", "hr", "html", "img", "input", "kbd", "label", "legend", "li",
  "main", "map", "marquee", "menu", "menuitem", "meter", "nav", "nobr", "ol", "optgroup",
  "option", "output", "p", "picture", "pre", "progress", "q", "rp", "rt", "ruby",
  "samp", "search", "section", "select", "shadow", "slot", "source", "spacer", "span",
  "strike", "style", "summary", "table", "tbody", "td", "template", "textarea", "tfoot",
  "th", "thead", "time", "tr", "track", "tt", "ul", "var", "video", "wbr",
  // SVG
   "svg", "altglyph", "altglyphdef", "altglyphitem", "animatecolor", "animatemotion",
  "animatetransform", "circle", "clippath", "defs", "desc", "ellipse", "enterkeyhint",
  "exportparts", "filter", "g", "glyph", "glyphref", "hkern", "image", "inputmode",
  "line", "lineargradient", "marker", "mask", "metadata", "mpath", "part", "path",
  "pattern", "polygon", "polyline", "radialgradient", "rect", "stop", "switch", "symbol",
  "text", "textpath", "title", "tref", "tspan", "view", "vkern", "animate", "color-profile",
  "cursor", "discard", "font-face", "font-face-format", "font-face-name", "font-face-src",
  "font-face-uri", "foreignobject", "hatch", "hatchpath", "mesh", "meshgradient",
  "meshpatch", "meshrow", "missing-glyph", "script", "set", "solidcolor", "unknown",
  "use",
  // MathML
   "math", "menclose", "merror", "mfenced", "mfrac", "mglyph", "mi", "mlabeledtr",
  "mmultiscripts", "mn", "mo", "mover", "mpadded", "mphantom", "mroot", "mrow", "ms",
  "mspace", "msqrt", "mstyle", "msub", "msup", "msubsup", "mtable", "mtd", "mtext",
  "mtr", "munder", "munderover", "mprescripts", "maction", "maligngroup", "malignmark",
  "mlongdiv", "mscarries", "mscarry", "msgroup", "mstack", "msline", "msrow", "semantics",
  "annotation", "annotation-xml", "none",
  // Parsed in a way of their own
   "base", "basefont", "bgsound", "link", "meta", "noembed", "noframes", "noscript",
  "plaintext", "xmp", "iframe", "frame", "frameset", "object", "embed", "param",
  "applet", "listing", "image", "isindex", "keygen", "nextid", "rb", "rtc",
]

///|
/// Character data as the HTML serializer writes it once the parser has
/// read it: character references are resolved, and `&`, `<`, `>` and the
/// no-break space are written as references.
fn reserialized_text(text : String) -> String raise ClassError {
  let out = StringBuilder()
  let escape = (piece : StringView) => {
    for c in piece {
      match c {
        '<' => out.write_string("&lt;")
        '>' => out.write_string("&gt;")
        '\u{a0}' => out.write_string("&nbsp;")
        _ => out.write_char(c)
      }
    }
  }
  let mut rest = text[:]
  while rest.find("&") is Some(at) {
    escape(rest[:at])
    let after = rest[at + 1:]
    // A reference ends at its semicolon; the sanitizer resolves it and
    // writes the three characters above as references again.
    let mut length = 0
    while length < after.length() &&
          after[length] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '#') {
      length += 1
    }
    if length == 0 {
      out.write_string("&amp;")
      rest = after
      continue
    }
    guard length < after.length() && after[length] == ';' else {
      // The parser knows some names without their semicolon.
      raise Unsupported("class diagram text with markup: \{text}")
    }
    let reference = "&" + after[:length + 1].to_owned()
    let resolved = @dom.sanitized_text(reference)
    if resolved == reference && !(reference is ("&amp;" | "&lt;" | "&gt;")) {
      // Not a reference this port knows; the parser knows many more.
      raise Unsupported("class diagram text with markup: \{text}")
    }
    escape(resolved[:])
    rest = after[length + 1:]
  }
  escape(rest)
  out.to_string()
}

///|
/// The end of a tag whose name ends at `from`: the index after its `>`,
/// reading attributes as the HTML tokenizer does, so that a `>` inside a
/// quoted value does not end the tag. Nothing when the text ends first.
fn tag_end(chars : Array[Char], from : Int32) -> Int32? {
  let n = chars.length()
  let space = (c : Char) => c is (' ' | '\t' | '\n' | '\r' | '\u{c}')
  let mut i = from
  while i < n {
    let c = chars[i]
    if c == '>' {
      return Some(i + 1)
    }
    if space(c) || c == '/' {
      i += 1
      continue
    }
    // An attribute name, then possibly a value.
    i += 1
    while i < n && !(space(chars[i]) || chars[i] is ('/' | '>' | '=')) {
      i += 1
    }
    while i < n && space(chars[i]) {
      i += 1
    }
    if i < n && chars[i] == '=' {
      i += 1
      while i < n && space(chars[i]) {
        i += 1
      }
      if i < n && chars[i] is ('"' | '\'' as quote) {
        i += 1
        while i < n && chars[i] != quote {
          i += 1
        }
        i += 1
      } else {
        while i < n && !(space(chars[i]) || chars[i] == '>') {
          i += 1
        }
      }
    }
  }
  None
}

///|
/// mermaid's `sanitizeText`. Text without a `<` comes back from DOMPurify
/// as it went in. Anything else is parsed as HTML there and serialized
/// again: elements it does not know are dropped and their content kept,
/// which is what becomes of a type written as `List<int>`, and character
/// data is escaped.
///
/// Only the outcomes that are certain are produced: unknown elements,
/// line breaks and plain inline formatting. Anything else is refused.
fn sanitize_text(text : String) -> String raise ClassError {
  if !text.contains("<") {
    return text
  }
  let unsupported = Unsupported("class diagram text with markup: \{text}")
  let chars = text.to_array()
  let n = chars.length()
  let out = StringBuilder()
  let pending = StringBuilder()
  let flush = () => {
    if !pending.is_empty() {
      out.write_string(reserialized_text(pending.to_string()))
      pending.reset()
    }
  }
  let letter = (c : Char) => c is ('a'..<='z' | 'A'..<='Z')
  let open : Array[String] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    let next = if i + 1 < n { chars[i + 1] } else { ' ' }
    guard c == '<' && (letter(next) || next is ('/' | '!' | '?')) else {
      pending.write_char(c)
      i += 1
      continue
    }
    let closing = next == '/'
    let start = if closing { i + 2 } else { i + 1 }
    // `</>` is dropped; any other tag needs a name, and comments are not
    // modelled.
    if closing && start < n && chars[start] == '>' {
      i = start + 1
      continue
    }
    guard start < n && letter(chars[start]) else { raise unsupported }
    let mut name_end = start
    while name_end < n &&
          !(chars[name_end] is (' ' | '\t' | '\n' | '\r' | '\u{c}' | '/' | '>')) {
      name_end += 1
    }
    let name = String::from_array(chars[start:name_end]).to_lower()
    guard name.iter().all(c => c.to_int() < 0x80) else { raise unsupported }
    // A tag the text ends in is dropped with everything in it.
    guard tag_end(chars, name_end) is Some(end) else { break }
    // Without attributes: nothing but white space and slashes after the
    // name.
    let bare = chars[name_end:end - 1]
      .iter()
      .all(c => c is (' ' | '\t' | '\n' | '\r' | '\u{c}' | '/'))
    i = end
    if name == "br" {
      guard bare else { raise unsupported }
      flush()
      out.write_string("<br>")
    } else if formatting_elements.contains(name) {
      guard bare else { raise unsupported }
      flush()
      if closing {
        guard open.last() == Some(name) else { raise unsupported }
        open.pop() |> ignore
        out.write_string("</\{name}>")
      } else {
        open.push(name)
        out.write_string("<\{name}>")
      }
    } else if known_elements.contains(name) {
      raise unsupported
    }
    // Any other element is unknown to the sanitizer, which removes it and
    // keeps what is inside.
  }
  flush()
  // Elements still open are closed where the text ends.
  for name in open.rev() {
    out.write_string("</\{name}>")
  }
  out.to_string()
}

///|
/// mermaid's `formatUrl`: outside the loose security level a link is
/// sanitized; a `javascript:` URL becomes `about:blank`.
fn format_url(link : String, config : @config.Config) -> String {
  let url = js_trim(link)
  if url == "" {
    return url
  }
  if config.text("securityLevel") is Some("loose") {
    return url
  }
  // Like @braintree/sanitize-url: script-capable schemes are refused.
  let stripped = try! @jsregex.Regex::compile("[\\u0000-\\u0020]")
  let compact = stripped.replace_all(url.to_lower(), _ => "")
  for scheme in ["javascript:", "data:", "vbscript:"] {
    if compact.has_prefix(scheme) {
      return "about:blank"
    }
  }
  // The URL comes back normalized: a bare origin gains its root path.
  let origin = try! @jsregex.Regex::compile("^https?://[^/?#]+$", flags="i")
  if origin.matches(url) {
    url + "/"
  } else {
    url
  }
}
