///|
/// What may stand among the children of an element, for Blink's fast-path
/// fragment parser (`html_document_parser_fastpath.cc`).
priv enum FastChildren {
  /// Flow content: every supported element but `<option>`.
  Flow
  /// Phrasing content: no `<div>`, `<p>`, `<li>`, lists or `<footer>`.
  Phrasing
  /// `<a>` in flow content, which takes flow content but no `<a>`.
  AnchorFlow
  /// `<a>` in phrasing content.
  AnchorPhrasing
  /// `<li>`: flow content, but no `<li>` that is not in a list of its own.
  ListItem
  /// `<ol>` and `<ul>`: only `<li>`.
  OnlyListItems
  /// `<select>`: only `<option>`.
  OnlyOptions
  /// `<option>`: text only.
  TextOnly
}

///|
/// A spelling the fast path decodes differently from the HTML parser's
/// specification, which the full parser follows: `start` to `end` of the
/// input is better written `replacement`.
priv struct FastPathEdit {
  start : Int32
  end : Int32
  replacement : String
}

///|
/// Chrome parses `innerHTML` and `DOMParser` input with a fast path first,
/// and only when that gives up with the full HTML parser. The fast path
/// takes few elements and well-formed markup only, and builds the same
/// tree the full parser would, with two differences in character
/// references: in attribute values it decodes them as in text (`&copy=1`
/// is `©=1`, where the full parser keeps it), and `&#x;` is U+FFFD.
/// This replays its decisions without building anything.
priv struct FastPath {
  html : String
  mut pos : Int32
  mut failed : Bool
  mut inside_a : Bool
  mut inside_li : Bool
  mut depth : Int32
  edits : Array[FastPathEdit]
}

///|
/// Whether Chrome's fast path parses `html` into an element named
/// `context`, and where its character references come out differently
/// from the full parser's.
fn fast_path(html : String, context : String) -> Array[FastPathEdit]? {
  let parser : FastPath = {
    html,
    pos: 0,
    failed: false,
    inside_a: false,
    inside_li: false,
    depth: 0,
    edits: [],
  }
  let children : FastChildren? = match context {
    // A document parsed by `DOMParser` is parsed into its body; that
    // leading white space is dropped makes no difference to what it takes.
    "body" | "div" | "footer" => Some(Flow)
    "b" | "button" | "i" | "label" | "p" | "span" | "strong" => Some(Phrasing)
    "a" => Some(AnchorFlow)
    "li" => Some(ListItem)
    "ol" | "ul" => Some(OnlyListItems)
    "select" => Some(OnlyOptions)
    "option" => Some(TextOnly)
    _ => None
  }
  guard children is Some(children) else { return None }
  parser.children(children)
  if parser.pos != html.length() {
    parser.failed = true
  }
  if parser.failed {
    None
  } else {
    Some(parser.edits)
  }
}

///|
fn FastPath::at_end(self : FastPath) -> Bool {
  self.pos >= self.html.length()
}

///|
/// `GetNext()`: the current code unit; at the end the parse fails and
/// this is NUL.
fn FastPath::next(self : FastPath) -> UInt16 {
  if self.at_end() {
    self.failed = true
    return 0
  }
  self.html[self.pos]
}

///|
/// `ConsumeNext()`.
fn FastPath::consume(self : FastPath) -> UInt16 {
  if self.at_end() {
    self.failed = true
    return 0
  }
  let c = self.html[self.pos]
  self.pos += 1
  c
}

///|
fn fast_whitespace(c : UInt16) -> Bool {
  c is (' ' | '\t' | '\n' | '\r' | '\u{c}')
}

///|
fn FastPath::skip_whitespace(self : FastPath) -> Unit {
  while !self.at_end() && fast_whitespace(self.html[self.pos]) {
    self.pos += 1
  }
}

///|
/// `ParseChildren`: text and elements up to the `<` of an end tag or the
/// end of the input.
fn FastPath::children(self : FastPath, kind : FastChildren) -> Unit {
  while true {
    self.text()
    if self.failed || self.at_end() {
      return
    }
    // At a `<`.
    self.pos += 1
    if self.next() == '/' {
      return
    }
    self.depth += 1
    // HTMLConstructionSite::kMaximumHTMLParserDOMTreeDepth
    if self.depth == 512 {
      self.failed = true
      return
    }
    match kind {
      Flow => self.element(true)
      Phrasing => self.element(false)
      AnchorFlow | AnchorPhrasing => {
        self.inside_a = true
        self.element(kind is AnchorFlow)
        self.inside_a = false
      }
      ListItem => {
        let was_inside = self.inside_li
        self.inside_li = true
        self.element(true)
        self.inside_li = was_inside
      }
      OnlyListItems => self.specific_element("li")
      OnlyOptions => self.specific_element("option")
      TextOnly => self.failed = true
    }
    self.depth -= 1
    if self.failed {
      return
    }
  }
}

