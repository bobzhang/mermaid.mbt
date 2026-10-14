///|
/// Why a Sankey diagram cannot be rendered.
pub(all) suberror SankeyError {
  /// The diagram is invalid, with upstream's message.
  Invalid(String)
  /// What the port cannot reproduce exactly and therefore refuses.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// A parsed Sankey diagram: the flows between nodes.
pub struct Sankey {
  /// Node ids in the order they first appear.
  nodes : Array[String]
  /// `(source, target, value)`, with indices into `nodes`.
  links : Array[(Int32, Int32, Double)]
  /// How `sanitizeText` treats node ids.
  priv security_level : String
  priv html_labels : Bool
}

///|
fn Sankey::new(config : @config.Config) -> Sankey {
  {
    nodes: [],
    links: [],
    security_level: config.text("securityLevel").unwrap_or("strict"),
    // `getEffectiveHtmlLabels`
    html_labels: match config.get("htmlLabels") {
      Null =>
        match config.get("flowchart.htmlLabels") {
          Null => true
          value => @config.evaluate(value)
        }
      value => @config.evaluate(value)
    },
  }
}

///|
/// mermaid's `sanitizeText` for a node id. DOMPurify returns text without
/// a `<` as it is; anything else would go through the HTML parser, which
/// is not reproduced.
fn Sankey::sanitize_text(
  self : Sankey,
  text : String,
) -> String raise SankeyError {
  let escaped = self.html_labels &&
    !(self.security_level is ("antiscript" | "strict" | "sandbox" | "loose"))
  let text = if escaped {
    text
    .replace_all(old="<", new="&lt;")
    .replace_all(old=">", new="&gt;")
    .replace_all(old="=", new="&equals;")
  } else {
    text
  }
  if text.contains("<") {
    raise Unsupported("markup in a Sankey node name: \{text}")
  }
  text
}

///|
/// The index of the node called `id`, added when it is new.
fn Sankey::find_or_create_node(
  self : Sankey,
  id : String,
) -> Int32 raise SankeyError {
  let id = self.sanitize_text(id)
  match self.nodes.search(id) {
    Some(index) => index
    None => {
      self.nodes.push(id)
      self.nodes.length() - 1
    }
  }
}
