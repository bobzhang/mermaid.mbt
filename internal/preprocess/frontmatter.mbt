///|
/// Where a YAML frontmatter block sits in the text.
priv struct FrontMatterMatch {
  /// The whitespace before the opening fence, which the closing fence must
  /// repeat.
  indent : String
  body : String
  /// How much of the text the block occupies, fences included.
  length : Int32
}

///|
fn is_space_unit(unit : UInt16) -> Bool {
  unit is (' ' | '\t' | '\n' | '\r' | 0x0b | 0x0c | 0xa0 | 0xfeff)
}

///|
fn is_line_break(unit : UInt16) -> Bool {
  unit is ('\n' | '\r')
}

///|
fn starts_with_at(text : String, prefix : String, at : Int32) -> Bool {
  if at < 0 || at + prefix.length() > text.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if text[at + i] != prefix[i] {
      return false
    }
  }
  true
}

///|
/// Find a frontmatter block at the start of `text`: a line of `---`, the
/// YAML body, and a closing `---` at the same indentation.
fn match_front_matter(text : String) -> FrontMatterMatch? {
  let n = text.length()
  let mut cursor = 0
  while cursor < n &&
        is_space_unit(text[cursor]) &&
        !is_line_break(text[cursor]) {
    cursor += 1
  }
  let indent = text[:cursor].to_owned()
  if !starts_with_at(text, "---", cursor) {
    return None
  }
  // Every line break in the whitespace after the opening fence could end it.
  let opening_ends = []
  for i = cursor + 3; i < n && is_space_unit(text[i]); i = i + 1 {
    if is_line_break(text[i]) {
      opening_ends.push(i)
    }
  }
  if opening_ends.length() == 0 {
    return None
  }
  let closing_fence = indent + "---"
  // If a closing fence follows the line break at `i`, the index of the last
  // line break in the whitespace after it.
  let closing_end = (i : Int32) => {
    if !(i < n &&
      is_line_break(text[i]) &&
      starts_with_at(text, closing_fence, i + 1)) {
      return -1
    }
    let mut index = -1
    for j = i + 1 + closing_fence.length()
        j < n && is_space_unit(text[j])
        j = j + 1 {
      if is_line_break(text[j]) {
        index = j
      }
    }
    index
  }
  let mut last_closing = -1
  for i in (opening_ends[0] + 1)..<n {
    if closing_end(i) != -1 {
      last_closing = i
    }
  }
  if last_closing == -1 {
    return None
  }
  // The longest opening that still leaves a closing fence behind.
  let mut opening_end = opening_ends[0]
  for candidate in opening_ends {
    if candidate < last_closing {
      opening_end = candidate
    }
  }
  let body_start = opening_end + 1
  for i in body_start..<=last_closing {
    let end = closing_end(i)
    if end != -1 {
      return Some({
        indent,
        body: text[body_start:i].to_owned(),
        length: end + 1,
      })
    }
  }
  None
}

///|
/// The frontmatter fields mermaid reads.
priv struct FrontMatter {
  text : String
  title : String?
  display_mode : String?
  config : Json?
}

///|
/// `value.toString()` for a truthy YAML value, `None` for a falsy one, as
/// in `if (parsed.title) metadata.title = parsed.title.toString()`.
fn scalar_text(value : Json) -> String? {
  match value {
    Null | False | String("") => None
    Number(n, ..) if n == 0.0 || n != n => None
    value => Some(js_string(value))
  }
}

///|
/// JavaScript's `String(value)` for a value of JSON: arrays join their
/// elements with commas (`null` as nothing), objects are
/// `[object Object]`.
fn js_string(value : Json) -> String {
  match value {
    Null => "null"
    True => "true"
    False => "false"
    Number(n, ..) => if n == 0.0 { "0" } else { n.to_string() }
    String(s) => s
    Array(items) =>
      items
      .map(item => if item is Null { "" } else { js_string(item) })
      .join(",")
    Object(_) => "[object Object]"
  }
}

///|
/// Split frontmatter off `text` and read its metadata. Invalid YAML is an
/// error, as it is upstream.
fn extract_front_matter(text : String) -> FrontMatter raise {
  guard match_front_matter(text) is Some(front) else {
    return { text, title: None, display_mode: None, config: None, }
  }
  let body = if front.indent == "" {
    front.body
  } else {
    front.body
    .split("\n")
    .map(line => {
      match line.strip_prefix(front.indent) {
        Some(rest) => rest.to_owned()
        None => line.to_owned()
      }
    })
    .collect()
    .join("\n")
  }
  // mermaid loads it with js-yaml, which takes quoted scalars indented
  // less than YAML 1.2 asks.
  let parsed : Json = match
    @yaml.Yaml::load_from_string(body, lenient_quoted_scalar_indentation=true) {
    [document] => Json(document)
    [] => Json::null()
    _ => fail("expected a single document in the stream, but found more")
  }
  let field = (name : String) => {
    match parsed {
      Object(fields) => fields.get(name).unwrap_or(Json::null())
      _ => Json::null()
    }
  }
  {
    text: text[front.length:].to_owned(),
    title: scalar_text(field("title")),
    display_mode: scalar_text(field("displayMode")),
    config: match field("config") {
      Null | False => None
      config => Some(config)
    },
  }
}
