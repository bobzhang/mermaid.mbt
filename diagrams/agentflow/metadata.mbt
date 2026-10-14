// The `@{ ... }` metadata blocks: YAML, read more forgivingly than the
// flowchart reads them.

///|
/// Drop the keys that could pollute a prototype in JavaScript, at every
/// level: mermaid's `stripPrototypeKeys`.
fn strip_prototype_keys(value : Json) -> Json {
  match value {
    Array(items) => Json::array(items.map(strip_prototype_keys))
    Object(fields) => {
      let clean : Map[String, Json] = Map([])
      for key, field in fields {
        if key is ("__proto__" | "constructor" | "prototype") {
          continue
        }
        clean[key] = strip_prototype_keys(field)
      }
      Json::object(clean)
    }
    other => other
  }
}

///|
/// The number of leading whitespace characters of a line, as JavaScript's
/// `trimStart` counts them.
fn indent_of(line : String) -> Int32 {
  line.length() - line.trim_start().length()
}

///|
/// A block-scalar header at the end of a line: `key: |`, `key: >-2`.
let block_scalar_header : @jsregex.Regex = try! @jsregex.Regex::compile(
  ":\\s*[>|][\\d+-]*\\s*$",
)

///|
/// A comma closing a line, with the blanks after it.
let trailing_comma : @jsregex.Regex = try! @jsregex.Regex::compile(
  ",([\\t ]*)$",
)

///|
/// Remove a comma at the end of each line of a multi-line block, outside
/// quotes, flow collections, comments and block scalars, so that a block
/// written like a JavaScript object still reads as YAML: mermaid's
/// `stripLineTrailingCommas`.
fn strip_line_trailing_commas(body : String) -> String {
  let mut in_single = false
  let mut in_double = false
  let mut flow_depth = 0
  let mut block_scalar_indent : Int32? = None
  let out : Array[String] = []
  for view in body.split("\n") {
    let line = view.to_owned()
    if block_scalar_indent is Some(indent) {
      if line.trim() == "" || indent_of(line) > indent {
        out.push(line)
        continue
      }
      block_scalar_indent = None
    }
    let mut comment_start = -1
    let n = line.length()
    let mut i = 0
    while i < n {
      let ch = line[i]
      if in_double {
        if ch == '\\' {
          i += 1
        } else if ch == '"' {
          in_double = false
        }
      } else if in_single {
        if ch == '\'' {
          in_single = false
        }
      } else if ch == '"' {
        in_double = true
      } else if ch == '\'' {
        in_single = true
      } else if ch == '#' &&
        (i == 0 || line[i - 1] == ' ' || line[i - 1] == '\t') {
        comment_start = i
        break
      } else if ch == '[' || ch == '{' {
        flow_depth += 1
      } else if ch == ']' || ch == '}' {
        flow_depth = (flow_depth - 1).max(0)
      }
      i += 1
    }
    if in_single || in_double || flow_depth > 0 {
      out.push(line)
      continue
    }
    let code = if comment_start >= 0 {
      line[:comment_start].to_owned()
    } else {
      line
    }
    let comment = if comment_start >= 0 {
      line[comment_start:].to_owned()
    } else {
      ""
    }
    if block_scalar_header.matches(code) {
      block_scalar_indent = Some(indent_of(line))
      out.push(line)
      continue
    }
    out.push(
      trailing_comma.replace_all(code, m => m.group(1).unwrap_or("")) + comment,
    )
  }
  out.join("\n")
}

///|
/// The fields of an `@{ ... }` block. A multi-line block that is not YAML
/// is tried again without the commas at the ends of its lines. A document
/// that is not a mapping has no fields.
fn parse_shape_data(metadata : String) -> Map[String, Json] raise {
  let doc = @flowchart.parse_metadata(metadata) catch {
    error => {
      let stripped = if metadata.contains("\n") {
        strip_line_trailing_commas(metadata)
      } else {
        metadata
      }
      if stripped == metadata {
        raise error
      }
      @flowchart.parse_metadata(stripped) catch {
        _ => raise error
      }
    }
  }
  match strip_prototype_keys(doc) {
    Object(fields) => fields
    _ => Map([])
  }
}
