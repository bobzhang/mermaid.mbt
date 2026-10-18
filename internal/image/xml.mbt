// Enough of an XML parser to tell, as libxml2 does for Chrome, whether an
// SVG image is a namespace-well-formed document, and to read its root
// element.
//
// The document is UTF-8 unless a byte order mark says UTF-16, whatever its
// declaration says (Chrome fails on an ISO-8859-1 document with non-ASCII
// bytes). The internal subset of a document type declaration defines
// entities; other declarations in it are skipped, and the external subset
// is not read.

///|
/// Why a document is not read.
priv suberror XmlError {
  /// Not namespace-well-formed: Chrome cannot decode the image.
  Malformed
  /// The port does not evaluate it; the reason.
  Unevaluated(String)
}

///|
const XML_NAMESPACE : String = "http://www.w3.org/XML/1998/namespace"

///|
/// The root element of a document.
priv struct XmlRoot {
  /// The namespace of the root, `None` for none.
  namespace_uri : String?
  local_name : String
  /// The attributes without a namespace, by name, their values
  /// normalized.
  attributes : Map[String, String]
  /// Whether the document has a `style` element anywhere.
  has_style_element : Bool
}

///|
priv struct XmlParser {
  text : Array[Char]
  mut pos : Int32
  /// Entities of the internal subset: their replacement text, or `None`
  /// for one the port does not expand (external, or with markup or
  /// references in it).
  entities : Map[String, String?]
  /// Whether declarations the port does not read may declare entities
  /// (an external subset or parameter entity references), which makes an
  /// undeclared entity no error.
  mut unread_declarations : Bool
}

///|
/// The characters of a document: UTF-8, or UTF-16 after its byte order
/// mark, with line ends normalized to `\n`. `None` when the bytes are not
/// in the encoding or hold characters XML does not allow.
fn xml_chars(data : Bytes) -> Array[Char]? {
  let view = data[:]
  let decoded : Array[Char] = []
  if has_prefix(data, b"\xfe\xff") || has_prefix(data, b"\xff\xfe") {
    let little_endian = byte(view, 0) == 0xff
    guard data.length() % 2 == 0 else { return None }
    let mut at = 2
    while at < data.length() {
      let unit = if little_endian { le16(view, at) } else { be16(view, at) }
      at += 2
      if unit >= 0xd800 && unit < 0xdc00 {
        guard at < data.length() else { return None }
        let low = if little_endian { le16(view, at) } else { be16(view, at) }
        guard low >= 0xdc00 && low < 0xe000 else { return None }
        at += 2
        decoded.push(
          (0x10000 + ((unit - 0xd800) << 10) + (low - 0xdc00)).unsafe_to_char(),
        )
      } else if unit >= 0xdc00 && unit < 0xe000 {
        return None
      } else {
        decoded.push(unit.unsafe_to_char())
      }
    }
  } else {
    let start = if has_prefix(data, b"\xef\xbb\xbf") { 3 } else { 0 }
    let text = @utf8.decode(view[start:]) catch { _ => return None }
    for c in text {
      decoded.push(c)
    }
  }
  let chars = []
  for i, c in decoded {
    if c == '\r' {
      chars.push('\n')
    } else if c == '\n' && i > 0 && decoded[i - 1] == '\r' {
      continue
    } else {
      guard is_xml_char(c) else { return None }
      chars.push(c)
    }
  }
  Some(chars)
}

///|
/// XML 1.0's `Char`.
fn is_xml_char(c : Char) -> Bool {
  let code = c.to_int()
  code is (0x9 | 0xa | 0xd) ||
  (code >= 0x20 && code <= 0xd7ff) ||
  (code >= 0xe000 && code <= 0xfffd) ||
  (code >= 0x10000 && code <= 0x10ffff)
}