///|
/// `ScanText`: text up to the next `<`.
fn FastPath::text(self : FastPath) -> Unit {
  while !self.at_end() {
    match self.html[self.pos] {
      '<' => return
      '&' => {
        self.reference(false)
        if self.failed {
          return
        }
      }
      '\u{0}' => {
        self.failed = true
        return
      }
      _ => self.pos += 1
    }
  }
}

///|
/// `ScanHTMLCharacterReference`: only references closed by a `;` within
/// 20 characters of the `&`, and only ones that resolve; anything else
/// gives up. Named ones are resolved as in text even in attribute values,
/// where the longest name that is no reference there is recorded.
fn FastPath::reference(self : FastPath, in_attribute : Bool) -> Unit {
  let ampersand = self.pos
  self.pos += 1
  let start = self.pos
  while true {
    if self.at_end() || self.pos - start > 20 {
      self.failed = true
      return
    }
    if self.html[self.pos] == 0 {
      self.failed = true
      return
    }
    if self.consume() == ';' {
      break
    }
  }
  let reference = self.html[start:self.pos - 1]
  if reference.length() < 2 {
    self.failed = true
    return
  }
  if reference[0] == '#' {
    let hex = reference[1] is ('x' | 'X')
    let digits = if hex { reference[2:] } else { reference[1:] }
    if reference_code(digits, if hex { 16 } else { 10 }) is None {
      self.failed = true
      return
    }
    // Decimal digits are checked by `reference_code` only up to its
    // radix.
    if !hex && digits.iter().any(c => !(c is ('0'..<='9'))) {
      self.failed = true
      return
    }
    // No digits make a zero, where the full parser keeps the text.
    if digits.is_empty() {
      self.edits.push({
        start: ampersand,
        end: self.pos,
        replacement: "&#xfffd;",
      })
    }
    return
  }
  if reference is ("amp" | "lt" | "gt" | "nbsp") {
    return
  }
  // `ConsumeHTMLEntity` on the name and its `;`: the longest name of the
  // table the text starts with; what follows it is scanned again.
  let input = self.html[start:self.pos]
  let longest = name_span(input)
  for length = longest; length > 0; length = length - 1 {
    guard named_references.contains(input[:length].to_owned()) else { continue }
    if in_attribute &&
      input[length - 1] != ';' &&
      input[length:] is ['a'..<='z' | 'A'..<='Z' | '0'..<='9' | '=', ..] {
      self.edits.push({
        start: start + length,
        end: start + length,
        replacement: ";",
      })
    }
    self.pos = start + length
    return
  }
  self.failed = true
}

///|
/// `ScanTagname`: lower case letters, or letters of either case, followed
/// by white space, `>` or `/`; then white space.
fn FastPath::tag_name(self : FastPath) -> String? {
  let html = self.html
  let start = self.pos
  let after = (pos : Int32) => {
    pos < html.length() &&
    (fast_whitespace(html[pos]) || html[pos] is ('>' | '/'))
  }
  while !self.at_end() && html[self.pos] is ('a'..<='z' | 'A'..<='Z') {
    self.pos += 1
  }
  if !after(self.pos) {
    self.failed = true
    return None
  }
  let name = html[start:self.pos].to_owned().to_lower()
  self.skip_whitespace()
  Some(name)
}

///|
/// `ParseElement`: one of the supported elements, where the parent takes
/// it.
fn FastPath::element(self : FastPath, flow : Bool) -> Unit {
  guard self.tag_name() is Some(name) else { return }
  match name {
    // Nested anchors would be closed by the full parser.
    "a" if !self.inside_a =>
      self.container(if flow { AnchorFlow } else { AnchorPhrasing }, name)
    "b" | "button" | "i" | "label" | "span" | "strong" =>
      self.container(Phrasing, name)
    "br" | "input" => self.attributes()
    "select" => self.container(OnlyOptions, name)
    "div" | "footer" if flow => self.container(Flow, name)
    "p" if flow => self.container(Phrasing, name)
    "ol" | "ul" if flow => self.container(OnlyListItems, name)
    "li" if flow && !self.inside_li => {
      self.inside_li = true
      self.container(ListItem, name)
      self.inside_li = false
    }
    _ => self.failed = true
  }
}

///|
/// `ParseSpecificElements`: only the element `expected`.
fn FastPath::specific_element(self : FastPath, expected : String) -> Unit {
  guard self.tag_name() is Some(name) else { return }
  match name {
    "li" if expected == "li" => self.container(ListItem, name)
    "option" if expected == "option" => self.container(TextOnly, name)
    _ => self.failed = true
  }
}

///|
/// `ParseContainerElement`: attributes, children and the end tag, in any
/// case, followed by white space and `>`.
fn FastPath::container(
  self : FastPath,
  kind : FastChildren,
  name : String,
) -> Unit {
  self.attributes()
  if self.failed {
    return
  }
  self.children(kind)
  if self.failed || self.at_end() {
    self.failed = true
    return
  }
  // At the `/` of an end tag.
  self.pos += 1
  let html = self.html
  if html.length() - self.pos <= name.length() {
    self.failed = true
    return
  }
  let end_name = html[self.pos:self.pos + name.length()].to_owned().to_lower()
  self.pos += name.length()
  if end_name != name {
    self.failed = true
    return
  }
  self.skip_whitespace()
  if self.consume() != '>' {
    self.failed = true
  }
}

