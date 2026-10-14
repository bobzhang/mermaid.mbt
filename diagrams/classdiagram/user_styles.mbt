///|
/// Whether `text` is a CSS identifier without escapes: what may follow
/// the dot of a class selector.
fn is_css_identifier(text : StringView) -> Bool {
  let start = (c : Char) => {
    c is ('a'..<='z' | 'A'..<='Z' | '_') || c.to_int() >= 0x80
  }
  let chars = text.to_owned().to_array()
  let rest = match chars {
    ['-', '-', .. rest] => rest
    ['-', first, .. rest] if start(first) => rest
    [first, .. rest] if start(first) => rest
    _ => return false
  }
  rest.iter().all(c => start(c) || c is ('0'..<='9' | '-'))
}

///|
/// What follows the dot of the selector a styled class gets, as the
/// browser writes the selector back, if a dot followed by `id` is a
/// selector for certain: class selectors, which a name with dots in it
/// makes several of, and, after spaces, type selectors with classes of
/// their own. Type selectors come back in lower case and runs of spaces
/// as one. Nothing for anything else.
fn selector_tail(id : String) -> String? {
  let out = []
  for index, compound in id.split(" ").collect() {
    // Extra spaces between compounds, and after the last, mean nothing.
    if index > 0 && compound.is_empty() {
      continue
    }
    let parts = compound.split(".").collect()
    let (type_name, classes) = match parts {
      // After a space a compound starts with a type or with a class.
      [first, .. rest] if index > 0 =>
        (if first.is_empty() { None } else { Some(first) }, rest)
      parts => (None, parts[:])
    }
    if type_name is None && classes.is_empty() {
      return None
    }
    if type_name is Some(name) && !is_css_identifier(name) {
      return None
    }
    if !classes.iter().all(is_css_identifier) {
      return None
    }
    let text = StringBuilder()
    if type_name is Some(name) {
      text.write_string(name.to_owned().to_lower())
    }
    for position, class_name in classes {
      if position > 0 || index > 0 {
        text.write_char('.')
      }
      text.write_view(class_name)
    }
    out.push(text.to_string())
  }
  Some(out.join(" "))
}

///|
/// The classes that have styles of their own, by id, for the stylesheet.
///
/// Upstream hands the classes themselves to the code that writes a rule
/// for every `classDef` of other diagrams, so each styled class gets
/// rules under `.` and its id, inserted through the CSSOM: an id the
/// browser does not take as a selector fails the diagram.
pub fn ClassDb::styled_classes(
  self : ClassDb,
) -> Array[(String, Array[String])] raise ClassError {
  let styled = []
  for _, node in self.classes {
    if node.styles.is_empty() {
      continue
    }
    let id = node.id
    guard selector_tail(id) is Some(selector) else {
      // Certain to be refused when nothing but the characters of
      // identifiers is involved; any other character may make the id a
      // selector of some other shape, which is not modelled.
      let plain = id
        .iter()
        .all(c => {
          c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_' | '-' | '.' | ' ') ||
          c.to_int() >= 0x80
        })
      if plain {
        raise Invalid(
          "Failed to execute 'insertRule' on 'CSSStyleSheet': Failed to parse the rule '.\{id} > * { \{node.styles.join(" !important; ")} !important; }'.",
        )
      }
      raise Unsupported("styles on a class named \{id}")
    }
    styled.push((selector, node.styles))
  }
  styled
}
