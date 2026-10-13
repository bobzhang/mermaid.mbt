///|
/// No diagram type matches the text.
pub(all) suberror UnknownDiagramError {
  UnknownDiagramError(String)
} derive(Eq, Debug)

///|
fn is_space(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}' | '\u{a0}' | '\u{feff}')
}

///|
fn is_word(c : Char) -> Bool {
  c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_')
}

///|
/// What may follow a keyword for a detector to accept it.
priv enum After {
  /// Anything.
  Any
  /// A word boundary (`\b`).
  Boundary
  /// Whitespace or the end of the text.
  Space
  /// Whitespace, a colon or the end of the text.
  SpaceOrColon
}

///|
/// Whether `text`, after leading whitespace, starts with `keyword`.
fn starts_with(
  text : String,
  keyword : String,
  after~ : After = Any,
  ignore_case~ : Bool = false,
) -> Bool {
  let trimmed = text.trim_start(chars=" \t\n\r\u{0b}\u{0c}\u{a0}\u{feff}")
  let head = if ignore_case { trimmed.to_lower() } else { trimmed }
  let keyword = if ignore_case { keyword.to_lower() } else { keyword }
  guard head.strip_prefix(keyword) is Some(rest) else { return false }
  let next = rest.get_char(0)
  match after {
    Any => true
    Boundary => !(next is Some(c) && is_word(c))
    Space => !(next is Some(c) && !is_space(c))
    SpaceOrColon => !(next is Some(c) && !(is_space(c) || c == ':'))
  }
}

///|
/// The diagram type of `text`, tried in mermaid's registration order: the
/// first detector to match wins. `text` must already be free of
/// frontmatter, directives and comments.
fn detect(text : String) -> String? {
  if text.to_lower().trim().to_owned() == "error" {
    return Some("error")
  }
  if starts_with(text, "---") {
    return Some("---")
  }
  if starts_with(text, "flowchart-elk") {
    return Some("flowchart-elk")
  }
  if starts_with(text, "mindmap") {
    return Some("mindmap")
  }
  if starts_with(text, "architecture") {
    return Some("architecture")
  }
  if starts_with(text, "agentflow-beta", after=Boundary) {
    return Some("agentflow")
  }
  if starts_with(text, "C4Context") ||
    ["C4Container", "C4Component", "C4Dynamic", "C4Deployment"]
    .iter()
    .any(keyword => text.contains(keyword)) {
    return Some("c4")
  }
  let simple : Array[(String, String)] = [
    ("kanban", "kanban"),
    ("classDiagram", "classDiagram"),
    ("erDiagram", "er"),
    ("gantt", "gantt"),
    ("info", "info"),
    ("pie", "pie"),
    ("requirement", "requirement"),
    ("sequenceDiagram", "sequence"),
  ]
  for entry in simple {
    if starts_with(text, entry.0) {
      return Some(entry.1)
    }
  }
  if starts_with(text, "swimlane-beta", after=Boundary) {
    return Some("swimlane")
  }
  let simple : Array[(String, String)] = [
    ("graph", "flowchart-v2"),
    ("flowchart", "flowchart-v2"),
    ("timeline", "timeline"),
    ("gitGraph", "gitGraph"),
    ("stateDiagram", "stateDiagram"),
    ("journey", "journey"),
    ("quadrantChart", "quadrantChart"),
    ("sankey", "sankey"),
    ("packet", "packet"),
    ("xychart", "xychart"),
    ("block", "block"),
    ("eventmodeling", "eventmodeling"),
    ("treeView-beta", "treeView"),
    ("radar-beta", "radar"),
  ]
  for entry in simple {
    if starts_with(text, entry.0) {
      return Some(entry.1)
    }
  }
  if starts_with(text, "ishikawa-beta", after=Boundary, ignore_case=true) ||
    starts_with(text, "ishikawa", after=Boundary, ignore_case=true) {
    return Some("ishikawa")
  }
  if starts_with(text, "treemap") {
    return Some("treemap")
  }
  let railroad : Array[(String, String)] = [
    ("railroad-beta", "railroad"),
    ("railroad-ebnf-beta", "railroadEbnf"),
    ("railroad-abnf-beta", "railroadAbnf"),
    ("railroad-peg-beta", "railroadPeg"),
  ]
  for entry in railroad {
    if starts_with(text, entry.0, ignore_case=true) {
      return Some(entry.1)
    }
  }
  if starts_with(text, "venn-beta") {
    return Some("venn")
  }
  if starts_with(text, "wardley-beta", ignore_case=true) {
    return Some("wardley")
  }
  if starts_with(text, "cynefin-beta", after=SpaceOrColon) {
    return Some("cynefin")
  }
  if starts_with(text, "usecase-beta", after=Space) {
    return Some("usecase")
  }
  None
}

///|
/// Detect the diagram type of raw diagram text: frontmatter, directives
/// and comments are looked past.
pub fn detect_type(text : String) -> String raise UnknownDiagramError {
  let text = match match_front_matter(text) {
    Some(front) => text[front.length:].to_owned()
    None => text
  }
  let text = strip_any_comments(remove_directives(text))
  match detect(text) {
    Some(diagram_type) => diagram_type
    None =>
      raise UnknownDiagramError(
        "No diagram type detected matching given configuration for text: \{text}",
      )
  }
}
