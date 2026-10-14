// Markdown labels: mermaid's `markdownToHTML`, which keeps paragraphs,
// emphasis, escapes and inline HTML of what marked's lexer finds and
// passes everything else through as written.
//
// This follows marked for the constructs labels use. It is not a full
// CommonMark lexer: block constructs other than paragraphs are passed
// through as text.

///|
fn is_md_punctuation(c : Char) -> Bool {
  c is ('!'..<='/' | ':'..<='@' | '['..<='`' | '{'..<='~')
}

///|
fn is_md_space(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\r')
}

///|
/// Whether a line starts a block other than a paragraph. Indented code
/// only counts at the start of a block: it cannot interrupt a paragraph.
fn starts_other_block(line : Array[Char], in_paragraph~ : Bool = false) -> Bool {
  let n = line.length()
  let mut i = 0
  while i < n && line[i] == ' ' {
    i += 1
  }
  if i >= 4 || (i < n && line[i] == '\t') {
    // Indented code.
    return !in_paragraph
  }
  if i >= n {
    return false
  }
  match line[i] {
    '#' => {
      let mut j = i
      while j < n && line[j] == '#' {
        j += 1
      }
      j - i <= 6 && (j == n || is_md_space(line[j]))
    }
    '>' => true
    '`' | '~' => i + 2 < n && line[i + 1] == line[i] && line[i + 2] == line[i]
    '-' | '*' | '+' | '_' => {
      // A bullet, or a thematic break.
      if line[i] != '_' && (i + 1 == n || is_md_space(line[i + 1])) {
        return true
      }
      let mut count = 0
      for k in i..<n {
        if line[k] == line[i] {
          count += 1
        } else if !(line[k] is (' ' | '\t')) {
          return false
        }
      }
      line[i] != '+' && count >= 3
    }
    '0'..<='9' => {
      let mut j = i
      while j < n && line[j] is ('0'..<='9') {
        j += 1
      }
      j - i <= 9 &&
      j < n &&
      line[j] is ('.' | ')') &&
      (j + 1 == n || is_md_space(line[j + 1]))
    }
    _ => false
  }
}

///|
/// An inline token of marked's lexer, as far as labels need them.
priv enum MdToken {
  MdText(String)
  MdStrong(Array[MdToken])
  MdEm(Array[MdToken])
  /// Inline HTML, kept as written.
  MdHtml(String)
  /// A character behind a backslash.
  MdEscape(Char)
  /// Anything else (code spans): written out as it stands in HTML labels
  /// and left out of text labels.
  MdRaw(String)
}

///|
/// A block of markdown: a paragraph, or anything else as raw text.
priv enum MdBlock {
  Paragraph(Array[MdToken])
  Raw(String)
}

///|
/// The inline tokens of a paragraph.
fn inline_tokens(text : Array[Char]) -> Array[MdToken] {
  let out : Array[MdToken] = []
  let pending = StringBuilder()
  let flush = () => {
    if !pending.is_empty() {
      out.push(MdText(pending.to_string()))
      pending.reset()
    }
  }
  let n = text.length()
  let mut i = 0
  while i < n {
    let c = text[i]
    // A backslash before punctuation is an escape.
    if c == '\\' && i + 1 < n && is_md_punctuation(text[i + 1]) {
      flush()
      out.push(MdEscape(text[i + 1]))
      i += 2
      continue
    }
    // Inline HTML is kept.
    if c == '<' &&
      i + 1 < n &&
      text[i + 1] is ('a'..<='z' | 'A'..<='Z' | '/' | '!' | '?') {
      let mut j = i + 1
      while j < n && text[j] != '>' && text[j] != '<' {
        j += 1
      }
      if j < n && text[j] == '>' {
        flush()
        out.push(MdHtml(String::from_array(text[i:j + 1])))
        i = j + 1
        continue
      }
    }
    // Code spans are not supported upstream either.
    if c == '`' {
      let mut ticks = i
      while ticks < n && text[ticks] == '`' {
        ticks += 1
      }
      let run = ticks - i
      let mut j = ticks
      let mut close = -1
      while j < n {
        if text[j] == '`' {
          let mut k = j
          while k < n && text[k] == '`' {
            k += 1
          }
          if k - j == run {
            close = k
            break
          }
          j = k
        } else {
          j += 1
        }
      }
      if close >= 0 {
        flush()
        out.push(MdRaw(String::from_array(text[i:close])))
        i = close
        continue
      }
    }
    if c is ('*' | '_') {
      let mut run_end = i
      while run_end < n && text[run_end] == c {
        run_end += 1
      }
      let run = run_end - i
      let before_alnum = i > 0 &&
        !is_md_space(text[i - 1]) &&
        !is_md_punctuation(text[i - 1])
      let opens = run_end < n &&
        !is_md_space(text[run_end]) &&
        !(c == '_' && before_alnum)
      if opens {
        // The closing run: same character, not after white space, and for
        // underscores not inside a word.
        let mut j = run_end
        let mut close = -1
        let mut close_len = 0
        while j < n {
          if text[j] == '\\' && j + 1 < n {
            j += 2
            continue
          }
          if text[j] == c {
            let mut k = j
            while k < n && text[k] == c {
              k += 1
            }
            let after_alnum = k < n &&
              !is_md_space(text[k]) &&
              !is_md_punctuation(text[k])
            if !is_md_space(text[j - 1]) && !(c == '_' && after_alnum) {
              close = j
              close_len = k - j
              break
            }
            j = k
          } else {
            j += 1
          }
        }
        if close >= 0 {
          let used = if run < close_len { run } else { close_len }
          let used = if used > 3 { 3 } else { used }
          // Unmatched opening delimiters stay text.
          for _ in 0..<(run - used) {
            pending.write_char(c)
          }
          flush()
          let inner = inline_tokens(text[run_end:close].to_owned())
          out.push(
            match used {
              1 => MdEm(inner)
              2 => MdStrong(inner)
              _ => MdEm([MdStrong(inner)])
            },
          )
          i = close + used
          continue
        }
      }
      for _ in 0..<run {
        pending.write_char(c)
      }
      i = run_end
      continue
    }
    pending.write_char(c)
    i += 1
  }
  flush()
  out
}

