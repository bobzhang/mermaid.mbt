///|
/// A diagram's text after preprocessing, with the configuration it carried.
pub struct Diagram {
  /// The text handed to the diagram's parser: no frontmatter, directives
  /// or comments.
  code : String
  /// The frontmatter `title`, if any.
  title : String?
  /// Frontmatter `config` merged with the `init` directive.
  config : Json
}

///|
/// Normalize line endings, and turn double-quoted attributes of HTML tags
/// into single-quoted ones, which the diagram grammars can digest.
fn cleanup_text(code : String) -> String {
  let code = code
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let n = code.length()
  let out = StringBuilder()
  let mut i = 0
  // Everything else is copied a run at a time, which keeps surrogate
  // pairs whole.
  let mut copied = 0
  while i < n {
    // `<(\w+)([^>]*)>`
    if code[i] == '<' && i + 1 < n && is_word_unit(code[i + 1]) {
      let mut close = i + 1
      while close < n && code[close] != '>' {
        close += 1
      }
      if close < n {
        let mut name_end = i + 1
        while name_end < close && is_word_unit(code[name_end]) {
          name_end += 1
        }
        out.write_view(code[copied:name_end])
        out.write_string(requote(code[name_end:close].to_owned()))
        out.write_char('>')
        i = close + 1
        copied = i
        continue
      }
    }
    i += 1
  }
  out.write_view(code[copied:])
  out.to_string()
}

///|
/// `="value"` becomes `='value'`.
fn requote(attributes : String) -> String {
  let n = attributes.length()
  let out = StringBuilder()
  let mut i = 0
  let mut copied = 0
  while i < n {
    if starts_with_at(attributes, "=\"", i) {
      let mut close = i + 2
      while close < n && attributes[close] != '"' {
        close += 1
      }
      if close < n {
        out.write_view(attributes[copied:i])
        out.write_string("='")
        out.write_view(attributes[i + 2:close])
        out.write_char('\'')
        i = close + 1
        copied = i
        continue
      }
    }
    i += 1
  }
  out.write_view(attributes[copied:])
  out.to_string()
}

///|
/// lodash's `merge`: objects merge recursively, everything else is replaced.
fn deep_merge(base : Json, extra : Json) -> Json {
  match (base, extra) {
    (Object(a), Object(b)) => {
      let merged = a.copy()
      for key, value in b {
        merged[key] = match merged.get(key) {
          Some(current) => deep_merge(current, value)
          None => value
        }
      }
      Json::object(merged)
    }
    (_, Null) => base
    _ => extra
  }
}

///|
/// Prepare diagram text for parsing: clean it up, split off the YAML
/// frontmatter and `%%{init}%%` directives into configuration, and drop
/// comments.
pub fn preprocess(code : String) -> Diagram raise {
  let normalized = cleanup_text(code)
  let front = extract_front_matter(normalized)
  let mut front_config = front.config.unwrap_or(Json::object(Map([])))
  if front.display_mode is Some(mode) {
    // Supported for legacy reasons: `displayMode` belongs to gantt.
    let gantt = deep_merge(
      match front_config {
        Object({ "gantt": Object(gantt), .. }) => Json::object(gantt)
        _ => Json::object(Map([]))
      },
      { "displayMode": Json::string(mode) },
    )
    front_config = deep_merge(front_config, { "gantt": gantt })
  }
  let mut directive = detect_init(front.text).unwrap_or(Json::object(Map([])))
  if has_wrap_directive(front.text) {
    directive = deep_merge(directive, { "wrap": true })
  }
  {
    code: cleanup_comments(remove_directives(front.text)),
    title: front.title,
    config: deep_merge(front_config, directive),
  }
}