///|
/// XML 1.0's `NameStartChar` (fifth edition).
fn is_name_start(c : Char) -> Bool {
  let code = c.to_int()
  c is (':' | '_' | 'A'..<='Z' | 'a'..<='z') ||
  (code >= 0xc0 && code <= 0xd6) ||
  (code >= 0xd8 && code <= 0xf6) ||
  (code >= 0xf8 && code <= 0x2ff) ||
  (code >= 0x370 && code <= 0x37d) ||
  (code >= 0x37f && code <= 0x1fff) ||
  (code >= 0x200c && code <= 0x200d) ||
  (code >= 0x2070 && code <= 0x218f) ||
  (code >= 0x2c00 && code <= 0x2fef) ||
  (code >= 0x3001 && code <= 0xd7ff) ||
  (code >= 0xf900 && code <= 0xfdcf) ||
  (code >= 0xfdf0 && code <= 0xfffd) ||
  (code >= 0x10000 && code <= 0xeffff)
}

///|
/// XML 1.0's `NameChar`.
fn is_name_char(c : Char) -> Bool {
  let code = c.to_int()
  is_name_start(c) ||
  c is ('-' | '.' | '0'..<='9') ||
  code == 0xb7 ||
  (code >= 0x300 && code <= 0x36f) ||
  (code >= 0x203f && code <= 0x2040)
}

///|
fn is_xml_space(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\r')
}

///|
fn XmlParser::at_end(self : XmlParser) -> Bool {
  self.pos >= self.text.length()
}

///|
fn XmlParser::peek(self : XmlParser) -> Char? {
  self.text.get(self.pos)
}

///|
fn XmlParser::looking_at(self : XmlParser, prefix : String) -> Bool {
  let mut at = self.pos
  for c in prefix {
    guard self.text.get(at) == Some(c) else { return false }
    at += 1
  }
  true
}

///|
/// Consume `prefix` if the text continues with it.
fn XmlParser::accept(self : XmlParser, prefix : String) -> Bool {
  guard self.looking_at(prefix) else { return false }
  self.pos += prefix.length()
  true
}

///|
fn XmlParser::expect(self : XmlParser, prefix : String) -> Unit raise XmlError {
  guard self.accept(prefix) else { raise Malformed }
}

///|
/// Skip white space; whether there was any.
fn XmlParser::skip_space(self : XmlParser) -> Bool {
  let start = self.pos
  while self.peek() is Some(c) && is_xml_space(c) {
    self.pos += 1
  }
  self.pos > start
}

///|
fn XmlParser::require_space(self : XmlParser) -> Unit raise XmlError {
  guard self.skip_space() else { raise Malformed }
}

///|
fn XmlParser::name(self : XmlParser) -> String raise XmlError {
  guard self.peek() is Some(c) && is_name_start(c) else { raise Malformed }
  let name = StringBuilder()
  while self.peek() is Some(c) && is_name_char(c) {
    name.write_char(c)
    self.pos += 1
  }
  name.to_string()
}

///|
/// Text up to `end`, which is consumed.
fn XmlParser::until(self : XmlParser, end : String) -> String raise XmlError {
  let text = StringBuilder()
  while !self.looking_at(end) {
    guard self.peek() is Some(c) else { raise Malformed }
    text.write_char(c)
    self.pos += 1
  }
  self.pos += end.length()
  text.to_string()
}

///|
/// A quoted literal, taken as it is.
fn XmlParser::literal(self : XmlParser) -> String raise XmlError {
  guard self.peek() is Some('"' | '\'' as quote) else { raise Malformed }
  self.pos += 1
  self.until(quote.to_string())
}

///|
/// `S? '=' S?`.
fn XmlParser::equals(self : XmlParser) -> Unit raise XmlError {
  self.skip_space() |> ignore
  self.expect("=")
  self.skip_space() |> ignore
}

///|
/// A comment, after its `<!--`: no `--` inside.
fn XmlParser::comment(self : XmlParser) -> Unit raise XmlError {
  self.until("--") |> ignore
  self.expect(">")
}

///|
/// A processing instruction, after its `<?`; its target may not be `xml`.
fn XmlParser::processing_instruction(self : XmlParser) -> Unit raise XmlError {
  let target = self.name()
  guard target.to_lower() != "xml" && target.find(":") is None else {
    raise Malformed
  }
  if self.accept("?>") {
    return
  }
  self.require_space()
  self.until("?>") |> ignore
}