///|
/// Inline tokens as the HTML of a label.
fn tokens_to_html(
  tokens : Array[MdToken],
  auto_wrap : Bool,
  out : StringBuilder,
) -> Unit {
  for token in tokens {
    match token {
      MdText(text) => {
        // Line breaks, with the indentation after them, become `<br/>`.
        let chars = text.to_array()
        let mut i = 0
        while i < chars.length() {
          if chars[i] == '\n' {
            out.write_string("<br/>")
            i += 1
            while i < chars.length() && chars[i] == ' ' {
              i += 1
            }
          } else {
            if chars[i] == ' ' && !auto_wrap {
              out.write_string("&nbsp;")
            } else {
              out.write_char(chars[i])
            }
            i += 1
          }
        }
      }
      MdStrong(inner) => {
        out.write_string("<strong>")
        tokens_to_html(inner, auto_wrap, out)
        out.write_string("</strong>")
      }
      MdEm(inner) => {
        out.write_string("<em>")
        tokens_to_html(inner, auto_wrap, out)
        out.write_string("</em>")
      }
      MdHtml(text) | MdRaw(text) => out.write_string(text)
      MdEscape(c) => out.write_char(c)
    }
  }
}

///|
/// The blocks of a markdown text.
fn markdown_blocks(markdown : String) -> Array[MdBlock] {
  let source = markdown
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let lines = source
    .split("\n")
    .map(line => line.to_owned().to_array())
    .collect()
  let blocks = []
  let is_blank = (line : Array[Char]) => line.all(c => c is (' ' | '\t'))
  let mut index = 0
  while index < lines.length() {
    if is_blank(lines[index]) {
      index += 1
      continue
    }
    let start = index
    if starts_other_block(lines[index]) {
      // Not a paragraph: passed through as written, up to the blank line.
      while index < lines.length() && !is_blank(lines[index]) {
        index += 1
      }
      let raw = lines[start:index]
        .iter()
        .map(line => String::from_array(line))
        .collect()
        .join("\n")
      // The raw text of a block includes the line break after it.
      blocks.push(Raw(if index < lines.length() { raw + "\n" } else { raw }))
      continue
    }
    index += 1
    while index < lines.length() &&
          !is_blank(lines[index]) &&
          !starts_other_block(lines[index], in_paragraph=true) {
      index += 1
    }
    let text : Array[Char] = []
    for k in start..<index {
      if k > start {
        text.push('\n')
      }
      // The indentation of a line after the first does not count; the
      // spaces the paragraph starts and ends with are part of its text.
      let line = lines[k]
      let mut skip = 0
      while k > start && skip < line.length() && line[skip] is (' ' | '\t') {
        skip += 1
      }
      for position in skip..<line.length() {
        text.push(line[position])
      }
    }
    blocks.push(Paragraph(inline_tokens(text)))
  }
  blocks
}

///|
/// Markdown to the HTML of a label.
fn markdown_to_html(markdown : String, auto_wrap : Bool) -> String {
  let out = StringBuilder()
  for block in markdown_blocks(markdown) {
    match block {
      Paragraph(tokens) => {
        out.write_string("<p>")
        tokens_to_html(tokens, auto_wrap, out)
        out.write_string("</p>")
      }
      Raw(text) => out.write_string(text)
    }
  }
  out.to_string()
}