///|
/// `ParseAttributes`, up to and including the `>` of the start tag.
fn FastPath::attributes(self : FastPath) -> Unit {
  if self.next() == '>' {
    self.pos += 1
    return
  }
  if self.next() == '/' {
    self.pos += 1
    self.skip_whitespace()
    if self.consume() != '>' {
      self.failed = true
    }
    return
  }
  let names : Array[String] = []
  while true {
    guard self.attribute_name() is Some(name) else { return }
    if name.is_empty() {
      if self.next() == '>' {
        self.pos += 1
        break
      } else if self.next() == '/' {
        self.pos += 1
        self.skip_whitespace()
        if self.consume() != '>' {
          self.failed = true
          return
        }
        break
      } else {
        self.failed = true
        return
      }
    }
    // Event handlers and customized built-ins are left to the full parser.
    if (name.length() > 2 && name.has_prefix("on")) || name == "is" {
      self.failed = true
      return
    }
    names.push(name)
    if self.next() != '=' {
      self.skip_whitespace()
    }
    if self.next() == '=' {
      self.pos += 1
      self.attribute_value()
      if self.failed {
        return
      }
      self.skip_whitespace()
    }
    if self.next() == '>' {
      self.pos += 1
      break
    }
    if self.next() == '/' {
      self.pos += 1
      self.skip_whitespace()
      if self.consume() != '>' {
        self.failed = true
        return
      }
      break
    }
    if self.failed {
      return
    }
  }
  // A repeated attribute, which the full parser ignores.
  for i in 1..<names.length() {
    if names[:i].contains(names[i]) {
      self.failed = true
      return
    }
  }
}

///|
/// `ScanAttrName`: letters, digits and `-`, in lower case; empty where
/// none starts here.
fn FastPath::attribute_name(self : FastPath) -> String? {
  let html = self.html
  let start = self.pos
  while !self.at_end() &&
        html[self.pos] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-') {
    self.pos += 1
  }
  if self.at_end() {
    self.failed = true
    return None
  }
  Some(html[start:self.pos].to_owned().to_lower())
}

///|
/// `ScanAttrValue`: a quoted value, or an unquoted one of letters, digits,
/// `_` and `-`.
fn FastPath::attribute_value(self : FastPath) -> Unit {
  self.skip_whitespace()
  let html = self.html
  let quote = self.next()
  if self.failed {
    return
  }
  if quote is ('"' | '\'') {
    self.pos += 1
    let start = self.pos
    // Long input is scanned with SIMD for the closing quote, `&`, CR and
    // NUL; short input byte by byte, where the other quote also ends the
    // value, and then the value is malformed.
    let vectorized = html.length() - self.pos >= 64
    while !self.at_end() {
      let c = html[self.pos]
      if c is ('&' | '\r') {
        self.pos = start
        self.escaped_attribute_value(quote)
        return
      } else if c == quote || (!vectorized && c is ('"' | '\'')) {
        break
      } else if c == 0 {
        self.failed = true
        return
      }
      self.pos += 1
    }
    if self.consume() != quote {
      self.failed = true
    }
  } else {
    while !self.at_end() &&
          html[self.pos] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_' | '-') {
      self.pos += 1
    }
    let after = self.next()
    if !(fast_whitespace(after) || after == '>') {
      self.failed = true
    }
  }
}

///|
/// `ScanEscapedAttrValue`: a quoted value with references or CRs, from
/// just after its opening quote to the same quote.
fn FastPath::escaped_attribute_value(self : FastPath, quote : UInt16) -> Unit {
  while !self.at_end() && self.html[self.pos] != quote {
    if self.failed {
      return
    }
    if self.html[self.pos] == '&' {
      self.reference(true)
    } else {
      self.pos += 1
    }
  }
  if self.failed {
    return
  }
  if self.consume() != quote {
    self.failed = true
  }
}

///|
/// Whether Chrome would parse `html` into an element named `context`
/// with its fast path, which decodes character references differently.
fn fast_path_parses(html : String, context : String) -> Bool {
  html.contains("&") && fast_path(html, context) is Some(_)
}

///|
/// What DOMPurify's parse of `text` does to its character references,
/// written so that any later parse reads them the same: where Chrome's
/// fast path takes the markup, a name in an attribute value that the HTML
/// parser would leave alone (`&copy=1`) is closed with its `;`, and `&#x;`
/// becomes U+FFFD. Text without `<` is not parsed by DOMPurify and comes
/// back as it is.
pub fn settle_references(text : String) -> String {
  if !text.contains("<") || !text.contains("&") {
    return text
  }
  guard fast_path(text, "body") is Some(edits) && !edits.is_empty() else {
    return text
  }
  let out = StringBuilder()
  let mut done = 0
  for edit in edits {
    out.write_view(text[done:edit.start])
    out.write_string(edit.replacement)
    done = edit.end
  }
  out.write_view(text[done:])
  out.to_string()
}
