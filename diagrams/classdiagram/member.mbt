///|
/// A member of a class as its source line describes it: mermaid's
/// `ClassMember`.
pub struct ClassMember {
  /// The name, with one leading space kept if the source had any.
  id : String
  /// `method` or `attribute`.
  member_type : String
  /// `#`, `+`, `~`, `-` or nothing.
  visibility : String
  /// What the class box shows, as markdown with entities.
  text : String
  /// `*` for abstract, `$` for static, or nothing.
  classifier : String
  parameters : String
  return_type : String
}

///|
/// `/([#+~-])?(.+)\((.*)\)([\s$*])?(.*)([$*])?/`
let method_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  "([#+~-])?(.+)\\((.*)\\)([\\s$*])?(.*)([$*])?",
)

///|
fn is_visibility(text : String) -> Bool {
  text is ("#" | "+" | "~" | "-" | "")
}

///|
/// `text.trim()` as JavaScript trims.
fn js_trim(text : String) -> String {
  text.trim(chars=" \t\n\r\u{b}\u{c}\u{a0}\u{feff}\u{2028}\u{2029}").to_owned()
}

///|
/// Parse a member line that has been sanitized: `parseMember`.
fn ClassMember::new(
  input : String,
  member_type : String,
) -> ClassMember raise ClassError {
  let mut visibility = ""
  let mut classifier = ""
  let mut id = ""
  let mut parameters = ""
  let mut return_type = ""
  if member_type == "method" {
    if method_pattern.exec(input) is Some(found) {
      let group = (index : Int32) => found.group(index).unwrap_or("")
      let detected = js_trim(group(1))
      if is_visibility(detected) {
        visibility = detected
      }
      id = group(2)
      parameters = js_trim(group(3))
      classifier = js_trim(group(4))
      return_type = js_trim(group(5))
      if classifier == "" {
        let length = return_type.length()
        if length > 0 &&
          return_type[length - 1:].to_owned() is ("$" | "*" as last) {
          classifier = last
          return_type = return_type[:length - 1].to_owned()
        }
      }
    } else {
      // Upstream goes on with a name it never set, and fails.
      raise Invalid(
        "Cannot read properties of undefined (reading 'startsWith')",
      )
    }
  } else {
    let length = input.length()
    let first = if length > 0 { input[:1].to_owned() } else { "" }
    let last = if length > 0 { input[length - 1:].to_owned() } else { "" }
    if is_visibility(first) {
      visibility = first
    }
    if last is ("$" | "*") {
      classifier = last
    }
    let start = if visibility == "" { 0 } else { 1 }
    let end = if classifier == "" { length } else { length - 1 }
    id = if start < end { input[start:end].to_owned() } else { "" }
  }
  // One leading space survives.
  id = if id.has_prefix(" ") { " " + js_trim(id) } else { js_trim(id) }
  let generic = @rendering.parse_generic_types
  let combined = (if visibility == "" { "" } else { "\\" + visibility }) +
    generic(id) +
    (if member_type == "method" {
      "(" +
      generic(parameters) +
      ")" +
      (if return_type == "" { "" } else { " : " + generic(return_type) })
    } else {
      ""
    })
  let mut text = combined
    .replace_all(old="<", new="&lt;")
    .replace_all(old=">", new="&gt;")
  if text.has_prefix("\\&lt;") {
    text = text.replace(old="\\&lt;", new="~")
  }
  { id, member_type, visibility, text, classifier, parameters, return_type, }
}

///|
/// The style a classifier asks for: `parseClassifier`.
pub fn ClassMember::css_style(self : ClassMember) -> String {
  match self.classifier {
    "*" => "font-style:italic;"
    "$" => "text-decoration:underline;"
    _ => ""
  }
}