///|
/// The XML declaration, after its `<?xml`.
fn XmlParser::declaration(self : XmlParser) -> Unit raise XmlError {
  self.require_space()
  self.expect("version")
  self.equals()
  let version = self.literal()
  guard version.length() > 2 &&
    version.has_prefix("1.") &&
    version[2:].iter().all(c => c is ('0'..<='9')) else {
    raise Malformed
  }
  let mut spaced = self.skip_space()
  if spaced && self.accept("encoding") {
    self.equals()
    let encoding = self.literal()
    for i, c in encoding {
      guard c is ('A'..<='Z' | 'a'..<='z') ||
        (i > 0 && c is ('0'..<='9' | '.' | '_' | '-')) else {
        raise Malformed
      }
    }
    guard encoding != "" else { raise Malformed }
    spaced = self.skip_space()
  }
  if spaced && self.accept("standalone") {
    self.equals()
    guard self.literal() is ("yes" | "no") else { raise Malformed }
    self.skip_space() |> ignore
  }
  self.expect("?>")
}

///|
/// Skip a markup declaration the port does not read, up to its `>`.
fn XmlParser::skip_declaration(self : XmlParser) -> Unit raise XmlError {
  while true {
    match self.peek() {
      None => raise Malformed
      Some('>') => {
        self.pos += 1
        break
      }
      Some('"' | '\'') => self.literal() |> ignore
      Some(_) => self.pos += 1
    }
  }
}

///|
/// `SYSTEM` or `PUBLIC` and their literals; whether there was one.
fn XmlParser::external_id(self : XmlParser) -> Bool raise XmlError {
  if self.accept("SYSTEM") {
    self.require_space()
    self.literal() |> ignore
    true
  } else if self.accept("PUBLIC") {
    self.require_space()
    self.literal() |> ignore
    self.require_space()
    self.literal() |> ignore
    true
  } else {
    false
  }
}

///|
/// An entity declaration, after its `<!ENTITY`.
fn XmlParser::entity_declaration(self : XmlParser) -> Unit raise XmlError {
  self.require_space()
  if self.accept("%") {
    // A parameter entity, which only declarations use.
    self.skip_declaration()
    return
  }
  let name = self.name()
  self.require_space()
  let value = if self.peek() is Some('"' | '\'') {
    let value = self.literal()
    if value.find("&") is Some(_) ||
      value.find("%") is Some(_) ||
      value.find("<") is Some(_) {
      None
    } else {
      Some(value)
    }
  } else {
    guard self.external_id() else { raise Malformed }
    None
  }
  // The first declaration of an entity is the one that counts.
  if !self.entities.contains(name) {
    self.entities[name] = value
  }
  self.skip_declaration()
}

///|
/// The document type declaration, after its `<!DOCTYPE`.
fn XmlParser::doctype(self : XmlParser) -> Unit raise XmlError {
  self.require_space()
  self.name() |> ignore
  let spaced = self.skip_space()
  if spaced && self.external_id() {
    self.unread_declarations = true
    self.skip_space() |> ignore
  }
  if self.accept("[") {
    while true {
      self.skip_space() |> ignore
      if self.accept("]") {
        break
      } else if self.accept("<!ENTITY") {
        self.entity_declaration()
      } else if self.accept("<!--") {
        self.comment()
      } else if self.accept("<?") {
        self.processing_instruction()
      } else if self.accept("<!ELEMENT") ||
        self.accept("<!ATTLIST") ||
        self.accept("<!NOTATION") {
        self.skip_declaration()
      } else if self.accept("%") {
        self.name() |> ignore
        self.expect(";")
        self.unread_declarations = true
      } else {
        raise Malformed
      }
    }
    self.skip_space() |> ignore
  }
  self.expect(">")
}

///|
/// The replacement text of a reference, after its `&`.
fn XmlParser::reference(self : XmlParser) -> String raise XmlError {
  if self.accept("#x") {
    self.character_reference(16)
  } else if self.accept("#") {
    self.character_reference(10)
  } else {
    let name = self.name()
    self.expect(";")
    match name {
      "lt" => "<"
      "gt" => ">"
      "amp" => "&"
      "apos" => "'"
      "quot" => "\""
      _ =>
        match self.entities.get(name) {
          Some(Some(value)) => value
          Some(None) => raise Unevaluated("the entity \{name} is not expanded")
          None if self.unread_declarations =>
            raise Unevaluated("the entity \{name} may be declared externally")
          None => raise Malformed
        }
    }
  }
}

