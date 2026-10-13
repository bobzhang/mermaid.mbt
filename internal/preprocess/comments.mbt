///|
/// Remove `%%` comment lines (but not `%%{` directives), together with any
/// blank lines before them, then trim leading whitespace.
fn cleanup_comments(text : String) -> String {
  let n = text.length()
  let out = StringBuilder()
  let mut line_start = 0
  let mut copied = 0
  while line_start < n {
    let mut cursor = line_start
    while cursor < n && is_space_unit(text[cursor]) {
      cursor += 1
    }
    let is_comment = starts_with_at(text, "%%", cursor) &&
      cursor + 2 < n &&
      text[cursor + 2] != '{' &&
      text[cursor + 2] != '\n'
    if is_comment {
      let mut end = cursor + 2
      while end < n && text[end] != '\n' {
        end += 1
      }
      if end < n {
        end += 1
      }
      out.write_view(text[copied:line_start])
      copied = end
      line_start = end
    } else {
      // Move on to the next line start.
      let mut next = line_start
      while next < n && text[next] != '\n' {
        next += 1
      }
      line_start = next + 1
    }
  }
  out.write_view(text[copied:])
  out
  .to_string()
  .trim_start(chars=" \t\n\r\u{0b}\u{0c}\u{a0}\u{feff}")
  .to_owned()
}

///|
/// Replace every `%%` comment up to the end of its line, along with the
/// whitespace before it, by a single line break.
fn strip_any_comments(text : String) -> String {
  let n = text.length()
  let out = StringBuilder()
  let mut consumed = 0
  let mut search_from = 0
  while search_from < n {
    let mut marker = -1
    for i in search_from..<(n - 1) {
      if text[i] == '%' && text[i + 1] == '%' {
        marker = i
        break
      }
    }
    if marker == -1 {
      break
    }
    let mut line_end = -1
    for i in marker..<n {
      if text[i] == '\n' {
        line_end = i
        break
      }
    }
    if line_end == -1 {
      break
    }
    let mut start = marker
    while start > consumed && is_space_unit(text[start - 1]) {
      start -= 1
    }
    out.write_view(text[consumed:start])
    out.write_char('\n')
    consumed = line_end + 1
    search_from = consumed
  }
  out.write_view(text[consumed:])
  out.to_string()
}
