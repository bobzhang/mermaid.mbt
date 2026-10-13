///|
/// One `%%{ type: args }%%` directive.
priv struct Directive {
  /// Where the directive starts and ends in the text.
  start : Int32
  end : Int32
  kind : String
  /// The directive's arguments: a bare word, or the raw text up to `}%%`.
  word : String?
  body : String?
}

///|
fn is_word_unit(unit : UInt16) -> Bool {
  unit is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_')
}

///|
/// Scan `text` for directives the way mermaid's `directiveRegex` matches
/// them: `%%{`, a type word optionally followed by a colon, then either a
/// bare word or everything up to `}%%`.
fn find_directives(text : String) -> Array[Directive] {
  let n = text.length()
  let directives = []
  let skip_space = (i : Int32) => {
    let mut j = i
    while j < n && is_space_unit(text[j]) {
      j += 1
    }
    j
  }
  let word_end = (i : Int32) => {
    let mut j = i
    while j < n && is_word_unit(text[j]) {
      j += 1
    }
    j
  }
  let mut i = 0
  while i < n {
    if !starts_with_at(text, "%%{", i) {
      i += 1
      continue
    }
    let kind_start = skip_space(i + 3)
    let kind_end = word_end(kind_start)
    if kind_end == kind_start {
      i += 1
      continue
    }
    let kind = text[kind_start:kind_end].to_owned()
    // `word :` if a colon follows, else just the word.
    let after_kind = skip_space(kind_end)
    let mut cursor = if after_kind < n && text[after_kind] == ':' {
      after_kind + 1
    } else {
      kind_end
    }
    cursor = skip_space(cursor)
    let mut word : String? = None
    let mut body : String? = None
    let bare_end = word_end(cursor)
    if bare_end > cursor {
      word = Some(text[cursor:bare_end].to_owned())
      cursor = bare_end
    } else {
      let mut j = cursor
      while j < n && !starts_with_at(text, "}%%", j) {
        j += 1
      }
      if j > cursor {
        body = Some(text[cursor:j].to_owned())
      }
      cursor = j
    }
    // Trailing whitespace is part of the match only when it is followed by
    // something the pattern can still consume; the body already took it.
    let after_space = skip_space(cursor)
    cursor = if starts_with_at(text, "}%%", after_space) {
      after_space + 3
    } else {
      after_space
    }
    directives.push({ start: i, end: cursor, kind, word, body, })
    i = if cursor > i { cursor } else { i + 1 }
  }
  directives
}

///|
/// Delete every directive from `text`.
fn remove_directives(text : String) -> String {
  let out = StringBuilder()
  let mut last = 0
  for directive in find_directives(text) {
    out.write_view(text[last:directive.start])
    last = directive.end
  }
  out.write_view(text[last:])
  out.to_string()
}

///|
/// The text the directive scanner runs on: trimmed, with single quotes
/// turned into double quotes so the arguments parse as JSON.
fn directive_source(text : String) -> String {
  text.trim().to_owned().replace_all(old="'", new="\"")
}

///|
/// The merged arguments of the `init` / `initialize` directives in `text`,
/// or `None` when there are none. A directive whose arguments are not valid
/// JSON makes the whole lookup come back empty, as upstream.
fn detect_init(text : String) -> Json? raise UnknownDiagramError {
  let source = directive_source(text)
  let args = []
  for directive in find_directives(source) {
    if !(directive.kind.has_suffix("init") ||
      directive.kind.has_suffix("initialize")) {
      continue
    }
    let value : Json = match (directive.word, directive.body) {
      (Some(word), _) => Json::string(word.trim().to_owned())
      (None, Some(body)) =>
        @json.parse(body.trim().to_owned()) catch {
          _ => return None
        }
      (None, None) => Json::null()
    }
    args.push(value)
  }
  let mut results : Json = match args {
    [] => return None
    [single] => single
    many => {
      let sanitized = many.map(@config.sanitize_directive)
      @config.assign_with_depth(Json::object(Map([])), Json::array(sanitized))
    }
  }
  guard results is Object(fields) else {
    return if results is (Null | False) { None } else { Some(results) }
  }
  // A `config` key applies to the section of the detected diagram type.
  if fields.get("config") is Some(section) {
    let diagram_type = match detect_type(source) {
      "flowchart-v2" => "flowchart"
      other => other
    }
    let moved = fields.copy()
    moved.remove("config")
    moved[diagram_type] = section
    results = Json::object(moved)
  }
  Some(results)
}

///|
/// Whether `text` carries a `wrap` directive.
fn has_wrap_directive(text : String) -> Bool {
  find_directives(directive_source(text))
  .iter()
  .any(directive => directive.kind.contains("wrap"))
}