///|
fn XmlParser::character_reference(
  self : XmlParser,
  base : Int32,
) -> String raise XmlError {
  let mut code = 0
  let mut digits = 0
  while self.peek() is Some(c) && c != ';' {
    let digit = match c {
      '0'..<='9' => c.to_int() - '0'.to_int()
      'a'..<='f' if base == 16 => c.to_int() - 'a'.to_int() + 10
      'A'..<='F' if base == 16 => c.to_int() - 'A'.to_int() + 10
      _ => raise Malformed
    }
    code = code * base + digit
    guard code <= 0x10ffff else { raise Malformed }
    digits += 1
    self.pos += 1
  }
  guard digits > 0 && self.accept(";") else { raise Malformed }
  let c = code.unsafe_to_char()
  guard is_xml_char(c) else { raise Malformed }
  c.to_string()
}

///|
/// An attribute value, references replaced and white space normalized.
fn XmlParser::attribute_value(self : XmlParser) -> String raise XmlError {
  guard self.peek() is Some('"' | '\'' as quote) else { raise Malformed }
  self.pos += 1
  let value = StringBuilder()
  while true {
    match self.peek() {
      None | Some('<') => raise Malformed
      Some(c) if c == quote => {
        self.pos += 1
        break
      }
      Some('&') => {
        self.pos += 1
        let character = self.peek() == Some('#')
        let text = self.reference()
        for c in text {
          // Character references are not normalized; entities are.
          value.write_char(if !character && is_xml_space(c) { ' ' } else { c })
        }
      }
      Some(c) => {
        value.write_char(if is_xml_space(c) { ' ' } else { c })
        self.pos += 1
      }
    }
  }
  value.to_string()
}

///|
/// A start tag, after its `<`: the name, the attributes in order and
/// whether the element is empty.
fn XmlParser::start_tag(
  self : XmlParser,
) -> (String, Array[(String, String)], Bool) raise XmlError {
  let name = self.name()
  let attributes = []
  let seen = Set([])
  while true {
    let spaced = self.skip_space()
    if self.accept("/>") {
      return (name, attributes, true)
    }
    if self.accept(">") {
      return (name, attributes, false)
    }
    guard spaced else { raise Malformed }
    let attribute = self.name()
    self.equals()
    let value = self.attribute_value()
    guard !seen.contains(attribute) else { raise Malformed }
    seen.add(attribute)
    attributes.push((attribute, value))
  }
  abort("unreachable")
}

///|
/// The prefix and local part of a qualified name.
fn split_qname(name : String) -> (String?, String) raise XmlError {
  match name.find(":") {
    None => (None, name)
    Some(at) => {
      let prefix = name[:at].to_owned()
      let local_part = name[at + 1:].to_owned()
      guard prefix != "" &&
        local_part != "" &&
        local_part.find(":") is None &&
        local_part.get_char(0) is Some(c) &&
        is_name_start(c) else {
        raise Malformed
      }
      (Some(prefix), local_part)
    }
  }
}

