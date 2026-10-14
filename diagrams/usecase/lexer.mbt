// The token patterns of the use case grammar that are functions:
// mermaid's `usecase.tokens.ts`.

///|
fn code_at(text : String, index : Int32) -> Int32 {
  if index >= 0 && index < text.length() {
    text.unsafe_get(index).to_int()
  } else {
    -1
  }
}

///|
/// Whether `expected` is spelled at `offset`.
fn spelled_at(text : String, offset : Int32, expected : String) -> Bool {
  guard offset + expected.length() <= text.length() else { return false }
  for index in 0..<expected.length() {
    if text.unsafe_get(offset + index) != expected.unsafe_get(index) {
      return false
    }
  }
  true
}

///|
/// Where `needle` first appears at or after `from`.
fn index_from(text : String, needle : String, from : Int32) -> Int32? {
  let last = text.length() - needle.length()
  let mut index = from
  while index <= last {
    if spelled_at(text, index, needle) {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
/// Whether only spaces and tabs lie between the start of the line and
/// `offset`: `isIndentedLineStart`.
fn at_line_start(text : String, offset : Int32) -> Bool {
  let mut index = offset - 1
  while index >= 0 {
    match code_at(text, index) {
      '\n' | '\r' => return true
      ' ' | '\t' => ()
      _ => return false
    }
    index -= 1
  }
  true
}

///|
/// How far a line runs from `offset`.
fn line_end(text : String, offset : Int32) -> Int32 {
  let mut end = offset
  while end < text.length() && !(code_at(text, end) is ('\n' | '\r')) {
    end += 1
  }
  end
}

///|
/// A string in double quotes and backticks, which may span lines.
fn match_markdown_string(text : String, offset : Int32) -> Int32? {
  guard spelled_at(text, offset, "\"`") else { return None }
  let mut index = offset + 2
  while index < text.length() - 1 {
    if spelled_at(text, index, "`\"") {
      return Some(index + 2 - offset)
    }
    index += 1
  }
  None
}

///|
/// `%%` at the start of a line, to the end of the line.
fn match_comment(text : String, offset : Int32) -> Int32? {
  guard spelled_at(text, offset, "%%") && at_line_start(text, offset) else {
    return None
  }
  Some(line_end(text, offset + 2) - offset)
}

///|
/// `accTitle: ...` or `accDescr: ...` at the start of a line:
/// `^<keyword>[\t ]*:[^\n\r]*`.
fn match_accessibility_line(
  text : String,
  offset : Int32,
  keyword : String,
) -> Int32? {
  guard at_line_start(text, offset) && spelled_at(text, offset, keyword) else {
    return None
  }
  let mut index = offset + keyword.length()
  while code_at(text, index) is (' ' | '\t') {
    index += 1
  }
  guard code_at(text, index) == ':' else { return None }
  Some(line_end(text, index + 1) - offset)
}

///|
/// `accDescr { ... }` at the start of a line, to the first closing brace.
fn match_acc_descr_block(text : String, offset : Int32) -> Int32? {
  guard at_line_start(text, offset) && spelled_at(text, offset, "accDescr") else {
    return None
  }
  let mut index = offset + 8
  while code_at(text, index) is (' ' | '\t') {
    index += 1
  }
  guard code_at(text, index) == '{' else { return None }
  guard index_from(text, "}", index + 1) is Some(end) else { return None }
  Some(end + 1 - offset)
}

///|
/// A balanced `{ ... }`, braces inside JSON strings not counting.
fn match_json_object(text : String, offset : Int32) -> Int32? {
  guard code_at(text, offset) == '{' else { return None }
  let mut depth = 0
  let mut quoted = false
  let mut escaped = false
  for index in offset..<text.length() {
    let character = code_at(text, index)
    if quoted {
      if escaped {
        escaped = false
      } else if character == '\\' {
        escaped = true
      } else if character == '"' {
        quoted = false
      }
      continue
    }
    if character == '"' {
      quoted = true
    } else if character == '{' {
      depth += 1
    } else if character == '}' {
      depth -= 1
      if depth == 0 {
        return Some(index + 1 - offset)
      }
    }
  }
  None
}

///|
/// JavaScript's `String.prototype.trim` leaves nothing of `text`.
fn is_blank(text : StringView) -> Bool {
  for character in text {
    guard character
      is (' '
      | '\t'
      | '\n'
      | '\r'
      | '\u{0b}'
      | '\u{0c}'
      | '\u{a0}'
      | '\u{1680}'
      | '\u{2000}'..<='\u{200a}'
      | '\u{2028}'
      | '\u{2029}'
      | '\u{202f}'
      | '\u{205f}'
      | '\u{3000}'
      | '\u{feff}') else {
      return false
    }
  }
  true
}

///|
/// What stands between `<<` and the `>>` on the same line, unless blank.
fn match_stereotype_text(text : String, offset : Int32) -> Int32? {
  guard index_from(text, ">>", offset) is Some(end) else { return None }
  guard line_end(text, offset) >= end else { return None }
  if is_blank(text[offset:end]) {
    None
  } else {
    Some(end - offset)
  }
}

///|
/// The token types the generated grammar leaves to functions.
fn custom_token(name : String, text : String, offset : Int32) -> Int32? {
  match name {
    "MARKDOWN_STRING" => match_markdown_string(text, offset)
    "COMMENT" => match_comment(text, offset)
    "ACC_DESCR_BLOCK" => match_acc_descr_block(text, offset)
    "ACC_TITLE_LINE" => match_accessibility_line(text, offset, "accTitle")
    "ACC_DESCR_LINE" => match_accessibility_line(text, offset, "accDescr")
    "JSON_OBJECT_LITERAL" => match_json_object(text, offset)
    "STEREOTYPE_TEXT" => match_stereotype_text(text, offset)
    _ => None
  }
}