///|
/// Bind the namespaces an element declares on top of `scope`, and
/// resolve its name and attributes: its namespace and local name, and its
/// attributes without a namespace.
fn bind_namespaces(
  scope : Map[String, String],
  name : String,
  attributes : Array[(String, String)],
) -> (Map[String, String], String?, String, Map[String, String]) raise XmlError {
  let mut scope = scope
  let mut copied = false
  let bind = (prefix : String, uri : String) => {
    if !copied {
      scope = Map::from_iter(scope.iter())
      copied = true
    }
    scope[prefix] = uri
  }
  for attribute in attributes {
    let (attribute, value) = attribute
    if attribute == "xmlns" {
      bind("", value)
    } else if attribute.strip_prefix("xmlns:") is Some(prefix) {
      let prefix = prefix.to_owned()
      guard prefix != "" &&
        prefix.find(":") is None &&
        prefix != "xmlns" &&
        value != "" &&
        (prefix != "xml" || value == XML_NAMESPACE) else {
        raise Malformed
      }
      bind(prefix, value)
    }
  }
  let resolve = (prefix : String) => {
    if prefix == "xml" {
      Some(XML_NAMESPACE)
    } else {
      scope.get(prefix)
    }
  }
  let (prefix, local_name) = split_qname(name)
  let namespace_uri = match prefix {
    Some(prefix) =>
      match resolve(prefix) {
        Some(uri) => Some(uri)
        None => raise Malformed
      }
    None =>
      match scope.get("") {
        Some("") | None => None
        Some(uri) => Some(uri)
      }
  }
  let plain = Map([])
  let qualified = Set([])
  for attribute in attributes {
    let (attribute, value) = attribute
    if attribute == "xmlns" || attribute.has_prefix("xmlns:") {
      continue
    }
    match split_qname(attribute) {
      (None, local_part) => plain[local_part] = value
      (Some(prefix), local_part) => {
        guard resolve(prefix) is Some(uri) else { raise Malformed }
        let key = "\{uri} \{local_part}"
        guard !qualified.contains(key) else { raise Malformed }
        qualified.add(key)
      }
    }
  }
  (scope, namespace_uri, local_name, plain)
}

///|
/// Read a document: its root element, if it is namespace-well-formed.
fn parse_xml(data : Bytes) -> XmlRoot raise XmlError {
  guard xml_chars(data) is Some(text) else { raise Malformed }
  let parser = { text, pos: 0, entities: Map([]), unread_declarations: false, }
  if parser.looking_at("<?xml") &&
    parser.text.get(5) is Some(c) &&
    is_xml_space(c) {
    parser.pos = 5
    parser.declaration()
  }
  // The prolog: comments, processing instructions, one document type.
  let mut doctype_seen = false
  while true {
    parser.skip_space() |> ignore
    if parser.accept("<!--") {
      parser.comment()
    } else if parser.accept("<?") {
      parser.processing_instruction()
    } else if !doctype_seen && parser.accept("<!DOCTYPE") {
      parser.doctype()
      doctype_seen = true
    } else {
      break
    }
  }
  parser.expect("<")
  let (name, attributes, empty) = parser.start_tag()
  let (scope, namespace_uri, local_name, plain) = bind_namespaces(
    Map([]),
    name,
    attributes,
  )
  let mut has_style_element = local_name == "style"
  // The open elements: their names and namespace scopes.
  let open = if empty { [] } else { [(name, scope)] }
  while open.last() is Some((current, scope)) {
    match parser.peek() {
      None => raise Malformed
      Some('<') => {
        parser.pos += 1
        if parser.accept("/") {
          guard parser.name() == current else { raise Malformed }
          parser.skip_space() |> ignore
          parser.expect(">")
          open.pop() |> ignore
        } else if parser.accept("!--") {
          parser.comment()
        } else if parser.accept("![CDATA[") {
          parser.until("]]>") |> ignore
        } else if parser.accept("?") {
          parser.processing_instruction()
        } else {
          let (name, attributes, empty) = parser.start_tag()
          let (scope, _, local_name, _) = bind_namespaces(
            scope, name, attributes,
          )
          has_style_element = has_style_element || local_name == "style"
          if !empty {
            open.push((name, scope))
          }
        }
      }
      // An entity in text cannot change the root; one libxml2 does not
      // expand is left out.
      Some('&') => {
        parser.pos += 1
        let _ = parser.reference() catch {
          Unevaluated(_) => ""
          Malformed => raise Malformed
        }
      }
      Some(_) => {
        guard !parser.looking_at("]]>") else { raise Malformed }
        parser.pos += 1
      }
    }
  }
  // After the root: comments, processing instructions, white space.
  while true {
    parser.skip_space() |> ignore
    if parser.accept("<!--") {
      parser.comment()
    } else if parser.accept("<?") {
      parser.processing_instruction()
    } else {
      break
    }
  }
  guard parser.at_end() else { raise Malformed }
  { namespace_uri, local_name, attributes: plain, has_style_element, }
}
